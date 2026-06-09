import SwiftUI
import AppKit

/// Hex ⇄ Color helpers for user-chosen colors (e.g. the Customize break screen
/// editor). Brand/theme colors must still come from `OtoTheme` tokens — this is
/// only for values the user picks themselves.
extension Color {
    /// Parse `#RRGGBB` / `RRGGBB` (and `#RRGGBBAA`). Falls back to teal-ish gray
    /// on malformed input rather than crashing.
    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).uppercased()
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r, g, b, a: Double
        switch hex.count {
        case 8: // RRGGBBAA
            r = Double((value & 0xFF00_0000) >> 24) / 255
            g = Double((value & 0x00FF_0000) >> 16) / 255
            b = Double((value & 0x0000_FF00) >> 8) / 255
            a = Double(value & 0x0000_00FF) / 255
        case 6: // RRGGBB
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
            a = 1
        default:
            r = 0.06; g = 0.62; b = 0.56; a = 1
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// `#RRGGBB` for the current resolved RGB. Used to persist a picked color.
    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .gray
        let r = Int(round(ns.redComponent * 255))
        let g = Int(round(ns.greenComponent * 255))
        let b = Int(round(ns.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
