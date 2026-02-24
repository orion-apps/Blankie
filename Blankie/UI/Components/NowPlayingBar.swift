//
//  NowPlayingBar.swift
//  SereneScapes
//

import SwiftUI

struct NowPlayingBar: View {
    @ObservedObject private var audioManager = AudioManager.shared
    @ObservedObject private var globalSettings = GlobalSettings.shared
    @ObservedObject private var sleepTimer = SleepTimer.shared

    @Binding var showMixer: Bool
    @Binding var showPlayer: Bool
    @State private var showSleepTimer = false

    private var activeSoundCount: Int {
        audioManager.sounds.filter { $0.isSelected }.count
    }

    var body: some View {
        HStack(spacing: 16) {
            // Play/Pause
            Button {
                let feedback = UIImpactFeedbackGenerator(style: .light)
                feedback.impactOccurred()
                audioManager.togglePlayback()
            } label: {
                Image(systemName: audioManager.isGloballyPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text("\(activeSoundCount) sound\(activeSoundCount == 1 ? "" : "s") playing")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text(PresetManager.shared.currentPreset?.name ?? "Custom Mix")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onTapGesture {
                showMixer = true
            }

            Spacer()

            // Volume
            Image(systemName: volumeIcon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Slider(value: Binding(
                get: { globalSettings.volume },
                set: { newValue in Task { @MainActor in globalSettings.setVolume(newValue) } }
            ), in: 0...1)
            .tint(.accentColor)
            .frame(width: 80)

            // Sleep timer button
            Button {
                showSleepTimer = true
            } label: {
                ZStack {
                    Image(systemName: sleepTimer.isRunning ? "moon.fill" : "moon")
                        .font(.system(size: 14))
                        .foregroundStyle(sleepTimer.isRunning ? .accent : .secondary)

                    if sleepTimer.isRunning {
                        Text(sleepTimer.displayString)
                            .font(.system(size: 7, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .offset(y: 14)
                    }
                }
                .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showSleepTimer) {
                SleepTimerSheet()
            }

            // Lock/Player button
            Button {
                showPlayer = true
            } label: {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color(.systemGray5)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        .padding(.horizontal, 8)
    }

    private var volumeIcon: String {
        if globalSettings.volume == 0 { return "speaker.slash.fill" }
        if globalSettings.volume < 0.33 { return "speaker.fill" }
        if globalSettings.volume < 0.66 { return "speaker.wave.1.fill" }
        return "speaker.wave.2.fill"
    }
}
