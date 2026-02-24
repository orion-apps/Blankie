//
//  AppState.swift
//  Blankie
//
//  Created by Cody Bromley on 1/1/25.
//

import SwiftUI

class AppState: ObservableObject {
  enum ContentMode: String {
    case bundledOnly
    case hybrid
  }

  enum ContentTelemetryLevel: String {
    case info
    case warning
    case error
  }

  struct ContentTelemetryEvent: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let level: ContentTelemetryLevel
    let message: String
  }

  static let shared = AppState()

  @Published var isAboutViewPresented = false
  @Published var hideInactiveSounds = false
  @Published var contentMode: ContentMode = .bundledOnly
  @Published var contentStatusMessage: String = "Using built-in sounds"
  @Published var contentTelemetry: [ContentTelemetryEvent] = []

  private let contentModeKey = "contentMode"
  private let contentStatusMessageKey = "contentStatusMessage"

  private init() {
    hideInactiveSounds = UserDefaults.standard.bool(forKey: "hideInactiveSounds")

    if let rawMode = UserDefaults.standard.string(forKey: contentModeKey),
       let mode = ContentMode(rawValue: rawMode) {
      contentMode = mode
    }

    if let savedMessage = UserDefaults.standard.string(forKey: contentStatusMessageKey), !savedMessage.isEmpty {
      contentStatusMessage = savedMessage
    }
  }

  func setContentMode(_ mode: ContentMode, message: String) {
    contentMode = mode
    contentStatusMessage = message

    UserDefaults.standard.set(mode.rawValue, forKey: contentModeKey)
    UserDefaults.standard.set(message, forKey: contentStatusMessageKey)

    appendTelemetry(message, level: .info)
  }

  func appendTelemetry(_ message: String, level: ContentTelemetryLevel = .info) {
    contentTelemetry.insert(ContentTelemetryEvent(level: level, message: message), at: 0)
    if contentTelemetry.count > 50 {
      contentTelemetry = Array(contentTelemetry.prefix(50))
    }
  }
}
