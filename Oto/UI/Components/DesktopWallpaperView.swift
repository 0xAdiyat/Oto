import SwiftUI
import AppKit

/// Renders the current desktop wallpaper (blurred + dark scrim) as a section
/// background — the technique LookAway uses for its menu-bar preview strip. Used
/// only for designated hero/preview sections, not whole windows.
///
/// Falls back to a tasteful gradient if the wallpaper image can't be read (e.g.
/// the sandbox denies access to the picture's path).
struct DesktopWallpaperView: View {
    var blurRadius: CGFloat = 16
    var scrim: Double = 0.42

    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.12)          // hide blur edge bleed
                    .blur(radius: blurRadius)
            } else {
                LinearGradient(
                    colors: [Color.otoNavy.opacity(0.55), Color.black.opacity(0.65)],
                    startPoint: .top, endPoint: .bottom
                )
            }
            Color.black.opacity(scrim)
        }
        .clipped()
        .task { load() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)) { _ in
            load()
        }
    }

    private func load() {
        guard let screen = NSScreen.main,
              let url = try? NSWorkspace.shared.desktopImageURL(for: screen),
              let loaded = NSImage(contentsOf: url) else {
            image = nil
            return
        }
        image = loaded
    }
}
