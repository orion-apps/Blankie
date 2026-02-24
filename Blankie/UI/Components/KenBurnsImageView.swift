import SwiftUI

struct KenBurnsImageView: View {
    let imageNames: [String]
    let isActive: Bool
    let reduceMotion: Bool

    @State private var frontIndex: Int = 0
    @State private var backIndex: Int = 1
    @State private var frontOpacity: Double = 1
    @State private var backOpacity: Double = 0

    @State private var frontScale: CGFloat = 1.15
    @State private var backScale: CGFloat = 1.15
    @State private var frontOffset: CGSize = .zero
    @State private var backOffset: CGSize = .zero

    @State private var timer: Timer?
    @State private var lastPresetIndex: Int = -1

    private let imageDuration: TimeInterval = 8.0
    private let crossfadeDuration: TimeInterval = 2.0

    private enum Preset: CaseIterable {
        case panLeftToRight, panRightToLeft, zoomInCenter, panDiagonalDown, panDiagonalUp

        var start: (CGFloat, CGSize) {
            switch self {
            case .panLeftToRight: return (1.20, CGSize(width: 160, height: 0))
            case .panRightToLeft: return (1.20, CGSize(width: -160, height: 0))
            case .zoomInCenter: return (1.10, CGSize(width: 0, height: 8))
            case .panDiagonalDown: return (1.20, CGSize(width: 100, height: 45))
            case .panDiagonalUp: return (1.20, CGSize(width: -100, height: -45))
            }
        }

        var end: (CGFloat, CGSize) {
            switch self {
            case .panLeftToRight: return (1.26, CGSize(width: -160, height: 0))
            case .panRightToLeft: return (1.26, CGSize(width: 160, height: 0))
            case .zoomInCenter: return (1.34, CGSize(width: 0, height: -8))
            case .panDiagonalDown: return (1.26, CGSize(width: -100, height: -45))
            case .panDiagonalUp: return (1.26, CGSize(width: 100, height: 45))
            }
        }
    }

    var body: some View {
        ZStack {
            layer(index: backIndex, scale: backScale, offset: backOffset)
                .opacity(backOpacity)
            layer(index: frontIndex, scale: frontScale, offset: frontOffset)
                .opacity(frontOpacity)
        }
        .onAppear { startIfNeeded() }
        .onDisappear { timer?.invalidate() }
        .onChange(of: isActive) { _, _ in startIfNeeded() }
        .onChange(of: imageNames) { _, _ in startIfNeeded() }
    }

    @ViewBuilder
    private func layer(index: Int, scale: CGFloat, offset: CGSize) -> some View {
        if let name = safeImageName(index: index) {
            Image(name)
                .resizable()
                .scaledToFill()
                .scaleEffect(scale)
                .offset(offset)
                .clipped()
        } else {
            Color.clear
        }
    }

    private func safeImageName(index: Int) -> String? {
        guard !imageNames.isEmpty else { return nil }
        return imageNames[index % imageNames.count]
    }

    private func pickPreset() -> Preset {
        var candidates = Array(Preset.allCases.indices).filter { $0 != lastPresetIndex }
        if candidates.isEmpty { candidates = Array(Preset.allCases.indices) }
        let idx = candidates.randomElement() ?? 0
        lastPresetIndex = idx
        return Preset.allCases[idx]
    }

    private func apply(_ preset: Preset, toFront: Bool, start: Bool) {
        let state = start ? preset.start : preset.end
        if toFront {
            frontScale = state.0
            frontOffset = state.1
        } else {
            backScale = state.0
            backOffset = state.1
        }
    }

    private func startIfNeeded() {
        timer?.invalidate()

        guard isActive, !reduceMotion, !imageNames.isEmpty else {
            frontIndex = 0
            backIndex = min(1, max(0, imageNames.count - 1))
            frontOpacity = 1
            backOpacity = 0
            return
        }

        frontIndex = 0
        backIndex = imageNames.count > 1 ? 1 : 0
        frontOpacity = 1
        backOpacity = 0

        let frontPreset = pickPreset()
        apply(frontPreset, toFront: true, start: true)
        withAnimation(.easeInOut(duration: imageDuration)) {
            apply(frontPreset, toFront: true, start: false)
        }

        guard imageNames.count > 1 else { return }

        let backPreset = pickPreset()
        apply(backPreset, toFront: false, start: true)

        timer = Timer.scheduledTimer(withTimeInterval: imageDuration, repeats: true) { _ in
            withAnimation(.easeInOut(duration: crossfadeDuration)) {
                frontOpacity = 0
                backOpacity = 1
            }

            let activeBackPreset = Preset.allCases[lastPresetIndex]
            withAnimation(.easeInOut(duration: imageDuration)) {
                apply(activeBackPreset, toFront: false, start: false)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + crossfadeDuration) {
                frontIndex = (backIndex + 1) % imageNames.count
                frontOpacity = 1
                backOpacity = 0

                let nextFront = pickPreset()
                apply(nextFront, toFront: true, start: true)
                withAnimation(.easeInOut(duration: imageDuration)) {
                    apply(nextFront, toFront: true, start: false)
                }

                backIndex = (frontIndex + 1) % imageNames.count
                let nextBack = pickPreset()
                apply(nextBack, toFront: false, start: true)
            }
        }
    }
}
