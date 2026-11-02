import KeypadCore
import SwiftUI

/// A trackpad-shaped preview with the active area on it: drag the area to move it, a corner to resize it.
struct ActiveAreaEditor: View {
    private static let aspectRatio: CGFloat = 1.6
    private static let handleSize: CGFloat = 12
    private static let touchSize: CGFloat = 10
    private static let accessibilityStep = 0.05
    private static let space = "trackpad"

    let area: ActiveArea
    let touches: [TrackpadPoint]
    let onChange: (ActiveArea) -> Void
    @State private var areaAtDragStart: ActiveArea?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let rect = Self.viewRect(for: area, in: size)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12).fill(.quaternary)
                grid(in: rect)
                    .gesture(moveGesture(in: size))
                ForEach(Self.corners, id: \.offset) { corner in
                    Circle()
                        .fill(.tint)
                        .frame(width: Self.handleSize, height: Self.handleSize)
                        .position(Self.point(of: corner.element, in: rect))
                        .gesture(resizeGesture(corner.element, in: size))
                }
                ForEach(Array(touches.enumerated()), id: \.offset) { touch in
                    Circle()
                        .fill(.secondary)
                        .frame(width: Self.touchSize, height: Self.touchSize)
                        .position(Self.viewPoint(for: touch.element, in: size))
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(.named(Self.space))
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text("settings.activeArea", bundle: .keypadUI))
        .accessibilityValue(Self.accessibilityValue(for: area))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(area.resizedEvenly(by: Self.accessibilityStep))
            case .decrement: onChange(area.resizedEvenly(by: -Self.accessibilityStep))
            @unknown default: break
            }
        }
    }

    /// The view's origin is top-left; the trackpad's is bottom-left.
    static func viewRect(for area: ActiveArea, in size: CGSize) -> CGRect {
        CGRect(
            x: area.x * size.width,
            y: (1 - area.y - area.height) * size.height,
            width: area.width * size.width,
            height: area.height * size.height
        )
    }

    static func viewPoint(for point: TrackpadPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: (1 - point.y) * size.height)
    }

    static func trackpadPoint(for location: CGPoint, in size: CGSize) -> TrackpadPoint {
        TrackpadPoint(x: location.x / size.width, y: 1 - location.y / size.height)
    }

    private static let corners = Array(
        [ActiveArea.Corner.topLeft, .topRight, .bottomLeft, .bottomRight].enumerated())

    private static func point(of corner: ActiveArea.Corner, in rect: CGRect) -> CGPoint {
        switch corner {
        case .topLeft: CGPoint(x: rect.minX, y: rect.minY)
        case .topRight: CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    static func accessibilityValue(for area: ActiveArea) -> String {
        let percent = { (value: Double) in Int((value * 100).rounded()) }
        return String(
            format: String(localized: "settings.activeArea.accessibilityValue", bundle: .keypadUI),
            percent(area.width), percent(area.height), percent(area.x), percent(area.y))
    }

    private func grid(in rect: CGRect) -> some View {
        let layout = Layout.numpad
        return ZStack {
            Rectangle().fill(.tint.opacity(0.2))
            Path { path in
                for column in 1..<layout.columns {
                    let x = rect.width * CGFloat(column) / CGFloat(layout.columns)
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: rect.height))
                }
                for row in 1..<layout.rows {
                    let y = rect.height * CGFloat(row) / CGFloat(layout.rows)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: rect.width, y: y))
                }
            }
            .stroke(.tint.opacity(0.5), lineWidth: 1)
            Rectangle().stroke(.tint, lineWidth: 2)
        }
        .frame(width: rect.width, height: rect.height)
        .offset(x: rect.minX, y: rect.minY)
    }

    private func moveGesture(in size: CGSize) -> some Gesture {
        DragGesture(coordinateSpace: .named(Self.space))
            .onChanged { value in
                let start = areaAtDragStart ?? area
                areaAtDragStart = start
                onChange(
                    start.moved(byX: value.translation.width / size.width, y: -value.translation.height / size.height))
            }
            .onEnded { _ in areaAtDragStart = nil }
    }

    private func resizeGesture(_ corner: ActiveArea.Corner, in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in
                onChange(area.resized(corner: corner, to: Self.trackpadPoint(for: value.location, in: size)))
            }
    }
}
