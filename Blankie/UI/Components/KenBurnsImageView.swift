import SwiftUI

struct KenBurnsImageView: View {
    let imageNames: [String]
    let isActive: Bool
    let reduceMotion: Bool

    @State private var frontIndex: Int = 0
    @State private var backIndex: Int = 1
    @State private var frontOpacity: Double = 1
    @State private var backOpacity: Double = 0

    @State private var frontScale: CGFloat = 1.12
    @State private var backScale: CGFloat = 1.12
    @State private var frontOffset: CGSize = .zero
    @State private var backOffset: CGSize = .zero

    @State private var timer: Timer?

    private let imageDuration: TimeInterval = 8
    private let crossfadeDuration: TimeInterval = 1.8

    var body: some View {
        ZStack {
            layer(index: backIndex, scale: backScale, offset: backOffset)
                .opacity(backOpacity)
            layer(index: frontIndex, scale: frontScale, offset: frontOffset)
                .opacity(frontOpacity)
        }
        .onAppear {
            startIfNeeded()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: isActive) { _, _ in
            startIfNeeded()
        }
        .onChange(of: imageNames) { _, _ in
            startIfNeeded()
        }
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

        applyRandomMotion(toFront: true)
        animateFrontLayer()

        guard imageNames.count > 1 else { return }

        timer = Timer.scheduledTimer(withTimeInterval: imageDuration, repeats: true) { _ in
            withAnimation(.easeInOut(duration: crossfadeDuration)) {
                frontOpacity = 0
                backOpacity = 1
            }

            animateBackLayer()

            DispatchQueue.main.asyncAfter(deadline: .now() + crossfadeDuration) {
                frontIndex = (backIndex + 1) % imageNames.count
                frontOpacity = 1
                backOpacity = 0
                applyRandomMotion(toFront: true)
                animateFrontLayer()

                let nextBack = (frontIndex + 1) % imageNames.count
                backIndex = nextBack
                applyRandomMotion(toFront: false)
            }
        }
    }

    private func animateFrontLayer() {
        withAnimation(.easeInOut(duration: imageDuration + crossfadeDuration)) {
            frontScale += 0.08
            frontOffset = CGSize(width: -frontOffset.width, height: -frontOffset.height)
        }
    }

    private func animateBackLayer() {
        withAnimation(.easeInOut(duration: imageDuration + crossfadeDuration)) {
            backScale += 0.08
            backOffset = CGSize(width: -backOffset.width, height: -backOffset.height)
        }
    }

    private func applyRandomMotion(toFront: Bool) {
        let baseScale = CGFloat.random(in: 1.10...1.22)
        let offset = CGSize(width: CGFloat.random(in: -120...120), height: CGFloat.random(in: -50...50))
        if toFront {
            frontScale = baseScale
            frontOffset = offset
        } else {
            backScale = baseScale
            backOffset = offset
        }
    }
}
