import XCTest
@testable import Invoke

final class SQLiteHistoryTests: XCTestCase {
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    private func directory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SQLiteHistoryTests-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    private func fixture(_ count: Int, tiedTimes: Bool = false) -> AppData {
        var value = AppData(), practice = PracticeDefinition(title: "Historical practice")
        practice.schedule.kind = .daily; practice.schedule.startDate = LocalDay(year: 2020, month: 1, day: 1)
        practice.schedule.homeTimeZoneID = "GMT"
        value.grimoire.practices = [practice]
        let range = DateInterval(start: date("2020-01-01T00:00:00Z"), end: date("2040-01-01T00:00:00Z"))
        value.grimoire.occurrences = Array(ScheduleEngine.occurrences(for: practice, in: range, settings: value.grimoire.settings, limit: count).prefix(count))
        value.grimoire.actions = value.grimoire.occurrences.map { row in
            ActionRecord(occurrenceID: row.id, practiceID: practice.id, kind: .complete,
                occurredAt: tiedTimes ? date("2024-01-01T12:00:00Z") : row.availableAt,
                recordedAt: tiedTimes ? date("2024-01-01T12:00:00Z") : row.availableAt,
                timeZoneID: "GMT", notes: "Original history note", titleSnapshot: row.title)
        }
        return value
    }
    @MainActor private func store(with value: AppData) throws -> AppStore {
        let store = AppStore(directory: try directory()); try store.commitGrimoire(value.grimoire); return store
    }
    @MainActor func testOrdinaryLaunchAndTodayDoNotDecodeFullHistory() throws {
        let source = try store(with: fixture(1_000))
        let reopened = AppStore(directory: source.directory)
        let repository = try XCTUnwrap(reopened.historyRepository)
        XCTAssertEqual(repository.decodedHistoryRecords, 0)
        XCTAssertEqual(reopened.historyCounts.actions, 1_000)
        XCTAssertTrue(reopened.data.grimoire.actions.isEmpty); XCTAssertTrue(reopened.data.grimoire.occurrences.isEmpty)
        let range = DateInterval(start: date("2026-10-26T00:00:00Z"), end: date("2026-10-27T00:00:00Z"))
        XCTAssertEqual(reopened.grimoireOccurrences(in: range).count, 1)
        XCTAssertEqual(repository.decodedHistoryRecords, 0, "Today must not deserialize older action notes or occurrence scripts")
        let page = try reopened.historyPage(limit: 25)
        XCTAssertEqual(page.actions.count, 25); XCTAssertNotNil(page.nextCursor)
        XCTAssertEqual(repository.decodedHistoryRecords, 25)
    }
    @MainActor func testStableKeysetPaginationAtEqualTimestampsHasNoGapsOrDuplicates() throws {
        var source = fixture(53, tiedTimes: true)
        for index in 0..<4 {
            source.grimoire.revisions.append(GrimoireRevision(recordID: source.grimoire.practices[0].id, recordType: "Practice",
                title: "Revision \(index)", summary: "Changed", changedAt: date("2024-01-01T12:00:00Z"), before: Data("{}".utf8), after: Data("{}".utf8)))
        }
        let store = try store(with: source)
        var cursor: HistoryCursor?, actionIDs: [UUID] = [], revisionIDs: [UUID] = []
        repeat {
            let page = try store.historyPage(limit: 7, cursor: cursor)
            actionIDs += page.actions.map(\.id); revisionIDs += page.revisions.map(\.id); cursor = page.nextCursor
            XCTAssertLessThanOrEqual(actionIDs.count + revisionIDs.count, 57)
        } while cursor != nil
        XCTAssertEqual(Set(actionIDs), Set(source.grimoire.actions.map(\.id))); XCTAssertEqual(actionIDs.count, 53)
        XCTAssertEqual(Set(revisionIDs), Set(source.grimoire.revisions.map(\.id))); XCTAssertEqual(revisionIDs.count, 4)
    }
    @MainActor func testCorrectionOutsideVisibleDateRangeStillMarksOriginalAndChangesCounts() throws {
        let source = fixture(3), store = try store(with: fixture(0))
        try store.commitGrimoire(source.grimoire)
        let original = source.grimoire.actions[0]
        try store.undoAction(original.id, now: date("2026-10-26T12:00:00Z"))
        let range = DateInterval(start: date("2020-01-01T00:00:00Z"), end: date("2020-01-02T00:00:00Z"))
        let page = try store.historyPage(in: range, includeRevisions: false)
        XCTAssertEqual(page.actions.map(\.id), [original.id]); XCTAssertTrue(page.correctedActionIDs.contains(original.id))
        XCTAssertEqual(store.completionCount(), 2); XCTAssertTrue(store.isActionCorrected(original.id))
    }
    @MainActor func testLiteralWildcardSearchAndCrossPagePayloadBudget() throws {
        var source = fixture(3, tiedTimes: true)
        source.grimoire.actions[0].notes = "Literal 50%_\\token " + String(repeating: "a", count: 3 * 1_024 * 1_024)
        source.grimoire.actions[1].notes = String(repeating: "b", count: 3 * 1_024 * 1_024)
        source.grimoire.actions[2].notes = String(repeating: "c", count: 3 * 1_024 * 1_024)
        let store = try store(with: source)
        XCTAssertEqual(try store.historyPage(search: "50%_\\token").actions.map(\.id), [source.grimoire.actions[0].id])
        let first = try store.historyPage(limit: 100)
        XCTAssertEqual(first.actions.count, 2); XCTAssertNotNil(first.nextCursor)
        let second = try store.historyPage(limit: 100, cursor: first.nextCursor)
        XCTAssertEqual(second.actions.count, 1); XCTAssertNil(second.nextCursor)
    }
    @MainActor func testChunkedCompletionQueriesDeduplicateMoreThanFourHundredPractices() throws {
        var value = AppData()
        for _ in 0..<450 {
            let slice = fixture(1, tiedTimes: true)
            value.grimoire.practices += slice.grimoire.practices; value.grimoire.occurrences += slice.grimoire.occurrences; value.grimoire.actions += slice.grimoire.actions
        }
        let store = try store(with: value)
        let ids = value.grimoire.practices.map(\.id), repeated = ids + ids
        XCTAssertEqual(store.completionCount(practiceIDs: repeated), 450)
        XCTAssertEqual(store.completionCount(practiceIDs: []), 0)
        let expected = value.grimoire.actions.sorted { $0.id.uuidString > $1.id.uuidString }.prefix(17).map(\.id)
        XCTAssertEqual(store.recentCompletions(practiceIDs: repeated, limit: 17).map(\.id), expected)
        XCTAssertEqual(try store.historyConflictCount(actionIDs: value.grimoire.actions.map(\.id) + value.grimoire.actions.map(\.id),
            occurrenceIDs: value.grimoire.occurrences.map(\.id), revisionIDs: []), 900)
    }
    @MainActor func testDeltaCommitCannotRewriteActionReuseRequestOrOrphanHistory() throws {
        let source = fixture(2), store = try store(with: fixture(0))
        try store.commitGrimoire(source.grimoire)
        let core = store.data, revision = store.historyRevision
        var edit = store.data.grimoire, changed = source.grimoire.actions[0]
        changed.notes = "Silently rewritten"; edit.actions = [changed]
        XCTAssertThrowsError(try store.commitGrimoire(edit))
        changed.id = UUID(); edit.actions = [changed]
        XCTAssertThrowsError(try store.commitGrimoire(edit))
        edit = store.data.grimoire; edit.practices = []
        XCTAssertThrowsError(try store.commitGrimoire(edit))
        XCTAssertEqual(store.data, core); XCTAssertEqual(store.historyRevision, revision); XCTAssertEqual(store.historyCounts.actions, 2)
        XCTAssertEqual(store.action(id: source.grimoire.actions[0].id)?.notes, "Original history note")
    }
    @MainActor func testRepositoryRejectsFutureSeedAndNoncurrentCoreCommitBeforeWriting() throws {
        let root = try directory(), repository = try SQLiteHistoryRepository(url: root.appendingPathComponent("history.sqlite"), create: true)
        var future = AppData(); future.schemaVersion = 99
        XCTAssertThrowsError(try repository.seed(future))
        try repository.seed(AppData())
        for version in [1, 99] {
            var invalid = AppData(); invalid.schemaVersion = version
            XCTAssertThrowsError(try repository.commit(invalid)); XCTAssertThrowsError(try repository.validateCore(invalid))
        }
        XCTAssertEqual(try repository.loadCore().schemaVersion, 2); XCTAssertEqual(try repository.counts().actions, 0)
    }
    @MainActor func testDailyRenewDeferralAndSnoozeRemainDiscoverableAfterRelaunch() throws {
        var source = fixture(1); source.grimoire.actions = []
        let store = try store(with: source), row = source.grimoire.occurrences[0]
        try store.deferOccurrence(row.id, to: date("2020-01-03T12:00:00Z"), now: date("2020-01-01T12:00:00Z"))
        try store.snoozeReminder(row.id, until: date("2020-01-03T13:00:00Z"))
        let reopened = AppStore(directory: store.directory)
        let range = DateInterval(start: date("2020-01-03T00:00:00Z"), end: date("2020-01-04T00:00:00Z"))
        let projected = reopened.grimoireOccurrences(in: range, now: date("2020-01-03T12:00:00Z"))
        XCTAssertTrue(projected.contains { $0.id == row.id && $0.deferredUntil == date("2020-01-03T12:00:00Z") })
        XCTAssertTrue(try reopened.reminderProjectionData(in: range, now: date("2020-01-03T12:00:00Z")).occurrences.contains { $0.id == row.id })
    }
    @MainActor func testSQLiteCorruptionBlocksEmptyBackupAndExplicitRestorePreservesDamagedGeneration() throws {
        var source: AppStore? = try store(with: fixture(3))
        let root = source!.directory, backup = try source!.makeBackup().payload
        let generation = try String(contentsOf: root.appendingPathComponent("CURRENT"), encoding: .utf8)
        source = nil
        let database = root.appendingPathComponent("generations/\(generation)/history.sqlite"), damaged = Data("damaged SQLite source".utf8)
        try damaged.write(to: database)
        let recovery = AppStore(directory: root)
        XCTAssertTrue(recovery.storageRecoveryRequired); XCTAssertThrowsError(try recovery.makeBackup())
        XCTAssertEqual(try Data(contentsOf: database), damaged)
        try recovery.restore(backup)
        XCTAssertFalse(recovery.storageRecoveryRequired); XCTAssertEqual(recovery.historyCounts.actions, 3)
        XCTAssertEqual(try Data(contentsOf: database), damaged)
        XCTAssertEqual(AppStore(directory: root).historyCounts.actions, 3)
    }
    @MainActor func testJSONHistoryMigrationIsAtomicPreservesRawBytesAndDoesNotRepeat() throws {
        let root = try directory(), old = UUID().uuidString, original = fixture(5)
        let folder = root.appendingPathComponent("generations/\(old)")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("images"), withIntermediateDirectories: true)
        let json = try JSONSerialization.jsonObject(with: PersistenceCoding.encoder().encode(original))
        let raw = try JSONSerialization.data(withJSONObject: ["formatVersion": 1, "writtenAt": 1_700_000_000_000, "data": json, "unrecognized": "Retain exact original bytes"])
        try raw.write(to: folder.appendingPathComponent("data.json")); try Data(old.utf8).write(to: root.appendingPathComponent("CURRENT"))
        let migrated = AppStore(directory: root)
        XCTAssertFalse(migrated.storageRecoveryRequired); XCTAssertEqual(migrated.historyCounts.actions, 5)
        XCTAssertTrue(migrated.data.grimoire.actions.isEmpty)
        let active = try String(contentsOf: root.appendingPathComponent("CURRENT"), encoding: .utf8)
        XCTAssertNotEqual(active, old); XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("data.json")), raw)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("generations/\(active)/legacy-schema-2.json")), raw)
        let reopened = AppStore(directory: root)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("CURRENT"), encoding: .utf8), active)
        XCTAssertEqual(reopened.historyRepository?.decodedHistoryRecords, 0); XCTAssertEqual(reopened.historyCounts.actions, 5)
        XCTAssertEqual(try reopened.exportFullData().grimoire.actions.map(\.id), original.grimoire.actions.map(\.id))
    }
}
