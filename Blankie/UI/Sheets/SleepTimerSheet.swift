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
                quickPickButton(minutes: 5)
                quickPickButton(minutes: 30)
                quickPickButton(minutes: 60)
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
                    sleepTimer.start(duration: customDurationSeconds)
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

            Spacer()

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
