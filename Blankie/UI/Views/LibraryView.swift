import SwiftUI

struct LibraryView: View {
    @ObservedObject private var audioManager = AudioManager.shared
    @State private var searchText = ""

    private var bundled: [Sound] {
        if searchText.isEmpty { return audioManager.sounds }
        return audioManager.sounds.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var remote: [ServerSoundMetadata] {
        if searchText.isEmpty { return audioManager.remoteSoundCatalog }
        return audioManager.remoteSoundCatalog.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private func statusLabel(_ state: AudioManager.RemoteDownloadState) -> String {
        switch state {
        case .notDownloaded: return "Not downloaded"
        case .queued: return "Queued"
        case .downloading: return "Downloading"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }

    var body: some View {
        List {
            Section("Catalog Status") {
                HStack {
                    Text("Source")
                    Spacer()
                    Text(audioManager.lastCatalogSourceLabel)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Built-in")
                    Spacer()
                    Text("\(audioManager.sounds.count)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Online")
                    Spacer()
                    Text("\(audioManager.remoteSoundCatalog.count)")
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await audioManager.refreshRemoteCatalog() }
                } label: {
                    HStack {
                        if audioManager.isRefreshingCatalog { ProgressView() }
                        Text(audioManager.isRefreshingCatalog ? "Refreshing…" : "Refresh Library")
                    }
                }
                .disabled(audioManager.isRefreshingCatalog)
            }

            Section("Downloaded / Built-in") {
                if bundled.isEmpty {
                    Text("No built-in sounds")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(bundled) { sound in
                        HStack {
                            Text(sound.title)
                            Spacer()
                            Text("Built-in")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Available Online") {
                if remote.isEmpty {
                    Text("No online catalog items right now")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(remote, id: \.id) { item in
                        let status = audioManager.downloadStatus(for: item.id)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                    Text(item.sourceServerID)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(statusLabel(status.state))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            if status.state == .queued || status.state == .downloading {
                                ProgressView(value: status.progress)
                            }

                            HStack(spacing: 10) {
                                switch status.state {
                                case .notDownloaded:
                                    Button("Download") {
                                        Task { @MainActor in
                                            audioManager.startRemoteDownload(id: item.id)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                case .queued, .downloading:
                                    Button("Mark Failed") {
                                        Task { @MainActor in
                                            audioManager.failRemoteDownloadForDebug(id: item.id)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                case .failed:
                                    Button("Retry") {
                                        Task { @MainActor in
                                            audioManager.retryRemoteDownload(id: item.id)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                case .completed:
                                    Button(audioManager.currentlyPlayingRemoteID == item.id ? "Stop" : "Play") {
                                        Task { @MainActor in
                                            if audioManager.currentlyPlayingRemoteID == item.id {
                                                audioManager.stopDownloadedRemotePlayback()
                                            } else {
                                                audioManager.playDownloadedRemote(id: item.id)
                                            }
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)

                                    Button("Remove") {
                                        Task { @MainActor in
                                            audioManager.removeRemoteDownload(id: item.id)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .searchable(text: $searchText)
        .navigationTitle("Library")
    }
}
