//
//  MixerView.swift
//  SereneScapes
//

import SwiftUI

struct MixerView: View {
    @ObservedObject private var audioManager = AudioManager.shared
    @ObservedObject private var globalSettings = GlobalSettings.shared
    @ObservedObject private var presetManager = PresetManager.shared
    @ObservedObject private var appState = AppState.shared

    @Environment(\.dismiss) private var dismiss

    @State private var showSavePreset = false
    @State private var showSleepTimer = false
    @State private var presetName = ""
    @State private var workflowMessage: String?

    private var activeSounds: [Sound] {
        audioManager.sounds.filter { $0.isSelected }
    }

    var body: some View {
        NavigationView {
            List {
                contentSourceSection
                masterVolumeSection
                activeSoundsSection
                blendWorkflowSection
                presetsSection
                timerSection
            }
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Save Preset", isPresented: $showSavePreset) {
                TextField("Preset name", text: $presetName)
                Button("Save") {
                    if !presetName.isEmpty {
                        presetManager.saveNewPreset(name: presetName)
                        presetName = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    presetName = ""
                }
            }
            .alert("Blend Update", isPresented: Binding(
                get: { workflowMessage != nil },
                set: { if !$0 { workflowMessage = nil } }
            )) {
                Button("OK", role: .cancel) { workflowMessage = nil }
            } message: {
                Text(workflowMessage ?? "")
            }
            .sheet(isPresented: $showSleepTimer) {
                SleepTimerSheet()
            }
        }
    }

    // MARK: - Sections

    private var contentSourceSection: some View {
        Section("Content Source") {
            HStack(spacing: 8) {
                Circle()
                    .fill(appState.contentMode == .hybrid ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)

                Text(appState.contentMode == .hybrid ? "Built-in + Online" : "Built-in Only")
                Spacer()
            }

            Text(appState.contentStatusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Refresh Content Catalog") {
                Task { await audioManager.refreshRemoteCatalog() }
            }
        }
    }

    private var masterVolumeSection: some View {
        Section("Volume") {
            HStack(spacing: 12) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text("Master")
                    .font(.subheadline.weight(.medium))
                Slider(value: Binding(
                    get: { globalSettings.volume },
                    set: { newValue in Task { @MainActor in globalSettings.setVolume(newValue) } }
                ), in: 0...1)
                .tint(.accentColor)
            }
        }
    }

    private var activeSoundsSection: some View {
        Section("Active Sounds") {
            if activeSounds.isEmpty {
                Text("No sounds selected")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(activeSounds) { sound in
                    SoundMixerRow(sound: sound)
                }
            }
        }
    }

    private var blendWorkflowSection: some View {
        Section("Blend Workflow") {
            Button {
                do {
                    try presetManager.startNewBlend()
                    workflowMessage = "Started a new blend from default state"
                } catch {
                    workflowMessage = "Could not start a new blend"
                }
            } label: {
                Label("New Blend", systemImage: "plus.square.on.square")
            }

            Button {
                let updated = presetManager.overwriteCurrentPresetFromCurrentState()
                workflowMessage = updated
                    ? "Updated current blend from mixer state"
                    : "Select a saved custom blend before updating"
            } label: {
                Label("Update Current Blend", systemImage: "square.and.arrow.down")
            }

            Text("Use New Blend to reset. Use Update Current Blend to save edits to the active custom preset.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var presetsSection: some View {
        Section("Presets") {
            if let current = presetManager.currentPreset, !current.isDefault {
                HStack {
                    Image(systemName: "music.note.list")
                        .foregroundStyle(.secondary)
                    Text(current.name)
                        .font(.subheadline)
                    Spacer()
                    Text("Current")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                showSavePreset = true
            } label: {
                Label("Save as Preset", systemImage: "plus.circle")
            }
            .disabled(activeSounds.isEmpty)

            ForEach(presetManager.presets.filter { !$0.isDefault }) { preset in
                presetRow(preset)
            }
        }
    }

    private func presetRow(_ preset: Preset) -> some View {
        Button {
            try? presetManager.applyPreset(preset)
        } label: {
            HStack {
                Text(preset.name)
                    .foregroundStyle(.primary)
                Spacer()
                if preset.id == presetManager.currentPreset?.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private var timerSection: some View {
        Section("Timer") {
            Button {
                showSleepTimer = true
            } label: {
                Label("Sleep Timer", systemImage: "moon.zzz")
            }
        }
    }
}

// MARK: - Sound Mixer Row
struct SoundMixerRow: View {
    @ObservedObject var sound: Sound

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sound.systemIconName)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(sound.title)
                .font(.subheadline)
                .frame(width: 90, alignment: .leading)

            Slider(value: Binding(
                get: { sound.volume },
                set: { sound.volume = $0 }
            ), in: 0...1)
            .tint(.accentColor)

            Button {
                sound.toggle()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
