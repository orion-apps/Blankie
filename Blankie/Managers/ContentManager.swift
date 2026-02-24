import Foundation

protocol ContentNetworkSession {
  func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: ContentNetworkSession {}

enum ManifestSource: Equatable {
  case network
  case cache
}

enum ManifestFetchWarning: Equatable {
  case staleCacheUsed
}

struct ManifestFetchResult {
  let manifest: ServerManifest
  let source: ManifestSource
  let warning: ManifestFetchWarning?

  var remoteSoundCatalog: [ServerSoundMetadata] {
    manifest.remoteSoundCatalog()
  }
}

enum ContentManagerError: Error, Equatable {
  case networkFailureNoCache
  case invalidManifestNoCache
  case cacheReadFailed
}

private extension URLError.Code {
  var isTransientManifestFailure: Bool {
    switch self {
    case .timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed, .resourceUnavailable:
      return true
    default:
      return false
    }
  }
}

final class ContentManager {
  static let defaultManifestURL = URL(string: "https://sounds.serenescapes.app/manifest.json")!
  static let defaultCacheTTL: TimeInterval = 3600

  private struct CachedManifest: Codable {
    let fetchedAt: Date
    let payload: Data
  }

  private let session: ContentNetworkSession
  private let manifestURL: URL
  private let cacheTTL: TimeInterval
  private let cacheFileURL: URL
  private let now: () -> Date
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()
  private let maxAttempts = 3
  private let requestTimeout: TimeInterval = 8

  init(
    manifestURL: URL = ContentManager.defaultManifestURL,
    cacheTTL: TimeInterval = ContentManager.defaultCacheTTL,
    session: ContentNetworkSession = URLSession.shared,
    cacheDirectory: URL? = nil,
    now: @escaping () -> Date = Date.init
  ) {
    self.manifestURL = manifestURL
    self.cacheTTL = cacheTTL
    self.session = session
    self.now = now

    if let cacheDirectory {
      self.cacheFileURL = cacheDirectory.appendingPathComponent("server-manifest-cache.json")
    } else {
      let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        ?? URL(fileURLWithPath: NSTemporaryDirectory())
      self.cacheFileURL = base.appendingPathComponent("server-manifest-cache.json")
    }
  }

  func fetchManifest() async throws -> ManifestFetchResult {
    if let cached = try loadCachedManifest(), isFresh(cachedDate: cached.fetchedAt) {
      emitTelemetry("Manifest loaded from fresh cache", level: .info)
      return ManifestFetchResult(manifest: cached.manifest, source: .cache, warning: nil)
    }

    do {
      let data = try await fetchManifestDataWithRetry()
      let manifest = try decodeAndValidate(data: data)
      try saveCache(payload: data, fetchedAt: now())
      print("[ContentManager] manifest fetch success source=network")
      emitTelemetry("Manifest fetch success from network", level: .info)
      return ManifestFetchResult(manifest: manifest, source: .network, warning: nil)
    } catch let error as ManifestValidationError {
      if let cached = try loadCachedManifest() {
        emitTelemetry("Manifest invalid; using stale cache fallback", level: .warning)
        return ManifestFetchResult(manifest: cached.manifest, source: .cache, warning: .staleCacheUsed)
      }
      _ = error
      emitTelemetry("Manifest invalid and no cache available", level: .error)
      throw ContentManagerError.invalidManifestNoCache
    } catch {
      if let cached = try loadCachedManifest() {
        emitTelemetry("Manifest network failure; using stale cache fallback", level: .warning)
        return ManifestFetchResult(manifest: cached.manifest, source: .cache, warning: .staleCacheUsed)
      }
      emitTelemetry("Manifest network failure and no cache available", level: .error)
      throw ContentManagerError.networkFailureNoCache
    }
  }

  private func fetchManifestDataWithRetry() async throws -> Data {
    var attempt = 0
    var lastError: Error?

    while attempt < maxAttempts {
      attempt += 1
      do {
        let (data, _) = try await withTimeout(seconds: requestTimeout) { [self] in
          try await self.session.data(from: self.manifestURL)
        }
        if attempt > 1 {
          print("[ContentManager] manifest fetch recovered on attempt=\(attempt)")
        }
        return data
      } catch {
        lastError = error
        let shouldRetry = isRetryable(error: error)
        if shouldRetry && attempt < maxAttempts {
          let backoffNs = UInt64(Double(250_000_000) * pow(2.0, Double(attempt - 1)))
          try? await Task.sleep(nanoseconds: backoffNs)
          continue
        }
        throw error
      }
    }

    throw lastError ?? URLError(.unknown)
  }

  private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
      group.addTask { try await operation() }
      group.addTask {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        throw URLError(.timedOut)
      }

      let result = try await group.next()!
      group.cancelAll()
      return result
    }
  }

  private func isRetryable(error: Error) -> Bool {
    if let urlError = error as? URLError {
      return urlError.code.isTransientManifestFailure
    }
    return false
  }

  private func isFresh(cachedDate: Date) -> Bool {
    now().timeIntervalSince(cachedDate) <= cacheTTL
  }

  private func decodeAndValidate(data: Data) throws -> ServerManifest {
    let manifest = try decoder.decode(ServerManifest.self, from: data)
    try manifest.validate()
    return manifest
  }

  private func loadCachedManifest() throws -> (manifest: ServerManifest, fetchedAt: Date)? {
    guard FileManager.default.fileExists(atPath: cacheFileURL.path) else { return nil }

    do {
      let data = try Data(contentsOf: cacheFileURL)
      let cached = try decoder.decode(CachedManifest.self, from: data)
      let manifest = try decodeAndValidate(data: cached.payload)
      return (manifest, cached.fetchedAt)
    } catch {
      throw ContentManagerError.cacheReadFailed
    }
  }

  private func saveCache(payload: Data, fetchedAt: Date) throws {
    let cached = CachedManifest(fetchedAt: fetchedAt, payload: payload)
    let data = try encoder.encode(cached)
    let directory = cacheFileURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try data.write(to: cacheFileURL, options: .atomic)
  }

  private func emitTelemetry(_ message: String, level: AppState.ContentTelemetryLevel) {
    Task { @MainActor in
      AppState.shared.appendTelemetry("[ContentManager] \(message)", level: level)
    }
  }
}

extension ServerManifest {
  func remoteSoundCatalog() -> [ServerSoundMetadata] {
    servers.flatMap { server in
      server.sounds.map {
        ServerSoundMetadata(
          id: $0.id,
          title: $0.title,
          remoteAudioURL: $0.audioURL,
          sourceServerID: server.identifier,
          thumbnailURL: $0.thumbnailURL,
          heroImageURL: $0.heroImageURL,
          metadata: $0.metadata,
          downloadState: .notDownloaded
        )
      }
    }
  }

  func mergedLibraryEntries(with bundled: [SoundData]) -> [SoundLibraryEntry] {
    let remote = remoteSoundCatalog()
    var seen = Set<String>()

    let bundledEntries = bundled.filter { seen.insert($0.fileName).inserted }.map { SoundLibraryEntry.bundled($0) }
    let remoteEntries = remote.filter { seen.insert($0.id).inserted }.map { SoundLibraryEntry.remote($0) }

    return bundledEntries + remoteEntries
  }
}
