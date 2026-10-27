/// The normalized rectangle of the trackpad that maps onto the layout.
public struct ActiveArea: Equatable, Sendable {
    public static let fullSurface = ActiveArea(x: 0, y: 0, width: 1, height: 1)

    private let x: Double
    private let y: Double
    private let width: Double
    private let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Returns `point` relative to the area, or `nil` when it lies outside. The edges belong to the area.
    public func map(_ point: TrackpadPoint) -> TrackpadPoint? {
        guard point.x >= x, point.x <= x + width, point.y >= y, point.y <= y + height else {
            return nil
        }
        return TrackpadPoint(x: (point.x - x) / width, y: (point.y - y) / height)
    }
}
