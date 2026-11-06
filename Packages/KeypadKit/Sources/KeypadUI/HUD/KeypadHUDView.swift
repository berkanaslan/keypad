import AppKit
import KeypadCore
import SwiftUI

public struct KeypadHUDView: View {
    private let model: KeypadHUDModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: KeypadHUDModel) {
        self.model = model
    }

    public var body: some View {
        if let hud = model.hud {
            VStack(spacing: HUDMetrics.sectionSpacing) {
                TargetRow(target: hud.target)
                NumberDisplay(text: hud.buffer.display(decimalSeparator: model.decimalSeparator))
                KeyGrid(
                    layout: hud.layout, highlightedCell: model.highlightedCell, decimalSeparator: model.decimalSeparator
                )
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: model.highlightedCell)
                .opacity(hud.showsPermissionWarning ? HUDMetrics.disabledOpacity : 1)
                if hud.showsPermissionWarning {
                    PermissionWarning(
                        nudges: hud.permissionNudges,
                        isEmphasized: model.isWarningEmphasized,
                        onOpenSettings: { model.onOpenSettings?() },
                        onButtonFrame: { model.onSettingsButtonFrame?($0) }
                    )
                } else {
                    Text("hud.hint", bundle: .keypadUI)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(HUDMetrics.padding)
            .frame(width: HUDMetrics.width)
            .glassEffect(.regular, in: .rect(cornerRadius: HUDMetrics.cornerRadius))
            .coordinateSpace(.named(HUDMetrics.coordinateSpace))
        }
    }
}

private enum HUDMetrics {
    static let contentWidth: CGFloat = 280
    static let padding: CGFloat = 24
    static let width = contentWidth + 2 * padding
    static let cornerRadius: CGFloat = 32
    static let sectionSpacing: CGFloat = 16
    static let keySpacing: CGFloat = 8
    static let keyHeight: CGFloat = 64
    static let keyCornerRadius: CGFloat = 16
    static let disabledOpacity = 0.4
    static let coordinateSpace = "hud"
}

private struct TargetRow: View {
    let target: AppIdentity

    var body: some View {
        HStack(spacing: 8) {
            if let icon = NSRunningApplication(processIdentifier: target.processID)?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
            }
            Text(verbatim: target.name)
                .font(.headline)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(format: String(localized: "hud.target.accessibilityLabel", bundle: .keypadUI), target.name))
    }
}

private struct KeyGrid: View {
    let layout: KeypadCore.Layout
    let highlightedCell: KeypadCore.Layout.Cell?
    let decimalSeparator: String

    private var keyWidth: CGFloat {
        (HUDMetrics.contentWidth - HUDMetrics.keySpacing * CGFloat(layout.columns - 1)) / CGFloat(layout.columns)
    }

    var body: some View {
        GlassEffectContainer(spacing: HUDMetrics.keySpacing) {
            ZStack(alignment: .topLeading) {
                ForEach(layout.cells.indices, id: \.self) { index in
                    let cell = layout.cells[index]
                    KeyCell(cell: cell, isHighlighted: cell == highlightedCell, decimalSeparator: decimalSeparator)
                        .frame(
                            width: extent(of: keyWidth, spanning: cell.columnSpan),
                            height: extent(of: HUDMetrics.keyHeight, spanning: cell.rowSpan)
                        )
                        .offset(
                            x: CGFloat(cell.column) * (keyWidth + HUDMetrics.keySpacing),
                            y: CGFloat(cell.row) * (HUDMetrics.keyHeight + HUDMetrics.keySpacing)
                        )
                }
            }
            .frame(
                width: HUDMetrics.contentWidth,
                height: extent(of: HUDMetrics.keyHeight, spanning: layout.rows),
                alignment: .topLeading
            )
        }
    }

    private func extent(of slot: CGFloat, spanning count: Int) -> CGFloat {
        slot * CGFloat(count) + HUDMetrics.keySpacing * CGFloat(count - 1)
    }
}

private struct KeyCell: View {
    let cell: KeypadCore.Layout.Cell
    let isHighlighted: Bool
    let decimalSeparator: String

    var body: some View {
        label
            .font(.system(.title, design: .rounded, weight: .medium))
            .monospacedDigit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassEffect(
                isHighlighted ? .regular.tint(.accentColor) : .regular,
                in: .rect(cornerRadius: HUDMetrics.keyCornerRadius)
            )
    }

    @ViewBuilder
    private var label: some View {
        switch cell.action {
        case .digit(let value):
            Text(verbatim: String(value))
        case .decimalSeparator:
            Text(verbatim: decimalSeparator)
        case .backspace:
            Image(systemName: "delete.left")
                .accessibilityLabel(Text("hud.backspace.accessibilityLabel", bundle: .keypadUI))
        }
    }
}

private struct PermissionWarning: View {
    let nudges: Int
    let isEmphasized: Bool
    let onOpenSettings: () -> Void
    let onButtonFrame: (CGRect?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            Text("hud.permissionMissing", bundle: .keypadUI)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(reduceMotion && isEmphasized ? Color.red : Color.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .keyframeAnimator(initialValue: 0.0, trigger: nudges) { [reduceMotion] content, offset in
                    content.offset(x: reduceMotion ? 0 : offset)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(-8, duration: 0.05)
                        LinearKeyframe(8, duration: 0.1)
                        LinearKeyframe(-6, duration: 0.1)
                        LinearKeyframe(4, duration: 0.08)
                        LinearKeyframe(0, duration: 0.07)
                    }
                }
            Button(action: onOpenSettings) {
                Text("hud.permission.openSettings", bundle: .keypadUI)
            }
            .buttonStyle(.glass)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(HUDMetrics.coordinateSpace))
            } action: { frame in
                onButtonFrame(frame)
            }
            .onDisappear { onButtonFrame(nil) }
        }
        .onChange(of: nudges) {
            AccessibilityNotification.Announcement(String(localized: "hud.permissionMissing", bundle: .keypadUI)).post()
        }
    }
}
