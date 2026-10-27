import Foundation
import KeypadCore
import Testing

@testable import KeypadUI

@MainActor
struct KeypadHUDModelTests {
    private let first = Layout.numpad.cells[0]
    private let second = Layout.numpad.cells[1]

    private func state(highlighting cell: Layout.Cell?) -> HUDState {
        HUDState(
            target: AppIdentity(processID: 1, bundleIdentifier: nil, name: "Notes"),
            layout: .numpad,
            buffer: EntryBuffer(),
            highlightedCell: cell,
            showsPermissionWarning: false
        )
    }

    private func wait(until condition: () -> Bool) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while !condition() && ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func applyStoresTheStateAndItsHighlight() {
        let model = KeypadHUDModel()
        let state = state(highlighting: first)

        model.apply(state)

        #expect(model.hud == state)
        #expect(model.highlightedCell == first)
    }

    @Test func theHighlightClearsAfterTheDuration() async {
        let model = KeypadHUDModel(highlightDuration: .milliseconds(50))

        model.apply(state(highlighting: first))
        await wait { model.highlightedCell == nil }

        #expect(model.highlightedCell == nil)
        #expect(model.hud != nil)
    }

    @Test func aNewHighlightCancelsThePendingClear() async throws {
        let model = KeypadHUDModel(highlightDuration: .milliseconds(400))

        model.apply(state(highlighting: first))
        try await Task.sleep(for: .milliseconds(250))
        model.apply(state(highlighting: second))
        try await Task.sleep(for: .milliseconds(250))

        #expect(model.highlightedCell == second)
        await wait { model.highlightedCell == nil }
        #expect(model.highlightedCell == nil)
    }

    @Test func aStateWithoutHighlightClearsItAtOnce() {
        let model = KeypadHUDModel()

        model.apply(state(highlighting: first))
        model.apply(state(highlighting: nil))

        #expect(model.highlightedCell == nil)
    }
}
