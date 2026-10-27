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
        XCTAssertEqual(try reopened.historyPage(includeRevisions: false, actionKinds: [.correction]).actions.count, 1)
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
        // Deliberately use identical timestamps: the most recently saved progress,
        // including an unchecked step, must survive reopen and portable restore.
        _ = try s.recordAction(occurrenceID: row.id, kind: .progress, sessionID: session, requestID: UUID(), steps: [p.steps[1].id], occurredAt: date(), now: date())
        _ = try s.recordAction(occurrenceID: row.id, kind: .progress, sessionID: session, requestID: UUID(), steps: [], occurredAt: date(), now: date())
        _ = try s.recordAction(occurrenceID: row.id, kind: .progress, sessionID: session, requestID: UUID(), steps: [p.steps[0].id], occurredAt: date(), now: date())
        let reopened = AppStore(directory: s.directory)
        XCTAssertEqual(try reopened.beginSession(occurrenceID: row.id, now: date()), session)
        XCTAssertEqual(reopened.activeActions(for: row.id).last?.completedStepIDs, [p.steps[0].id])
        let restored = store()
        try restored.restore(reopened.makeBackup().payload)
        XCTAssertEqual(restored.activeActions(for: row.id).last?.completedStepIDs, [p.steps[0].id])
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
        XCTAssertEqual(s.occurrence(id: row.id)?.hardDeadline, row.hardDeadline)
        let action = try XCTUnwrap(s.activeActions(for: row.id).last)
        try s.undoAction(action.id, now: date())
        XCTAssertNil(s.occurrence(id: row.id)?.deferredUntil)
        XCTAssertEqual(s.occurrence(id: row.id)?.reminderSnoozedUntil, later)
    }
    @MainActor func testUndoCompletionInvalidatesDerivedFutureIntervalReminder() throws {
        let s = store(); var p = practice(.afterCompletion); p.schedule.interval = 1; p.schedule.intervalUnit = .month
        let row = try occurrence(s, practice: p), session = try s.beginSession(occurrenceID: row.id, now: date())
        let action = try s.recordAction(occurrenceID: row.id, kind: .complete, sessionID: session, requestID: UUID(), occurredAt: date(), now: date())
        let next = try XCTUnwrap(s.grimoireOccurrences(in: DateInterval(start: date("2024-02-01T00:00:00Z"), end: date("2024-03-01T00:00:00Z"))).first)
        try s.ensureOccurrence(next); try s.undoAction(action.id, now: date())
        XCTAssertTrue(s.occurrence(id: next.id)!.superseded)
    }
    @MainActor func testFutureRevisionRetainsOriginalCompletedTitleAndSteps() throws {
        let s = store(); var p = practice(); p.steps = [PracticeStep(title: "Original step")]
        p.instructions = "Original instructions"; p.context = "Original trigger"; p.materials = "Original materials"; p.smallerVersion = "Original smaller version"
        let row = try occurrence(s, practice: p), session = try s.beginSession(occurrenceID: row.id, now: date())
        _ = try s.recordAction(occurrenceID: row.id, kind: .complete, sessionID: session, requestID: UUID(), steps: p.steps.map(\.id), occurredAt: date(), now: date())
        p.title = "Changed"; p.steps = [PracticeStep(title: "Future step")]; p.schedule.kind = .weekly
        p.instructions = "Future instructions"; p.context = "Future trigger"; p.materials = "Future materials"; p.smallerVersion = "Future smaller version"
        try s.savePractice(p, effectiveFrom: date("2024-01-03T00:00:00Z"))
        XCTAssertEqual(s.data.grimoire.practices[0].version, 2)
        XCTAssertEqual(s.occurrence(id: row.id)?.title, "My practice")
        XCTAssertEqual(s.occurrence(id: row.id)?.steps[0].title, "Original step")
        XCTAssertEqual(s.sessionCount(for: row), 1)
        let saved = try XCTUnwrap(s.occurrence(id: row.id))
        XCTAssertEqual(saved.instructions, "Original instructions"); XCTAssertEqual(saved.context, "Original trigger")
        XCTAssertEqual(saved.materials, "Original materials"); XCTAssertEqual(saved.smallerVersion, "Original smaller version")
        XCTAssertEqual(s.data.grimoire.practices[0].revisions[0].context, "Original trigger")
    }
    @MainActor func testPauseArchiveAndRestoreViewPreferencesNeverEraseHistory() throws {
        let s = store(); let row = try occurrence(s)
        let session = try s.beginSession(occurrenceID: row.id, now: date())
        _ = try s.recordAction(occurrenceID: row.id, kind: .complete, sessionID: session, requestID: UUID(), occurredAt: date(), now: date())
        try s.setPracticePaused(row.practiceID, paused: true)
        XCTAssertEqual(s.historyCounts.actions, 2)
        try s.setPracticePaused(row.practiceID, paused: false); try s.archivePractice(row.practiceID)
        var v = s.data.grimoire; v.settings.restorationMode = true; try s.commitGrimoire(v)
        XCTAssertEqual(AppStore(directory: s.directory).historyCounts.actions, 2)
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
        XCTAssertEqual(s.data.grimoire.assets[0].condition, "Needs repair")
        XCTAssertEqual(AppStore(directory: s.directory).data.grimoire.practices.count, 1)
    }
    @MainActor func testArcanaBeliefRevisionAndEchoSourcesSurvivePortableRoundTrip() throws {
        let s = store(); var record = ArcanaRecord(title: "A question", source: "My chosen source", interpretation: "My interpretation")
        try s.saveArcana(record); record.beliefStatus = "Practicing"; try s.saveArcana(record)
        let echo = Echo(title: "Two perspectives", sourceA: "Source A", sourceB: "Source B", similarities: "A perceived similarity", differences: "A meaningful difference")
        try s.saveEcho(echo)
        XCTAssertEqual(s.historyCounts.revisions, 1)
        XCTAssertTrue(s.revisions(for: record.id)[0].summary.contains("Exploring → Practicing"))
        let before = try PersistenceCoding.decoder().decode(ArcanaRecord.self, from: s.revisions(for: record.id)[0].before)
        XCTAssertEqual(before.beliefStatus, "Exploring")
        let restored = store(); try restored.restore(s.makeBackup().payload)
        XCTAssertEqual(restored.data.grimoire.echoes[0].differences, echo.differences)
        XCTAssertEqual(restored.data.grimoire.arcana[0].beliefStatus, "Practicing")
        XCTAssertEqual(restored.historyCounts.revisions, 1)
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
        let s = store(), row = try occurrence(s)
        let session = try s.beginSession(occurrenceID: row.id, now: date())
        let repository = try XCTUnwrap(s.historyRepository)
        try repository.constrainStorageToCurrentSizeForTesting()
        let before = s.historyCounts.actions, revision = s.historyRevision
        XCTAssertThrowsError(try s.recordAction(occurrenceID: row.id, kind: .complete, sessionID: session,
            requestID: UUID(), notes: String(repeating: "large payload ", count: 20_000), occurredAt: date(), now: date()))
        XCTAssertEqual(s.historyCounts.actions, before); XCTAssertEqual(s.historyRevision, revision)
        XCTAssertEqual(s.occurrenceStatus(row), .inProgress)
        let reopened = AppStore(directory: s.directory)
        XCTAssertFalse(reopened.storageRecoveryRequired); XCTAssertEqual(reopened.historyCounts.actions, before)
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
        XCTAssertEqual(s.historyCounts.occurrences, 1)
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
        let reopenStart = ProcessInfo.processInfo.systemUptime
        let reopened = AppStore(directory: s.directory)
        let reopenDuration = ProcessInfo.processInfo.systemUptime - reopenStart
        let decoded = try XCTUnwrap(reopened.historyRepository).decodedHistoryRecords
        XCTAssertEqual(decoded, 0)
        let projectionStart = ProcessInfo.processInfo.systemUptime
        let rows = reopened.grimoireOccurrences(in: DateInterval(start: date("2026-10-26T00:00:00Z"), end: date("2026-10-27T00:00:00Z")))
        for row in rows { XCTAssertEqual(reopened.occurrenceStatus(row), .unrecorded); XCTAssertEqual(reopened.sessionCount(for: row), 0) }
        let projectionDuration = ProcessInfo.processInfo.systemUptime - projectionStart
        XCTAssertEqual(rows.count, 1_000); XCTAssertEqual(reopened.historyCounts.actions, 3_000); XCTAssertEqual(reopened.historyCounts.occurrences, 3_000)
        XCTAssertEqual(reopened.historyRepository?.decodedHistoryRecords, decoded, "Rendering 1,000 statuses must use indexed summaries, not decode action notes")
        let pageStart = ProcessInfo.processInfo.systemUptime
        let page = try reopened.historyPage(limit: 50)
        let pageDuration = ProcessInfo.processInfo.systemUptime - pageStart
        XCTAssertEqual(page.actions.count, 50); XCTAssertNotNil(page.nextCursor)
        print(String(format: "INVOKE_SCALE_METRICS practices=1000 actions=3000 occurrences=3000 in_process_reopen_ms=%.3f today_projection_and_1000_statuses_ms=%.3f chronicle_first_50_rows_ms=%.3f",
            reopenDuration * 1_000, projectionDuration * 1_000, pageDuration * 1_000))
    }
    @MainActor func testReplenishmentFollowUpIsExplicitAtomicAndRetrySafe() throws {
        let s = store(), asset = CareAsset(name: "Household supply")
        try s.saveAsset(asset)
        let observation = AssetInspection(condition: "Needs replenishment", notes: "Observed low stock")
        let quest = practice(.once, title: "Review replenishment")
        try s.recordInspection(assetID: asset.id, inspection: observation, followUp: quest)
        try s.recordInspection(assetID: asset.id, inspection: observation, followUp: quest)
        XCTAssertEqual(s.data.grimoire.assets[0].inspections.count, 1)
        XCTAssertEqual(s.data.grimoire.assets[0].condition, "Needs replenishment")
        XCTAssertEqual(s.data.grimoire.practices.map(\.id), [quest.id])
        XCTAssertThrowsError(try s.recordInspection(assetID: asset.id, inspection: AssetInspection(condition: "Needs repair"), followUp: quest))
        XCTAssertEqual(s.data.grimoire.assets[0].inspections.count, 1)
    }
    @MainActor func testEarlierOneOffRevisionRejectsWithoutLosingOriginalObligation() throws {
        let s = store(); var p = practice(.once)
        p.schedule.startDate = LocalDay(year: 2024, month: 1, day: 5)
        try s.activatePractice(p)
        let range = DateInterval(start: date("2024-01-01T00:00:00Z"), end: date("2024-01-10T00:00:00Z"))
        let old = try XCTUnwrap(s.grimoireOccurrences(in: range).first); try s.ensureOccurrence(old)
        p.schedule.startDate = LocalDay(year: 2024, month: 1, day: 2)
        XCTAssertThrowsError(try s.savePractice(p, effectiveFrom: date("2024-01-04T00:00:00Z")))
        XCTAssertEqual(s.data.grimoire.practices[0].version, 1)
        XCTAssertEqual(s.grimoireOccurrences(in: range).map(\.id), [old.id])
        XCTAssertFalse(s.occurrence(id: old.id)!.superseded)
    }
    @MainActor func testWeekStartChangeKeepsEarnedQuotaUntilOriginalBoundary() throws {
        let s = store(), p = practice(.weeklyQuota)
        let original = try occurrence(s, practice: p)
        _ = try s.recordAction(occurrenceID: original.id, kind: .complete, sessionID: UUID(), requestID: UUID(), occurredAt: date(), now: date())
        var changed = s.data.grimoire; changed.settings.weekStartsOn = 1
        try s.commitGrimoire(changed, now: date("2024-01-03T12:00:00Z"))
        let thisWeek = s.grimoireOccurrences(in: DateInterval(start: date("2024-01-03T00:00:00Z"), end: date("2024-01-04T00:00:00Z")), now: date("2024-01-03T12:00:00Z"))
        XCTAssertEqual(thisWeek.map(\.id), [original.id]); XCTAssertEqual(s.sessionCount(for: thisWeek[0]), 1)
        let next = s.grimoireOccurrences(in: DateInterval(start: date("2024-01-08T00:00:00Z"), end: date("2024-01-09T00:00:00Z")), now: date("2024-01-08T12:00:00Z"))
        XCTAssertEqual(next.count, 1); XCTAssertEqual(next[0].availableAt, date("2024-01-08T00:00:00Z"))
        XCTAssertEqual(next[0].windowEnd, LocalDay(year: 2024, month: 1, day: 14)); XCTAssertEqual(s.sessionCount(for: next[0]), 0)
    }
    @MainActor func testWeekStartChangeEstablishesOldPeriodBeforeAnyAction() throws {
        let s = store(), p = practice(.weeklyQuota); try s.activatePractice(p)
        XCTAssertEqual(s.historyCounts.occurrences, 0)
        var changed = s.data.grimoire; changed.settings.weekStartsOn = 1
        try s.commitGrimoire(changed, now: date("2024-01-03T12:00:00Z"))
        let current = try XCTUnwrap(s.exportFullData().grimoire.occurrences.first)
        XCTAssertEqual(current.windowStart, LocalDay(year: 2024, month: 1, day: 1))
        let rows = s.grimoireOccurrences(in: DateInterval(start: date("2024-01-03T00:00:00Z"), end: date("2024-01-04T00:00:00Z")))
        XCTAssertEqual(rows.map(\.id), [current.id]); XCTAssertEqual(s.sessionCount(for: current), 0)
    }
    @MainActor func testActionIndexInvalidatesAfterCorrectionAndReopen() throws {
        let s = store(), row = try occurrence(s)
        let action = try s.recordAction(occurrenceID: row.id, kind: .complete, sessionID: UUID(), requestID: UUID(), occurredAt: date(), now: date())
        XCTAssertEqual(s.occurrenceStatus(row), .completed)
        let before = s.historyRevision
        XCTAssertEqual(s.sessionCount(for: row), 1); XCTAssertEqual(s.historyRevision, before)
        try s.undoAction(action.id, now: date())
        XCTAssertEqual(s.occurrenceStatus(row), .unrecorded); XCTAssertEqual(s.sessionCount(for: row), 0)
        XCTAssertEqual(s.historyRevision, before + 1)
        XCTAssertEqual(AppStore(directory: s.directory).sessionCount(for: row), 0)
    }
    @MainActor func testProjectionOverflowIsDisclosedAndCannotSilentlyMaterializePartialHistory() throws {
        let s = store(); var p = practice()
        p.schedule.startDate = LocalDay(year: 1900, month: 1, day: 1); p.schedule.policy = .persist
        try s.activatePractice(p)
        let range = DateInterval(start: date("2024-01-01T00:00:00Z"), end: date("2024-01-02T00:00:00Z"))
        let report = s.grimoireProjection(in: range)
        XCTAssertTrue(report.truncated); XCTAssertFalse(report.warnings.isEmpty); XCTAssertEqual(report.occurrences.count, 20_000)
        XCTAssertThrowsError(try s.materializeOccurrences(in: range)); XCTAssertEqual(s.historyCounts.occurrences, 0)
    }
    @MainActor func testSpecialtySavesKeepCreationAdvanceUpdatedAndNormalizeInvocationArchive() throws {
        let s = store(), original = date("2020-01-01T00:00:00Z")
        var goal = Invocation(title: "Goal", createdAt: original, updatedAt: original)
        var spell = Spell(title: "Method", createdAt: original, updatedAt: original)
        var enchantment = Enchantment(title: "Arrangement", createdAt: original, updatedAt: original)
        var asset = CareAsset(name: "Asset", createdAt: original, updatedAt: original)
        var arcana = ArcanaRecord(title: "Record", createdAt: original, updatedAt: original)
        var echo = Echo(title: "Comparison", createdAt: original, updatedAt: original)
        try s.saveInvocation(goal); try s.saveSpell(spell); try s.saveEnchantment(enchantment); try s.saveAsset(asset); try s.saveArcana(arcana); try s.saveEcho(echo)
        goal.createdAt = date(); goal.status = "Archived"; spell.createdAt = date(); enchantment.createdAt = date(); asset.createdAt = date(); arcana.createdAt = date(); echo.createdAt = date()
        try s.saveInvocation(goal); try s.saveSpell(spell); try s.saveEnchantment(enchantment); try s.saveAsset(asset); try s.saveArcana(arcana); try s.saveEcho(echo)
        let v = s.data.grimoire
        XCTAssertEqual([v.invocations[0].createdAt, v.spells[0].createdAt, v.enchantments[0].createdAt, v.assets[0].createdAt, v.arcana[0].createdAt, v.echoes[0].createdAt], Array(repeating: original, count: 6))
        for updated in [v.invocations[0].updatedAt, v.spells[0].updatedAt, v.enchantments[0].updatedAt, v.assets[0].updatedAt, v.arcana[0].updatedAt, v.echoes[0].updatedAt] { XCTAssertGreaterThan(updated, original) }
        XCTAssertTrue(v.invocations[0].archived); XCTAssertEqual(v.invocations[0].status, "Archived")
        goal.archived = false; goal.status = "Active"; try s.saveInvocation(goal); XCTAssertFalse(s.data.grimoire.invocations[0].archived)
    }
}
