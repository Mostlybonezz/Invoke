import XCTest
import UserNotifications
@testable import Invoke

@MainActor
final class ReminderCoordinatorTests: XCTestCase {
    private let zone = TimeZone(identifier: "America/Los_Angeles") ?? .current
    private func instant(_ value: String) -> Date { ISO8601DateFormatter().date(from: value) ?? .distantPast }
    private func fixture(day: LocalDay = LocalDay(year: 2026, month: 10, day: 27), hour: Int = 9) -> GrimoireData {
        var data = GrimoireData()
        data.settings.remindersEnabled = true
        data.settings.followsTravelTimeZone = false
        data.settings.homeTimeZoneID = zone.identifier
        data.settings.quietHoursStart = 0; data.settings.quietHoursEnd = 0
        var practice = PracticeDefinition()
        practice.title = "Private practice title"; practice.effectiveFrom = instant("2026-01-01T00:00:00Z")
        practice.schedule.kind = .once; practice.schedule.startDate = day
        practice.schedule.reminderHour = hour; practice.schedule.reminderMinute = 30
        data.practices = [practice]
        return data
    }
    private func firstOccurrence(_ data: GrimoireData) throws -> PracticeOccurrence {
        try XCTUnwrap(ScheduleEngine.occurrences(for: data.practices[0],
            in: DateInterval(start: instant("2026-01-01T00:00:00Z"), end: instant("2027-01-01T00:00:00Z")),
            settings: data.settings).first)
    }
    func testDSTGapAndRepeatedHourEachScheduleOneInstant() {
        let spring = ReminderPlanner.plan(data: fixture(day: LocalDay(year: 2026, month: 3, day: 8), hour: 2),
            namespace: "spring.", now: instant("2026-03-07T12:00:00Z"), currentZone: zone)
        XCTAssertEqual(spring.count, 1)
        XCTAssertEqual(spring.first?.fireDate, instant("2026-03-08T10:00:00Z"))
        let autumn = ReminderPlanner.plan(data: fixture(day: LocalDay(year: 2026, month: 11, day: 1), hour: 1),
            namespace: "autumn.", now: instant("2026-10-31T12:00:00Z"), currentZone: zone)
        XCTAssertEqual(autumn.count, 1)
        XCTAssertEqual(autumn.first?.fireDate, instant("2026-11-01T08:30:00Z"))
    }
    func testQuietHoursMoveNotificationWithoutChangingDeadline() throws {
        var data = fixture(hour: 23)
        data.settings.quietHoursStart = 22; data.settings.quietHoursEnd = 8
        data.practices[0].schedule.deadlineHour = 23
        data.practices[0].schedule.hardDeadline = true
        data.occurrences = [try firstOccurrence(data)]
        let before = data
        let reminders = ReminderPlanner.plan(data: data, namespace: "invoke.", now: instant("2026-10-26T12:00:00Z"))
        XCTAssertEqual(reminders.first?.fireDate, instant("2026-10-28T15:00:00Z"))
        XCTAssertEqual(data, before)
        XCTAssertNotEqual(reminders.first?.fireDate, data.occurrences.first?.hardDeadline)
    }
    func testCompletionAndSkipCancelButUndoRestoresReminder() throws {
        var data = fixture()
        let occurrence = try firstOccurrence(data)
        data.occurrences = [occurrence]
        var action = ActionRecord(practiceID: occurrence.practiceID)
        action.occurrenceID = occurrence.id; action.kind = .complete
        data.actions = [action]
        let now = instant("2026-10-26T12:00:00Z")
        XCTAssertTrue(ReminderPlanner.plan(data: data, namespace: "invoke.", now: now).isEmpty)
        var correction = ActionRecord(practiceID: occurrence.practiceID)
        correction.occurrenceID = occurrence.id; correction.kind = .correction
        correction.reversesActionID = action.id
        data.actions.append(correction)
        XCTAssertEqual(ReminderPlanner.plan(data: data, namespace: "invoke.", now: now).count, 1)
        action.id = UUID(); action.kind = .skip
        data.actions.append(action)
        XCTAssertTrue(ReminderPlanner.plan(data: data, namespace: "invoke.", now: now).isEmpty)
    }
    func testQuietHoursUsePersonalZoneForPracticePinnedElsewhere() {
        var data = fixture(hour: 9)
        data.settings.quietHoursStart = 22; data.settings.quietHoursEnd = 8
        data.practices[0].schedule.homeTimeZoneID = "America/New_York"
        let reminders = ReminderPlanner.plan(data: data, namespace: "invoke.", now: instant("2026-10-26T12:00:00Z"), currentZone: zone)
        // 09:30 New York is 06:30 Los Angeles, inside the person's quiet hours.
        XCTAssertEqual(reminders.first?.fireDate, instant("2026-10-27T15:00:00Z"))
    }
    func testSmallerVersionDoesNotCancelFullPracticeReminder() throws {
        var data = fixture()
        let occurrence = try firstOccurrence(data)
        data.occurrences = [occurrence]
        var action = ActionRecord(practiceID: occurrence.practiceID)
        action.occurrenceID = occurrence.id; action.kind = .smaller
        data.actions = [action]
        XCTAssertEqual(ReminderPlanner.plan(data: data, namespace: "invoke.", now: instant("2026-10-26T12:00:00Z")).count, 1)
    }
    func testSnoozeUsesStoredOccurrenceAndKeepsItsDeadline() throws {
        var data = fixture()
        var occurrence = try firstOccurrence(data)
        let originalDue = occurrence.dueAt
        occurrence.reminderSnoozedUntil = instant("2026-10-28T18:00:00Z")
        data.occurrences = [occurrence]
        let reminders = ReminderPlanner.plan(data: data, namespace: "invoke.", now: instant("2026-10-26T12:00:00Z"))
        XCTAssertEqual(reminders.count, 1)
        XCTAssertEqual(reminders.first?.fireDate, occurrence.reminderSnoozedUntil)
        XCTAssertEqual(data.occurrences.first?.dueAt, originalDue)
    }
    func testManyPracticesRemainBoundedAndPrivate() {
        var data = fixture()
        let original = data.practices[0]
        data.practices = (0..<150).map { index in
            var practice = original; practice.id = UUID(); practice.title = "Private record \(index)"; return practice
        }
        let result = ReminderPlanner.plan(data: data, namespace: "private.", now: instant("2026-10-26T12:00:00Z"))
        XCTAssertEqual(result.count, 48)
        XCTAssertEqual(Set(result.map(\.id)).count, 48)
        XCTAssertTrue(result.allSatisfy { !$0.body.contains("Private record") && $0.title == "Invoke" && !$0.sound })
    }
    func testArchivePauseAndDisabledPreferencesRemoveCandidates() {
        var data = fixture()
        let now = instant("2026-10-26T12:00:00Z")
        data.practices[0].paused = true
        XCTAssertTrue(ReminderPlanner.plan(data: data, namespace: "invoke.", now: now).isEmpty)
        data.practices[0].paused = false; data.practices[0].archived = true
        XCTAssertTrue(ReminderPlanner.plan(data: data, namespace: "invoke.", now: now).isEmpty)
        data.practices[0].archived = false; data.settings.remindersEnabled = false
        XCTAssertTrue(ReminderPlanner.plan(data: data, namespace: "invoke.", now: now).isEmpty)
    }
    func testDeniedPermissionOnlyCancelsThisInstallationRequests() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("InvokeReminderTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let identifier = UUID()
        try Data(identifier.uuidString.utf8).write(to: directory.appendingPathComponent("notification-installation-id"))
        let own = "app.invoke.\(identifier.uuidString).old"
        let other = "another.guest.reminder"
        let gateway = FakeNotificationGateway()
        gateway.authorization = .denied; gateway.pending = [own, other]
        let coordinator = ReminderCoordinator(gateway: gateway)
        await coordinator.reconcile(data: fixture(), directory: directory, now: instant("2026-10-26T12:00:00Z"))
        XCTAssertEqual(gateway.removed, [own])
        XCTAssertTrue(gateway.added.isEmpty)
        XCTAssertEqual(coordinator.scheduledCount, 0)
        XCTAssertTrue(coordinator.statusMessage.contains("Today"))
    }
    func testNotificationFailureIsReportedWithoutChangingPlans() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("InvokeReminderTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let gateway = FakeNotificationGateway(); gateway.failAdd = true
        let coordinator = ReminderCoordinator(gateway: gateway)
        let data = fixture()
        await coordinator.reconcile(data: data, directory: directory, now: instant("2026-10-26T12:00:00Z"))
        XCTAssertEqual(data.practices.count, 1)
        XCTAssertTrue(coordinator.statusMessage.contains("could not be updated"))
        XCTAssertEqual(coordinator.scheduledCount, 0)
    }
}

@MainActor
private final class FakeNotificationGateway: NotificationGateway {
    var authorization: UNAuthorizationStatus = .authorized
    var pending: [String] = []
    var removed: [String] = []
    var added: [PlannedReminder] = []
    var failAdd = false
    func settings() async -> UNAuthorizationStatus { authorization }
    func requestPermission() async throws -> Bool { authorization == .authorized }
    func pendingIdentifiers() async -> [String] { pending }
    func remove(identifiers: [String]) { removed.append(contentsOf: identifiers) }
    func add(_ reminder: PlannedReminder) async throws {
        if failAdd { throw CocoaError(.featureUnsupported) }
        added.append(reminder)
    }
}
