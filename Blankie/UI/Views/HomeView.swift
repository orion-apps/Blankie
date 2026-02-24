//
//  HomeView.swift
//  SereneScapes
//

import SwiftUI

struct HomeView: View {
    @ObservedObject private var audioManager = AudioManager.shared
    @ObservedObject private var appState = AppState.shared

    @State private var selectedCategory = "All"
    @State private var showMixer = false
    @State private var showPlayer = false
    @State private var showPreferences = false

    private let categories = ["All", "Nature", "Weather", "Urban", "Noise"]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var filteredSounds: [Sound] {
        guard selectedCategory != "All" else {
            return audioManager.sounds
        }
        guard let fileNames = SoundGradients.category[selectedCategory] else {
            return audioManager.sounds
        }
        return audioManager.sounds.filter { fileNames.contains($0.fileName) }
    }

    private var hasActiveSounds: Bool {
        audioManager.sounds.contains { $0.isSelected }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Filter pills
                        filterPills

                        // Sound grid
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredSounds) { sound in
                                SoundCard(sound: sound)
                            }
                        }
                        .padding(.horizontal, 16)

                        // Bottom spacing for NowPlayingBar
                        if hasActiveSounds {
                            Color.clear.frame(height: 90)
                        }
                    }
                }

                // Now Playing Bar
                if hasActiveSounds {
                    NowPlayingBar(showMixer: $showMixer, showPlayer: $showPlayer)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 4)
                }
            }
            .animation(.spring(response: 0.4), value: hasActiveSounds)
            .navigationTitle("SereneScapes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPreferences = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showMixer) {
                MixerView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showPlayer) {
                PlayerView()
            }
            .sheet(isPresented: $showPreferences) {
                NavigationView {
                    PreferencesView()
                        .navigationTitle("Settings")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showPreferences = false }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Filter Pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.self) { category in
                    FilterPillView(
                        title: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}
