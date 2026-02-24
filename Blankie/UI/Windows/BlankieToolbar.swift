//
//  BlankieToolbar.swift
//  Blankie
//
//  Created by Cody Bromley on 1/11/25.
//

import SwiftUI

struct BlankieToolbar: ToolbarContent {
  @Binding var showingAbout: Bool
  @Binding var showingNewPresetPopover: Bool
  @Binding var presetName: String

  @ObservedObject private var appState = AppState.shared
  @StateObject private var audioManager = AudioManager.shared
  @StateObject private var presetManager = PresetManager.shared

  @State private var showingPreferences = false

  var body: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      if !PresetManager.shared.presets.isEmpty {
        PresetPicker()
      }
    }

    ToolbarItem(placement: .topBarTrailing) {
      Menu {
        Button {
          withAnimation {
            appState.hideInactiveSounds.toggle()
            UserDefaults.standard.set(appState.hideInactiveSounds, forKey: "hideInactiveSounds")
          }
        } label: {
          HStack {
            Text("Hide Inactive Sounds")
            if appState.hideInactiveSounds {
              Spacer()
              Image(systemName: "checkmark")
            }
          }
        }

        Divider()

        Button("About SereneScapes") {
          showingAbout = true
          appState.isAboutViewPresented = true
        }

        Button("Preferences") {
          showingPreferences = true
        }
      } label: {
        Image(systemName: "line.3.horizontal")
      }
      .sheet(isPresented: $showingPreferences) {
        NavigationView {
          PreferencesView()
            .navigationTitle("Preferences")
            .toolbar {
              ToolbarItem(placement: .confirmationAction) {
                Button("Done") { showingPreferences = false }
              }
            }
        }
      }
    }
  }
}
