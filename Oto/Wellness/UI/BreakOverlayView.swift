import SwiftUI

/// Full-screen break screen shown while `BreakManager` is `.onBreak`, modelled
/// on LookAway's: a current-time chip + trial pill up top, a bold "Refuel your
/// focus" prompt, a large MM:SS countdown, and Skip Break / Lock Screen
/// controls with a double-Esc hint. Hosted over a blurred backdrop (the
/// `NSVisualEffectView` supplied by `BreakOverlayController`) on every display;
/// secondary displays show the backdrop only.
struct BreakOverlayView: View {
    @Environment(BreakManager.self) private var breaks

    var isPrimary: Bool = true
    /// Lock the Mac (wired by the controller).
    var onLockScreen: () -> Void = {}

    var body: some View {
        ZStack {
            // Custom background (gradient / solid / image) drawn over the blur,
            // then a scrim so white text stays legible on bright backgrounds.
            background.ignoresSafeArea()
            Color.black.opacity(0.28).ignoresSafeArea()

            if isPrimary {
                content
                    .overlay(alignment: .top) { topBar }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Background

    @ViewBuilder
    private var background: some View {
        let style = breaks.screenStyle
        switch style.background {
        case .gradient:
            style.gradient
        case .solid:
            style.baseColor
        case .image:
            if let image = style.resolvedImage() {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                style.gradient   // graceful fallback when the image is gone
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        ZStack {
            if breaks.screenStyle.showClock {
                HStack(spacing: 6) {
                    OtoIcon(name: "clock", size: 12).foregroundStyle(.white.opacity(0.85))
                    Text(timeString)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }

            HStack(spacing: 10) {
                if breaks.isLongBreak {
                    HStack(spacing: 6) {
                        OtoIcon(name: "hourglass", size: 11)
                        Text(breaks.longBreakLabel)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.14), in: Capsule())
                    .overlay { Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1) }
                }
                Spacer()
                if trialDaysRemaining > 0 {
                    HStack(spacing: 6) {
                        OtoIcon(name: "timer", size: 11)
                        Text("\(trialDaysRemaining) trial days remaining")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.12), in: Capsule())
                    .overlay { Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1) }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
    }

    // MARK: Center

    private var content: some View {
        VStack(spacing: 22) {
            Spacer()

            VStack(spacing: 12) {
                Text(breaks.screenStyle.headline)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(breaks.screenStyle.subtitle)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
            }

            Rectangle()
                .fill(.white.opacity(0.25))
                .frame(width: 64, height: 1)

            Text(breaks.clockBreakRemaining)
                .font(.system(size: 60, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.92))
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy(duration: 0.35), value: breaks.breakSecondsRemaining)

            Spacer()

            controls
        }
        .padding(40)
        .shadow(color: .black.opacity(0.35), radius: 12, y: 2)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if breaks.allowsEndEarly {
                    overlayButton(title: "End break", icon: "checkmark", enabled: true) {
                        breaks.endBreakEarly()
                    }
                }
                if breaks.allowsSkipping {
                    overlayButton(title: "Skip Break", icon: "forward.fill", enabled: breaks.canSkipNow) {
                        breaks.skipBreak()
                    }
                }
                overlayButton(title: "Lock Screen", icon: "lock.fill", enabled: true) {
                    onLockScreen()
                }
            }

            if breaks.doubleEscapeShouldSkip {
                (Text("Press ")
                 + Text("Esc").font(.system(size: 11, weight: .semibold))
                 + Text(" twice to skip the break"))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            } else if !breaks.allowsSkipping {
                Text("Breaks can't be skipped on Hardcore")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.bottom, 8)
    }

    private func overlayButton(title: String, icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                OtoIcon(name: icon, size: 12)
                Text(title).font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.white.opacity(enabled ? 0.95 : 0.4))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.white.opacity(enabled ? 0.14 : 0.06), in: Capsule())
            .overlay { Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: Derived values

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: Date())
    }

    /// 7-day trial counter keyed off first launch. Purely cosmetic for now —
    /// there's no licensing backend yet.
    private var trialDaysRemaining: Int {
        let key = "Oto.firstLaunchDate.v1"
        let defaults = UserDefaults.standard
        let start: Date
        if let saved = defaults.object(forKey: key) as? Date {
            start = saved
        } else {
            start = Date()
            defaults.set(start, forKey: key)
        }
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
        return max(0, 7 - elapsed)
    }
}

#if DEBUG
#Preview("Break overlay") {
    let store = WellnessStore()
    let manager = BreakManager(store: store)
    manager.startBreakNow()
    return BreakOverlayView()
        .environment(manager)
        .frame(width: 1000, height: 640)
        .background(LinearGradient(colors: [.gray, .blue.opacity(0.5)], startPoint: .top, endPoint: .bottom))
}
#endif
