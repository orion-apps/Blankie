//
//  ColorSquare.swift
//  SereneScapes
//
//  Created by Cody Bromley on 1/2/25.
//  Converted to iOS by SereneScapes team.
//

import SwiftUI
import UIKit

struct ColorSquare: View {
  let color: AccentColor
  let isSelected: Bool
  @ObservedObject private var globalSettings = GlobalSettings.shared

  var textColorForAccent: Color {
    let uiColor = UIColor(color.color ?? .accentColor)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    
    if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
      let brightness = (0.299 * red) + (0.587 * green) + (0.114 * blue)
      return brightness > 0.5 ? .black : .white
    }
    return .white
  }

  var body: some View {
    Button(action: {
      globalSettings.setAccentColor(color.color)
    }) {
      RoundedRectangle(cornerRadius: 4)
        .fill(color.color ?? Color.accentColor)
        .frame(width: 24, height: 24)
        .overlay {
          if isSelected {
            RoundedRectangle(cornerRadius: 4)
              .strokeBorder(textColorForAccent, lineWidth: 2)
              .padding(2)
          }
        }
    }
    .buttonStyle(.plain)
  }
}
