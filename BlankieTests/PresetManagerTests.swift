//
//  PresetManagerTests.swift
//  Blankie
//
//  Created by Cody Bromley on 1/10/25.
//

import XCTest

@testable import Blankie

final class PresetManagerTests: XCTestCase {
  var presetManager: PresetManager!

  override func setUp() {
    super.setUp()
    presetManager = PresetManager.shared
  }

  override func tearDown() async throws {
    // Clean up test presets
    await MainActor.run {
      presetManager.presets
        .filter { !$0.isDefault }
        .forEach { presetManager.deletePreset($0) }
    }
    try await super.tearDown()
  }

  func testCreateNewPreset() async throws {
    let presetName = "Test Preset"

    await MainActor.run {
      presetManager.saveNewPreset(name: presetName)
      XCTAssertTrue(presetManager.presets.contains { $0.name == presetName })
    }
  }

  func testDeletePreset() async throws {
    let presetName = "Test Delete"

    await MainActor.run {
      presetManager.saveNewPreset(name: presetName)

      if let preset = presetManager.presets.first(where: { $0.name == presetName }) {
        presetManager.deletePreset(preset)
        XCTAssertFalse(presetManager.presets.contains { $0.name == presetName })
      } else {
        XCTFail("Failed to create test preset")
      }
    }
  }

  func testUpdatePreset() async throws {
    let originalName = "Original Name"
    let newName = "Updated Name"

    await MainActor.run {
      presetManager.saveNewPreset(name: originalName)

      if let preset = presetManager.presets.first(where: { $0.name == originalName }) {
        presetManager.updatePreset(preset, newName: newName)
        XCTAssertTrue(presetManager.presets.contains { $0.name == newName })
        XCTAssertFalse(presetManager.presets.contains { $0.name == originalName })
      } else {
        XCTFail("Failed to create test preset")
      }
    }
  }

  func testDuplicatePresetNameGetsUniqued() async throws {
    await MainActor.run {
      presetManager.saveNewPreset(name: "Evening")
      presetManager.saveNewPreset(name: "Evening")

      XCTAssertTrue(presetManager.presets.contains { $0.name == "Evening" })
      XCTAssertTrue(presetManager.presets.contains { $0.name == "Evening 2" })
    }
  }

  func testOverwriteCurrentPresetFromCurrentState() async throws {
    await MainActor.run {
      presetManager.saveNewPreset(name: "Mutable")
      guard let created = presetManager.presets.first(where: { $0.name == "Mutable" }) else {
        XCTFail("Missing created preset")
        return
      }

      try? presetManager.applyPreset(created)

      if let firstSound = AudioManager.shared.sounds.first {
        firstSound.isSelected = true
        firstSound.volume = 0.42
      }

      let didUpdate = presetManager.overwriteCurrentPresetFromCurrentState()
      XCTAssertTrue(didUpdate)

      guard let updated = presetManager.currentPreset,
            let firstState = updated.soundStates.first else {
        XCTFail("Missing updated preset state")
        return
      }

      XCTAssertEqual(firstState.isSelected, true)
      XCTAssertEqual(firstState.volume, 0.42, accuracy: 0.001)
    }
  }

  func testApplyPresetWarnsForMissingSoundFiles() async throws {
    let preset = Preset(
      id: UUID(),
      name: "Broken",
      soundStates: [
        PresetState(fileName: "definitely_missing_sound", isSelected: true, volume: 1.0)
      ],
      isDefault: false
    )

    await MainActor.run {
      try? presetManager.applyPreset(preset)
    }

    try? await Task.sleep(nanoseconds: 250_000_000)

    await MainActor.run {
      XCTAssertNotNil(presetManager.lastApplyWarning)
      XCTAssertTrue(presetManager.lastApplyWarning?.contains("definitely_missing_sound") == true)
    }
  }
}
