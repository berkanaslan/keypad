import AppKit
import KeypadCore
import KeypadSystem
import KeypadUI
import SwiftUI

@MainActor
final class HUDCaptureSurface: CaptureSurface {
    var onTouch: (@MainActor (TouchSample) -> Void)? {
        get { capturePanel.onTouch }
        set { capturePanel.onTouch = newValue }
    }

    var onOpenSettings: (@MainActor () -> Void)? {
        get { model.onOpenSettings }
        set { model.onOpenSettings = newValue }
    }

    var isKey: Bool { capturePanel.isKey }

    private let model = KeypadHUDModel()
    private let capturePanel: CapturePanelController
    private let separatorProvider: DecimalSeparatorProvider

    init(decimalSeparator: DecimalSeparatorProvider) {
        separatorProvider = decimalSeparator
        capturePanel = CapturePanelController(content: NSHostingView(rootView: KeypadHUDView(model: model)))
        model.onSettingsButtonFrame = { [weak capturePanel] frame in capturePanel?.setClickThrough(frame) }
    }

    func show(_ hud: HUDState) {
        apply(hud)
        capturePanel.show(freezesPointer: !hud.showsPermissionWarning)
    }

    func render(_ hud: HUDState) {
        apply(hud)
    }

    func hide() {
        capturePanel.hide()
    }

    func makeKey() {
        capturePanel.makeKey()
    }

    private func apply(_ hud: HUDState) {
        model.decimalSeparator = separatorProvider.decimalSeparator
        model.apply(hud)
    }
}
