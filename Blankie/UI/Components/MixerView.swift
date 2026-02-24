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
    @State private var showRenamePreset = false
    @State private var presetName = ""
    @State private var renamePresetName = ""
    @State private var presetToRename: Preset?
    @State private var workflowMessage: String?
    @State private var studioMode: StudioMode = .mixer
    @AppStorage("mixerSingleSoloMode") private var singleSoloMode = true

    enum StudioMode: String, CaseIterable, Identifiable {
        case mixer = "Mixer"
        case presets = "Presets"
        var id: String { rawValue }
    }

    private var activeSounds: [Sound] {
        audioManager.sounds.filter { $0.isSelected }
    }

    var body: some View {
        NavigationView {
            List {
                studioModeSection
                blendPlayerSection
                contentSourceSection

                if studioMode == .mixer {
                    masterVolumeSection
                    activeSoundsSection
                    downloadedRemoteSection
                    blendWorkflowSection
                    timerSection
                } else {
                    presetsSection
                }
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
                        workflowMessage = "Preset saved"
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
            .alert("Rename Preset", isPresented: $showRenamePreset) {
                TextField("Preset name", text: $renamePresetName)
                Button("Save") {
                    if let preset = presetToRename, !renamePresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        presetManager.updatePreset(preset, newName: renamePresetName)
                        workflowMessage = "Preset renamed"
                    }
                    presetToRename = nil
                    renamePresetName = ""
                }
                Button("Cancel", role: .cancel) {
                    presetToRename = nil
                    renamePresetName = ""
                }
            }
            .sheet(isPresented: $showSleepTimer) {
                SleepTimerSheet()
            }
        }
    }

    // MARK: - Sections

    private var studioModeSection: some View {
        Section("Studio") {
            Picker("Workspace", selection: $studioMode) {
                ForEach(StudioMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var blendPlayerSection: some View {
        Section("Blend Player") {
            let userPresets = presetManager.presets.filter { !$0.isDefault }
            if userPresets.isEmpty {
                Text("No saved blends yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(userPresets) { preset in
                            Button {
                                playBlend(preset)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(preset.name)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Label("Play Blend", systemImage: "play.fill")
                                        .font(.caption)
                                }
                                .frame(width: 150, alignment: .leading)
                                .padding(10)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

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
        Section {
            Toggle("Single-solo mode", isOn: $singleSoloMode)

            if activeSounds.contains(where: { $0.isSolo }) {
                Button("Clear Solo") {
                    activeSounds.forEach { $0.isSolo = false }
                }
                .foregroundStyle(.orange)
            }

            if activeSounds.isEmpty {
                Text("No sounds selected")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(activeSounds) { sound in
                    SoundMixerRow(sound: sound, singleSoloMode: singleSoloMode)
                }
            }
        } header: {
            Text("Active Sounds")
        } footer: {
            Text(singleSoloMode ? "Soloing one sound clears solo on others." : "Multiple sounds can be soloed together.")
        }
    }

    private var downloadedRemoteSection: some View {
        Section("Downloaded Remote Tracks") {
            let downloaded = audioManager.remoteSoundCatalog.filter {
                audioManager.downloadStatus(for: $0.id).state == .completed
            }

            if downloaded.isEmpty {
                Text("No downloaded remote tracks")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(downloaded, id: \.id) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                            Text(item.sourceServerID)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(audioManager.currentlyPlayingRemoteID == item.id ? "Stop" : "Play") {
                            Task { @MainActor in
                                if audioManager.currentlyPlayingRemoteID == item.id {
                                    audioManager.stopDownloadedRemotePlayback()
                                } else {
                                    audioManager.playDownloadedRemote(id: item.id)
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
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

            if let current = presetManager.currentPreset, !current.isDefault {
                if let lastAutosaveAt = presetManager.lastAutosaveAt {
                    Text("Autosave enabled for this blend • Last saved \(lastAutosaveAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Autosave enabled for this blend")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Load a custom blend to enable autosave while editing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Use New Blend to reset. Use Update Current Blend to force-save immediately.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var presetsSection: some View {
        Section("Presets") {
            if let warning = presetManager.lastApplyWarning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let current = presetManager.currentPreset {
                HStack {
                    Image(systemName: current.isDefault ? "shippingbox.fill" : "music.note.list")
                        .foregroundStyle(.secondary)
                    Text(current.name)
                        .font(.subheadline)
                    Spacer()
                    Text(current.isDefault ? "Built-in • Current" : "User • Current")
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

            if let builtInPreset = presetManager.presets.first(where: { $0.isDefault }) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Built-in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    presetRow(builtInPreset)
                }
            }

            let userPresets = presetManager.presets.filter { !$0.isDefault }
            if !userPresets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("User Presets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(userPresets) { preset in
                        presetRow(preset)
                    }
                }
            }
        }
    }

    private func presetRow(_ preset: Preset) -> some View {
        Button {
            do {
                try presetManager.applyPreset(preset)
                workflowMessage = "Loaded preset: \(preset.name)"
            } catch {
                workflowMessage = "Could not load preset: \(preset.name)"
            }
        } label: {
            HStack {
                Text(preset.name)
                    .foregroundStyle(.primary)
                Spacer()
                Text(preset.isDefault ? "Built-in" : "User")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if preset.id == presetManager.currentPreset?.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .contextMenu {
            if !preset.isDefault {
                Button("Rename") {
                    presetToRename = preset
                    renamePresetName = preset.name
                    showRenamePreset = true
                }
                Button("Delete", role: .destructive) {
                    presetManager.deletePreset(preset)
                    workflowMessage = "Deleted preset: \(preset.name)"
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

    private func playBlend(_ preset: Preset) {
        do {
            try presetManager.applyPreset(preset)
            audioManager.setPlaybackState(true)
            workflowMessage = "Playing blend: \(preset.name)"
        } catch {
            workflowMessage = "Could not play blend: \(preset.name)"
        }
    }
}

// MARK: - Sound Mixer Row
struct SoundMixerRow: View {
    @ObservedObject var sound: Sound
    let singleSoloMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: sound.systemIconName)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                Text(sound.title)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    sound.isMuted.toggle()
                } label: {
                    Image(systemName: sound.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundStyle(sound.isMuted ? .orange : .secondary)
                }
                .buttonStyle(.plain)

                Button {
                    if sound.isSolo {
                        sound.isSolo = false
                    } else {
                        if singleSoloMode {
                            AudioManager.shared.sounds.forEach { $0.isSolo = false }
                        }
                        sound.isSolo = true
                    }
                } label: {
                    Text("S")
                        .font(.caption.bold())
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(sound.isSolo ? Color.accentColor.opacity(0.25) : Color.clear))
                }
                .buttonStyle(.plain)

                Button {
                    sound.togglePlayback()
                } label: {
                    Image(systemName: sound.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    sound.toggle()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    Text("Vol")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .leading)

                    Slider(value: Binding(
                        get: { sound.volume },
                        set: { sound.volume = $0 }
                    ), in: 0...1)
                    .tint(.accentColor)
                }

                HStack(spacing: 10) {
                    Text("Pan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .leading)

                    Text("L")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Slider(value: Binding(
                        get: { sound.pan },
                        set: { sound.pan = $0 }
                    ), in: -1...1)
                    .tint(.accentColor)

                    Text("R")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
