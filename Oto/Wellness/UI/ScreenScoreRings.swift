import SwiftUI

/// Compact Apple-Watch-style activity rings used as the menu-bar "Screen Score"
/// glyph (LookAway's "Colored rings" option). Three concentric rings:
///   • outer  — today's screen score (teal)
///   • middle — break adherence (yellow)
///   • inner  — focus toward a daily goal (magenta)
struct ScreenScoreRings: View {
    let score: Int
    let breakFraction: Double
    let focusFraction: Double
    var size: CGFloat = 16

    private var scoreFraction: Double { Double(max(0, min(100, score))) / 100 }
    private let inner = Color(red: 0.93, green: 0.35, blue: 0.72)

    var body: some View {
        ZStack {
            ring(fraction: scoreFraction, color: .otoTeal, inset: 0)
            ring(fraction: breakFraction, color: .otoYellow, inset: size * 0.24)
            ring(fraction: focusFraction, color: inner, inset: size * 0.48)
        }
        .frame(width: size, height: size)
    }

    private func ring(fraction: Double, color: Color, inset: CGFloat) -> some View {
        let lineWidth = max(2, size * 0.12)
        return Circle()
            .stroke(color.opacity(0.22), lineWidth: lineWidth)
            .overlay {
                Circle()
                    .trim(from: 0, to: max(0.001, min(1, fraction)))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(inset)
    }
}

#if DEBUG
#Preview {
    ScreenScoreRings(score: 82, breakFraction: 0.6, focusFraction: 0.4, size: 120)
        .padding(40)
        .background(Color.black)
}
#endif
