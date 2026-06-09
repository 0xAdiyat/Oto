import SwiftUI

/// "Stepped away?" prompt shown when the user returns from a long idle gap.
/// Offers to start a fresh focus session or keep the current one going.
/// Hosted in a vibrancy panel (`SteppedAwayController`) so it blends with the
/// desktop behind it.
struct SteppedAwayView: View {
    let intervalMinutes: Int
    var onStartFresh: () -> Void
    var onKeepGoing: () -> Void

    private let accent = Color(red: 0.93, green: 0.35, blue: 0.72)

    var body: some View {
        VStack(spacing: 16) {
            SettingsTileIcon(name: "figure.walk", tint: accent, size: 44)

            VStack(spacing: 6) {
                Text("Stepped away?")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text("If that was your break, you can start a fresh \(intervalMinutes)-minute session")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                actionButton(title: "Start fresh", keys: ["⌘", "R"], prominent: true, action: onStartFresh)
                    .keyboardShortcut("r", modifiers: .command)
                actionButton(title: "Keep going", keys: ["Esc"], prominent: false, action: onKeepGoing)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 300)
        .overlay(alignment: .topLeading) {
            Button(action: onKeepGoing) {
                OtoIcon(name: "xmark", size: 10, weight: .semibold)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 22, height: 22)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    private func actionButton(title: String, keys: [String], prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(prominent ? 1 : 0.85))
                Spacer()
                HStack(spacing: 4) {
                    ForEach(keys, id: \.self) { keycap($0) }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.white.opacity(prominent ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(.white.opacity(prominent ? 0.22 : 0.12), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func keycap(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.7))
            .frame(minWidth: 16, minHeight: 16)
            .padding(.horizontal, 3)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
