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

  struct ContentTelemetryEvent: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let message: String
  }

  static let shared = AppState()

  @Published var isAboutViewPresented = false
  @Published var hideInactiveSounds = false
  @Published var contentMode: ContentMode = .bundledOnly
  @Published var contentStatusMessage: String = "Using built-in sounds"
  @Published var contentTelemetry: [ContentTelemetryEvent] = []

  private init() {
    hideInactiveSounds = UserDefaults.standard.bool(forKey: "hideInactiveSounds")
  }

  func setContentMode(_ mode: ContentMode, message: String) {
    contentMode = mode
    contentStatusMessage = message
    appendTelemetry(message)
  }

  func appendTelemetry(_ message: String) {
    contentTelemetry.insert(ContentTelemetryEvent(message: message), at: 0)
    if contentTelemetry.count > 50 {
      contentTelemetry = Array(contentTelemetry.prefix(50))
    }
  }
}
