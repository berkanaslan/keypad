import AppKit

@MainActor
public enum DockMenu {
    public static func make(
        isEnabled: Bool,
        toggle: @escaping @MainActor () -> Void,
        openSettings: @escaping @MainActor () -> Void
    ) -> NSMenu {
        let menu = NSMenu()
        let toggleTitle =
            isEnabled
            ? String(localized: "dock.disable", bundle: .keypadUI) : String(localized: "dock.enable", bundle: .keypadUI)
        menu.addItem(ClosureMenuItem(title: toggleTitle, handler: toggle))
        menu.addItem(.separator())
        menu.addItem(
            ClosureMenuItem(title: String(localized: "settings.open", bundle: .keypadUI), handler: openSettings))
        return menu
    }
}

@MainActor
private final class ClosureMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(title: String, handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func run() {
        handler()
    }
}
