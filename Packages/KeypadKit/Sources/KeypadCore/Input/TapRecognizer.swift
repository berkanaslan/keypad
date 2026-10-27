import Foundation

public enum TapEvent: Equatable, Sendable {
    case touchDown(TrackpadPoint)
    case tap(TrackpadPoint)
}

/// Turns touch samples into taps: a finger that lifts quickly without having travelled.
public struct TapRecognizer: Sendable {
    private struct Contact {
        let start: TrackpadPoint
        let time: TimeInterval
        var hasMoved = false
    }

    private let maxDuration: TimeInterval
    private let maxMovement: Double
    private var contacts: [Int: Contact] = [:]

    public init(maxDuration: TimeInterval = 0.4, maxMovement: Double = 0.04) {
        self.maxDuration = maxDuration
        self.maxMovement = maxMovement
    }

    public mutating func handle(_ sample: TouchSample) -> TapEvent? {
        switch sample.phase {
        case .began:
            contacts[sample.id] = Contact(start: sample.point, time: sample.time)
            return .touchDown(sample.point)
        case .moved:
            if let start = contacts[sample.id]?.start,
                hypot(sample.point.x - start.x, sample.point.y - start.y) >= maxMovement
            {
                contacts[sample.id]?.hasMoved = true
            }
            return nil
        case .ended:
            guard let contact = contacts.removeValue(forKey: sample.id) else { return nil }
            let isTap = !contact.hasMoved && sample.time - contact.time <= maxDuration
            return isTap ? .tap(contact.start) : nil
        case .cancelled:
            contacts[sample.id] = nil
            return nil
        }
    }
}
