import AppKit
import KeypadCore

@MainActor
public final class NoticePanelController: NoticeSurface {
    private let duration: Duration
    private let content: @MainActor (Notice) -> NSView
    private let panel = OverlayPanel(backgroundColor: .clear)
    private var hideTask: Task<Void, Never>?

    public init(duration: Duration = .seconds(2), content: @escaping @MainActor (Notice) -> NSView) {
        self.duration = duration
        self.content = content
        panel.ignoresMouseEvents = true
    }

    isolated deinit {
        hideTask?.cancel()
        panel.orderOut(nil)
    }

    public func show(_ notice: Notice) {
        guard let screen = NSScreen.underPointer else { return }
        let view = content(notice)
        panel.contentView = view
        let size = view.fittingSize
        let area = screen.visibleFrame
        let origin = NSPoint(x: area.midX - size.width / 2, y: area.minY + area.height / 6 - size.height / 2)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()

        hideTask?.cancel()
        hideTask = Task { [weak self, duration] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.panel.orderOut(nil)
        }
    }
}
