import SwiftUI

/// The menu-bar item's label. Renders the brand glyph plus the live focus
/// countdown (e.g. "27m"), LookAway-style. Reads the shared `BreakManager` so it
/// re-renders every tick, and honours the user's `menuBarDisplay` preference.
struct MenuBarLabel: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let s = state.wellness.settings
        let countdown = state.breakManager.menuBarCountdown(style: s.menuBarTimerStyle)

        HStack(spacing: 5) {
            // Live status — brand glyph + focus countdown.
            if s.menuBarDisplay != .textOnly {
                Image("MenuBarIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }
            if s.menuBarDisplay != .iconOnly, s.breaksEnabled {
                Text(countdown)
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
            }

            // Screen Score — colored rings and/or the numeric score.
            if s.screenScoreEnabled {
                if s.screenScoreColoredRings, s.screenScoreDisplay != .textOnly {
                    ScreenScoreRings(
                        score: score,
                        breakFraction: breakFraction,
                        focusFraction: focusFraction,
                        size: 16
                    )
                }
                if s.screenScoreDisplay != .iconOnly {
                    Text("\(score)")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: Screen-score inputs

    private var score: Int {
        state.wellnessStats.screenScore(breakIntervalMinutes: state.wellness.settings.breakIntervalMinutes)
    }

    private var breakFraction: Double {
        let t = state.wellnessStats.today
        let total = t.breaksCompleted + t.breaksSkipped
        return total == 0 ? 1 : Double(t.breaksCompleted) / Double(total)
    }

    private var focusFraction: Double {
        min(1, Double(state.wellnessStats.today.focusSeconds) / (4 * 3600))
    }
}
