/// A position on the trackpad surface, normalized to `0...1` with the origin at the bottom-left.
public struct TrackpadPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}
