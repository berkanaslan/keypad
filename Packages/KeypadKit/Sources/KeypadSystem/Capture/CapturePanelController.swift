import AppKit
import KeypadCore

@MainActor
public final class CapturePanelController {
    public var onTouch: (@MainActor (TouchSample) -> Void)?
    public var onClickThrough: (@MainActor () -> Void)?

    private let panel = CapturePanel()
    private let touchView = TouchCaptureView(frame: .zero)
    private let content: NSView
    private var displacedWindows: [NSWindow] = []
    private var clickThroughRect: CGRect?
    private let passThroughGrace: Duration = .milliseconds(150)
    private var graceTask: Task<Void, Never>?
    private var clickMonitor: Any?
    private var isPassingThrough = false

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
        touchView.onSample = { [weak self] sample in
            self?.onTouch?(sample)
            self?.applyPassThrough()
        }
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

    public func setPointer(_ mode: PointerMode) {
        CGAssociateMouseAndMouseCursorPosition(mode == .pointer ? 1 : 0)
        if mode == .pointer {
            startClickMonitor()
        } else {
            stopClickMonitor()
        }
    }

    /// The panel must take mouse events back before the next finger lands, or that touch never reaches it (RFC-0000 F12).
    public func setMousePassThrough(_ state: MousePassThrough) {
        graceTask?.cancel()
        graceTask = nil
        switch state {
        case .on:
            isPassingThrough = true
            applyPassThrough()
        case .offNow:
            endPassThrough()
        case .offAfterGrace:
            graceTask = Task { [weak self, passThroughGrace] in
                try? await Task.sleep(for: passThroughGrace)
                guard !Task.isCancelled else { return }
                self?.endPassThrough()
            }
        }
    }

    public func hide() {
        CGAssociateMouseAndMouseCursorPosition(1)
        stopClickMonitor()
        graceTask?.cancel()
        graceTask = nil
        isPassingThrough = false
        applyPassThrough()
        panel.orderOut(nil)
        touchView.forgetTouches()
        let windows = displacedWindows
        displacedWindows = []
        for window in windows {
            window.orderBack(nil)
        }
    }

    /// Touches stop reaching the panel when the pointer leaves it, so the panel follows the pointer to another display.
    private func endPassThrough() {
        isPassingThrough = false
        applyPassThrough()
        guard let screen = NSScreen.underPointer, screen.frame != panel.frame else { return }
        panel.setFrame(screen.frame, display: true)
    }

    /// A click on the visible HUD must not fire a control hidden behind it, so the panel keeps the mouse there. The pointer
    /// only moves with a finger down, so touch samples are enough to follow it.
    private func applyPassThrough() {
        panel.ignoresMouseEvents = isPassingThrough && !isPointerOverContent
    }

    private var isPointerOverContent: Bool {
        content.convert(content.bounds, to: nil).contains(panel.convertPoint(fromScreen: NSEvent.mouseLocation))
    }

    private func startClickMonitor() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) {
            [weak self] _ in
            MainActor.assumeIsolated { self?.onClickThrough?() }
        }
    }

    private func stopClickMonitor() {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
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
