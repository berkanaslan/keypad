import AppKit
import KeypadCore

@MainActor
public final class CapturePanelController {
    public var onTouch: (@MainActor (TouchSample) -> Void)?

    private let panel = CapturePanel()
    private let touchView = TouchCaptureView(frame: .zero)
    private let content: NSView
    private var displacedWindows: [NSWindow] = []
    private var clickThroughRect: CGRect?

    public init(content: NSView) {
        self.content = content
        let container = NSView()
        panel.contentView = container
        content.translatesAutoresizingMaskIntoConstraints = false
        touchView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        container.addSubview(touchView)
        NSLayoutConstraint.activate([
            content.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            content.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            touchView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            touchView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            touchView.topAnchor.constraint(equalTo: container.topAnchor),
            touchView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        touchView.onSample = { [weak self] sample in self?.onTouch?(sample) }
        touchView.clickThroughRect = { [weak self] in self?.clickThroughInTouchView }
    }

    isolated deinit {
        hide()
    }

    public var isKey: Bool { panel.isKeyWindow }

    public func show(freezesPointer: Bool) {
        guard !panel.isVisible, let screen = NSScreen.underPointer else { return }
        panel.setFrame(screen.frame, display: false)
        orderOutOtherWindows()
        if freezesPointer { CGAssociateMouseAndMouseCursorPosition(0) }
        NSApplication.shared.activate()
        makeKey()
    }

    /// `rect` is in the content view's coordinates; the content view can still move after this call.
    public func setClickThrough(_ rect: CGRect?) {
        clickThroughRect = rect
    }

    public func makeKey() {
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(touchView)
    }

    public func hide() {
        CGAssociateMouseAndMouseCursorPosition(1)
        panel.orderOut(nil)
        touchView.forgetTouches()
        let windows = displacedWindows
        displacedWindows = []
        for window in windows {
            window.orderBack(nil)
        }
    }

    private var clickThroughInTouchView: NSRect? {
        clickThroughRect.map { content.convert($0, to: touchView) }
    }

    /// Activating Keypad would otherwise bring them in front of the target app (RFC-0000 F9). Windows that cannot
    /// become key, such as the notice panel, are left to manage their own visibility.
    private func orderOutOtherWindows() {
        displacedWindows = NSApplication.shared.windows.filter { $0 !== panel && $0.isVisible && $0.canBecomeKey }
        for window in displacedWindows {
            window.orderOut(nil)
        }
    }
}
