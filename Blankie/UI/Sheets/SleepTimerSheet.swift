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

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if sleepTimer.isRunning {
                    activeTimerView
                } else {
                    presetGrid
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
        .presentationDetents([.medium])
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

    // MARK: - Preset Grid

    private var presetGrid: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Text("Stop playing after…")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(SleepTimer.presets, id: \.self) { minutes in
                    Button {
                        sleepTimer.start(minutes: minutes)
                        let feedback = UIImpactFeedbackGenerator(style: .medium)
                        feedback.impactOccurred()
                    } label: {
                        VStack(spacing: 4) {
                            Text(formatDuration(minutes))
                                .font(.title2.weight(.semibold))
                            Text(minutes < 60 ? "min" : "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h):\(String(format: "%02d", m))"
    }
}
