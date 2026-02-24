//
//  AudioManager.swift
//  SereneScapes
//
//  Created by Cody Bromley on 12/30/24.
//  Converted to iOS by SereneScapes team.
//

import AVFoundation
import Combine
import MediaPlayer
import SwiftUI
import UIKit

class AudioManager: ObservableObject {
  final class RemoteDownloadDelegate: NSObject, URLSessionDownloadDelegate, URLSessionTaskDelegate {
    var onProgress: ((Int, Double) -> Void)?
    var onFinish: ((Int, URL) -> Void)?
    var onError: ((Int, Error?) -> Void)?
    var onDidFinishEvents: (() -> Void)?

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
      guard totalBytesExpectedToWrite > 0 else { return }
      let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
      onProgress?(downloadTask.taskIdentifier, progress)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
      onFinish?(downloadTask.taskIdentifier, location)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
      if error != nil {
        onError?(task.taskIdentifier, error)
      }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
      onDidFinishEvents?()
    }
  }
  enum RemoteDownloadState: String, Codable {
    case notDownloaded
    case queued
    case downloading
    case completed
    case failed
  }

  struct RemoteDownloadStatus: Codable {
    var state: RemoteDownloadState
    var progress: Double
    var updatedAt: Date
  }

  struct RemoteTrackMixSettings: Codable {
    var volume: Float
    var pan: Float
  }

  private var cancellables = Set<AnyCancellable>()
  static let shared = AudioManager()
  var onReset: (() -> Void)?

  @Published var sounds: [Sound] = []
  @Published private(set) var remoteSoundCatalog: [ServerSoundMetadata] = []
  @Published private(set) var isGloballyPlaying: Bool = false
  @Published private(set) var isRefreshingCatalog: Bool = false
  @Published private(set) var lastCatalogSourceLabel: String = "none"
  @Published private(set) var remoteDownloadStatus: [String: RemoteDownloadStatus] = [:]
  @Published private(set) var currentlyPlayingRemoteID: String?
  @Published private(set) var selectedRemoteTrackIDs: Set<String> = []
  @Published private(set) var remoteTrackMix: [String: RemoteTrackMixSettings] = [:]

  private let commandCenter = MPRemoteCommandCenter.shared()
  private var nowPlayingInfo: [String: Any] = [:]
  private var isInitializing = true
  private let contentManager = ContentManager()
  private var remoteDownloadTasks: [String: Task<Void, Never>] = [:]
  private var remotePreviewPlayer: AVAudioPlayer?
  private var remotePlayers: [String: AVAudioPlayer] = [:]
  private let remoteDownloadStatusKey = "remoteDownloadStatus"
  private let remoteTrackMixKey = "remoteTrackMix"
  private let remoteDownloadDelegate = RemoteDownloadDelegate()
  private var remoteTaskToID: [Int: String] = [:]
  private var backgroundSessionCompletionHandler: (() -> Void)?
  private lazy var backgroundDownloadSession: URLSession = {
    let config = URLSessionConfiguration.background(withIdentifier: "com.orioninternetservices.blankie.remote-downloads")
    config.sessionSendsLaunchEvents = true
    config.isDiscretionary = false
    return URLSession(configuration: config, delegate: remoteDownloadDelegate, delegateQueue: nil)
  }()

  private init() {
    print("🎵 AudioManager: Initializing")
    setupAudioSession()
    loadSounds()
    loadSavedState()
    setupNowPlaying()
    setupMediaControls()
    setupNotificationObservers()
    setupSoundObservers()
    loadRemoteDownloadStatus()
    loadRemoteTrackMix()
    setupRemoteDownloadCallbacks()
    recoverInterruptedDownloads()

    // Handle autoplay behavior after a slight delay to ensure proper initialization
    Task { @MainActor in
      // Short delay to allow everything to initialize
      try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

      self.isInitializing = false

      // Default to bundled mode until remote content check completes.
      AppState.shared.setContentMode(.bundledOnly, message: "Using built-in sounds")
      await self.refreshRemoteCatalog()

      if !GlobalSettings.shared.alwaysStartPaused {
        let hasSelectedSounds = self.sounds.contains { $0.isSelected }
        if hasSelectedSounds {
          // Set initial state
          self.isGloballyPlaying = true

          // Start playback
          self.playSelected()

          // Update Now Playing info with preset name
          if let currentPreset = PresetManager.shared.currentPreset {
            self.updateNowPlayingInfo(presetName: currentPreset.name)
          } else {
            self.updateNowPlayingInfo()
          }
        }
      } else {
        // Ensure we're in a paused state
        self.isGloballyPlaying = false
        self.updateNowPlayingInfo()
      }
    }
  }

  private func setupAudioSession() {
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try audioSession.setActive(true)
      print("🎵 AudioManager: Audio session configured for background playback")
    } catch {
      print("❌ AudioManager: Failed to setup audio session: \(error)")
    }
  }

  private func setupSoundObservers() {
    // Clear any existing observers
    cancellables.removeAll()
    // Set up new observers for each sound
    for sound in sounds {
      sound.objectWillChange
        .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
        .sink { [weak self] _ in
          guard self != nil else { return }
          Task { @MainActor in
            PresetManager.shared.updateCurrentPresetState()
          }
        }
        .store(in: &cancellables)
    }
  }

  func setPlaybackState(_ playing: Bool, forceUpdate: Bool = false) {
    guard !isInitializing || forceUpdate else {
      print("🎵 AudioManager: Ignoring setPlaybackState during initialization")
      return
    }
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      if self.isGloballyPlaying != playing {
        print(
          "🎵 AudioManager: Setting playback state to \(playing) - Current global state: \(self.isGloballyPlaying)"
        )
        self.isGloballyPlaying = playing

        if playing {
          self.playSelected()
        } else {
          self.pauseAll()
        }
        self.updateNowPlayingInfo()
      } else {
        print("🎵 AudioManager: setPlaybackState called, but state is the same \(playing), ignoring")
      }
    }
  }

  private func loadSounds() {
    print("🎵 AudioManager: Loading sounds from JSON")
    let bundlePath = Bundle.main.bundlePath
    print("📦 Bundle path: \(bundlePath)")

    if let resourcePath = Bundle.main.resourcePath {
      print("📂 Resource path: \(resourcePath)")
      do {
        let resources = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
        print("📑 Resources in bundle: \(resources)")
      } catch {
        print("❌ Error listing resources: \(error)")
      }
    }

    guard let url = Bundle.main.url(forResource: "sounds", withExtension: "json") else {
      print("❌ AudioManager: sounds.json file not found in Resources folder")
      ErrorReporter.shared.report(AudioError.fileNotFound)
      return
    }

    do {
      let data = try Data(contentsOf: url)
      let decoder = JSONDecoder()
      let soundsContainer = try decoder.decode(SoundsContainer.self, from: data)

      self.sounds = soundsContainer.sounds
        .sorted(by: { $0.defaultOrder < $1.defaultOrder })
        .map { soundData in
          let supportedExtensions = ["wav", "m4a", "mp3", "aiff"]
          let fileExtension =
            supportedExtensions.first { soundData.fileName.hasSuffix(".\($0)") } ?? "mp3"
          let cleanedFileName = soundData.fileName.replacingOccurrences(
            of: ".\(fileExtension)", with: "")

          return Sound(
            title: soundData.title,
            systemIconName: soundData.systemIconName,
            fileName: cleanedFileName,
            fileExtension: fileExtension
          )
        }
    } catch {
      print("❌ AudioManager: Failed to parse sounds.json: \(error)")
      ErrorReporter.shared.report(error)
    }
  }

  func ingestRemoteMetadata(_ metadata: [ServerSoundMetadata]) {
    remoteSoundCatalog = metadata
    reconcileDownloadStatusesWithLocalFiles()

    if metadata.isEmpty {
      AppState.shared.setContentMode(.bundledOnly, message: "Using built-in sounds")
    } else {
      AppState.shared.setContentMode(.hybrid, message: "Using built-in + online catalog")
    }
  }

  func refreshRemoteCatalog() async {
    await MainActor.run { isRefreshingCatalog = true }
    defer {
      Task { @MainActor in
        self.isRefreshingCatalog = false
      }
    }

    do {
      let result = try await contentManager.fetchManifest()
      ingestRemoteMetadata(result.remoteSoundCatalog)

      if result.source == .cache {
        await MainActor.run { lastCatalogSourceLabel = "cache" }
        AppState.shared.appendTelemetry("[AudioManager] Loaded remote catalog from cache", level: .info)
      } else {
        await MainActor.run { lastCatalogSourceLabel = "network" }
        AppState.shared.appendTelemetry("[AudioManager] Loaded remote catalog from network", level: .info)
      }

      if result.warning == .staleCacheUsed {
        AppState.shared.appendTelemetry("[AudioManager] Using stale cached catalog fallback", level: .warning)
      }
    } catch {
      ingestRemoteMetadata([])
      await MainActor.run { lastCatalogSourceLabel = "failed" }
      AppState.shared.setContentMode(.bundledOnly, message: "Online catalog unavailable — using built-in sounds")
      AppState.shared.appendTelemetry("[AudioManager] Remote catalog refresh failed: \(error)", level: .warning)
    }
  }

  func mergedLibraryEntries(bundledData: [SoundData]) -> [SoundLibraryEntry] {
    var seen = Set<String>()
    let bundled = bundledData.filter { seen.insert($0.fileName).inserted }.map { SoundLibraryEntry.bundled($0) }
    let remote = remoteSoundCatalog.filter { seen.insert($0.id).inserted }.map { SoundLibraryEntry.remote($0) }
    return bundled + remote
  }

  func downloadStatus(for remoteID: String) -> RemoteDownloadStatus {
    remoteDownloadStatus[remoteID] ?? RemoteDownloadStatus(state: .notDownloaded, progress: 0, updatedAt: Date())
  }

  @MainActor
  func startRemoteDownload(id: String) {
    guard let remote = remoteSoundCatalog.first(where: { $0.id == id }) else {
      updateRemoteDownload(id: id, state: .failed, progress: 0)
      AppState.shared.appendTelemetry("[AudioManager] Download failed: missing remote metadata for \(id)", level: .error)
      return
    }

    remoteDownloadTasks[id]?.cancel()
    updateRemoteDownload(id: id, state: .queued, progress: 0)

    let request = URLRequest(url: remote.remoteAudioURL)
    let task = backgroundDownloadSession.downloadTask(with: request)
    remoteTaskToID[task.taskIdentifier] = id
    task.resume()

    updateRemoteDownload(id: id, state: .downloading, progress: 0.01)
    AppState.shared.appendTelemetry("[AudioManager] Started background download for \(remote.title)", level: .info)
  }

  @MainActor
  func retryRemoteDownload(id: String) {
    startRemoteDownload(id: id)
  }

  @MainActor
  func setRemoteTrackSelected(id: String, isSelected: Bool) {
    if remoteTrackMix[id] == nil {
      remoteTrackMix[id] = RemoteTrackMixSettings(volume: 1.0, pan: 0.0)
    }

    if isSelected {
      selectedRemoteTrackIDs.insert(id)
      playDownloadedRemote(id: id)
    } else {
      selectedRemoteTrackIDs.remove(id)
      stopDownloadedRemotePlayback(id: id)
    }
    persistRemoteTrackMix()
  }

  func remoteMixSettings(for id: String) -> RemoteTrackMixSettings {
    remoteTrackMix[id] ?? RemoteTrackMixSettings(volume: 1.0, pan: 0.0)
  }

  @MainActor
  func updateRemoteTrackMix(id: String, volume: Float? = nil, pan: Float? = nil) {
    var current = remoteTrackMix[id] ?? RemoteTrackMixSettings(volume: 1.0, pan: 0.0)
    if let volume { current.volume = min(max(volume, 0), 1) }
    if let pan { current.pan = min(max(pan, -1), 1) }
    remoteTrackMix[id] = current

    if let player = remotePlayers[id] {
      player.volume = current.volume * Float(GlobalSettings.shared.volume)
      player.pan = current.pan
    }
    persistRemoteTrackMix()
  }

  @MainActor
  func applyRemotePresetStates(_ states: [RemotePresetState]) async -> [String] {
    let targetSelected = Set(states.filter { $0.isSelected }.map { $0.remoteID })
    let availableIDs = Set(remoteSoundCatalog.map { $0.id })

    for state in states {
      remoteTrackMix[state.remoteID] = RemoteTrackMixSettings(volume: state.volume, pan: state.pan)
    }
    persistRemoteTrackMix()

    let missing = Array(targetSelected.subtracting(availableIDs))

    // Stop remote tracks not selected by this preset.
    for id in selectedRemoteTrackIDs.subtracting(targetSelected) {
      stopDownloadedRemotePlayback(id: id)
    }

    selectedRemoteTrackIDs = targetSelected.subtracting(Set(missing))

    for id in selectedRemoteTrackIDs {
      playDownloadedRemote(id: id)
    }

    return missing
  }

  @MainActor
  func playDownloadedRemote(id: String) {
    guard let remote = remoteSoundCatalog.first(where: { $0.id == id }) else { return }
    let fileURL = localFileURL(for: remote)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      AppState.shared.appendTelemetry("[AudioManager] Cannot play remote item; file missing for \(remote.title)", level: .warning)
      return
    }

    do {
      // Pause bundled loop playback when first remote track begins.
      if remotePlayers.isEmpty {
        pauseAll()
        isGloballyPlaying = false
      }

      let mix = remoteMixSettings(for: id)
      let player = try AVAudioPlayer(contentsOf: fileURL)
      player.numberOfLoops = -1
      player.volume = mix.volume * Float(GlobalSettings.shared.volume)
      player.pan = mix.pan
      player.prepareToPlay()
      player.play()
      remotePlayers[id] = player

      remotePreviewPlayer = player
      currentlyPlayingRemoteID = id
      AppState.shared.appendTelemetry("[AudioManager] Playing downloaded remote track: \(remote.title)", level: .info)
    } catch {
      AppState.shared.appendTelemetry("[AudioManager] Failed to play remote track \(remote.title): \(error.localizedDescription)", level: .error)
    }
  }

  @MainActor
  func stopDownloadedRemotePlayback(id: String? = nil) {
    if let id {
      let targetPlayer = remotePlayers[id]
      targetPlayer?.stop()
      remotePlayers[id] = nil
      selectedRemoteTrackIDs.remove(id)
      if currentlyPlayingRemoteID == id {
        currentlyPlayingRemoteID = remotePlayers.keys.first
      }
      if let targetPlayer, remotePreviewPlayer === targetPlayer {
        remotePreviewPlayer = nil
      }
      return
    }

    remotePlayers.values.forEach { $0.stop() }
    remotePlayers.removeAll()
    remotePreviewPlayer?.stop()
    remotePreviewPlayer = nil
    currentlyPlayingRemoteID = nil
    selectedRemoteTrackIDs.removeAll()
  }

  @MainActor
  func removeRemoteDownload(id: String) {
    remoteDownloadTasks[id]?.cancel()
    remoteDownloadTasks[id] = nil
    cancelBackgroundDownload(id: id)

    if currentlyPlayingRemoteID == id {
      stopDownloadedRemotePlayback()
    }

    if let remote = remoteSoundCatalog.first(where: { $0.id == id }) {
      try? FileManager.default.removeItem(at: localFileURL(for: remote))
    }

    updateRemoteDownload(id: id, state: .notDownloaded, progress: 0)
  }

  @MainActor
  func failRemoteDownloadForDebug(id: String) {
    remoteDownloadTasks[id]?.cancel()
    remoteDownloadTasks[id] = nil
    cancelBackgroundDownload(id: id)
    updateRemoteDownload(id: id, state: .failed, progress: 0)
  }

  private func cancelBackgroundDownload(id: String) {
    backgroundDownloadSession.getAllTasks { [weak self] tasks in
      guard let self else { return }
      for task in tasks where self.remoteTaskToID[task.taskIdentifier] == id {
        task.cancel()
        self.remoteTaskToID[task.taskIdentifier] = nil
      }
    }
  }

  @MainActor
  private func updateRemoteDownload(id: String, state: RemoteDownloadState, progress: Double) {
    remoteDownloadStatus[id] = RemoteDownloadStatus(state: state, progress: progress, updatedAt: Date())
    persistRemoteDownloadStatus()
  }

  private func persistRemoteDownloadStatus() {
    guard let data = try? JSONEncoder().encode(remoteDownloadStatus) else { return }
    UserDefaults.standard.set(data, forKey: remoteDownloadStatusKey)
  }

  private func loadRemoteDownloadStatus() {
    guard let data = UserDefaults.standard.data(forKey: remoteDownloadStatusKey),
          let decoded = try? JSONDecoder().decode([String: RemoteDownloadStatus].self, from: data) else {
      return
    }
    remoteDownloadStatus = decoded
  }

  private func persistRemoteTrackMix() {
    guard let data = try? JSONEncoder().encode(remoteTrackMix) else { return }
    UserDefaults.standard.set(data, forKey: remoteTrackMixKey)
  }

  private func loadRemoteTrackMix() {
    guard let data = UserDefaults.standard.data(forKey: remoteTrackMixKey),
          let decoded = try? JSONDecoder().decode([String: RemoteTrackMixSettings].self, from: data) else {
      return
    }
    remoteTrackMix = decoded
  }

  func handleBackgroundSessionEvents(identifier: String, completionHandler: @escaping () -> Void) {
    guard identifier == "com.orioninternetservices.blankie.remote-downloads" else {
      completionHandler()
      return
    }

    backgroundSessionCompletionHandler = completionHandler
    AppState.shared.appendTelemetry("[AudioManager] Received background session wake: \(identifier)", level: .info)
  }

  private func setupRemoteDownloadCallbacks() {
    remoteDownloadDelegate.onProgress = { [weak self] taskID, progress in
      guard let self, let remoteID = self.remoteTaskToID[taskID] else { return }
      Task { @MainActor in
        self.updateRemoteDownload(id: remoteID, state: .downloading, progress: progress)
      }
    }

    remoteDownloadDelegate.onFinish = { [weak self] taskID, tempLocation in
      guard let self, let remoteID = self.remoteTaskToID[taskID],
            let remote = self.remoteSoundCatalog.first(where: { $0.id == remoteID }) else { return }
      do {
        let destination = self.localFileURL(for: remote)
        try FileManager.default.createDirectory(at: self.remoteAudioDirectoryURL(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) {
          try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: tempLocation, to: destination)

        Task { @MainActor in
          self.updateRemoteDownload(id: remoteID, state: .completed, progress: 1.0)
          self.remoteTaskToID[taskID] = nil
          AppState.shared.appendTelemetry("[AudioManager] Background download completed for \(remote.title)", level: .info)
        }
      } catch {
        Task { @MainActor in
          self.updateRemoteDownload(id: remoteID, state: .failed, progress: 0)
          self.remoteTaskToID[taskID] = nil
          AppState.shared.appendTelemetry("[AudioManager] Background download move failed for \(remote.title)", level: .error)
        }
      }
    }

    remoteDownloadDelegate.onError = { [weak self] taskID, error in
      guard let self, let remoteID = self.remoteTaskToID[taskID] else { return }
      Task { @MainActor in
        self.updateRemoteDownload(id: remoteID, state: .failed, progress: 0)
        self.remoteTaskToID[taskID] = nil
        AppState.shared.appendTelemetry("[AudioManager] Background download failed for \(remoteID): \(error?.localizedDescription ?? "unknown")", level: .warning)
      }
    }

    remoteDownloadDelegate.onDidFinishEvents = { [weak self] in
      guard let self else { return }
      Task { @MainActor in
        self.backgroundSessionCompletionHandler?()
        self.backgroundSessionCompletionHandler = nil
      }
    }
  }

  private func recoverInterruptedDownloads() {
    let interrupted = remoteDownloadStatus
      .filter { $0.value.state == .queued || $0.value.state == .downloading }
      .map { $0.key }

    guard !interrupted.isEmpty else { return }

    AppState.shared.appendTelemetry("[AudioManager] Recovering \(interrupted.count) interrupted downloads", level: .info)

    Task { @MainActor in
      for id in interrupted {
        retryRemoteDownload(id: id)
      }
    }
  }

  private func remoteAudioDirectoryURL() -> URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory())
    return docs.appendingPathComponent("RemoteAudio", isDirectory: true)
  }

  private func localFileURL(for remote: ServerSoundMetadata) -> URL {
    let ext = remote.remoteAudioURL.pathExtension.isEmpty ? "m4a" : remote.remoteAudioURL.pathExtension
    return remoteAudioDirectoryURL().appendingPathComponent("\(remote.id).\(ext)")
  }

  private func saveRemoteAudioData(_ data: Data, for remote: ServerSoundMetadata) throws {
    let dir = remoteAudioDirectoryURL()
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let destination = localFileURL(for: remote)
    try data.write(to: destination, options: .atomic)
  }

  private func reconcileDownloadStatusesWithLocalFiles() {
    var changed = false
    for remote in remoteSoundCatalog {
      let fileExists = FileManager.default.fileExists(atPath: localFileURL(for: remote).path)
      let current = remoteDownloadStatus[remote.id]?.state ?? .notDownloaded
      if fileExists && current != .completed {
        remoteDownloadStatus[remote.id] = RemoteDownloadStatus(state: .completed, progress: 1.0, updatedAt: Date())
        changed = true
      } else if !fileExists && current == .completed {
        remoteDownloadStatus[remote.id] = RemoteDownloadStatus(state: .notDownloaded, progress: 0, updatedAt: Date())
        changed = true
      }
    }

    if changed { persistRemoteDownloadStatus() }
  }

  private func setupMediaControls() {
    print("🎵 AudioManager: Setting up media controls")
    // Remove all previous handlers
    commandCenter.playCommand.removeTarget(nil)
    commandCenter.pauseCommand.removeTarget(nil)
    commandCenter.togglePlayPauseCommand.removeTarget(nil)

    // Add handlers
    commandCenter.playCommand.addTarget { [weak self] _ in
      print("🎵 AudioManager: Media key play command received")
      Task { @MainActor in
        self?.togglePlayback()
      }
      return .success
    }
    commandCenter.pauseCommand.addTarget { [weak self] _ in
      print("🎵 AudioManager: Media key pause command received")
      Task { @MainActor in
        self?.togglePlayback()
      }
      return .success
    }
    commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
      print("🎵 AudioManager: Media key toggle command received")
      Task { @MainActor in
        self?.togglePlayback()
      }
      return .success
    }
  }

  // Update playSelected to check global state
  private func playSelected() {
    print("🎵 AudioManager: Playing selected sounds")
    guard isGloballyPlaying else {
      print("🎵 AudioManager: Not playing sounds because global playback is disabled")
      return
    }

    for sound in sounds where sound.isSelected {
      print("  - Playing '\(sound.fileName)'")
      sound.play()
    }

    for remoteID in selectedRemoteTrackIDs {
      Task { @MainActor in
        self.playDownloadedRemote(id: remoteID)
      }
    }

    // Update Now Playing info with current preset name
    if let currentPreset = PresetManager.shared.currentPreset {
      self.updateNowPlayingInfo(presetName: currentPreset.name)
    } else {
      self.updateNowPlayingInfo()
    }
  }

  private func loadSavedState() {
    guard let state = UserDefaults.standard.array(forKey: "soundState") as? [[String: Any]] else {
      return
    }
    for savedState in state {
      guard let fileName = savedState["fileName"] as? String,
        let sound = sounds.first(where: { $0.fileName == fileName })
      else {
        continue
      }
      sound.isSelected = savedState["isSelected"] as? Bool ?? false
      sound.volume = savedState["volume"] as? Float ?? 1.0
    }
  }

  private func setupNowPlaying() {
    print("🎵 AudioManager: Setting up Now Playing info")
    nowPlayingInfo[MPMediaItemPropertyTitle] = "Ambient Sounds"
    nowPlayingInfo[MPMediaItemPropertyArtist] = "SereneScapes"

    if let url = Bundle.main.url(forResource: "NowPlaying", withExtension: "png"),
      let image = UIImage(contentsOfFile: url.path)
    {
      let artwork = MPMediaItemArtwork(boundsSize: image.size) { size in
        return image
      }
      nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
    }
    updatePlaybackState()
  }

  public func updateNowPlayingInfo(presetName: String? = nil) {
    var nowPlayingInfo = [String: Any]()

    // Get the current preset name for the title
    let displayTitle: String
    if let name = presetName {
      // Only use preset name if it's not "Default" or doesn't start with "Preset "
      if name != "Default" && !name.starts(with: "Preset ") {
        displayTitle = name
      } else {
        displayTitle = "Ambient Sounds"
      }
    } else {
      displayTitle = "Ambient Sounds"
    }

    // Build subtitle from active sound names
    let activeSoundNames = sounds.filter { $0.isSelected }.map { $0.title }
    let subtitle: String
    switch activeSoundNames.count {
    case 0:
      subtitle = "SereneScapes"
    case 1...3:
      subtitle = activeSoundNames.joined(separator: ", ")
    default:
      subtitle = "\(activeSoundNames.prefix(2).joined(separator: ", ")) +\(activeSoundNames.count - 2) more"
    }

    print("🎵 AudioManager: Updating Now Playing — title: \(displayTitle), subtitle: \(subtitle)")

    nowPlayingInfo[MPMediaItemPropertyTitle] = displayTitle
    nowPlayingInfo[MPMediaItemPropertyArtist] = subtitle
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isGloballyPlaying ? 1.0 : 0.0

    if let url = Bundle.main.url(forResource: "NowPlaying", withExtension: "png"),
      let image = UIImage(contentsOfFile: url.path)
    {
      let artwork = MPMediaItemArtwork(boundsSize: image.size) { size in
        return image
      }
      nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
    }

    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
  }

  func updateNowPlayingState() async {
    let playbackRate: Double = isGloballyPlaying ? 1.0 : 0.0
    print(
      "🎵 AudioManager: Updating now playing state to \(isGloballyPlaying), playbackRate: \(playbackRate)"
    )

    // Update volume through GlobalSettings
    await GlobalSettings.shared.setVolume(isGloballyPlaying ? 1.0 : 0.0)
  }

  private func updatePlaybackState() {
    // Update playback state
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isGloballyPlaying ? 1.0 : 0.0
    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 0  // Infinite for ambient sounds
    // Update the now playing info
    print(
      "🎵 AudioManager: Updating now playing state to \(isGloballyPlaying), "
        + "playbackRate: \(nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? -1)"
    )
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
  }

  private func setupNotificationObservers() {
    NotificationCenter.default.addObserver(
      forName: UIApplication.willTerminateNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.handleAppTermination()
    }

    // Audio interruption handling (phone calls, Siri, alarms, etc.)
    NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { [weak self] notification in
      self?.handleInterruption(notification)
    }

    // Route change handling (headphones unplugged, Bluetooth disconnected)
    NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { [weak self] notification in
      self?.handleRouteChange(notification)
    }
  }

  /// Track whether we were playing before an interruption so we can resume
  private var wasPlayingBeforeInterruption = false

  private func handleInterruption(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue)
    else { return }

    switch type {
    case .began:
      print("🎵 AudioManager: Audio interruption began (phone call, Siri, etc.)")
      wasPlayingBeforeInterruption = isGloballyPlaying
      if isGloballyPlaying {
        Task { @MainActor in
          self.pauseAll()
          // Don't change isGloballyPlaying — we want to remember we were playing
        }
      }

    case .ended:
      print("🎵 AudioManager: Audio interruption ended")
      guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
      let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

      if options.contains(.shouldResume) && wasPlayingBeforeInterruption {
        print("🎵 AudioManager: Resuming playback after interruption")
        Task { @MainActor in
          // Reactivate the audio session
          do {
            try AVAudioSession.sharedInstance().setActive(true)
          } catch {
            print("❌ AudioManager: Failed to reactivate audio session: \(error)")
          }
          self.setGlobalPlaybackState(true, forceUpdate: true)
        }
      }
      wasPlayingBeforeInterruption = false

    @unknown default:
      print("🎵 AudioManager: Unknown interruption type")
    }
  }

  private func handleRouteChange(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
    else { return }

    switch reason {
    case .oldDeviceUnavailable:
      // Headphones unplugged or Bluetooth disconnected — pause (standard iOS behavior)
      print("🎵 AudioManager: Audio route lost (headphones unplugged?) — pausing")
      Task { @MainActor in
        self.setGlobalPlaybackState(false)
      }

    case .newDeviceAvailable:
      print("🎵 AudioManager: New audio device connected")
      // Don't auto-resume — let the user decide

    default:
      break
    }
  }

  private func handleAppTermination() {
    print("🎵 AudioManager: App is terminating, cleaning up")
    cleanup()
  }

  private func cleanup() {
    pauseAll()
    remotePlayers.values.forEach { $0.stop() }
    remotePlayers.removeAll()
    remotePreviewPlayer?.stop()
    remotePreviewPlayer = nil
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    print("🎵 AudioManager: Cleanup complete")
  }

  func pauseAll() {
    print("🎵 AudioManager: Pausing all sounds")
    print("  - Current global play state: \(isGloballyPlaying)")

    sounds.forEach { sound in
      if sound.isSelected {
        print("  - Pausing '\(sound.fileName)'")
        sound.pause()
      }
    }

    remotePlayers.values.forEach { $0.pause() }

    print("🎵 AudioManager: Pause all complete")
  }

  func saveState() {
    let state = sounds.map { sound in
      [
        "id": sound.id.uuidString,
        "fileName": sound.fileName,
        "isSelected": sound.isSelected,
        "volume": sound.volume,
      ]
    }
    UserDefaults.standard.set(state, forKey: "soundState")
  }

  /// Toggles the playback state of all selected sounds
  @MainActor func togglePlayback() {
    print("🎵 AudioManager: Toggling playback")
    print("  - Current state (pre-toggle): \(isGloballyPlaying)")
    setGlobalPlaybackState(!isGloballyPlaying)
    print("  - New state (post-toggle): \(isGloballyPlaying)")
  }

  @MainActor
  func resetSounds() {
    print("🎵 AudioManager: Resetting all sounds")

    // First pause all sounds immediately
    sounds.forEach { sound in
      print("  - Stopping '\(sound.fileName)'")
      sound.pause(immediate: true)
    }
    setPlaybackState(false)
    // Reset all sounds
    sounds.forEach { sound in
      sound.volume = 1.0
      sound.isSelected = false
    }
    // Reset global volume
    GlobalSettings.shared.setVolume(1.0)

    // Call the reset callback
    onReset?()
    print("🎵 AudioManager: Reset complete")
  }

  // Public method for changing playback state
  @MainActor
  public func setGlobalPlaybackState(_ playing: Bool, forceUpdate: Bool = false) {
    guard !isInitializing || forceUpdate else {
      print("🎵 AudioManager: Ignoring setPlaybackState during initialization")
      return
    }

    print(
      "🎵 AudioManager: Setting playback state to \(playing) - Current global state: \(self.isGloballyPlaying)"
    )

    // Update state first
    self.isGloballyPlaying = playing

    // Then handle playback
    if playing {
      self.playSelected()
    } else {
      self.pauseAll()
    }

    // Always update Now Playing info with current preset name
    if let currentPreset = PresetManager.shared.currentPreset {
      self.updateNowPlayingInfo(presetName: currentPreset.name)
    } else {
      self.updateNowPlayingInfo()
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    cleanup()
    print("🎵 AudioManager: Deinit called, cleanup performed")
  }
}
