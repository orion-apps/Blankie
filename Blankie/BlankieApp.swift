//
//  BlankieApp.swift
//  SereneScapes
//

import SwiftUI

@main
struct SereneScapesApp: App {
    @StateObject private var audioManager = AudioManager.shared

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
