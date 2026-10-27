import XCTest
@testable import Invoke

final class InvocationObservationTests: XCTestCase {
    @MainActor func testCorrectingObservationKeepsIdentityAndEarlierValueAcrossRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("InvocationObservationTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(directory: directory)
        let original = InvocationObservation(observedAt: Date(timeIntervalSince1970: 1_700_000_000), text: "First reading", measurement: 12, unit: "minutes")
        let other = InvocationObservation(observedAt: Date(timeIntervalSince1970: 1_700_000_100), text: "A separate observation")
        var invocation = Invocation(title: "Explore an idea", observations: [original, other])
        try store.saveInvocation(invocation)

        var corrected = original
        corrected.text = "Corrected reading"
        corrected.measurement = 21
        corrected.observedAt = Date(timeIntervalSince1970: 1_700_000_050)
        let index = try XCTUnwrap(invocation.observations.firstIndex { $0.id == corrected.id })
        invocation.observations[index] = corrected
        try store.saveInvocation(invocation)

        let reopened = AppStore(directory: directory)
        let saved = try XCTUnwrap(reopened.data.grimoire.invocations.first { $0.id == invocation.id })
        XCTAssertEqual(saved.observations.count, 2)
        XCTAssertEqual(saved.observations.first { $0.id == original.id }, corrected)
        XCTAssertEqual(saved.observations.first { $0.id == other.id }, other)
        XCTAssertEqual(reopened.historyCounts.actions, 0, "Correcting an outcome must not create action credit.")

        let revisions = reopened.revisions(for: invocation.id)
        XCTAssertEqual(revisions.count, 1)
        let revision = try XCTUnwrap(revisions.first)
        let before = try PersistenceCoding.decoder().decode(Invocation.self, from: revision.before)
        let after = try PersistenceCoding.decoder().decode(Invocation.self, from: revision.after)
        XCTAssertEqual(before.observations.first { $0.id == original.id }, original)
        XCTAssertEqual(after.observations.first { $0.id == original.id }, corrected)
    }
}
