import AppKit

/// A dimmed icon marks Keypad as disabled. A badge would read as a notification count.
@MainActor
public enum DockIcon {
    private static let disabledOpacity = 0.4

    public static func show(isEnabled: Bool) {
        let tile = NSApplication.shared.dockTile
        if isEnabled {
            tile.contentView = nil
        } else {
            let icon = NSImageView(image: NSApplication.shared.applicationIconImage)
            icon.alphaValue = disabledOpacity
            tile.contentView = icon
        }
        tile.display()
    }
}
