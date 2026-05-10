#if DEBUG
import Foundation
import SwiftUI

// MARK: - Preview view helpers

@MainActor
extension View {
    /// Drops the view onto a padded canvas that mimics the spotlight panel
    /// sitting beneath the sheet. The backdrop tone tracks the sheet's own
    /// adaptive palette, so flipping the canvas color scheme in Xcode shows
    /// the sheet in both light and dark modes correctly. Also wires in a
    /// no-op `otoDismiss` so sheets that read `\.otoDismiss` don't crash.
    func previewSheetBackdrop(width: CGFloat? = nil) -> some View {
        Group {
            if let width {
                self.frame(width: width)
            } else {
                self
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OtoUI.adaptiveTone(lightOpacity: 0.04, darkOpacity: 0.92))
        .environment(\.otoDismiss, OtoDismissAction(action: {}))
    }
}

/// Mock-data factories for SwiftUI #Preview blocks. DEBUG-only so none of
/// this ships in release builds.
@MainActor
extension AppState {
    /// An empty AppState — no rules, no profiles. Use for empty-state previews.
    static var previewEmpty: AppState {
        AppState()
    }

    /// A populated AppState with a few representative rules so list rows,
    /// filter counts, master toggle, and footer hints all render meaningfully.
    static var previewPopulated: AppState {
        let state = AppState()
        for rule in Rule.previewSamples {
            state.store.add(rule)
        }
        return state
    }
}

extension Rule {
    /// A handful of varied sample rules covering all trigger and action kinds.
    /// Update freely as the model grows — previews should reflect realistic
    /// shapes, not edge cases.
    static var previewSamples: [Rule] {
        [
            Rule(
                trigger: .deviceConnects(deviceUID: "preview-edifier", deviceName: "EDIFIER WH700NB Pro"),
                action: .setInput(deviceUID: "preview-edifier", deviceName: "EDIFIER WH700NB Pro")
            ),
            Rule(
                trigger: .appLaunches(bundleID: "com.spotify.client", appName: "Spotify"),
                action: .setOutputVolume(volume: 0.35),
                condition: .headphonesNotConnected
            ),
            Rule(
                trigger: .systemWakes,
                action: .setBoth(
                    inputUID: "preview-fifine", inputName: "fifine Microphone",
                    outputUID: "preview-mac", outputName: "Mac mini Speakers"
                )
            ),
            Rule(
                trigger: .anyBluetoothConnects,
                action: .keepCurrent,
                enabled: false
            ),
        ]
    }
}
#endif
