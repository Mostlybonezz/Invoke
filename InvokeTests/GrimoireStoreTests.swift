import XCTest
@testable import Invoke

final class GrimoireStoreTests: XCTestCase {
    private func date(_ value: String = "2024-01-02T12:00:00Z") -> Date { ISO8601DateFormatter().date(from: value)! }
    @MainActor private func store() -> AppStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("GrimoireTests-\(UUID())")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return AppStore(directory: directory)
    }
    private func practice(_ kind: ScheduleKind = .daily, title: String = "My practice") -> PracticeDefinition {
        var p = PracticeDefinition(title: title)
        p.createdAt = date("2024-01-01T00:00:00Z"); p.effectiveFrom = p.createdAt
        p.schedule.startDate = LocalDay(year: 2024, month: 1, day: 1); p.schedule.kind = kind; p.schedule.homeTimeZoneID = "GMT"
        return p
    }
    @MainActor private func occurrence(_ store: AppStore, practice p: PracticeDefinition? = nil) throws -> PracticeOccurrence {
        try store.activatePractice(p ?? practice())
        let row = try XCTUnwrap(store.grimoireOccurrences(in: DateInterval(start: date("2024-01-02T00:00:00Z"), end: date("2024-01-03T00:00:00Z"))).first)
        try store.ensureOccurrence(row); return row
    }
    @MainActor func testInvocationPracticeCompletionChronicleUndoAndRestartUseOneRecord() throws {
        let s = store(); let goal = Invocation(title: "Forge the form", intention: "My own direction")
        try s.saveInvocation(goal)
        var p = practice(); p.invocationID = goal.id
        let row = try occurrence(s, practice: p)
        let session = try s.beginSession(occurrenceID: row.id, now: date())
        let action = try s.recordAction(occurrenceID: row.id, kind: .complete, sessionID: session, requestID: UUID(), occurredAt: date(), now: date())
        XCTAssertEqual(s.sessionCount(for: row), 1); XCTAssertEqual(s.occurrenceStatus(row), .completed)
        XCTAssertEqual(s.data.grimoire.invocations[0].observations.count, 0)
        let reopened = AppStore(directory: s.directory)
        XCTAssertEqual(reopened.sessionCount(for: row), 1); XCTAssertEqual(reopened.data.grimoire.practices[0].invocationID, goal.id)
        try reopened.undoAction(action.id, now: date("2024-01-02T13:00:00Z"))
        XCTAssertEqual(reopened.sessionCount(for: row), 0)
        XCTAssertEqual(reopened.data.grimoire.actions.filter { $0.kind == .correction }.count, 1)
        XCTAssertEqual(AppStore(directory: s.directory).sessionCount(for: row), 0)
    }
    @MainActor func testRetryDoubleTapAndReopenCannotDuplicateOneCompletion() throws {
        let s = store(); let row = try occurrence(s)
        let session = try s.beginSession(occurrenceID: row.id, now: date()), request = UUID()
        let first = try s.recordAction(occurrenceID: row.id, kind: .complete, sessionID: session, requestID: request, occurredAt: date(), now: date())
        let retry = try s.recordAction(occurrenceID: row.id, kind: .complete, sessionID: session, requestID: request, occurredAt: date(), now: date())
        XCTAssertEqual(first.id, retry.id)
        let reopened = AppStore(directory: s.directory)
        let duplicate = try reopened.recordAction(occurrenceID: row.id, kind: .complete, sessionID: UUID(), requestID: UUID(), occurredAt: date(), now: date())
        XCTAssertEqual(first.id, duplicate.id); XCTAssertEqual(reopened.sessionCount(for: row), 1)
    }
    @MainActor func testQuotaCountsTwoDistinctSessionsButNotRetry() throws {
        let s = store(); let row = try occurrence(s, practice: practice(.weeklyQuota))
        let first = try s.beginSession(occurrenceID: row.id, now: date()), request = UUID()
        _ = try s.recordAction(occurrenceID: row.id, kind: .complete, sessionID: first, requestID: request, occurredAt: date(), now: date())
        _ = try s.recordAction(occurrenceID: row.id, kind: .complete, sessionID: first, requestID: request, occurredAt: date(), now: date())
        XCTAssertEqual(s.sessionCount(for: row), 1); XCTAssertEqual(s.occurrenceStatus(row), .partial)
        let second = try s.beginSession(occurrenceID: row.id, newSession: true, now: date("2024-01-03T12:00:00Z"))
        _ = try s.recordAction(occurrenceID: row.id, kind: .complete, sessionID: second, requestID: UUID(), occurredAt: date("2024-01-03T12:00:00Z"), now: date("2024-01-03T12:00:00Z"))
        XCTAssertNotEqual(first, second); XCTAssertEqual(s.sessionCount(for: row), 2); XCTAssertEqual(s.occurrenceStatus(row), .completed)
    }
    @MainActor func testBeginningAndResumingNeverCreditsCompletion() throws {
        let s = store(); var p = practice(); p.steps = [PracticeStep(title: "First"), PracticeStep(title: "Second")]; p.smallerVersion = "Only the first"
        let row = try occurrence(s, practice: p), session = try s.beginSession(occurrenceID: row.id, now: date())
        let reopened = AppStore(directory: s.directory)
        XCTAssertEqual(try reopened.beginSession(occurrenceID: row.id, now: date()), session)
        XCTAssertEqual(reopened.sessionCount(for: row), 0)
        XCTAssertEqual(reopened.occurrenceStatus(row), .inProgress)
    }
    @MainActor func testStepProgressDoesNotCreditFullRoutine() throws {
        let s = store(); var p = practice(); p.steps = [PracticeStep(title: "First"), PracticeStep(title: "Second")]
        let row = try occurrence(s, practice: p), session = try s.beginSession(occurrenceID: row.id, now: date())
        _ = try s.recordAction(occurrenceID: row.id, kind: .progress, sessionID: session, requestID: UUID(), steps: [p.steps[0].id], occurredAt: date(), now: date())
        let reopened = AppStore(directory: s.directory)
        XCTAssertEqual(try reopened.beginSession(occurrenceID: row.id, now: date()), session)
        XCTAssertEqual(reopened.activeActions(for: row.id).last?.completedStepIDs, [p.steps[0].id])
        XCTAssertThrowsError(try reopened.recordAction(occurrenceID: row.id, kind: .complete, sessionID: session, requestID: UUID(), steps: [p.steps[0].id], occurredAt: date(), now: date()))
        _ = try reopened.recordAction(occurrenceID: row.id, kind: .smaller, sessionID: session, requestID: UUID(), steps: [p.steps[0].id], occurredAt: date(), now: date())
        XCTAssertEqual(reopened.occurrenceStatus(row), .partial); XCTAssertEqual(reopened.sessionCount(for: row), 0)
    }
    @MainActor func testAnnualConsequentialDeadlineRemainsVisibleBesideDailyWork() throws {
        let s = store(); var annual = practice(.annual, title: "Actual obligation")
        annual.importance = .critical; annual.schedule.hardDeadline = true; annual.schedule.policy = .persist
        try s.activatePractice(annual); try s.activatePractice(practice())
        let rows = s.grimoireOccurrences(in: DateInterval(start: date("2024-01-15T00:00:00Z"), end: date("2024-01-16T00:00:00Z")), now: date("2024-01-15T12:00:00Z"))
        XCTAssertEqual(rows.first?.practiceID, annual.id); XCTAssertEqual(rows.filter { $0.practiceID != annual.id }.count, 1)
    }
    @MainActor func testMissingOptionalDaysDoNotAccumulateButDistinctBillsRemain() throws {
        let s = store(); try s.activatePractice(practice())
        var bills = practice(.daily, title: "Separate actual obligation"); bills.schedule.policy = .persist
        try s.activatePractice(bills)
        let rows = s.grimoireOccurrences(in: DateInterval(start: date("2024-01-15T00:00:00Z"), end: date("2024-01-16T00:00:00Z")))
        XCTAssertEqual(rows.filter { $0.practiceID == bills.id }.count, 15)
        XCTAssertEqual(rows.filter { $0.practiceID != bills.id }.count, 1)
    }
    @MainActor func testSnoozeAndDeferralDoNotAlterHardDeadlineAndUndoIsAudited() throws {
        let s = store(); var p = practice(); p.schedule.hardDeadline = true; p.schedule.deadlineHour = 17
        let row = try occurrence(s, practice: p), later = date("2024-01-03T12:00:00Z")
        try s.snoozeReminder(row.id, until: later); try s.deferOccurrence(row.id, to: later, now: date())
        XCTAssertEqual(s.data.grimoire.occurrences[0].hardDeadline, row.hardDeadline)
        let action = try XCTUnwrap(s.data.grimoire.actions.last)
        try s.undoAction(action.id, now: date())
        XCTAssertNil(s.data.grimoire.occurrences[0].deferredUntil)
        XCTAssertEqual(s.data.grimoire.occurrences[0].reminderSnoozedUntil, later)
    }
    @MainActor func testUndoCompletionInvalidatesDerivedFutureIntervalReminder() throws {
        let s = store(); var p = practice(.afterCompletion); p.schedule.interval = 1; p.schedule.intervalUnit = .month
        let row = try occurrence(s, practice: p), session = try s.beginSession(occurrenceID: row.id, now: date())
        let action = try s.recordAction(occurrenceID: row.id, kind: .complete, sessionID: session, requestID: UUID(), occurredAt: date(), now: date())
        let next = try XCTUnwrap(s.grimoireOccurrences(in: DateInterval(start: date("2024-02-01T00:00:00Z"), end: date("2024-03-01T00:00:00Z"))).first)
        try s.ensureOccurrence(next); try s.undoAction(action.id, now: date())
        XCTAssertTrue(s.data.grimoire.occurrences.first(where: { $0.id == next.id })!.superseded)
    }
    @MainActor func testFutureRevisionRetainsOriginalCompletedTitleAndSteps() throws {
        let s = store(); var p = practice(); p.steps = [PracticeStep(title: "Original step")]
        let row = try occurrence(s, practice: p), session = try s.beginSession(occurrenceID: row.id, now: date())
        _ = try s.recordAction(occurrenceID: row.id, kind: .complete, sessionID: session, requestID: UUID(), steps: p.steps.map(\.id), occurredAt: date(), now: date())
        p.title = "Changed"; p.steps = [PracticeStep(title: "Future step")]; p.schedule.kind = .weekly
        try s.savePractice(p, effectiveFrom: date("2024-01-03T00:00:00Z"))
        XCTAssertEqual(s.data.grimoire.practices[0].version, 2)
        XCTAssertEqual(s.data.grimoire.occurrences.first(where: { $0.id == row.id })?.title, "My practice")
        XCTAssertEqual(s.data.grimoire.occurrences.first(where: { $0.id == row.id })?.steps[0].title, "Original step")
        XCTAssertEqual(s.sessionCount(for: row), 1)
    }
    @MainActor func testPauseArchiveAndRestoreViewPreferencesNeverEraseHistory() throws {
        let s = store(); let row = try occurrence(s)
        let session = try s.beginSession(occurrenceID: row.id, now: date())
        _ = try s.recordAction(occurrenceID: row.id, kind: .complete, sessionID: session, requestID: UUID(), occurredAt: date(), now: date())
        try s.setPracticePaused(row.practiceID, paused: true)
        XCTAssertEqual(s.data.grimoire.actions.count, 2)
        try s.setPracticePaused(row.practiceID, paused: false); try s.archivePractice(row.practiceID)
        var v = s.data.grimoire; v.settings.restorationMode = true; try s.commitGrimoire(v)
        XCTAssertEqual(AppStore(directory: s.directory).data.grimoire.actions.count, 2)
    }
    @MainActor func testServiceableAssetKeepsUnknownDatesAndDoesNotCreateReplacement() throws {
        let s = store(); let boots = CareAsset(name: "Boots")
        try s.saveAsset(boots)
        let inspection = AssetInspection(date: date(), condition: "Serviceable")
        try s.recordInspection(assetID: boots.id, inspection: inspection)
        XCTAssertTrue(s.data.grimoire.practices.isEmpty); XCTAssertNil(s.data.grimoire.assets[0].purchasedAt)
        XCTAssertThrowsError(try s.recordInspection(assetID: boots.id, inspection: AssetInspection(condition: "Serviceable"), followUp: practice()))
    }
    @MainActor func testRepairInspectionCreatesOneExplicitLinkedQuestAtomically() throws {
        let s = store(); let boots = CareAsset(name: "Boots"); try s.saveAsset(boots)
        let inspection = AssetInspection(date: date(), condition: "Needs repair", notes: "Worn sole")
        let repair = practice(.unscheduled, title: "Arrange repair")
        try s.recordInspection(assetID: boots.id, inspection: inspection, followUp: repair)
        try s.recordInspection(assetID: boots.id, inspection: inspection, followUp: repair)
        XCTAssertEqual(s.data.grimoire.practices.count, 1); XCTAssertEqual(s.data.grimoire.assets[0].inspections.count, 1)
        XCTAssertEqual(s.data.grimoire.practices[0].assetID, boots.id)
        try s.saveAsset(boots)
        XCTAssertEqual(s.data.grimoire.assets[0].inspections.count, 1)
        XCTAssertEqual(AppStore(directory: s.directory).data.grimoire.practices.count, 1)
    }
    @MainActor func testArcanaBeliefRevisionAndEchoSourcesSurvivePortableRoundTrip() throws {
        let s = store(); var record = ArcanaRecord(title: "A question", source: "My chosen source", interpretation: "My interpretation")
        try s.saveArcana(record); record.beliefStatus = "Practicing"; try s.saveArcana(record)
        let echo = Echo(title: "Two perspectives", sourceA: "Source A", sourceB: "Source B", similarities: "A perceived similarity", differences: "A meaningful difference")
        try s.saveEcho(echo)
        XCTAssertEqual(s.data.grimoire.revisions.count, 1)
        XCTAssertTrue(s.data.grimoire.revisions[0].summary.contains("Exploring → Practicing"))
        let before = try PersistenceCoding.decoder().decode(ArcanaRecord.self, from: s.data.grimoire.revisions[0].before)
        XCTAssertEqual(before.beliefStatus, "Exploring")
        let restored = store(); try restored.restore(s.makeBackup().payload)
        XCTAssertEqual(restored.data.grimoire.echoes[0].differences, echo.differences)
        XCTAssertEqual(restored.data.grimoire.arcana[0].beliefStatus, "Practicing")
        XCTAssertEqual(restored.data.grimoire.revisions.count, 1)
    }
    @MainActor func testInvocationOutcomesAreIndependentAndStaleEditorPreservesObservations() throws {
        let s = store(); let original = Invocation(title: "Explore an idea"); try s.saveInvocation(original)
        var observed = original; observed.observations.append(InvocationObservation(observedAt: date(), text: "An actual change"))
        try s.saveInvocation(observed); try s.saveInvocation(original)
        XCTAssertEqual(s.data.grimoire.invocations[0].observations.count, 1)
        XCTAssertEqual(s.data.grimoire.invocations[0].status, "Active")
    }
    @MainActor func testSpecialtyRecordsAndSettingsPersistWithoutNetwork() throws {
        let s = store(); try s.saveSpell(Spell(title: "A saved technique", method: "My chosen steps", source: "Personal notes"))
        try s.saveEnchantment(Enchantment(title: "Prepared bag", supports: "My practice", establishmentEvidence: "I prepared it", status: "Established"))
        var v = s.data.grimoire; v.settings.fantasyLanguage = false; v.settings.homeTimeZoneID = "Asia/Kolkata"; v.settings.followsTravelTimeZone = false
        try s.commitGrimoire(v)
        let reopened = AppStore(directory: s.directory)
        XCTAssertEqual(reopened.data.grimoire.spells[0].source, "Personal notes")
        XCTAssertEqual(reopened.data.grimoire.enchantments[0].status, "Established")
        XCTAssertEqual(reopened.data.grimoire.settings.homeTimeZoneID, "Asia/Kolkata")
        XCTAssertFalse(reopened.data.grimoire.settings.fantasyLanguage)
    }
    @MainActor func testMergeIsIdempotentPreservesCurrentRecordsAndSettings() throws {
        let s = store(); let spell = Spell(title: "Mine"); try s.saveSpell(spell)
        let source = store(); var changed = spell; changed.title = "Incoming conflict"; try source.saveSpell(changed)
        try source.saveEcho(Echo(title: "Incoming additional record", sourceA: "A", sourceB: "B"))
        let payload = try source.makeBackup().payload
        try s.mergeBackup(payload); try s.mergeBackup(payload)
        XCTAssertEqual(s.data.grimoire.spells.count, 1); XCTAssertEqual(s.data.grimoire.spells[0].title, "Mine")
        XCTAssertEqual(s.data.grimoire.echoes.count, 1); XCTAssertNotNil(s.lastRecoveryBackupURL)
    }
    @MainActor func testInvalidImportCannotChangeMemoryOrCurrentPointer() throws {
        let s = store(); try s.saveSpell(Spell(title: "Keep this"))
        let pointer = try Data(contentsOf: s.directory.appendingPathComponent("CURRENT"))
        var broken = try s.makeBackup().payload
        broken.data.grimoire.settings.weekStartsOn = 9
        XCTAssertThrowsError(try s.restore(broken)); XCTAssertThrowsError(try s.mergeBackup(broken))
        XCTAssertEqual(try Data(contentsOf: s.directory.appendingPathComponent("CURRENT")), pointer)
        XCTAssertEqual(s.data.grimoire.spells[0].title, "Keep this")
    }
    @MainActor func testFailedAtomicActionDoesNotPublishSuccess() throws {
        let s = store(); let row = try occurrence(s)
        let generation = try String(contentsOf: s.directory.appendingPathComponent("CURRENT"), encoding: .utf8)
        let file = s.directory.appendingPathComponent("generations/\(generation)/data.json")
        try FileManager.default.moveItem(at: file, to: file.appendingPathExtension("retained"))
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        let before = s.data.grimoire.actions.count
        XCTAssertThrowsError(try s.beginSession(occurrenceID: row.id, now: date()))
        XCTAssertEqual(s.data.grimoire.actions.count, before)
    }
    @MainActor func testRetrospectiveActionKeepsEventTimeSeparateFromRecordedTime() throws {
        let s = store(); let row = try occurrence(s), session = try s.beginSession(occurrenceID: row.id, now: date("2024-01-05T12:00:00Z"))
        let action = try s.recordAction(occurrenceID: row.id, kind: .complete, sessionID: session, requestID: UUID(), occurredAt: date(), now: date("2024-01-05T12:00:00Z"))
        XCTAssertEqual(action.occurredAt, date()); XCTAssertEqual(action.recordedAt, date("2024-01-05T12:00:00Z"))
        XCTAssertEqual(action.timeZoneID, "GMT")
    }
    @MainActor func testLegacyDeletionClearsSourceLinksButKeepsNewPracticeHistory() throws {
        let s = store(); let entry = LibraryEntry(kind: .ritual, title: "Original ritual")
        s.data.entries.append(entry); s.flush()
        var p = practice(); p.legacyEntryID = entry.id; _ = try occurrence(s, practice: p)
        s.deleteEntry(id: entry.id)
        XCTAssertNil(s.data.grimoire.practices[0].legacyEntryID)
        XCTAssertEqual(s.data.grimoire.occurrences.count, 1)
        try BackupValidation.validateRecords(s.data)
    }
    @MainActor func testLargeFixtureProjectionDoesNotPersistSyntheticHistory() throws {
        let s = store(); var value = s.data.grimoire
        value.settings.followsTravelTimeZone = false; value.settings.homeTimeZoneID = "GMT"
        for index in 0..<1_000 {
            let p = practice(.daily, title: "Fixture practice \(index)")
            value.practices.append(p)
            for year in 2024...2026 {
                let range = DateInterval(start: date("\(year)-01-02T00:00:00Z"), end: date("\(year)-01-03T00:00:00Z"))
                let occurrence = try XCTUnwrap(ScheduleEngine.occurrences(for: p, in: range, settings: value.settings).first)
                value.occurrences.append(occurrence)
                value.actions.append(ActionRecord(occurrenceID: occurrence.id, practiceID: p.id, kind: .complete,
                    occurredAt: occurrence.availableAt, timeZoneID: "GMT", titleSnapshot: p.title))
            }
        }
        try s.commitGrimoire(value)
        let rows = s.grimoireOccurrences(in: DateInterval(start: date("2026-10-26T00:00:00Z"), end: date("2026-10-27T00:00:00Z")))
        XCTAssertEqual(rows.count, 1_000); XCTAssertEqual(s.data.grimoire.actions.count, 3_000); XCTAssertEqual(s.data.grimoire.occurrences.count, 3_000)
    }
}
