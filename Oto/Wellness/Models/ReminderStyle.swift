import SwiftUI

/// Presentation style for a wellness reminder overlay: size + on-screen position
/// + optional sound. One value per reminder kind (posture / blink). Persisted
/// inside `WellnessSettings`.
struct ReminderStyle: Codable, Hashable {
    enum Size: String, Codable, CaseIterable, Hashable {
        case small, medium, large

        var title: String {
            switch self {
            case .small:  return "Small"
            case .medium: return "Medium"
            case .large:  return "Large"
            }
        }

        /// Overlay edge length in points.
        var dimension: CGFloat {
            switch self {
            case .small:  return 220
            case .medium: return 320
            case .large:  return 440
            }
        }
    }

    /// 9-point anchor grid (LookAway-style position picker).
    enum Position: String, Codable, CaseIterable, Hashable, Identifiable {
        case topLeading, top, topTrailing
        case leading, center, trailing
        case bottomLeading, bottom, bottomTrailing

        var id: String { rawValue }

        /// Row/column (0…2) for laying the picker out as a 3×3 grid.
        var gridIndex: (row: Int, col: Int) {
            switch self {
            case .topLeading:     return (0, 0)
            case .top:            return (0, 1)
            case .topTrailing:    return (0, 2)
            case .leading:        return (1, 0)
            case .center:         return (1, 1)
            case .trailing:       return (1, 2)
            case .bottomLeading:  return (2, 0)
            case .bottom:         return (2, 1)
            case .bottomTrailing: return (2, 2)
            }
        }

        static func from(row: Int, col: Int) -> Position {
            allCases.first { $0.gridIndex == (row, col) } ?? .center
        }

        var unitPoint: UnitPoint {
            switch self {
            case .topLeading:     return .topLeading
            case .top:            return .top
            case .topTrailing:    return .topTrailing
            case .leading:        return .leading
            case .center:         return .center
            case .trailing:       return .trailing
            case .bottomLeading:  return .bottomLeading
            case .bottom:         return .bottom
            case .bottomTrailing: return .bottomTrailing
            }
        }

        /// Top-left origin for a `size`d overlay inside `frame`, with `inset`
        /// margin from the screen edges.
        func origin(for size: CGSize, in frame: CGRect, inset: CGFloat) -> CGPoint {
            let (row, col) = gridIndex
            let x: CGFloat
            switch col {
            case 0:  x = frame.minX + inset
            case 2:  x = frame.maxX - size.width - inset
            default: x = frame.midX - size.width / 2
            }
            // AppKit screen coords are bottom-left origin: row 0 = top.
            let y: CGFloat
            switch row {
            case 0:  y = frame.maxY - size.height - inset
            case 2:  y = frame.minY + inset
            default: y = frame.midY - size.height / 2
            }
            return CGPoint(x: x, y: y)
        }
    }

    var size: Size
    var position: Position
    /// Name of an `NSSound` (e.g. "Glass", "Submarine") to play, or nil = silent.
    var soundName: String?

    static let posture = ReminderStyle(size: .large, position: .center, soundName: nil)
    static let blink   = ReminderStyle(size: .large, position: .bottom, soundName: nil)
}
