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
}

enum ContentManagerError: Error, Equatable {
  case networkFailureNoCache
  case invalidManifestNoCache
  case cacheReadFailed
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
      return ManifestFetchResult(manifest: cached.manifest, source: .cache, warning: nil)
    }

    do {
      let (data, _) = try await session.data(from: manifestURL)
      let manifest = try decodeAndValidate(data: data)
      try saveCache(payload: data, fetchedAt: now())
      return ManifestFetchResult(manifest: manifest, source: .network, warning: nil)
    } catch let error as ManifestValidationError {
      if let cached = try loadCachedManifest() {
        return ManifestFetchResult(manifest: cached.manifest, source: .cache, warning: .staleCacheUsed)
      }
      _ = error
      throw ContentManagerError.invalidManifestNoCache
    } catch {
      if let cached = try loadCachedManifest() {
        return ManifestFetchResult(manifest: cached.manifest, source: .cache, warning: .staleCacheUsed)
      }
      throw ContentManagerError.networkFailureNoCache
    }
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
}
