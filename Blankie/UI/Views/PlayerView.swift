//
//  PlayerView.swift
//  SereneScapes
//
//  Full-screen immersive ambient display with lockable controls.
//

import SwiftUI
import UIKit

struct PlayerView: View {
    @ObservedObject private var audioManager = AudioManager.shared
    @ObservedObject private var globalSettings = GlobalSettings.shared
    @ObservedObject private var sleepTimer = SleepTimer.shared

    @Environment(\.dismiss) private var dismiss

    @State private var showControls = true
    @State private var isLocked = false
    @State private var showSleepTimerSheet = false
    @State private var controlsTimer: Timer?
    @State private var gradientPhase: CGFloat = 0
    @State private var backgroundImageName: String?
    @State private var imageRotationTimer: Timer?

    private var activeSounds: [Sound] {
        audioManager.sounds.filter { $0.isSelected }
    }

    /// Blended gradient from all active sounds
    private var blendedColors: [Color] {
        let allColors = activeSounds.flatMap { SoundGradients.colors(for: $0.fileName) }
        if allColors.isEmpty {
            return [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.15)]
        }
        // Take up to 4 colors for the gradient
        return Array(allColors.prefix(4))
    }

    var body: some View {
        ZStack {
            // Animated gradient background
            animatedBackground
                .ignoresSafeArea()

            // Controls overlay
            if showControls {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        .statusBarHidden(!showControls)
        .onTapGesture {
            guard !isLocked else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls.toggle()
            }
            scheduleHideControls()
        }
        .onAppear {
            scheduleHideControls()
            configureBackgroundRotation()
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: true)) {
                gradientPhase = 1
            }
        }
        .onDisappear {
            controlsTimer?.invalidate()
            imageRotationTimer?.invalidate()
        }
        .onReceive(audioManager.$sounds) { _ in
            configureBackgroundRotation()
        }
        .persistentSystemOverlays(.hidden)
    }

    // MARK: - Background

    private var animatedBackground: some View {
        ZStack {
            if let imageName = backgroundImageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(1.08 + (0.04 * gradientPhase))
                    .animation(.linear(duration: 8), value: gradientPhase)
                    .transition(.opacity)
            } else {
                LinearGradient(
                    colors: blendedColors,
                    startPoint: gradientPhase == 0 ? .topLeading : .bottomTrailing,
                    endPoint: gradientPhase == 0 ? .bottomTrailing : .topLeading
                )
            }
        }
        .overlay(
            RadialGradient(
                colors: [.white.opacity(0.05), .clear],
                center: gradientPhase == 0 ? .topTrailing : .bottomLeading,
                startRadius: 50,
                endRadius: 400
            )
        )
        .overlay(Color.black.opacity(0.18))
    }

    // MARK: - Controls

    private var controlsOverlay: some View {
        VStack {
            // Top bar
            HStack {
                Button {
                    if isLocked {
                        withAnimation(.spring(response: 0.3)) {
                            isLocked = false
                        }
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: isLocked ? "lock.fill" : "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(12)
                        .background(Circle().fill(.ultraThinMaterial))
                }

                Spacer()

                // Sleep timer button
                Button {
                    showSleepTimerSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: sleepTimer.isRunning ? "moon.fill" : "moon")
                            .font(.system(size: 14))
                        if sleepTimer.isRunning {
                            Text(sleepTimer.displayString)
                                .font(.caption.weight(.medium).monospacedDigit())
                        } else {
                            Text("Sleep")
                                .font(.caption.weight(.medium))
                        }
                    }
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.ultraThinMaterial))
                }
                .sheet(isPresented: $showSleepTimerSheet) {
                    SleepTimerSheet()
                }

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isLocked.toggle()
                    }
                    if isLocked {
                        scheduleHideControls(interval: 1.5)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isLocked ? "lock.fill" : "lock.open")
                            .font(.system(size: 14))
                        Text(isLocked ? "Locked" : "Lock")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.ultraThinMaterial))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            // Sound info
            VStack(spacing: 8) {
                Text(activeSoundNames)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)

                Text("\(activeSounds.count) sound\(activeSounds.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            // Bottom controls
            if !isLocked {
                VStack(spacing: 20) {
                    // Volume slider
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))

                        Slider(value: Binding(
                            get: { globalSettings.volume },
                            set: { newValue in Task { @MainActor in globalSettings.setVolume(newValue) } }
                        ), in: 0...1)
                        .tint(.white.opacity(0.8))

                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 40)

                    // Play/Pause
                    Button {
                        let feedback = UIImpactFeedbackGenerator(style: .medium)
                        feedback.impactOccurred()
                        audioManager.togglePlayback()
                    } label: {
                        Image(systemName: audioManager.isGloballyPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(
            Color.black.opacity(showControls ? 0.2 : 0)
                .ignoresSafeArea()
        )
    }

    // MARK: - Helpers

    private var activeSoundNames: String {
        let names = activeSounds.map { $0.title }
        switch names.count {
        case 0: return "No sounds"
        case 1: return names[0]
        case 2: return "\(names[0]) & \(names[1])"
        default:
            return "\(names.dropLast().joined(separator: ", ")) & \(names.last!)"
        }
    }

    private func scheduleHideControls(interval: TimeInterval = 3) {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                showControls = false
            }
        }
    }

    private func configureBackgroundRotation() {
        imageRotationTimer?.invalidate()

        let candidates = availableBackgroundImageNames()
        guard !candidates.isEmpty else {
            backgroundImageName = nil
            return
        }

        if backgroundImageName == nil || !candidates.contains(backgroundImageName ?? "") {
            backgroundImageName = candidates.first
        }

        guard candidates.count > 1 else { return }

        imageRotationTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                guard let current = backgroundImageName,
                      let idx = candidates.firstIndex(of: current) else {
                    backgroundImageName = candidates.first
                    return
                }
                let nextIndex = (idx + 1) % candidates.count
                backgroundImageName = candidates[nextIndex]
            }
        }
    }

    private func availableBackgroundImageNames() -> [String] {
        var names: [String] = []

        for sound in activeSounds {
            let base = sound.fileName
            let options = [
                "\(base)_hero",
                "\(base)_wide",
                base
            ]

            for option in options where UIImage(named: option) != nil {
                if !names.contains(option) { names.append(option) }
            }
        }

        return names
    }
}
