//
//  Preset.swift
//  Blankie
//
//  Created by Cody Bromley on 1/1/25.
//

import SwiftUI

struct Preset: Codable, Identifiable, Equatable {
  let id: UUID
  var name: String
  var soundStates: [PresetState]
  var remoteStates: [RemotePresetState]
  let isDefault: Bool

  enum CodingKeys: String, CodingKey {
    case id, name, soundStates, remoteStates, isDefault
  }

  init(id: UUID, name: String, soundStates: [PresetState], remoteStates: [RemotePresetState] = [], isDefault: Bool) {
    self.id = id
    self.name = name
    self.soundStates = soundStates
    self.remoteStates = remoteStates
    self.isDefault = isDefault
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    soundStates = try container.decode([PresetState].self, forKey: .soundStates)
    remoteStates = try container.decodeIfPresent([RemotePresetState].self, forKey: .remoteStates) ?? []
    isDefault = try container.decode(Bool.self, forKey: .isDefault)
  }

  static func == (lhs: Preset, rhs: Preset) -> Bool {
    lhs.id == rhs.id && lhs.name == rhs.name && lhs.soundStates == rhs.soundStates
      && lhs.remoteStates == rhs.remoteStates && lhs.isDefault == rhs.isDefault
  }

  func validate() -> Bool {
    // Check required sound states
    let requiredSounds = AudioManager.shared.sounds.map(\.fileName)
    let presetSounds = Set(soundStates.map(\.fileName))

    guard requiredSounds.allSatisfy(presetSounds.contains) else {
      print("❌ Preset: Missing required sounds")
      return false
    }

    // Validate volume ranges
    guard soundStates.allSatisfy({ $0.volume >= 0 && $0.volume <= 1 }) else {
      print("❌ Preset: Invalid volume range")
      return false
    }

    // Validate name
    guard !name.isEmpty else {
      print("❌ Preset: Empty name")
      return false
    }

    return true
  }
}
