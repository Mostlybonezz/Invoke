import XCTest
@testable import Invoke

final class ChronicleTimelineTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private var range: DateInterval { DateInterval(start: start, duration: 86_400) }

    func testUndoRetainsOriginalAndDatedCorrectionWithoutSecondCredit() {
        var data = AppData()
        let practice = PracticeDefinition(title: "A chosen practice")
        data.grimoire.practices = [practice]
        var action = ActionRecord(practiceID: practice.id)
        action.occurredAt = start; action.recordedAt = start; action.titleSnapshot = "The title at the time"
        action.timeZoneID = "Asia/Tokyo"
        var correction = ActionRecord(practiceID: practice.id)
        correction.kind = .correction; correction.reversesActionID = action.id
        correction.occurredAt = start.addingTimeInterval(1); correction.recordedAt = correction.occurredAt
        data.grimoire.actions = [action, correction]
        let result = ChronicleTimeline.items(data: data, range: range)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.summary, "Correction")
        XCTAssertEqual(result.last?.title, "The title at the time")
        XCTAssertEqual(result.last?.timeZoneID, "Asia/Tokyo")
        XCTAssertEqual(result.last?.undone, true)
        XCTAssertEqual(data.grimoire.actions.count, 2)
    }

    func testUnknownExperienceDateUsesKnownRecordDateWithoutInventingExperience() {
        var data = AppData()
        var record = ArcanaRecord()
        record.title = "An open question"; record.createdAt = start
        record.occurredAt = nil
        data.grimoire.arcana = [record]
        let result = ChronicleTimeline.items(data: data, range: range)
        XCTAssertEqual(result.first?.date, start)
        XCTAssertNil(data.grimoire.arcana.first?.occurredAt)
    }

    func testPracticeFilterIncludesLinkedAssetAndLegacyRitualOnly() {
        var data = AppData()
        let entry = LibraryEntry(kind: .ritual, title: "Original ritual")
        var asset = CareAsset(); asset.name = "Boots"
        var inspection = AssetInspection(); inspection.date = start; asset.inspections = [inspection]
        var practice = PracticeDefinition(title: "Inspect boots")
        practice.assetID = asset.id; practice.legacyEntryID = entry.id
        var ritual = RitualLog(ritualID: entry.id); ritual.date = start
        var unrelated = ArcanaRecord(); unrelated.createdAt = start
        data.entries = [entry]; data.ritualLogs = [ritual]
        data.grimoire.practices = [practice]; data.grimoire.assets = [asset]; data.grimoire.arcana = [unrelated]
        let result = ChronicleTimeline.items(data: data, range: range, practiceID: practice.id)
        XCTAssertEqual(Set(result.map(\.route)), ["asset", "legacyRitual"])
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(data.grimoire.actions.isEmpty)
    }

    func testRangeIsHalfOpenAndEmptyHistoryDoesNotInventSkips() {
        var data = AppData()
        XCTAssertTrue(ChronicleTimeline.items(data: data, range: range).isEmpty)
        var first = GrimoireEvent(); first.name = "Start"; first.occurredAt = start
        var next = GrimoireEvent(); next.name = "Next day"; next.occurredAt = range.end
        data.grimoire.events = [first, next]
        let result = ChronicleTimeline.items(data: data, range: range)
        XCTAssertEqual(result.map(\.title), ["Start"])
    }

    func testActionAndObservedOutcomeStaySeparate() {
        var data = AppData()
        var invocation = Invocation(); invocation.title = "A desired change"
        var observation = InvocationObservation(); observation.text = "What actually happened"; observation.observedAt = start
        invocation.observations = [observation]
        var practice = PracticeDefinition(title: "A concrete action"); practice.invocationID = invocation.id
        var action = ActionRecord(practiceID: practice.id); action.occurredAt = start
        data.grimoire.invocations = [invocation]; data.grimoire.practices = [practice]; data.grimoire.actions = [action]
        let result = ChronicleTimeline.items(data: data, range: range)
        XCTAssertEqual(result.filter { $0.category == .actions }.count, 1)
        XCTAssertEqual(result.filter { $0.category == .invocations }.count, 1)
        XCTAssertEqual(invocation.status, "Active")
    }
}
