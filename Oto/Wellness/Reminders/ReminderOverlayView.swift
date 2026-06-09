import SwiftUI

/// The floating posture / blink reminder widget (LookAway-style). Sized by
/// `ReminderStyle.Size`; hosted in a non-activating panel by
/// `ReminderOverlayController` and positioned per `ReminderStyle.Position`.
struct ReminderOverlayView: View {
    let kind: WellnessReminderManager.ReminderKind
    let size: ReminderStyle.Size

    private var scale: CGFloat {
        switch size {
        case .small:  return 0.72
        case .medium: return 0.86
        case .large:  return 1.0
        }
    }

    private var icon: String { kind == .posture ? "figure.stand" : "eye.fill" }
    private var title: String { kind == .posture ? "Posture check" : "Blink break" }
    private var subtitle: String {
        kind == .posture
            ? "Sit up tall and roll your shoulders back."
            : "Blink a few times to refresh your eyes."
    }
    private var tint: Color { kind == .posture ? .otoSage : .otoNavy }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 28 * scale, style: .continuous)
        VStack(spacing: 14 * scale) {
            OtoIcon(name: icon, size: 56 * scale, weight: .semibold)
                .foregroundStyle(.white)
            VStack(spacing: 6 * scale) {
                Text(title)
                    .font(.system(size: 24 * scale, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 14 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(28 * scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(
                    LinearGradient(
                        colors: [tint.opacity(0.92), tint.opacity(0.62)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            }
        }
        .overlay { shape.strokeBorder(.white.opacity(0.18), lineWidth: 1) }
        .clipShape(shape)
        .shadow(color: .black.opacity(0.3), radius: 22 * scale, y: 10 * scale)
    }
}

#if DEBUG
#Preview("Posture") {
    ReminderOverlayView(kind: .posture, size: .large)
        .frame(width: 440, height: 308)
        .padding(40)
        .background(Color.black)
}
#endif
