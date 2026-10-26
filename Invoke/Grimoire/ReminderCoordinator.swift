import Foundation
import Combine
import CryptoKit
import UserNotifications

struct PlannedReminder: Equatable, Identifiable {
    var id: String
    var fireDate: Date
    var title: String
    var body: String
    var occurrenceID: String?
    var sound: Bool
    var importanceRank: Int
}

/// Calendar-aware, bounded notification projection. It never changes a due date.
enum ReminderPlanner {
    static let maximumRequests = 48
    static let horizonDays = 30

    static func plan(data: GrimoireData, namespace: String, now: Date,
                     currentZone: TimeZone = .current) -> [PlannedReminder] {
        let settings = data.settings
        guard settings.remindersEnabled else { return [] }
        let zone = settings.followsTravelTimeZone ? currentZone : (TimeZone(identifier: settings.homeTimeZoneID) ?? currentZone)
        let calendar = ScheduleEngine.calendar(zone: zone, weekStart: settings.weekStartsOn)
        guard let end = calendar.date(byAdding: .day, value: horizonDays, to: now) else { return [] }
        let range = DateInterval(start: calendar.startOfDay(for: now), end: end)
        let practices = Dictionary(uniqueKeysWithValues: data.practices.map { ($0.id, $0) })
        let activeActions = ScheduleEngine.activeActions(data.actions)
        let byPractice = Dictionary(grouping: activeActions, by: \.practiceID)
        let byOccurrence = Dictionary(grouping: activeActions, by: \.occurrenceID)
        var occurrences: [String: PracticeOccurrence] = [:]
        for practice in data.practices where !practice.archived && !practice.paused && practice.schedule.reminderHour != nil {
            for occurrence in ScheduleEngine.occurrences(for: practice, in: range, settings: settings,
                actions: byPractice[practice.id] ?? [], events: data.events, currentZone: currentZone, limit: 500) {
                occurrences[occurrence.id] = occurrence
            }
        }
        // Stored deferrals, snoozes, history and supersession win over projection.
        for occurrence in data.occurrences { occurrences[occurrence.id] = occurrence }
        var result: [PlannedReminder] = []
        for occurrence in occurrences.values {
            guard !occurrence.superseded, let practice = practices[occurrence.practiceID],
                  !practice.archived, !practice.paused else { continue }
            let status = GrimoireLogic.status(of: occurrence, actions: byOccurrence[occurrence.id] ?? [])
            guard status != .completed && status != .skipped else { continue }
            let occurrenceZone = TimeZone(identifier: occurrence.timeZoneID) ?? zone
            let cal = ScheduleEngine.calendar(zone: occurrenceZone, weekStart: settings.weekStartsOn)
            var proposed: Date?
            if let snooze = occurrence.reminderSnoozedUntil {
                proposed = snooze
            } else if let hour = practice.schedule.reminderHour {
                let day = occurrence.deferredUntil.map { LocalDay($0, timeZone: occurrenceZone) } ?? occurrence.windowStart
                proposed = ScheduleEngine.wallTime(day: day, hour: hour, minute: practice.schedule.reminderMinute, calendar: cal)
            }
            guard var fire = proposed else { continue }
            fire = max(fire, occurrence.availableAt)
            if let deferred = occurrence.deferredUntil { fire = max(fire, deferred) }
            // Quiet hours follow the person's global home/travel preference, even
            // when a particular practice intentionally stays in another zone.
            fire = afterQuietHours(fire, settings: settings, calendar: calendar)
            guard fire > now, fire < end else { continue }
            let token = SHA256.hash(data: Data(occurrence.id.utf8)).map { String(format: "%02x", $0) }.joined()
            result.append(PlannedReminder(id: namespace + "occurrence." + token,
                fireDate: fire, title: "Invoke", body: settings.privateNotificationPreviews ? "A planned practice is ready. Open Invoke to review it." : occurrence.title,
                occurrenceID: occurrence.id, sound: settings.soundEnabled, importanceRank: practice.importance.rank))
        }
        if settings.digestEnabled {
            for offset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                      let wall = ScheduleEngine.wallTime(day: LocalDay(day, timeZone: zone), hour: settings.digestHour, minute: 0, calendar: calendar) else { continue }
                let fire = afterQuietHours(wall, settings: settings, calendar: calendar)
                guard fire > now else { continue }
                result.append(PlannedReminder(id: namespace + "digest." + LocalDay(day, timeZone: zone).description,
                    fireDate: fire, title: "Invoke", body: "Your daily review is ready when you are.",
                    occurrenceID: nil, sound: settings.soundEnabled, importanceRank: Importance.supporting.rank))
            }
        }
        return Array(result.sorted {
            if $0.fireDate != $1.fireDate { return $0.fireDate < $1.fireDate }
            if $0.importanceRank != $1.importanceRank { return $0.importanceRank < $1.importanceRank }
            return $0.id < $1.id
        }.prefix(maximumRequests))
    }

    static func afterQuietHours(_ date: Date, settings: GrimoireSettings, calendar: Calendar) -> Date {
        let start = settings.quietHoursStart, end = settings.quietHoursEnd
        guard start != end else { return date } // Equal hours means quiet hours are disabled.
        let hour = calendar.component(.hour, from: date)
        let inside = start < end ? (hour >= start && hour < end) : (hour >= start || hour < end)
        guard inside else { return date }
        let nextDay = start > end && hour >= start
        guard let target = nextDay ? calendar.date(byAdding: .day, value: 1, to: date) : date,
              let adjusted = ScheduleEngine.wallTime(day: LocalDay(target, timeZone: calendar.timeZone), hour: end, minute: 0, calendar: calendar) else { return date }
        return adjusted
    }
}

@MainActor
protocol NotificationGateway {
    func settings() async -> UNAuthorizationStatus
    func requestPermission() async throws -> Bool
    func pendingIdentifiers() async -> [String]
    func remove(identifiers: [String])
    func add(_ reminder: PlannedReminder) async throws
}

@MainActor
private final class SystemNotificationGateway: NotificationGateway {
    private let center = UNUserNotificationCenter.current()
    func settings() async -> UNAuthorizationStatus { await center.notificationSettings().authorizationStatus }
    func requestPermission() async throws -> Bool { try await center.requestAuthorization(options: [.alert, .sound]) }
    func pendingIdentifiers() async -> [String] { await center.pendingNotificationRequests().map(\.identifier) }
    func remove(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
    func add(_ reminder: PlannedReminder) async throws {
        let content = UNMutableNotificationContent()
        content.title = reminder.title; content.body = reminder.body
        if reminder.sound { content.sound = .default }
        if let id = reminder.occurrenceID { content.userInfo = ["invokeOccurrenceID": id] }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.fireDate)
        components.timeZone = calendar.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
    }
}

/// UserNotifications is optional; every quest remains available in the app.
/// The private installation namespace is outside portable backups and generations.
/// LiveContainer guest apps can share a notification host: never remove all requests.
@MainActor
final class ReminderCoordinator: ObservableObject {
    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined
    @Published private(set) var statusMessage = "Reminders are off. Your plans remain available in Invoke."
    @Published private(set) var scheduledCount = 0
    private let gateway: NotificationGateway
    private var requested: (GrimoireData, URL)?
    private var worker: Task<Void, Never>?

    init(gateway: NotificationGateway? = nil) { self.gateway = gateway ?? SystemNotificationGateway() }

    var authorizationDescription: String {
        switch authorization {
        case .authorized: "Allowed"; case .provisional: "Quiet delivery allowed"; case .ephemeral: "Temporarily allowed"
        case .denied: "Not allowed — in-app reminders remain available"; case .notDetermined: "Not requested"
        @unknown default: "Check device notification settings"
        }
    }
    func refreshAuthorization() async { authorization = await gateway.settings() }
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            let allowed = try await gateway.requestPermission()
            await refreshAuthorization()
            if !allowed { statusMessage = "Notifications are not allowed. Use Today for in-app reminders. In LiveContainer, its Fix Local Notifications option may be needed." }
            return allowed
        } catch {
            statusMessage = "Notifications could not be enabled. Your plans are still available in Invoke. \(error.localizedDescription)"
            return false
        }
    }
    func schedule(store: AppStore) {
        store.flush()
        guard store.saveState == "Saved on this iPhone" else {
            statusMessage = "Save changes successfully before updating device reminders. Existing reminders have been retained."
            return
        }
        requested = (store.data.grimoire, store.directory)
        guard worker == nil else { return }
        // Serialize reconciliation so an older async add cannot outlive a newer cancellation.
        worker = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let self else { return }
            while let (data, directory) = requested {
                requested = nil
                await reconcile(data: data, directory: directory)
            }
            worker = nil
        }
    }
    func reconcile(data: GrimoireData, directory: URL, now: Date = Date()) async {
        do {
            let prefix = try installationNamespace(directory: directory)
            authorization = await gateway.settings()
            let allPending = await gateway.pendingIdentifiers()
            let pending = allPending.filter { $0.hasPrefix(prefix) }
            let foreignCount = allPending.count - pending.count
            let allowed = authorization == .authorized || authorization == .provisional || authorization == .ephemeral
            let candidates = allowed ? ReminderPlanner.plan(data: data, namespace: prefix, now: now) : []
            // LiveContainer may share its notification host with other guests.
            // Budget conservatively against existing foreign requests instead
            // of filling a separate 48-request queue and displacing them.
            let availableSlots = max(0, ReminderPlanner.maximumRequests - foreignCount)
            let plan = Array(candidates.prefix(availableSlots))
            let desired = Set(plan.map(\.id))
            gateway.remove(identifiers: pending.filter { !desired.contains($0) })
            scheduledCount = 0
            for reminder in plan { try await gateway.add(reminder); scheduledCount += 1 }
            if !data.settings.remindersEnabled {
                statusMessage = "Reminders are off. Your plans remain available in Invoke."
            } else if !allowed {
                statusMessage = "Device notifications are unavailable. Today still shows in-app reminders. Check permission or LiveContainer's Fix Local Notifications setting."
            } else {
                statusMessage = "\(scheduledCount) upcoming reminders scheduled. Invoke schedules up to 48 requests within 30 days; reopen it to refresh the horizon. Device and LiveContainer settings control delivery."
                if candidates.count > availableSlots {
                    statusMessage += " Other notifications already use this host, so Invoke has reserved their capacity. Remaining plans are visible in Today."
                }
            }
        } catch {
            statusMessage = "Some device reminders could not be updated. Your plans remain in Invoke. \(error.localizedDescription)"
        }
    }
    private func installationNamespace(directory: URL) throws -> String {
        let url = directory.appendingPathComponent("notification-installation-id")
        let identifier: UUID
        if FileManager.default.fileExists(atPath: url.path) {
            let text = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let saved = UUID(uuidString: text) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            identifier = saved
        } else {
            identifier = UUID()
            try Data(identifier.uuidString.utf8).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        return "app.invoke.\(identifier.uuidString)."
    }
}
