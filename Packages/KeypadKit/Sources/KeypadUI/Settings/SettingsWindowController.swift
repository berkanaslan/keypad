import AppKit
import SwiftUI

enum SettingsMetrics {
    static let width: CGFloat = 480
}

/// An AppKit window, because SwiftUI's `Settings` scene can't be opened from the Dock without an undocumented
/// selector.
@MainActor
public final class SettingsWindowController {
    private let model: SettingsModel
    private lazy var window = makeWindow()

    public init(model: SettingsModel) {
        self.model = model
    }

    public func show() {
        model.refreshLoginItemStatus()
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.canPropagateSelectedChildViewControllerTitle = false
        tabs.addTabViewItem(
            tab(
                GeneralSettingsView(model: model), String(localized: "settings.tab.general", bundle: .keypadUI),
                symbol: "gearshape"))
        tabs.addTabViewItem(keypadTab())
        tabs.addTabViewItem(
            tab(
                FeedbackSettingsView(model: model), String(localized: "settings.tab.feedback", bundle: .keypadUI),
                symbol: "speaker.wave.2"))
        let window = NSWindow(contentViewController: tabs)
        window.title = String(localized: "settings.window.title", bundle: .keypadUI)
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    /// Live touches reach the window only through a view on top that accepts them (RFC-0000 F2).
    private func keypadTab() -> NSTabViewItem {
        let liveTouches = LiveTouches()
        let item = tab(
            KeypadSettingsView(model: model, liveTouches: liveTouches),
            String(localized: "settings.tab.keypad", bundle: .keypadUI), symbol: "square.grid.3x3")
        if let content = item.viewController?.view {
            let overlay = LiveTouchView(liveTouches: liveTouches)
            overlay.frame = content.bounds
            overlay.autoresizingMask = [.width, .height]
            content.addSubview(overlay)
        }
        return item
    }

    private func tab(_ view: some View, _ label: String, symbol: String) -> NSTabViewItem {
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = .preferredContentSize
        let item = NSTabViewItem(viewController: controller)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        return item
    }
}
