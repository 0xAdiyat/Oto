import SwiftUI

/// A compact stat readout — icon tile, big value, caption. Used in the menu-bar
/// Stats tab and the Stats settings page.
struct StatTile: View {
    let icon: String
    let tint: Color
    let value: String
    let caption: String

    var body: some View {
        VStack(spacing: 6) {
            OtoIcon(name: icon, size: 14)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(OtoUI.primaryFG)
            Text(caption)
                .font(.system(size: 10))
                .foregroundStyle(OtoUI.mutedFG)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius))
    }
}

/// Seven-day focus-time bars (newest on the right). Custom-drawn to avoid a
/// Swift Charts dependency for such a small visual.
struct WeeklyFocusBars: View {
    let days: [DayStats]
    var height: CGFloat = 90

    private var maxSeconds: Int { max(1, days.map(\.focusSeconds).max() ?? 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        let frac = Double(day.focusSeconds) / Double(maxSeconds)
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(day.focusSeconds > 0 ? Color.otoTeal : OtoUI.rowIdle)
                                .frame(height: max(3, geo.size.height * frac))
                        }
                    }
                    Text(Self.weekday(day.date))
                        .font(.system(size: 9))
                        .foregroundStyle(OtoUI.mutedFG)
                }
            }
        }
        .frame(height: height)
    }

    private static func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEEE" // single-letter weekday
        return f.string(from: date)
    }
}
