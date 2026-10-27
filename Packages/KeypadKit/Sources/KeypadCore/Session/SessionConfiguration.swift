public struct SessionConfiguration: Equatable, Sendable {
    public var layout: Layout = .numpad
    public var activeArea: ActiveArea = .fullSurface
    public var isSticky = true

    public init() {}
}
