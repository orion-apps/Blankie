import SwiftUI

struct LibraryView: View {
    enum RemoteFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case downloaded = "Downloaded"
        case notDownloaded = "Not Downloaded"
        var id: String { rawValue }
    }

    @ObservedObject private var audioManager = AudioManager.shared
    @State private var searchText = ""
    @State private var remoteFilter: RemoteFilter = .all

    private var bundled: [Sound] {
        if searchText.isEmpty { return audioManager.sounds }
        return audioManager.sounds.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var remote: [ServerSoundMetadata] {
        let base: [ServerSoundMetadata]
        if searchText.isEmpty {
            base = audioManager.remoteSoundCatalog
        } else {
            base = audioManager.remoteSoundCatalog.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        return base
            .filter { item in
                let state = audioManager.downloadStatus(for: item.id).state
                switch remoteFilter {
                case .all: return true
                case .downloaded: return state == .completed
                case .notDownloaded: return state != .completed
                }
            }
            .sorted { lhs, rhs in
                let lCompleted = audioManager.downloadStatus(for: lhs.id).state == .completed
                let rCompleted = audioManager.downloadStatus(for: rhs.id).state == .completed
                if lCompleted != rCompleted { return lCompleted && !rCompleted }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
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

    @ViewBuilder
    private func statusBadge(_ state: AudioManager.RemoteDownloadState) -> some View {
        let (text, color): (String, Color) = switch state {
        case .notDownloaded: ("Available", .secondary)
        case .queued: ("Queued", .orange)
        case .downloading: ("Downloading", .blue)
        case .completed: ("Downloaded", .green)
        case .failed: ("Failed", .red)
        }
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
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
                        HStack(spacing: 12) {
                            Image(systemName: sound.systemIconName)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .foregroundStyle(Color.accentColor)

                            Text(sound.title)
                            Spacer()
                            Text("Built-in")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Section("Available Online") {
                Picker("Remote Filter", selection: $remoteFilter) {
                    ForEach(RemoteFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                if remote.isEmpty {
                    Text("No online catalog items for current filter")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(remote, id: \.id) { item in
                        let status = audioManager.downloadStatus(for: item.id)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                // Thumbnail
                                if let thumbURL = item.thumbnailURL {
                                    AsyncImage(url: thumbURL) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        case .failure:
                                            Image(systemName: "waveform")
                                                .foregroundStyle(.secondary)
                                        case .empty:
                                            ProgressView()
                                        @unknown default:
                                            Image(systemName: "waveform")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    Image(systemName: "waveform")
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                        .background(Color.secondary.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .foregroundStyle(.secondary)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .lineLimit(1)
                                    HStack(spacing: 6) {
                                        Text(item.sourceServerID)
                                        if let duration = item.metadata["duration"] {
                                            Text("•")
                                            Text(duration)
                                        }
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                statusBadge(status.state)
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
                                    .accessibilityLabel("Download \(item.title)")
                                    .accessibilityHint("Double tap to download this sound")
                                case .queued, .downloading:
                                    Button("Cancel") {
                                        Task { @MainActor in
                                            audioManager.removeRemoteDownload(id: item.id)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityLabel("Cancel download of \(item.title)")
                                case .failed:
                                    Button("Retry") {
                                        Task { @MainActor in
                                            audioManager.retryRemoteDownload(id: item.id)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .accessibilityLabel("Retry download of \(item.title)")
                                case .completed:
                                    Button(audioManager.currentlyPlayingRemoteID == item.id ? "Stop" : "Play") {
                                        Task { @MainActor in
                                            if audioManager.currentlyPlayingRemoteID == item.id {
                                                audioManager.stopDownloadedRemotePlayback(id: item.id)
                                            } else {
                                                audioManager.playDownloadedRemote(id: item.id)
                                            }
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .accessibilityLabel(audioManager.currentlyPlayingRemoteID == item.id ? "Stop playing \(item.title)" : "Play \(item.title)")

                                    Button("Remove") {
                                        Task { @MainActor in
                                            audioManager.removeRemoteDownload(id: item.id)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityLabel("Remove \(item.title)")
                                    .accessibilityHint("Double tap to delete this downloaded sound")
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
