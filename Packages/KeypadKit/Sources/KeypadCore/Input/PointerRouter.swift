import Foundation

/// Decides which touches are the keypad's and which are the pointer's. A contact belongs to where it landed.
struct PointerRouter: Sendable {
    private struct Contact {
        let start: TrackpadPoint
        let isInside: Bool
        var hasTravelled = false
    }

    private(set) var mode = PointerMode.keypad

    private let area: ActiveArea
    private let wakeDistance: Double
    private var contacts: [Int: Contact] = [:]
    private var hadSeveralFingers = false

    init(area: ActiveArea, wakeDistance: Double = 0.04) {
        self.area = area
        self.wakeDistance = wakeDistance
    }

    mutating func handle(_ sample: TouchSample) -> [SessionEffect] {
        switch sample.phase {
        case .began:
            return landed(sample)
        case .moved:
            return moved(sample)
        case .ended, .cancelled:
            return lifted(sample)
        }
    }

    /// Back to keypad mode. A finger still down stays unknown from here on, so it can't wake the pointer.
    mutating func reset() -> [SessionEffect] {
        contacts = [:]
        hadSeveralFingers = false
        return freeze()
    }

    private mutating func landed(_ sample: TouchSample) -> [SessionEffect] {
        let isInside = area.map(sample.point) != nil
        if isInside { retireContacts() }
        contacts[sample.id] = Contact(start: sample.point, isInside: isInside)
        if contacts.count > 1 { hadSeveralFingers = true }
        guard mode == .pointer else { return [] }
        return isInside ? freeze() : [.mousePassThrough(.on)]
    }

    /// A stationary tap next to the keypad must stay harmless, so only travel wakes the pointer.
    private mutating func moved(_ sample: TouchSample) -> [SessionEffect] {
        guard var contact = contacts[sample.id], !contact.hasTravelled,
            hypot(sample.point.x - contact.start.x, sample.point.y - contact.start.y) >= wakeDistance
        else { return [] }
        contact.hasTravelled = true
        contacts[sample.id] = contact
        guard mode == .keypad, !contacts.values.contains(where: \.isInside) else { return [] }
        mode = .pointer
        return [.pointer(.pointer), .mousePassThrough(.on)]
    }

    /// The panel can't see a finger that lands while it lets mouse input through (RFC-0000 F12), so the grace period is
    /// kept for touches something can follow: a tap-to-click click after a stationary one, momentum after several fingers.
    private mutating func lifted(_ sample: TouchSample) -> [SessionEffect] {
        guard let contact = contacts.removeValue(forKey: sample.id), contacts.isEmpty else { return [] }
        let couldBeFollowed = !contact.hasTravelled || hadSeveralFingers
        hadSeveralFingers = false
        guard mode == .pointer else { return [] }
        return [.mousePassThrough(couldBeFollowed ? .offAfterGrace : .offNow)]
    }

    /// A finger that stays down through a tap is resting, so its slow drift must not wake the pointer later.
    private mutating func retireContacts() {
        for id in contacts.keys { contacts[id]?.hasTravelled = true }
    }

    private mutating func freeze() -> [SessionEffect] {
        guard mode == .pointer else { return [] }
        mode = .keypad
        return [.mousePassThrough(.offNow), .pointer(.keypad)]
    }
}
