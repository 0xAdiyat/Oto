import SwiftUI

/// Semicircular "Screen Score" gauge (0–100) with a yellow→magenta sweep and a
/// soft speckled glow, matching LookAway's score dial. The arc fills in
/// proportion to the score.
struct ScreenScoreGauge: View {
    let score: Int

    private var fraction: Double { Double(max(0, min(100, score))) / 100 }

    private let sweep = Gradient(colors: [
        .otoYellow,
        Color(red: 0.95, green: 0.55, blue: 0.25),
        Color(red: 0.93, green: 0.35, blue: 0.72),
    ])

    var body: some View {
        ZStack {
            // Track (full top semicircle).
            Circle()
                .trim(from: 0, to: 0.5)
                .stroke(.white.opacity(0.10), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(180))

            // Value arc.
            Circle()
                .trim(from: 0, to: 0.5 * fraction)
                .stroke(
                    AngularGradient(gradient: sweep, center: .center, startAngle: .degrees(180), endAngle: .degrees(360)),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(180))
                .shadow(color: Color(red: 0.93, green: 0.35, blue: 0.72).opacity(0.4), radius: 6)
                .animation(.snappy(duration: 0.5), value: fraction)

            Text("\(score)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .offset(y: 8)
        }
        .frame(width: 180, height: 180)
        .frame(height: 122, alignment: .top)   // crop to the visible top semicircle
        .clipped()
    }
}

#if DEBUG
#Preview {
    ScreenScoreGauge(score: 98)
        .padding(40)
        .background(Color.black)
}
#endif
