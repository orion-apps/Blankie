//
//  PreferencesView.swift
//  SereneScapes
//
//  Created by Cody Bromley on 1/1/25.
//  Converted to iOS by SereneScapes team.
//

import Foundation
import SwiftUI
import UIKit

struct PreferencesView: View {
  @ObservedObject private var globalSettings = GlobalSettings.shared
  @ObservedObject private var appState = AppState.shared
  @ObservedObject private var audioManager = AudioManager.shared
  @State private var showingRestartAlert = false
  @Environment(\.dismiss) private var dismiss
  private let colorsPerRow = 6

  var accentColorForUI: Color {
    globalSettings.customAccentColor ?? .accentColor
  }

  var textColorForAccent: Color {
    // Use a simple brightness calculation for iOS
    return .white
  }

  var appearanceButtons: some View {
    HStack(spacing: 8) {
      ForEach(AppearanceMode.allCases, id: \.self) { mode in
        Button(
          action: { globalSettings.setAppearance(mode) },
          label: {
            HStack(spacing: 4) {
              Image(systemName: mode.icon)
              Text(mode.localizedName)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
              globalSettings.appearance == mode ? accentColorForUI : Color.secondary.opacity(0.2)
            )
            .foregroundColor(globalSettings.appearance == mode ? textColorForAccent : .primary)
            .cornerRadius(6)
          }
        )
        .buttonStyle(.plain)
      }
    }
  }

  var colorButtons: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Button(
          action: { globalSettings.setAccentColor(nil) },
          label: {
            Text("System", comment: "System accent color option")
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(
                globalSettings.customAccentColor == nil
                  ? accentColorForUI : Color.secondary.opacity(0.2)
              )
              .foregroundColor(
                globalSettings.customAccentColor == nil ? textColorForAccent : .primary
              )
              .cornerRadius(6)
          }
        )
        .buttonStyle(.plain)

        ForEach(Array(AccentColor.allCases.dropFirst().prefix(colorsPerRow - 1)), id: \.self) {
          color in
          ColorSquare(color: color, isSelected: color.color == globalSettings.customAccentColor)
        }
      }

      HStack(spacing: 8) {
        ForEach(Array(AccentColor.allCases.dropFirst().dropFirst(colorsPerRow - 1)), id: \.self) {
          color in
          ColorSquare(color: color, isSelected: color.color == globalSettings.customAccentColor)
        }
      }
    }
  }

  var languageMenu: some View {
    Picker(
      "Language",
      selection: Binding(
        get: { globalSettings.language },
        set: { globalSettings.setLanguage($0) }
      )
    ) {
      ForEach(globalSettings.availableLanguages) { language in
        HStack {
          Image(systemName: language.icon)
          Text(language.displayName)
        }
        .tag(language)
      }
    }
    .pickerStyle(.menu)
  }

  private func levelColor(_ level: AppState.ContentTelemetryLevel) -> Color {
    switch level {
    case .info: return .blue
    case .warning: return .orange
    case .error: return .red
    }
  }

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Appearance")) {
          VStack(alignment: .leading, spacing: 12) {
            Text("Theme")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            appearanceButtons
          }
          .padding(.vertical, 4)

          VStack(alignment: .leading, spacing: 12) {
            Text("Accent Color")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            colorButtons
          }
          .padding(.vertical, 4)

          HStack {
            Text("Language")
            Spacer()
            languageMenu
          }
        }

        Section(header: Text("Behavior")) {
          Toggle(
            LocalizedStringKey("Always Start Paused"),
            isOn: Binding(
              get: { globalSettings.alwaysStartPaused },
              set: { globalSettings.setAlwaysStartPaused($0) }
            )
          )
          .tint(accentColorForUI)
        }

        Section(header: Text("Content Status")) {
          HStack {
            Circle()
              .fill(appState.contentMode == .hybrid ? Color.green : Color.orange)
              .frame(width: 8, height: 8)
            Text(appState.contentMode == .hybrid ? "Built-in + Online" : "Built-in Only")
            Spacer()
          }

          Text(appState.contentStatusMessage)
            .font(.subheadline)
            .foregroundStyle(.secondary)

          Picker(
            "Auto-Refresh",
            selection: Binding(
              get: { globalSettings.catalogRefreshInterval },
              set: { globalSettings.setCatalogRefreshInterval($0) }
            )
          ) {
            ForEach(CatalogRefreshInterval.allCases) { interval in
              Text(interval.rawValue).tag(interval)
            }
          }
          .pickerStyle(.menu)

          Button("Refresh Content Catalog") {
            Task { await audioManager.refreshRemoteCatalog() }
          }

          if appState.contentTelemetry.isEmpty {
            Text("No recent content events")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else {
            ForEach(appState.contentTelemetry.prefix(10)) { event in
              VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                  Text(event.level.rawValue.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(levelColor(event.level))
                  Text(event.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Text(event.message)
                  .font(.caption)
              }
              .padding(.vertical, 2)
            }
          }
        }
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
    .onChange(of: globalSettings.needsRestartForLanguageChange) { _, newValue in
      if newValue {
        showingRestartAlert = true
        globalSettings.needsRestartForLanguageChange = false
      }
    }
    .alert(
      Text("Language Changed"),
      isPresented: $showingRestartAlert
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Please restart the app for the language change to take effect.")
    }
  }
}

#Preview("Preferences") {
  PreferencesView()
}

#Preview("Dark Mode") {
  PreferencesView()
    .preferredColorScheme(.dark)
}
