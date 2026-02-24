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
    let sounds: [RemoteSound]

    enum CodingKeys: String, CodingKey {
      case identifier = "id"
      case displayName = "name"
      case baseURL
      case summary
      case sounds
    }

    init(identifier: String, displayName: String, baseURL: URL, summary: String?, sounds: [RemoteSound] = []) {
      self.identifier = identifier
      self.displayName = displayName
      self.baseURL = baseURL
      self.summary = summary
      self.sounds = sounds
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
      let sounds = try container.decodeIfPresent([RemoteSound].self, forKey: .sounds) ?? []

      self.init(identifier: identifier, displayName: displayName, baseURL: baseURL, summary: summary, sounds: sounds)
    }

    func validate() throws {
      // Base validation is handled during decoding. This method exists for future expansion.
    }
  }

  struct RemoteSound: Decodable, Equatable {
    let id: String
    let title: String
    let audioURL: URL
    let thumbnailURL: URL?
    let heroImageURL: URL?
    let metadata: [String: String]

    enum CodingKeys: String, CodingKey {
      case id
      case title
      case audioURL
      case thumbnailURL
      case heroImageURL
      case metadata
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)

      guard let id = try container.decodeIfPresent(String.self, forKey: .id), !id.isEmpty else {
        throw ManifestValidationError.missingRequiredField("servers[].sounds[].id")
      }

      guard let title = try container.decodeIfPresent(String.self, forKey: .title), !title.isEmpty else {
        throw ManifestValidationError.missingRequiredField("servers[].sounds[].title")
      }

      guard let audioURL = try container.decodeIfPresent(URL.self, forKey: .audioURL) else {
        throw ManifestValidationError.missingRequiredField("servers[].sounds[].audioURL")
      }

      self.id = id
      self.title = title
      self.audioURL = audioURL
      self.thumbnailURL = try container.decodeIfPresent(URL.self, forKey: .thumbnailURL)
      self.heroImageURL = try container.decodeIfPresent(URL.self, forKey: .heroImageURL)
      self.metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
    }
  }
}
