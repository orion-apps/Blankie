import Foundation

enum ServerSoundDownloadState: Equatable {
  case notDownloaded
  case downloaded(localFileName: String)
}

struct ServerSoundMetadata: Equatable, Identifiable {
  let id: String
  let title: String
  let remoteAudioURL: URL
  let sourceServerID: String
  let thumbnailURL: URL?
  let heroImageURL: URL?
  let metadata: [String: String]
  var downloadState: ServerSoundDownloadState

  init(
    id: String,
    title: String,
    remoteAudioURL: URL,
    sourceServerID: String,
    thumbnailURL: URL? = nil,
    heroImageURL: URL? = nil,
    metadata: [String: String] = [:],
    downloadState: ServerSoundDownloadState = .notDownloaded
  ) {
    self.id = id
    self.title = title
    self.remoteAudioURL = remoteAudioURL
    self.sourceServerID = sourceServerID
    self.thumbnailURL = thumbnailURL
    self.heroImageURL = heroImageURL
    self.metadata = metadata
    self.downloadState = downloadState
  }
}

enum SoundLibraryEntry {
  case bundled(SoundData)
  case remote(ServerSoundMetadata)
}
