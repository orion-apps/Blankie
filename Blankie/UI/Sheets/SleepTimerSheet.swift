//
//  SleepTimerSheet.swift
//  SereneScapes
//
//  Bottom sheet for setting or cancelling the sleep timer.
//

import SwiftUI

struct SleepTimerSheet: View {
    @ObservedObject private var sleepTimer = SleepTimer.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 10
    private let lastCustomDurationKey = "SleepTimer_lastCustomDurationSeconds"

    private let hourOptions = Array(0...4)
    private let minuteOptions = Array(0...59)

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if sleepTimer.isRunning {
                    activeTimerView
                } else {
                    timerSetupView
                }
            }
            .padding()
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            let savedSeconds = Int(UserDefaults.standard.double(forKey: lastCustomDurationKey))
            if savedSeconds >= 60 {
                selectedHours = min((savedSeconds / 3600), 4)
                selectedMinutes = (savedSeconds % 3600) / 60
            }
        }
    }

    private var timerSetupView: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Text("Stop playing after…")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(SleepTimer.presets, id: \.self) { minutes in
                    quickPickButton(minutes: minutes)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Custom")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 0) {
                    Picker("Hours", selection: $selectedHours) {
                        ForEach(hourOptions, id: \.self) { hour in
                            Text("\(hour) hr").tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Picker("Minutes", selection: $selectedMinutes) {
                        ForEach(minuteOptions, id: \.self) { minute in
                            Text("\(minute) min").tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
                .frame(height: 150)

                Button {
                    let seconds = customDurationSeconds
                    sleepTimer.start(duration: seconds)
                    UserDefaults.standard.set(Int(seconds), forKey: lastCustomDurationKey)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Text("Start Custom Timer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedHours == 0 && selectedMinutes == 0)
            }

            Spacer(minLength: 0)
        }
    }

    private func quickPickButton(minutes: Int) -> some View {
        Button {
            sleepTimer.start(minutes: minutes)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            Text(minutes == 60 ? "1 hr" : "\(minutes) min")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set timer for \(minutes == 60 ? "1 hour" : "\(minutes) minutes")")
        .accessibilityHint("Double tap to start sleep timer")
    }

    // MARK: - Active Timer

    private var activeTimerView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "moon.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(sleepTimer.displayString)
                .font(.system(size: 64, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .accessibilityLabel("\(sleepTimer.displayString) remaining")

            Text("remaining")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            if let endTime = sleepTimer.endTimeString {
                Text(endTime)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                sleepTimer.extend(byMinutes: 5)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Text("+5 min")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Add 5 minutes")
            .accessibilityHint("Double tap to extend the sleep timer by 5 minutes")

            Button(role: .destructive) {
                sleepTimer.cancel()
            } label: {
                Text("Cancel Timer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red.opacity(0.8))
            .accessibilityLabel("Cancel sleep timer")
            .accessibilityHint("Double tap to cancel the active sleep timer")

            Spacer()
        }
    }

    private var customDurationSeconds: TimeInterval {
        let total = (selectedHours * 3600) + (selectedMinutes * 60)
        return TimeInterval(max(total, 60))
    }
}
