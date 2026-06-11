import SwiftUI

/// LookAway-style preview strip for the General page: a faux menu bar showing
/// the Oto item exactly as the current Live Status / Screen Score settings
/// render it, over a soft waveform backdrop.
struct MenuBarPreview: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let s = state.wellness.settings
        let countdown = state.breakManager.menuBarCountdown(style: s.menuBarTimerStyle)

        ZStack {
            DesktopWallpaperView(blurRadius: 12, scrim: 0.35)

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Oto")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    menuItem(countdown: countdown, settings: s)
                }
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Color.black.opacity(0.33))

                Spacer()
            }
        }
        .frame(height: 98)
        .clipShape(RoundedRectangle(cornerRadius: OtoSettingsUI.cardRadius, style: .continuous))
    }

    @ViewBuilder
    private func menuItem(countdown: String, settings s: WellnessSettings) -> some View {
        HStack(spacing: 5) {
            if s.menuBarDisplay != .textOnly {
                Image("MenuBarIcon").resizable().scaledToFit().frame(width: 15, height: 15)
            }
            if s.menuBarDisplay != .iconOnly, s.breaksEnabled {
                Text(countdown).font(.system(size: 11, weight: .medium)).monospacedDigit()
                    .foregroundStyle(.white.opacity(0.92))
            }
            if s.screenScoreEnabled {
                if s.screenScoreColoredRings, s.screenScoreDisplay != .textOnly {
                    ScreenScoreRings(
                        score: state.wellnessStats.screenScore(breakIntervalMinutes: s.breakIntervalMinutes),
                        breakFraction: 0.7, focusFraction: 0.5, size: 15
                    )
                }
                if s.screenScoreDisplay != .iconOnly {
                    Text("\(state.wellnessStats.screenScore(breakIntervalMinutes: s.breakIntervalMinutes))")
                        .font(.system(size: 11, weight: .medium)).monospacedDigit()
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 20)
        .background(.black.opacity(0.24), in: Capsule())
    }

}
