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
        let result = ChronicleTimeline.items(data: data, range: range, history: HistoryPage(actions: [action, correction]))
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
        let result = ChronicleTimeline.items(data: data, range: range, history: HistoryPage(actions: [action]))
        XCTAssertEqual(result.filter { $0.category == .actions }.count, 1)
        XCTAssertEqual(result.filter { $0.category == .invocations }.count, 1)
        XCTAssertEqual(invocation.status, "Active")
    }

    func testPageMergeDeduplicatesRetriesAndCarriesCorrectionOutsidePage() {
        let practice = PracticeDefinition(title: "Original title")
        var original = ActionRecord(practiceID: practice.id)
        original.occurredAt = start; original.titleSnapshot = practice.title
        var loaded = ChronicleLoadedHistory()
        let first = HistoryPage(actions: [original], correctedActionIDs: [original.id],
                                nextCursor: HistoryCursor(timestamp: start, key: "a:\(original.id.uuidString)"))
        loaded.append(first); loaded.append(first)
        XCTAssertEqual(loaded.page.actions.count, 1)
        var core = AppData(); core.grimoire.practices = [practice]
        let rows = ChronicleTimeline.items(data: core, range: range, history: loaded.page)
        XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(rows[0].undone, "A correction need not fall inside the visible date range.")
        XCTAssertTrue(core.grimoire.actions.isEmpty)
    }

    func testShortPageFrontierHoldsOlderCoreRowsUntilLedgerIsRead() {
        let newest = ChronicleItem(id: "action:new", date: start.addingTimeInterval(20), category: .actions,
                                   title: "New action", summary: "", route: "action", recordID: UUID())
        let core = ChronicleItem(id: "legacy:old", date: start, category: .reflections,
                                 title: "Older reflection", summary: "", route: "legacyReflection", recordID: UUID())
        let cursor = HistoryCursor(timestamp: newest.date, key: newest.orderKey)
        XCTAssertEqual(ChronicleTimeline.merged(core: [core], history: [newest], cursor: cursor).map(\.title), ["New action"])
        let intervening = ChronicleItem(id: "revision:middle", date: start.addingTimeInterval(10), category: .revisions,
                                       title: "Intervening revision", summary: "", route: "revision", recordID: UUID())
        XCTAssertEqual(ChronicleTimeline.merged(core: [core], history: [newest, intervening], cursor: nil).map(\.title),
                       ["New action", "Intervening revision", "Older reflection"])
    }

    func testCoreProjectionDoesNotReadUnrequestedPortableHistory() {
        var data = AppData()
        var action = ActionRecord(practiceID: UUID()); action.occurredAt = start
        data.grimoire.actions = [action]
        XCTAssertTrue(ChronicleTimeline.items(data: data, range: range).isEmpty,
                      "Only an explicitly loaded page supplies the runtime ledger.")
    }

    @MainActor func testRepositoryPagesKeepTiedActionsRevisionsAndCorrectionsFaithful() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ChroniclePages-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        var data = AppData()
        var practice = PracticeDefinition(title: "Synthetic page fixture")
        practice.schedule.kind = .daily
        practice.schedule.startDate = LocalDay(start, timeZone: TimeZone(secondsFromGMT: 0)!)
        practice.schedule.homeTimeZoneID = "GMT"
        data.grimoire.settings.homeTimeZoneID = "GMT"; data.grimoire.settings.followsTravelTimeZone = false
        data.grimoire.practices = [practice]
        let occurrence = try XCTUnwrap(ScheduleEngine.occurrences(for: practice, in: range, settings: data.grimoire.settings).first)
        data.grimoire.occurrences = [occurrence]
        for index in 0..<113 {
            data.grimoire.actions.append(ActionRecord(occurrenceID: occurrence.id, practiceID: practice.id, kind: .progress,
                occurredAt: start.addingTimeInterval(Double(index % 3)), recordedAt: start.addingTimeInterval(Double(index)),
                timeZoneID: "GMT", notes: "Synthetic note \(index)", titleSnapshot: practice.title))
        }
        let original = data.grimoire.actions[0]
        data.grimoire.actions.append(ActionRecord(occurrenceID: occurrence.id, practiceID: practice.id,
            sessionID: original.sessionID, kind: .correction, occurredAt: range.end, recordedAt: range.end,
            timeZoneID: "GMT", reversesActionID: original.id, titleSnapshot: practice.title))
        for index in 0..<13 {
            data.grimoire.revisions.append(GrimoireRevision(recordID: practice.id, recordType: "Practice",
                title: practice.title, summary: "Synthetic revision \(index)", changedAt: start,
                before: Data("{}".utf8), after: Data("{}".utf8)))
        }
        let store = AppStore(directory: directory)
        try store.restore(BackupPayload(data: data, images: [:]))
        XCTAssertTrue(store.data.grimoire.actions.isEmpty)
        XCTAssertTrue(store.data.grimoire.revisions.isEmpty)
        var loaded = ChronicleLoadedHistory()
        var cursor: HistoryCursor?, pages = 0
        repeat {
            let page = try store.historyPage(in: range, limit: 7, cursor: cursor)
            XCTAssertLessThanOrEqual(page.actions.count + page.revisions.count, 7)
            if let next = page.nextCursor { XCTAssertNotEqual(next, cursor) }
            loaded.append(page); cursor = page.nextCursor; pages += 1
        } while cursor != nil && pages < 100
        XCTAssertNil(cursor)
        XCTAssertGreaterThan(pages, 1)
        XCTAssertEqual(loaded.page.actions.count, 113)
        XCTAssertEqual(loaded.page.revisions.count, 13)
        XCTAssertEqual(Set(loaded.page.actions.map(\.id)).count, 113)
        XCTAssertTrue(loaded.page.correctedActionIDs.contains(original.id))
        let rows = ChronicleTimeline.items(data: store.data, range: range, history: loaded.page)
        XCTAssertEqual(rows.count, 126)
        XCTAssertTrue(try XCTUnwrap(rows.first { $0.recordID == original.id }).undone)
        XCTAssertFalse(rows.contains { $0.actionKind == .correction }, "The correction itself lies outside the half-open range.")
    }
}
