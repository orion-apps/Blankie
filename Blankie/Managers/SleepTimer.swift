//
//  SleepTimer.swift
//  SereneScapes
//
//  Singleton sleep timer with countdown and graceful fade-out.
//

import Combine
import Foundation

class SleepTimer: ObservableObject {
    static let shared = SleepTimer()

    /// Available durations in minutes
    static let presets: [Int] = [15, 30, 45, 60, 90, 120]

    /// Whether the timer is currently running
    @Published private(set) var isRunning = false

    /// Seconds remaining (nil when not running)
    @Published private(set) var remainingSeconds: Int?

    /// The target end date (persisted for background recovery)
    private var endDate: Date?

    private var ticker: Timer?
    private var fadeTimer: Timer?

    /// Duration of the fade-out in seconds before the timer expires
    private let fadeDuration: TimeInterval = 30

    /// Volume snapshot before fade begins (to restore if cancelled)
    private var preFadeVolume: Double?

    private let endDateKey = "SleepTimer_endDate"

    private init() {
        restoreIfNeeded()
    }

    // MARK: - Public API

    /// Start (or restart) the timer with the given duration in minutes.
    @MainActor
    func start(minutes: Int) {
        cancel() // clear any existing timer

        let end = Date().addingTimeInterval(TimeInterval(minutes * 60))
        endDate = end
        UserDefaults.standard.set(end.timeIntervalSince1970, forKey: endDateKey)

        isRunning = true
        remainingSeconds = minutes * 60
        scheduleTicker()

        print("⏱️ SleepTimer: Started for \(minutes) minutes, ends at \(end)")
    }

    /// Cancel the timer and restore volume if mid-fade.
    @MainActor
    func cancel() {
        ticker?.invalidate()
        ticker = nil
        fadeTimer?.invalidate()
        fadeTimer = nil

        // Restore volume if we were fading
        if let savedVolume = preFadeVolume {
            Task { @MainActor in
                GlobalSettings.shared.setVolume(savedVolume)
            }
            preFadeVolume = nil
        }

        endDate = nil
        isRunning = false
        remainingSeconds = nil
        UserDefaults.standard.removeObject(forKey: endDateKey)

        print("⏱️ SleepTimer: Cancelled")
    }

    // MARK: - Display helpers

    /// Formatted remaining time string like "1:23:45" or "23:45"
    var displayString: String {
        guard let secs = remainingSeconds, secs > 0 else { return "" }
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Internals

    private func scheduleTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    @MainActor
    private func tick() {
        guard let end = endDate else {
            cancel()
            return
        }

        let remaining = Int(end.timeIntervalSinceNow)

        if remaining <= 0 {
            // Timer expired — stop playback
            expire()
            return
        }

        remainingSeconds = remaining

        // Begin fade-out when within fadeDuration seconds
        if Double(remaining) <= fadeDuration && preFadeVolume == nil {
            beginFadeOut()
        }
    }

    @MainActor
    private func beginFadeOut() {
        let currentVolume = GlobalSettings.shared.volume
        guard currentVolume > 0 else { return }
        preFadeVolume = currentVolume
        print("⏱️ SleepTimer: Beginning \(Int(fadeDuration))s fade-out from volume \(currentVolume)")

        // Gradual fade: reduce volume each second over fadeDuration
        let stepCount = Int(fadeDuration)
        let volumeStep = currentVolume / Double(stepCount)
        var step = 0

        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self, self.isRunning else {
                    timer.invalidate()
                    return
                }
                step += 1
                let newVolume = max(currentVolume - (volumeStep * Double(step)), 0)
                GlobalSettings.shared.setVolume(newVolume)
                if step >= stepCount {
                    timer.invalidate()
                }
            }
        }
    }

    @MainActor
    private func expire() {
        print("⏱️ SleepTimer: Timer expired, stopping playback")

        // Fade to zero, then pause
        Task { @MainActor in
            GlobalSettings.shared.setVolume(0)
            AudioManager.shared.setGlobalPlaybackState(false)

            // Restore the original volume setting (so next play isn't silent)
            if let saved = preFadeVolume {
                // Small delay so the pause takes effect first
                try? await Task.sleep(nanoseconds: 500_000_000)
                GlobalSettings.shared.setVolume(saved)
            }
        }

        // Clean up timer state
        ticker?.invalidate()
        ticker = nil
        fadeTimer?.invalidate()
        fadeTimer = nil
        preFadeVolume = nil
        endDate = nil
        isRunning = false
        remainingSeconds = nil
        UserDefaults.standard.removeObject(forKey: endDateKey)
    }

    /// Restore timer on app launch if it was running
    private func restoreIfNeeded() {
        let saved = UserDefaults.standard.double(forKey: endDateKey)
        guard saved > 0 else { return }

        let end = Date(timeIntervalSince1970: saved)
        let remaining = Int(end.timeIntervalSinceNow)

        if remaining > 0 {
            endDate = end
            isRunning = true
            remainingSeconds = remaining
            scheduleTicker()
            print("⏱️ SleepTimer: Restored with \(remaining)s remaining")
        } else {
            // Timer expired while app was suspended — stop playback
            UserDefaults.standard.removeObject(forKey: endDateKey)
            Task { @MainActor in
                AudioManager.shared.setGlobalPlaybackState(false)
            }
        }
    }
}
