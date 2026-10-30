/// The normalized rectangle of the trackpad that maps onto the layout. It always lies inside the trackpad and is at
/// least `minimumSize` wide and tall.
public struct ActiveArea: Codable, Equatable, Sendable {
    public enum Corner: Sendable {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    public static let fullSurface = ActiveArea(x: 0, y: 0, width: 1, height: 1)
    public static let minimumSize = 0.2

    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        guard [x, y, width, height].allSatisfy(\.isFinite) else {
            (self.x, self.y, self.width, self.height) = (0, 0, 1, 1)
            return
        }
        self.width = min(max(width, Self.minimumSize), 1)
        self.height = min(max(height, Self.minimumSize), 1)
        self.x = min(max(x, 0), 1 - self.width)
        self.y = min(max(y, 0), 1 - self.height)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            x: try container.decode(Double.self, forKey: .x),
            y: try container.decode(Double.self, forKey: .y),
            width: try container.decode(Double.self, forKey: .width),
            height: try container.decode(Double.self, forKey: .height)
        )
    }

    /// Returns `point` relative to the area, or `nil` when it lies outside. The edges belong to the area.
    public func map(_ point: TrackpadPoint) -> TrackpadPoint? {
        guard point.x >= x, point.x <= x + width, point.y >= y, point.y <= y + height else {
            return nil
        }
        return TrackpadPoint(x: (point.x - x) / width, y: (point.y - y) / height)
    }

    public func moved(byX dx: Double, y dy: Double) -> ActiveArea {
        ActiveArea(x: x + dx, y: y + dy, width: width, height: height)
    }

    /// The opposite corner stays where it is; the dragged one stops at the trackpad's edge and at the minimum size.
    public func resized(corner: Corner, to point: TrackpadPoint) -> ActiveArea {
        let movesLeft = corner == .topLeft || corner == .bottomLeft
        let movesBottom = corner == .bottomLeft || corner == .bottomRight
        let (right, top) = (x + width, y + height)
        let newWidth = movesLeft ? Self.clamp(right - point.x, room: right) : Self.clamp(point.x - x, room: 1 - x)
        let newHeight = movesBottom ? Self.clamp(top - point.y, room: top) : Self.clamp(point.y - y, room: 1 - y)
        return ActiveArea(
            x: movesLeft ? right - newWidth : x,
            y: movesBottom ? top - newHeight : y,
            width: newWidth,
            height: newHeight
        )
    }

    public func resizedEvenly(by delta: Double) -> ActiveArea {
        let newWidth = min(max(width + delta, Self.minimumSize), 1)
        let newHeight = min(max(height + delta, Self.minimumSize), 1)
        return ActiveArea(
            x: x + (width - newWidth) / 2, y: y + (height - newHeight) / 2, width: newWidth, height: newHeight)
    }

    private static func clamp(_ length: Double, room: Double) -> Double {
        min(max(length, minimumSize), room)
    }
}
