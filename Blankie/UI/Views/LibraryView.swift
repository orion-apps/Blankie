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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                            Text(item.sourceServerID)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText)
        .navigationTitle("Library")
    }
}
