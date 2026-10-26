import XCTest
@testable import Invoke

final class ScheduleEngineTests: XCTestCase {
    private let utc = TimeZone(secondsFromGMT: 0)!
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private func settings(week: Int = 2, zone: String = "GMT") -> GrimoireSettings {
        var value = GrimoireSettings(); value.weekStartsOn = week; value.followsTravelTimeZone = false; value.homeTimeZoneID = zone; return value
    }
    private func practice(_ kind: ScheduleKind, start: LocalDay = LocalDay(year: 2024, month: 1, day: 1)) -> PracticeDefinition {
        var value = PracticeDefinition(title: "Chosen practice")
        value.schedule.kind = kind; value.schedule.startDate = start
        value.createdAt = date("2024-01-01T00:00:00Z"); value.effectiveFrom = value.createdAt
        return value
    }
    private func project(_ value: PracticeDefinition, _ from: String = "2024-01-01T00:00:00Z", _ to: String = "2024-04-01T00:00:00Z",
                         settings: GrimoireSettings? = nil, actions: [ActionRecord] = [], events: [GrimoireEvent] = []) -> [PracticeOccurrence] {
        ScheduleEngine.occurrences(for: value, in: DateInterval(start: date(from), end: date(to)), settings: settings ?? self.settings(), actions: actions, events: events, currentZone: utc)
    }
    func testDailyDateWindowsAndDistinctTimeSlots() {
        var value = practice(.daily)
        value.schedule.slots = [TimeSlot(name: "Morning", hour: 8), TimeSlot(name: "Evening", hour: 20)]
        let rows = project(value, "2024-01-01T00:00:00Z", "2024-01-03T00:00:00Z")
        XCTAssertEqual(rows.count, 4); XCTAssertEqual(Set(rows.map(\.id)).count, 4)
        XCTAssertEqual(rows.first?.availableAt, date("2024-01-01T08:00:00Z"))
    }
    func testSelectedWeekdaysHaveStableIdentityAcrossQueries() {
        var value = practice(.weekdays); value.schedule.weekdays = [2, 4, 6]
        let broad = project(value, "2024-01-01T00:00:00Z", "2024-01-08T00:00:00Z")
        let narrow = project(value, "2024-01-03T00:00:00Z", "2024-01-04T00:00:00Z")
        XCTAssertEqual(broad.map { $0.windowStart.day }, [1, 3, 5]); XCTAssertEqual(narrow.first?.id, broad[1].id)
    }
    func testWeeklyQuotaIsOneWindowNotSevenDailyObligations() {
        var value = practice(.weeklyQuota); value.schedule.quota = 2
        let rows = project(value, "2024-01-01T00:00:00Z", "2024-01-08T00:00:00Z")
        XCTAssertEqual(rows.count, 1); XCTAssertEqual(rows[0].requiredSessions, 2)
        XCTAssertEqual(rows[0].windowEnd, LocalDay(year: 2024, month: 1, day: 8))
    }
    func testConfigurableSundayWeekStartCrossesYearWithoutDuplication() {
        let value = practice(.weeklyQuota)
        let rows = project(value, "2024-01-01T00:00:00Z", "2024-01-07T00:00:00Z", settings: settings(week: 1))
        XCTAssertEqual(rows.count, 1); XCTAssertEqual(rows[0].windowStart, LocalDay(year: 2023, month: 12, day: 31))
    }
    func testMonthly31ClampsAndReturnsTo31() {
        var value = practice(.monthly); value.schedule.dayOfMonth = 31
        XCTAssertEqual(project(value).map { $0.windowStart.description }, ["2024-01-31", "2024-02-29", "2024-03-31"])
    }
    func testLastDayAndLastWeekday() {
        var value = practice(.monthly); value.schedule.lastDayOfMonth = true
        XCTAssertEqual(project(value).map { $0.windowStart.day }, [31, 29, 31])
        value.schedule.weekdayOrdinal = -1; value.schedule.ordinalWeekday = 6
        XCTAssertEqual(project(value).map { $0.windowStart.day }, [26, 23, 29])
    }
    func testMissingFifthWeekdayIsSkipped() {
        var value = practice(.monthly); value.schedule.weekdayOrdinal = 5; value.schedule.ordinalWeekday = 2
        XCTAssertEqual(project(value).map { $0.windowStart.description }, ["2024-01-29"])
    }
    func testAnnualFebruary29HasExplicitFebruary28Fallback() {
        let value = practice(.annual, start: LocalDay(year: 2024, month: 2, day: 29))
        XCTAssertEqual(project(value, "2024-01-01T00:00:00Z", "2027-01-01T00:00:00Z").map { $0.windowStart.description },
                       ["2024-02-29", "2025-02-28", "2026-02-28"])
    }
    func testQuarterlyAndSemiannualUseCalendarMonths() {
        var value = practice(.quarterly, start: LocalDay(year: 2024, month: 1, day: 15)); value.schedule.dayOfMonth = 15
        XCTAssertEqual(project(value, "2024-01-01T00:00:00Z", "2025-01-01T00:00:00Z").map { $0.windowStart.month }, [1, 4, 7, 10])
        value.schedule.kind = .semiannual
        XCTAssertEqual(project(value, "2024-01-01T00:00:00Z", "2025-01-01T00:00:00Z").map { $0.windowStart.month }, [1, 7])
    }
    func testCalendarQuarterHasQuarterWindow() {
        var value = practice(.quarterly); value.schedule.calendarQuarter = true
        let rows = project(value, "2024-02-10T00:00:00Z", "2024-05-01T00:00:00Z")
        XCTAssertEqual(rows.count, 2); XCTAssertEqual(rows[0].windowStart.month, 1); XCTAssertEqual(rows[0].windowEnd.month, 4)
    }
    func testCustomMonthlyIntervalDoesNotDriftAfterShortMonth() {
        var value = practice(.custom, start: LocalDay(year: 2024, month: 1, day: 31)); value.schedule.intervalUnit = .month
        XCTAssertEqual(project(value, "2024-02-01T00:00:00Z", "2024-06-01T00:00:00Z").map { $0.windowStart.description },
                       ["2024-02-29", "2024-03-31", "2024-04-30", "2024-05-31"])
    }
    func testCustomDayFastForwardKeepsOriginalAnchor() {
        var value = practice(.custom); value.schedule.interval = 3
        XCTAssertEqual(project(value, "2024-03-01T00:00:00Z", "2024-03-10T00:00:00Z").map { $0.windowStart.day }, [1, 4, 7])
    }
    func testCompletionIntervalUsesRealCompletionAndIgnoresSkip() {
        var value = practice(.afterCompletion); value.schedule.interval = 2; value.schedule.intervalUnit = .month
        let completed = ActionRecord(practiceID: value.id, kind: .complete, occurredAt: date("2024-01-31T12:00:00Z"))
        let skipped = ActionRecord(practiceID: value.id, kind: .skip, occurredAt: date("2024-02-15T12:00:00Z"))
        let rows = project(value, "2024-03-01T00:00:00Z", "2024-04-01T00:00:00Z", actions: [completed, skipped])
        XCTAssertEqual(rows.first?.windowStart.description, "2024-03-31")
    }
    func testUnknownCompletionIsNotInventedAndOverdueInitialRemainsEligible() {
        let value = practice(.afterCompletion)
        let rows = project(value, "2024-03-01T00:00:00Z", "2024-03-02T00:00:00Z")
        XCTAssertNil(value.schedule.lastActualCompletion); XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.windowStart.description, "2024-01-01")
    }
    func testCorrectionRemovesCompletionAnchor() {
        let value = practice(.afterCompletion)
        let completed = ActionRecord(practiceID: value.id, kind: .complete, occurredAt: date("2024-02-01T12:00:00Z"))
        let undo = ActionRecord(practiceID: value.id, kind: .correction, reversesActionID: completed.id)
        let rows = project(value, actions: [completed, undo])
        XCTAssertTrue(rows.first?.id.contains("initial") == true)
    }
    func testEventRequiresActualUserRecordedEventAndKeepsDistinctEvents() {
        var value = practice(.event); value.schedule.eventName = "Move"
        XCTAssertTrue(project(value).isEmpty)
        let one = GrimoireEvent(name: "Move", occurredAt: date("2024-02-01T12:00:00Z"))
        let two = GrimoireEvent(name: "move", occurredAt: date("2024-02-01T14:00:00Z"))
        XCTAssertEqual(Set(project(value, events: [one, two]).map(\.id)).count, 2)
    }
    func testConditionReviewDoesNotCreateReplacementActions() {
        var value = practice(.condition); value.schedule.interval = 1; value.schedule.intervalUnit = .month
        let rows = project(value)
        XCTAssertEqual(rows.count, 3); XCTAssertEqual(rows[0].practiceID, value.id)
    }
    func testUnscheduledHasStableIdentityAndNoInventedDueDate() {
        let value = practice(.unscheduled)
        let early = project(value)[0], later = project(value, "2025-01-01T00:00:00Z", "2026-01-01T00:00:00Z")[0]
        XCTAssertEqual(early.id, later.id); XCTAssertEqual(early.windowEnd, later.windowEnd)
        XCTAssertNil(early.dueAt); XCTAssertNil(later.hardDeadline)
    }
    func testOneOffHardDeadlineIsSeparateFromReminder() {
        var value = practice(.once); value.schedule.deadlineHour = 17; value.schedule.reminderHour = 9; value.schedule.hardDeadline = true
        let rows = project(value)
        XCTAssertEqual(rows[0].hardDeadline, date("2024-01-01T17:00:00Z")); XCTAssertEqual(rows.count, 1)
    }
    func testDSTGapMovesToNextValidInstantWithoutDuplicateDay() {
        var value = practice(.daily, start: LocalDay(year: 2024, month: 3, day: 10))
        value.schedule.slots = [TimeSlot(hour: 2, minute: 30)]
        let rows = project(value, "2024-03-10T08:00:00Z", "2024-03-11T07:00:00Z", settings: settings(zone: "America/Los_Angeles"))
        XCTAssertEqual(rows.count, 1); XCTAssertEqual(rows[0].availableAt, date("2024-03-10T10:00:00Z"))
    }
    func testDSTRepeatedHourChoosesFirstOffsetOnce() {
        var value = practice(.daily, start: LocalDay(year: 2024, month: 11, day: 3))
        value.schedule.slots = [TimeSlot(hour: 1, minute: 30)]
        let rows = project(value, "2024-11-03T07:00:00Z", "2024-11-04T08:00:00Z", settings: settings(zone: "America/Los_Angeles"))
        XCTAssertEqual(rows.count, 1); XCTAssertEqual(rows[0].availableAt, date("2024-11-03T08:30:00Z"))
    }
    func testNonDSTZoneAndHomeZonePolicy() {
        var value = practice(.daily); value.schedule.homeTimeZoneID = "Asia/Kolkata"; value.schedule.slots = [TimeSlot(hour: 9)]
        let rows = project(value, "2024-01-01T00:00:00Z", "2024-01-02T00:00:00Z", settings: settings(zone: "America/Los_Angeles"))
        XCTAssertEqual(rows.first?.timeZoneID, "Asia/Kolkata"); XCTAssertEqual(rows.first?.availableAt, date("2024-01-01T03:30:00Z"))
    }
    func testPausedArchivedAndEndDatesStopFutureProjection() {
        var value = practice(.daily); value.paused = true; XCTAssertTrue(project(value).isEmpty)
        value.paused = false; value.archived = true; XCTAssertTrue(project(value).isEmpty)
        value.archived = false; value.schedule.endDate = LocalDay(year: 2024, month: 1, day: 2)
        XCTAssertEqual(project(value).count, 2)
    }
    func testPauseWindowDoesNotGenerateBacklogOnResume() {
        var value = practice(.daily)
        value.pauses = [PracticePause(startedAt: date("2024-01-02T00:00:00Z"), endedAt: date("2024-01-05T00:00:00Z"))]
        XCTAssertEqual(project(value, "2024-01-01T00:00:00Z", "2024-01-06T00:00:00Z").map { $0.windowStart.day }, [1, 5])
    }
    func testProjectionIsBoundedForVeryLargeRange() {
        let value = practice(.daily)
        let rows = ScheduleEngine.occurrences(for: value, in: DateInterval(start: date("2024-01-01T00:00:00Z"), end: date("2090-01-01T00:00:00Z")), settings: settings(), limit: 30)
        XCTAssertEqual(rows.count, 30)
    }
}
