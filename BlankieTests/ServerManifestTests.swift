//
//  ServerManifestTests.swift
//  BlankieTests
//
//  Created by Codex on 2/24/26.
//

import XCTest

@testable import Blankie

final class ServerManifestTests: XCTestCase {
  private let decoder = JSONDecoder()

  func testDecodeAndValidateWithValidManifest() throws {
    let json = """
    {
      "schemaVersion": 1,
      "servers": [
        {
          "id": "primary",
          "name": "Primary",
          "baseURL": "https://api.blankie.rest",
          "summary": "Production instance"
        },
        {
          "id": "beta",
          "name": "Beta",
          "baseURL": "https://beta.blankie.rest"
        }
      ]
    }
    """

    let data = try XCTUnwrap(json.data(using: .utf8))
    let manifest = try decoder.decode(ServerManifest.self, from: data)

    XCTAssertEqual(manifest.schemaVersion, 1)
    XCTAssertEqual(manifest.servers.count, 2)
    XCTAssertNoThrow(try manifest.validate())
  }

  func testValidateFailsForDuplicateIdentifiers() throws {
    let json = """
    {
      "schemaVersion": 1,
      "servers": [
        {
          "id": "shared",
          "name": "Primary",
          "baseURL": "https://api.blankie.rest"
        },
        {
          "id": "shared",
          "name": "Backup",
          "baseURL": "https://backup.blankie.rest"
        }
      ]
    }
    """

    let data = try XCTUnwrap(json.data(using: .utf8))
    let manifest = try decoder.decode(ServerManifest.self, from: data)

    XCTAssertThrowsError(try manifest.validate()) { error in
      XCTAssertEqual(
        error as? ManifestValidationError,
        .duplicateServerIdentifiers(["shared"])
      )
    }
  }

  func testDecoderThrowsForMissingRequiredField() {
    let json = """
    {
      "servers": [
        {
          "id": "primary",
          "name": "Primary",
          "baseURL": "https://api.blankie.rest"
        }
      ]
    }
    """

    let data = json.data(using: .utf8)!

    XCTAssertThrowsError(try decoder.decode(ServerManifest.self, from: data)) { error in
      XCTAssertEqual(
        error as? ManifestValidationError,
        .missingRequiredField("schemaVersion")
      )
    }
  }

  func testValidateFailsForUnsupportedSchemaVersion() throws {
    let json = """
    {
      "schemaVersion": 2,
      "servers": [
        {
          "id": "primary",
          "name": "Primary",
          "baseURL": "https://api.blankie.rest"
        }
      ]
    }
    """

    let data = try XCTUnwrap(json.data(using: .utf8))
    let manifest = try decoder.decode(ServerManifest.self, from: data)

    XCTAssertThrowsError(try manifest.validate()) { error in
      XCTAssertEqual(
        error as? ManifestValidationError,
        .unsupportedSchemaVersion(found: 2)
      )
    }
  }
}
