//
//  SoundCard.swift
//  SereneScapes
//

import SwiftUI

struct SoundCard: View {
    @ObservedObject var sound: Sound
    @ObservedObject private var audioManager = AudioManager.shared

    @State private var showVolumeSlider = false

    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        Button {
            impactFeedback.impactOccurred()
            sound.toggle()
            if sound.isSelected {
                showVolumeSlider = true
            }
        } label: {
            ZStack(alignment: .bottom) {
                // Background gradient
                SoundGradients.gradient(for: sound.fileName)

                // Large SF Symbol
                Image(systemName: sound.systemIconName)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.white.opacity(sound.isSelected ? 0.9 : 0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: -16)

                // Bottom overlay with title and optional volume
                VStack(spacing: 6) {
                    Text(sound.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2, y: 1)

                    if sound.isSelected && showVolumeSlider {
                        Slider(value: Binding(
                            get: { sound.volume },
                            set: { sound.volume = $0 }
                        ), in: 0...1)
                        .tint(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .aspectRatio(2/3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        sound.isSelected ? Color.accentColor : .clear,
                        lineWidth: 2
                    )
            )
            .shadow(
                color: sound.isSelected ? Color.accentColor.opacity(0.4) : .clear,
                radius: 8
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: sound.isSelected)
        .animation(.spring(response: 0.3), value: showVolumeSlider)
        .onChange(of: sound.isSelected) { _, isSelected in
            if !isSelected {
                showVolumeSlider = false
            }
        }
    }
}
