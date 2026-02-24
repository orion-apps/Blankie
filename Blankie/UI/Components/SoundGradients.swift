//
//  SoundGradients.swift
//  SereneScapes
//

import SwiftUI

enum SoundGradients {
    static func colors(for fileName: String) -> [Color] {
        switch fileName {
        case "rain":
            return [Color(red: 0.15, green: 0.25, blue: 0.55), Color(red: 0.3, green: 0.35, blue: 0.45)]
        case "storm":
            return [Color(red: 0.25, green: 0.15, blue: 0.4), Color(red: 0.2, green: 0.2, blue: 0.25)]
        case "wind":
            return [Color(red: 0.55, green: 0.58, blue: 0.62), Color(red: 0.75, green: 0.77, blue: 0.8)]
        case "waves":
            return [Color(red: 0.1, green: 0.45, blue: 0.5), Color(red: 0.1, green: 0.2, blue: 0.5)]
        case "stream":
            return [Color(red: 0.15, green: 0.45, blue: 0.3), Color(red: 0.1, green: 0.35, blue: 0.4)]
        case "birds":
            return [Color(red: 0.25, green: 0.5, blue: 0.2), Color(red: 0.6, green: 0.55, blue: 0.2)]
        case "summer-night":
            return [Color(red: 0.1, green: 0.1, blue: 0.35), Color(red: 0.05, green: 0.05, blue: 0.2)]
        case "train":
            return [Color(red: 0.45, green: 0.3, blue: 0.2), Color(red: 0.25, green: 0.22, blue: 0.2)]
        case "boat":
            return [Color(red: 0.12, green: 0.18, blue: 0.35), Color(red: 0.3, green: 0.35, blue: 0.42)]
        case "city":
            return [Color(red: 0.5, green: 0.4, blue: 0.3), Color(red: 0.25, green: 0.25, blue: 0.25)]
        case "coffee-shop":
            return [Color(red: 0.45, green: 0.3, blue: 0.18), Color(red: 0.85, green: 0.78, blue: 0.65)]
        case "fireplace":
            return [Color(red: 0.7, green: 0.45, blue: 0.1), Color(red: 0.5, green: 0.12, blue: 0.1)]
        case "pink-noise":
            return [Color(red: 0.7, green: 0.45, blue: 0.55), Color(red: 0.55, green: 0.35, blue: 0.5)]
        case "white-noise":
            return [Color(red: 0.7, green: 0.72, blue: 0.74), Color(red: 0.9, green: 0.9, blue: 0.92)]
        default:
            return [Color(red: 0.3, green: 0.3, blue: 0.4), Color(red: 0.15, green: 0.15, blue: 0.2)]
        }
    }

    static func gradient(for fileName: String) -> LinearGradient {
        LinearGradient(
            colors: colors(for: fileName),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let category: [String: [String]] = [
        "Nature": ["birds", "stream", "waves", "summer-night"],
        "Weather": ["rain", "storm", "wind"],
        "Urban": ["city", "coffee-shop", "train", "boat"],
        "Noise": ["pink-noise", "white-noise", "fireplace"]
    ]
}
