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

    @State private var customDuration: Date = Calendar.current.date(from: DateComponents(hour: 0, minute: 10)) ?? Date()
    private let lastCustomDurationKey = "SleepTimer_lastCustomDurationSeconds"

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
                let hours = (savedSeconds / 3600) % 24
                let minutes = (savedSeconds % 3600) / 60
                customDuration = Calendar.current.date(from: DateComponents(hour: hours, minute: minutes)) ?? customDuration
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

                DatePicker(
                    "",
                    selection: $customDuration,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .clipped()

                Button {
                    let seconds = customDurationSeconds
                    sleepTimer.start(duration: seconds)
                    UserDefaults.standard.set(seconds, forKey: lastCustomDurationKey)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Text("Start Custom Timer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
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

            Text("remaining")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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

            Spacer()
        }
    }

    private var customDurationSeconds: TimeInterval {
        let components = Calendar.current.dateComponents([.hour, .minute], from: customDuration)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        let total = (hours * 3600) + (minutes * 60)
        return TimeInterval(max(total, 60))
    }
}
