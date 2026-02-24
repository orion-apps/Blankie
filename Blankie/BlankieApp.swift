//
//  BlankieApp.swift
//  SereneScapes
//

import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        AudioManager.shared.handleBackgroundSessionEvents(identifier: identifier, completionHandler: completionHandler)
    }
}

@main
struct SereneScapesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var audioManager = AudioManager.shared

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
