import XCTest

@testable import Blankie

private final class MockContentSession: ContentNetworkSession {
  enum Mode {
    case success(Data)
    case failure(Error)
  }

  var mode: Mode

  init(mode: Mode) {
    self.mode = mode
  }

  func data(from url: URL) async throws -> (Data, URLResponse) {
    switch mode {
    case .success(let data):
      return (data, URLResponse(url: url, mimeType: "application/json", expectedContentLength: data.count, textEncodingName: nil))
    case .failure(let error):
      throw error
    }
  }
}

final class ContentManagerTests: XCTestCase {
  private var cacheDirectory: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    cacheDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: cacheDirectory)
    cacheDirectory = nil
    try super.tearDownWithError()
  }

  func testFetchFromNetworkWritesCache() async throws {
    let json = validManifestJSON(id: "primary")
    let session = MockContentSession(mode: .success(json))
    let manager = makeManager(session: session)

    let result = try await manager.fetchManifest()

    XCTAssertEqual(result.source, .network)
    XCTAssertNil(result.warning)
    XCTAssertEqual(result.manifest.schemaVersion, 1)
    XCTAssertEqual(result.manifest.servers.first?.identifier, "primary")
  }

  func testUsesFreshCacheWithinTTL() async throws {
    let session = MockContentSession(mode: .success(validManifestJSON(id: "cached")))
    var currentTime = Date()
    let manager = makeManager(session: session, now: { currentTime })

    _ = try await manager.fetchManifest()

    currentTime = currentTime.addingTimeInterval(30)
    session.mode = .failure(URLError(.timedOut))

    let cached = try await manager.fetchManifest()
    XCTAssertEqual(cached.source, .cache)
    XCTAssertNil(cached.warning)
    XCTAssertEqual(cached.manifest.servers.first?.identifier, "cached")
  }

  func testFallsBackToCacheWhenNetworkFails() async throws {
    let session = MockContentSession(mode: .success(validManifestJSON(id: "old")))
    var currentTime = Date()
    let manager = makeManager(session: session, now: { currentTime }, ttl: 1)

    _ = try await manager.fetchManifest()

    currentTime = currentTime.addingTimeInterval(120)
    session.mode = .failure(URLError(.cannotConnectToHost))

    let result = try await manager.fetchManifest()
    XCTAssertEqual(result.source, .cache)
    XCTAssertEqual(result.warning, .staleCacheUsed)
    XCTAssertEqual(result.manifest.servers.first?.identifier, "old")
  }

  func testFailsWithNoCacheWhenNetworkFails() async {
    let session = MockContentSession(mode: .failure(URLError(.notConnectedToInternet)))
    let manager = makeManager(session: session)

    do {
      _ = try await manager.fetchManifest()
      XCTFail("Expected failure")
    } catch {
      XCTAssertEqual(error as? ContentManagerError, .networkFailureNoCache)
    }
  }

  func testInvalidManifestVersionFailsWithoutCache() async {
    let session = MockContentSession(mode: .success(invalidVersionJSON()))
    let manager = makeManager(session: session)

    do {
      _ = try await manager.fetchManifest()
      XCTFail("Expected failure")
    } catch {
      XCTAssertEqual(error as? ContentManagerError, .invalidManifestNoCache)
    }
  }

  private func makeManager(
    session: ContentNetworkSession,
    now: @escaping () -> Date = Date.init,
    ttl: TimeInterval = 3600
  ) -> ContentManager {
    ContentManager(
      manifestURL: URL(string: "https://sounds.serenescapes.app/manifest.json")!,
      cacheTTL: ttl,
      session: session,
      cacheDirectory: cacheDirectory,
      now: now
    )
  }

  private func validManifestJSON(id: String) -> Data {
    """
    {
      "schemaVersion": 1,
      "servers": [
        {
          "id": "\(id)",
          "name": "Primary",
          "baseURL": "https://api.blankie.rest"
        }
      ]
    }
    """.data(using: .utf8)!
  }

  private func invalidVersionJSON() -> Data {
    """
    {
      "schemaVersion": 2,
      "servers": [
        {
          "id": "bad",
          "name": "Primary",
          "baseURL": "https://api.blankie.rest"
        }
      ]
    }
    """.data(using: .utf8)!
  }
}
