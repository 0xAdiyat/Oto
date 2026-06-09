import SwiftUI
import AppKit

/// The menu-bar "Stats" tab — LookAway-style: a Today's Screen Score dial with
/// an explainer, Break Stats (Oto / natural breaks / snoozes), and Screen Time
/// Stats (totals + per-app breakdown). Scrolls within the popover.
struct StatsMenuView: View {
    @Environment(AppState.self) private var state
    @State private var showScore = true
    @AppStorage("Oto.stats.scoreInfoDismissed") private var scoreInfoDismissed = false

    private var stats: WellnessStatsStore { state.wellnessStats }
    private var today: DayStats { stats.today }
    private var score: Int { stats.screenScore(breakIntervalMinutes: state.wellness.settings.breakIntervalMinutes) }

    /// Cap before the list scrolls instead of growing the popover unbounded.
    private let maxHeight: CGFloat = 520
    @State private var contentHeight: CGFloat = 520

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                scorePill

                if showScore {
                    ScreenScoreGauge(score: score)
                        .padding(.top, 2)
                    spentWithoutBreakRow
                    if !scoreInfoDismissed { scoreInfoCard }
                }

                breakStatsCard
                screenTimeCard
            }
            .padding(.bottom, 4)
            .background(GeometryReader { geo in
                Color.clear.preference(key: StatsHeightKey.self, value: geo.size.height)
            })
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        // Size the popover to its content, capped — no empty space when the
        // score is collapsed, scrolls when it overflows.
        .frame(height: min(contentHeight, maxHeight))
        .onPreferenceChange(StatsHeightKey.self) { contentHeight = $0 }
        .animation(.easeOut(duration: 0.2), value: showScore)
    }

    // MARK: Score

    private var scorePill: some View {
        Button {
            withAnimation(OtoUI.revealEase) { showScore.toggle() }
        } label: {
            Text("Today's Screen Score")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(OtoUI.secondaryFG)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(OtoUI.rowIdle, in: Capsule())
                .overlay { Capsule().strokeBorder(OtoUI.dividerColor, lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    private var spentWithoutBreakRow: some View {
        HStack(spacing: 10) {
            Circle().fill(Color.otoYellow).frame(width: 8, height: 8)
            Text("Spent \(WellnessStatsStore.durationLabel(seconds: today.longestStretchSeconds)) without a break")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(OtoUI.secondaryFG)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius))
    }

    private var scoreInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("What is screen score?", systemImage: "questionmark.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(OtoUI.secondaryFG)
                Spacer()
                Button { withAnimation { scoreInfoDismissed = true } } label: {
                    OtoIcon(name: "xmark", size: 10).foregroundStyle(OtoUI.mutedFG)
                }
                .buttonStyle(.plain)
            }
            Text("Screen Score reflects how healthy your screen habits were today — shorter work sessions and consistent breaks lead to a higher score.")
                .font(.system(size: 11))
                .foregroundStyle(OtoUI.mutedFG)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius))
        .overlay { RoundedRectangle(cornerRadius: OtoUI.chipRadius).strokeBorder(OtoUI.dividerColor, lineWidth: 1) }
    }

    // MARK: Break stats

    private var breakStatsCard: some View {
        let breakDuration = today.breaksCompleted * state.wellness.settings.breakLengthSeconds
        return statCard(icon: "leaf.fill", tint: .otoTeal, title: "Break Stats", columns: ("Total", "Duration")) {
            statRow(dot: .otoTeal, label: "Oto breaks",
                    total: "\(today.breaksCompleted)",
                    duration: WellnessStatsStore.durationLabel(seconds: breakDuration))
            statRow(dot: .otoSage, label: "Natural breaks",
                    total: "\(today.naturalBreaks)", duration: "–")
            statRow(dot: .otoNavy, label: "Snoozes",
                    total: "\(today.snoozeCount)",
                    duration: WellnessStatsStore.durationLabel(seconds: today.snoozeSeconds))
        }
    }

    // MARK: Screen time

    private var screenTimeCard: some View {
        statCard(icon: "bolt.fill", tint: .otoYellow, title: "Screen Time Stats", columns: (nil, "Duration")) {
            timeRow(label: "Total screen time", value: WellnessStatsStore.durationLabel(seconds: today.screenSeconds))
            timeRow(label: "Longest stretch", value: WellnessStatsStore.durationLabel(seconds: today.longestStretchSeconds))
            timeRow(label: "Typical stretch today", value: WellnessStatsStore.durationLabel(seconds: today.typicalStretchSeconds))

            let apps = stats.topApps(limit: 6)
            if !apps.isEmpty {
                Text("APPS")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(OtoUI.mutedFG)
                    .padding(.top, 6)
                ForEach(apps) { app in appRow(app) }
            }
        }
    }

    // MARK: Row builders

    @ViewBuilder
    private func statCard<Content: View>(
        icon: String, tint: Color, title: String,
        columns: (String?, String?),
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                OtoIcon(name: icon, size: 12)
                    .frame(width: 22, height: 22)
                    .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(OtoUI.primaryFG)
                Spacer()
                if let t = columns.0 {
                    Text(t).font(.system(size: 10)).foregroundStyle(OtoUI.mutedFG).frame(width: 40, alignment: .trailing)
                }
                if let d = columns.1 {
                    Text(d).font(.system(size: 10)).foregroundStyle(OtoUI.mutedFG).frame(width: 60, alignment: .trailing)
                }
            }
            content()
        }
        .padding(12)
        .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius))
        .overlay { RoundedRectangle(cornerRadius: OtoUI.chipRadius).strokeBorder(OtoUI.dividerColor, lineWidth: 1) }
    }

    private func statRow(dot: Color, label: String, total: String, duration: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(dot).frame(width: 7, height: 7)
            Text(label).font(.system(size: 12)).foregroundStyle(OtoUI.secondaryFG)
            Spacer()
            Text(total).font(.system(size: 12, weight: .medium)).monospacedDigit()
                .foregroundStyle(OtoUI.secondaryFG).frame(width: 40, alignment: .trailing)
            Text(duration).font(.system(size: 12, weight: .medium)).monospacedDigit()
                .foregroundStyle(OtoUI.mutedFG).frame(width: 60, alignment: .trailing)
        }
    }

    private func timeRow(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(Color.otoYellow.opacity(0.8)).frame(width: 7, height: 7)
            Text(label).font(.system(size: 12)).foregroundStyle(OtoUI.secondaryFG)
            Spacer()
            Text(value).font(.system(size: 12, weight: .medium)).monospacedDigit()
                .foregroundStyle(OtoUI.mutedFG).frame(width: 60, alignment: .trailing)
        }
    }

    private func appRow(_ app: AppUsage) -> some View {
        HStack(spacing: 8) {
            AppIconView(bundleID: app.bundleID).frame(width: 18, height: 18)
            Text(app.name).font(.system(size: 12)).foregroundStyle(OtoUI.secondaryFG).lineLimit(1)
            Spacer()
            Text(WellnessStatsStore.durationLabel(seconds: app.seconds))
                .font(.system(size: 12, weight: .medium)).monospacedDigit()
                .foregroundStyle(OtoUI.mutedFG).frame(width: 60, alignment: .trailing)
        }
    }
}

/// Reports the intrinsic height of the stats content so the popover can size
/// to it (capped) instead of a fixed frame.
private struct StatsHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 520
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Resolves an app icon from its bundle id (works even if the app isn't
/// currently running).
struct AppIconView: View {
    let bundleID: String

    var body: some View {
        if let image = Self.icon(for: bundleID) {
            Image(nsImage: image).resizable().interpolation(.high)
        } else {
            RoundedRectangle(cornerRadius: 4).fill(OtoUI.rowHover)
                .overlay { OtoIcon(name: "app", size: 10).foregroundStyle(OtoUI.mutedFG) }
        }
    }

    private static func icon(for bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
