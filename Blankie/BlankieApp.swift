//
//  BlankieApp.swift
//  SereneScapes
//
//  Created by Cody Bromley on 12/30/24.
//  Converted to iOS by SereneScapes team.
//

import SwiftUI

@main
struct BlankieApp: App {
  @StateObject private var audioManager = AudioManager.shared
  @State private var showingAbout = false
  @State private var showingNewPresetPopover = false
  @State private var presetName = ""

  var body: some Scene {
    WindowGroup {
      ContentView(
        showingAbout: $showingAbout,
        showingNewPresetPopover: $showingNewPresetPopover,
        presetName: $presetName
      )
    }
  }
}

#if DEBUG
struct BlankieApp_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(
      showingAbout: .constant(false),
      showingNewPresetPopover: .constant(false),
      presetName: .constant("")
    )
  }
}
#endif
