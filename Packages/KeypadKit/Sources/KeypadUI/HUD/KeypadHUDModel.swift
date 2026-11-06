import CoreGraphics
import KeypadCore
import Observation

/// Holds what the HUD shows. The engine leaves a rejected touch's highlight set until the next render, so the model
/// clears every highlight itself after a short time.
@MainActor
@Observable
public final class KeypadHUDModel {
    public private(set) var hud: HUDState?
    public private(set) var highlightedCell: Layout.Cell?
    public private(set) var isWarningEmphasized = false
    public var decimalSeparator = "."
    @ObservationIgnored public var onOpenSettings: (@MainActor () -> Void)?
    @ObservationIgnored public var onSettingsButtonFrame: (@MainActor (CGRect?) -> Void)?

    @ObservationIgnored private let highlightDuration: Duration
    @ObservationIgnored private let warningEmphasis: Duration
    @ObservationIgnored private var clearTask: Task<Void, Never>?
    @ObservationIgnored private var emphasisTask: Task<Void, Never>?

    public init(highlightDuration: Duration = .milliseconds(180), warningEmphasis: Duration = .milliseconds(400)) {
        self.highlightDuration = highlightDuration
        self.warningEmphasis = warningEmphasis
    }

    isolated deinit {
        clearTask?.cancel()
        emphasisTask?.cancel()
    }

    public func apply(_ hud: HUDState) {
        if hud.permissionNudges > self.hud?.permissionNudges ?? 0 { emphasizeWarning() }
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

    private func emphasizeWarning() {
        isWarningEmphasized = true
        emphasisTask?.cancel()
        emphasisTask = Task { [weak self, warningEmphasis] in
            try? await Task.sleep(for: warningEmphasis)
            guard !Task.isCancelled else { return }
            self?.isWarningEmphasized = false
        }
    }
}
