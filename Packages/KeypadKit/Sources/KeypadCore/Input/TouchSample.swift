import Foundation

/// One report of a single finger on the trackpad.
public struct TouchSample: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case began, moved, ended, cancelled
    }

    public let id: Int
    public let phase: Phase
    public let point: TrackpadPoint
    public let time: TimeInterval

    public init(id: Int, phase: Phase, point: TrackpadPoint, time: TimeInterval) {
        self.id = id
        self.phase = phase
        self.point = point
        self.time = time
    }
}
