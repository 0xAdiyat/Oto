import SwiftUI

/// Brand palette derived from the Oto logo.
///   Navy   #162C47 — primary dark
///   Teal   #0F9D8E — primary accent (also AccentColor)
///   Yellow #FBC02D — secondary accent
///   Cream  #F9F5EF — light surface
///   Sage   #B2D5D1 — subtle accent
extension Color {
    static let otoNavy   = Color(red: 0.086, green: 0.173, blue: 0.278)
    static let otoTeal   = Color(red: 0.059, green: 0.616, blue: 0.557)
    static let otoYellow = Color(red: 0.984, green: 0.753, blue: 0.176)
    static let otoCream  = Color(red: 0.976, green: 0.961, blue: 0.937)
    static let otoSage   = Color(red: 0.698, green: 0.835, blue: 0.820)

    /// Subtle red used for warning/disconnect emphasis (kept outside the
    /// brand palette so accidents stand out).
    static let otoAlert  = Color(red: 0.85, green: 0.30, blue: 0.30)
}
