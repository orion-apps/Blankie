//
//  AudioManagerTests.swift
//  Blankie
//
//  Created by Cody Bromley on 1/10/25.
//

import XCTest

@testable import Blankie

@MainActor
final class AudioManagerTests: XCTestCase {
  var audioManager: AudioManager!

  override func setUp() async throws {
    try await super.setUp()
    audioManager = AudioManager.shared
    // Ensure we start with a clean state
    GlobalSettings.shared.setAlwaysStartPaused(false)
    audioManager.resetSounds()
  }

  override func tearDown() async throws {
    // Reset to default state
    GlobalSettings.shared.setAlwaysStartPaused(true)
    audioManager.resetSounds()
    try await super.tearDown()
  }

  func testInitialState() async throws {
    XCTAssertFalse(audioManager.isGloballyPlaying)
    XCTAssertFalse(audioManager.sounds.isEmpty)
  }

  func testTogglePlayback() async throws {
    // Setup: Select a sound and verify initial state
    XCTAssertFalse(audioManager.isGloballyPlaying)
    audioManager.sounds[0].isSelected = true

    // Test direct state changes
    audioManager.setGlobalPlaybackState(true)
    XCTAssertTrue(audioManager.isGloballyPlaying, "Should be playing after setting state to true")

    audioManager.setGlobalPlaybackState(false)
    XCTAssertFalse(
      audioManager.isGloballyPlaying, "Should not be playing after setting state to false")
  }

  func testIngestRemoteMetadataDoesNotAffectBundledPlaybackArray() async throws {
    let originalCount = audioManager.sounds.count

    let remote = ServerSoundMetadata(
      id: "remote-1",
      title: "Forest Stream",
      remoteAudioURL: URL(string: "https://sounds.serenescapes.app/audio/forest-stream.m4a")!,
      sourceServerID: "primary"
    )

    audioManager.ingestRemoteMetadata([remote])

    XCTAssertEqual(audioManager.sounds.count, originalCount)
    XCTAssertEqual(audioManager.remoteSoundCatalog.count, 1)
    XCTAssertEqual(audioManager.remoteSoundCatalog.first?.id, "remote-1")
  }

  func testIngestRemoteMetadataUpdatesContentMode() async throws {
    audioManager.ingestRemoteMetadata([])
    XCTAssertEqual(AppState.shared.contentMode, .bundledOnly)

    audioManager.ingestRemoteMetadata([
      ServerSoundMetadata(
        id: "remote-3",
        title: "Harbor Wind",
        remoteAudioURL: URL(string: "https://sounds.serenescapes.app/audio/harbor-wind.m4a")!,
        sourceServerID: "primary"
      )
    ])

    XCTAssertEqual(AppState.shared.contentMode, .hybrid)
  }

  func testMergedLibraryEntriesCombinesBundledAndRemoteWithoutChangingPlaybackSounds() async throws {
    let bundled = [
      SoundData(
        defaultOrder: 0,
        title: "Rain",
        systemIconName: "cloud.rain",
        fileName: "rain",
        author: "A",
        authorUrl: nil,
        license: "ccBy4",
        editor: nil,
        editorUrl: nil,
        soundUrl: "https://example.com/rain",
        soundName: "Rain"
      )
    ]

    audioManager.ingestRemoteMetadata([
      ServerSoundMetadata(
        id: "remote-2",
        title: "Ocean",
        remoteAudioURL: URL(string: "https://sounds.serenescapes.app/audio/ocean.m4a")!,
        sourceServerID: "primary"
      )
    ])

    let merged = audioManager.mergedLibraryEntries(bundledData: bundled)

    XCTAssertEqual(merged.count, 2)
    XCTAssertEqual(audioManager.sounds.contains(where: { $0.fileName == "ocean" }), false)
  }

  func testResetSounds() async throws {
    // Select some sounds and adjust volumes
    audioManager.sounds[0].isSelected = true
    audioManager.sounds[0].volume = 0.5

    audioManager.resetSounds()

    // Verify all sounds are reset
    for sound in audioManager.sounds {
      XCTAssertFalse(sound.isSelected)
      XCTAssertEqual(sound.volume, 1.0)
    }
  }
}
