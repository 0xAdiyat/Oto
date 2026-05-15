import SwiftUI

/// Live download/upload throughput readout for the menu bar popover.
///
/// Owns its own `NetworkThroughputMonitor` instance and starts/stops it via
/// `.onAppear` / `.onDisappear`, so the meter only runs while the popover is
/// visible.
struct NetworkSpeedSection: View {
    @State private var monitor = NetworkThroughputMonitor()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Network")
                    .font(.system(size: 11))
                    .foregroundStyle(OtoUI.mutedFG)
                Spacer()
                if monitor.isOnline, let kind = monitor.interfaceKind {
                    Text(kind.otoDisplayName)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(OtoUI.rowIdle, in: Capsule())
                        .foregroundStyle(OtoUI.secondaryFG)
                }
            }

            if !monitor.isOnline {
                offlineRow
            } else {
                speedRow(
                    icon: "arrow.down",
                    tint: .otoTeal,
                    label: "Download",
                    bytesPerSec: monitor.downBytesPerSec
                )
                speedRow(
                    icon: "arrow.up",
                    tint: .otoNavy,
                    label: "Upload",
                    bytesPerSec: monitor.upBytesPerSec
                )
            }
        }
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    // MARK: - Rows

    private func speedRow(icon: String, tint: Color, label: String, bytesPerSec: Double?) -> some View {
        HStack(spacing: 10) {
            OtoIcon(name: icon, size: 12, weight: .semibold)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(tint.opacity(0.32), lineWidth: 1)
                }
                .foregroundStyle(tint)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(OtoUI.secondaryFG)

            Spacer()

            Text(formatted(bytesPerSec))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(bytesPerSec == nil ? OtoUI.mutedFG : OtoUI.primaryFG)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.18), value: bytesPerSec ?? 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(prefix: label, bytesPerSec: bytesPerSec))
    }

    private var offlineRow: some View {
        HStack(spacing: 10) {
            OtoIcon(name: "wifi.slash", size: 12, weight: .semibold)
                .frame(width: 26, height: 26)
                .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: 7))
                .foregroundStyle(OtoUI.mutedFG)
            Text("Offline")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(OtoUI.mutedFG)
            Spacer()
        }
        .padding(.vertical, 2)
        .accessibilityLabel("Network offline")
    }

    // MARK: - Formatting

    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .binary
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.includesUnit = true
        f.isAdaptive = true
        return f
    }()

    private func formatted(_ bytesPerSec: Double?) -> String {
        guard let bps = bytesPerSec else { return "Measuring…" }
        let clamped = max(0, bps)
        // ByteCountFormatter wants Int64; we know it fits — even saturated
        // 100 Gbps is ~12 GB/s, well within Int64.
        let str = Self.byteFormatter.string(fromByteCount: Int64(clamped))
        return "\(str)/s"
    }

    private func accessibilityLabel(prefix: String, bytesPerSec: Double?) -> String {
        guard let bps = bytesPerSec else { return "\(prefix), measuring" }
        // Spell the unit out for VoiceOver — "KB/s" gets read as letters.
        let mb = bps / 1_048_576
        let kb = bps / 1024
        if mb >= 1 {
            return String(format: "%@, %.1f megabytes per second", prefix, mb)
        } else if kb >= 1 {
            return String(format: "%@, %.0f kilobytes per second", prefix, kb)
        } else {
            return String(format: "%@, %.0f bytes per second", prefix, bps)
        }
    }
}

#if DEBUG
#Preview("Network speed section") {
    NetworkSpeedSection()
        .padding()
        .frame(width: 320)
        .preferredColorScheme(.dark)
}
#endif
