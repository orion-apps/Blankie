//
//  ServerManifest.swift
//  Blankie
//
//  Created by Codex on 2/24/26.
//

import Foundation

enum ManifestValidationError: Error, Equatable {
  case unsupportedSchemaVersion(found: Int)
  case missingRequiredField(_ field: String)
  case duplicateServerIdentifiers([String])
}

struct ServerManifest: Decodable, Equatable {
  let schemaVersion: Int
  let servers: [Server]

  func validate() throws {
    guard schemaVersion == 1 else {
      throw ManifestValidationError.unsupportedSchemaVersion(found: schemaVersion)
    }

    var seenIdentifiers = Set<String>()
    var duplicateIdentifiers = Set<String>()

    try servers.forEach { server in
      try server.validate()
      let wasInserted = seenIdentifiers.insert(server.identifier).inserted
      if !wasInserted {
        duplicateIdentifiers.insert(server.identifier)
      }
    }

    if !duplicateIdentifiers.isEmpty {
      let sortedIdentifiers = duplicateIdentifiers.sorted()
      throw ManifestValidationError.duplicateServerIdentifiers(sortedIdentifiers)
    }
  }

  enum CodingKeys: String, CodingKey {
    case schemaVersion
    case servers
  }

  init(schemaVersion: Int, servers: [Server]) {
    self.schemaVersion = schemaVersion
    self.servers = servers
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    guard let schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) else {
      throw ManifestValidationError.missingRequiredField("schemaVersion")
    }

    guard let servers = try container.decodeIfPresent([Server].self, forKey: .servers) else {
      throw ManifestValidationError.missingRequiredField("servers")
    }

    self.init(schemaVersion: schemaVersion, servers: servers)
  }
}

extension ServerManifest {
  struct Server: Decodable, Equatable {
    let identifier: String
    let displayName: String
    let baseURL: URL
    let summary: String?

    enum CodingKeys: String, CodingKey {
      case identifier = "id"
      case displayName = "name"
      case baseURL
      case summary
    }

    init(identifier: String, displayName: String, baseURL: URL, summary: String?) {
      self.identifier = identifier
      self.displayName = displayName
      self.baseURL = baseURL
      self.summary = summary
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)

      guard let identifier = try container.decodeIfPresent(String.self, forKey: .identifier), !identifier.isEmpty else {
        throw ManifestValidationError.missingRequiredField("servers[].id")
      }

      guard let displayName = try container.decodeIfPresent(String.self, forKey: .displayName), !displayName.isEmpty else {
        throw ManifestValidationError.missingRequiredField("servers[].name")
      }

      guard let baseURL = try container.decodeIfPresent(URL.self, forKey: .baseURL) else {
        throw ManifestValidationError.missingRequiredField("servers[].baseURL")
      }

      let summary = try container.decodeIfPresent(String.self, forKey: .summary)

      self.init(identifier: identifier, displayName: displayName, baseURL: baseURL, summary: summary)
    }

    func validate() throws {
      // Base validation is handled during decoding. This method exists for future expansion.
    }
  }
}
