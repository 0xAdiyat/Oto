import SwiftUI

/// The "Focus" genre of the menu-bar popover — the LookAway break dashboard.
/// Hosts the Now / Stats sub-tabs: Now shows the live countdown plus
/// start/delay controls; Stats is a lightweight summary (expanded in a later
/// phase).
struct FocusMenuSection: View {
    @Environment(AppState.self) private var state
    @State private var tab: FocusTab = .now

    private enum FocusTab: Hashable { case now, stats }

    var body: some View {
        VStack(spacing: 12) {
            SegmentedPill(
                items: [(.now, "Now"), (.stats, "Stats")],
                selection: $tab
            )
            .fixedSize()

            switch tab {
            case .now:   nowTab
            case .stats: statsTab
            }
        }
    }

    // MARK: Now

    private var nowTab: some View {
        let breaks = state.breakManager

        return VStack(spacing: 14) {
            VStack(spacing: 6) {
                OtoIcon(name: breaks.isOnBreak ? "cup.and.saucer" : "hourglass", size: 18)
                    .foregroundStyle(OtoUI.mutedFG)
                Text(breaks.isOnBreak ? "Break ends in" : "Break starts in")
                    .font(.system(size: 12))
                    .foregroundStyle(OtoUI.mutedFG)
                Text(breaks.isOnBreak ? breaks.clockBreakRemaining : breaks.clockUntilBreak)
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(OtoUI.primaryFG)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy(duration: 0.35),
                               value: breaks.isOnBreak ? breaks.breakSecondsRemaining : breaks.secondsUntilBreak)
            }
            .padding(.top, 4)

            controls(breaks: breaks)

            VStack(spacing: 6) {
                infoRow(
                    icon: "bolt.fill",
                    tint: .otoYellow,
                    title: "Current focus time",
                    value: breaks.focusElapsedLabel
                )
                infoRow(
                    icon: "leaf.fill",
                    tint: .otoTeal,
                    title: "Upcoming break",
                    value: state.wellness.settings.breakLengthLabel
                )
            }
        }
    }

    @ViewBuilder
    private func controls(breaks: BreakManager) -> some View {
        if breaks.isOnBreak {
            if breaks.allowsSkipping {
                pillButton("Skip break", prominent: true) { breaks.skipBreak() }
            }
        } else {
            HStack(spacing: 6) {
                pillButton("Start break", prominent: true) { breaks.startBreakNow() }
                pillButton("+1m") { breaks.delay(minutes: 1) }
                pillButton("+5m") { breaks.delay(minutes: 5) }
                pillButton("+15m") { breaks.delay(minutes: 15) }
            }
        }
    }

    private func pillButton(_ title: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(prominent ? OtoUI.rowHover : OtoUI.rowIdle, in: Capsule())
                .overlay { Capsule().strokeBorder(OtoUI.dividerColor, lineWidth: 1) }
                .foregroundStyle(prominent ? OtoUI.primaryFG : OtoUI.secondaryFG)
        }
        .buttonStyle(.plain)
    }

    private func infoRow(icon: String, tint: Color, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            OtoIcon(name: icon, size: 13)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 7))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(OtoUI.secondaryFG)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(OtoUI.mutedFG)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius))
    }

    // MARK: Stats (placeholder until the stats phase)

    private var statsTab: some View {
        StatsMenuView()
    }
}
