import KeypadCore
import Observation

/// Holds what the HUD shows. The engine leaves a rejected touch's highlight set until the next render, so the model
/// clears every highlight itself after a short time.
@MainActor
@Observable
public final class KeypadHUDModel {
    public private(set) var hud: HUDState?
    public private(set) var highlightedCell: Layout.Cell?
    public var decimalSeparator = "."

    @ObservationIgnored private let highlightDuration: Duration
    @ObservationIgnored private var clearTask: Task<Void, Never>?

    public init(highlightDuration: Duration = .milliseconds(180)) {
        self.highlightDuration = highlightDuration
    }

    isolated deinit {
        clearTask?.cancel()
    }

    public func apply(_ hud: HUDState) {
        self.hud = hud
        highlightedCell = hud.highlightedCell
        clearTask?.cancel()
        clearTask = nil
        guard hud.highlightedCell != nil else { return }
        clearTask = Task { [weak self, highlightDuration] in
            try? await Task.sleep(for: highlightDuration)
            guard !Task.isCancelled else { return }
            self?.highlightedCell = nil
        }
    }
}
