import Foundation

@MainActor
extension AppStore {
    func requireHistory() throws -> SQLiteHistoryRepository {
        guard !storageRecoveryRequired, let repository = historyRepository else {
            throw InvokeDataError.storageUnavailable("Saved history needs recovery before this operation can continue.")
        }
        return repository
    }
    private func historyRead<T>(_ fallback: T, _ operation: (SQLiteHistoryRepository) throws -> T) -> T {
        do { return try operation(requireHistory()) }
        catch {
            let message = error.localizedDescription
            // Keep selectors free of synchronous published changes during a SwiftUI body.
            Task { @MainActor [weak self] in
                guard let self, !self.storageRecoveryRequired else { return }
                self.markHistoryUnavailable(message)
            }
            return fallback
        }
    }
    var historyCounts: HistoryCounts {
        historyRead(HistoryCounts(actions: 0, occurrences: 0, revisions: 0)) { try $0.counts() }
    }
    func historyConflictCount(actionIDs: [UUID], occurrenceIDs: [String], revisionIDs: [UUID]) throws -> Int {
        try requireHistory().conflictCount(actionIDs: actionIDs, occurrenceIDs: occurrenceIDs, revisionIDs: revisionIDs)
    }
    func action(id: UUID) -> ActionRecord? { historyRead(nil) { try $0.action(id: id) } }
    func occurrence(id: String) -> PracticeOccurrence? { historyRead(nil) { try $0.occurrence(id: id) } }
    func revision(id: UUID) -> GrimoireRevision? { historyRead(nil) { try $0.revision(id: id) } }
    func isActionCorrected(_ id: UUID) -> Bool { historyRead(false) { try $0.isCorrected(id) } }
    func completionCount(practiceIDs: [UUID]? = nil, in range: DateInterval? = nil) -> Int {
        historyRead(0) { try $0.completionCount(practiceIDs: practiceIDs, range: range) }
    }
    func recentCompletions(practiceIDs: [UUID]? = nil, in range: DateInterval? = nil, limit: Int = 20) -> [ActionRecord] {
        historyRead([]) { try $0.recentCompletions(practiceIDs: practiceIDs, range: range, limit: limit) }
    }
    func revisions(for recordID: UUID, limit: Int = 50) -> [GrimoireRevision] {
        historyRead([]) { try $0.revisions(for: recordID, limit: limit) }
    }
    func activeActions(for occurrenceID: String) -> [ActionRecord] {
        if let saved = grimoireQueryCache.byOccurrence[occurrenceID] { return saved }
        let rows: [ActionRecord] = historyRead([]) { try $0.activeActions(for: occurrenceID) }
        if grimoireQueryCache.byOccurrence.count >= 500 { grimoireQueryCache.byOccurrence.removeAll() }
        grimoireQueryCache.byOccurrence[occurrenceID] = rows
        return rows
    }
    private func occurrenceSummary(_ occurrence: PracticeOccurrence) -> (OccurrenceStatus, Int) {
        if let saved = grimoireQueryCache.statuses[occurrence.id] { return saved }
        let result = historyRead((OccurrenceStatus.unrecorded, 0)) { try $0.summary(for: occurrence) }
        if grimoireQueryCache.statuses.count >= 20_000 { grimoireQueryCache.statuses.removeAll() }
        grimoireQueryCache.statuses[occurrence.id] = result
        return result
    }
    func occurrenceStatus(_ occurrence: PracticeOccurrence) -> OccurrenceStatus { occurrenceSummary(occurrence).0 }
    func sessionCount(for occurrence: PracticeOccurrence) -> Int { occurrenceSummary(occurrence).1 }
    func historyPage(in range: DateInterval? = nil, practiceID: UUID? = nil, includeActions: Bool = true,
                     includeRevisions: Bool = true, actionKinds: [ActionKind] = [], recordType: String? = nil,
                     search: String = "", limit: Int = 100, cursor: HistoryCursor? = nil) throws -> HistoryPage {
        try requireHistory().historyPage(in: range, practiceID: practiceID, includeActions: includeActions,
            includeRevisions: includeRevisions, actionKinds: actionKinds, recordType: recordType, search: search, limit: limit, cursor: cursor)
    }
    func exportFullData() throws -> AppData {
        let repository = try requireHistory()
        var complete = try repository.fullData(core: data)
        // Preserve any unsaved legacy draft and explicit pending history deltas.
        func merge<T: Identifiable>(_ pending: [T], into stored: inout [T]) throws where T.ID: Hashable {
            guard Set(pending.map(\.id)).count == pending.count else { throw InvokeDataError.invalidBackup("Pending history contains duplicate identifiers.") }
            let replacement = Dictionary(uniqueKeysWithValues: pending.map { ($0.id, $0) })
            let existing = Set(stored.map(\.id))
            stored = stored.map { replacement[$0.id] ?? $0 } + pending.filter { !existing.contains($0.id) }
        }
        try merge(data.grimoire.occurrences, into: &complete.grimoire.occurrences)
        try merge(data.grimoire.actions, into: &complete.grimoire.actions)
        try merge(data.grimoire.revisions, into: &complete.grimoire.revisions)
        return complete
    }
    private func completionAnchor(for practice: PracticeDefinition, repository: SQLiteHistoryRepository) throws -> [ActionRecord] {
        guard practice.schedule.kind == .afterCompletion else { return [] }
        if let saved = grimoireQueryCache.anchors[practice.id] { return saved }
        let rows = try repository.latestCompletion(for: practice.id).map { [$0] } ?? []
        grimoireQueryCache.anchors[practice.id] = rows
        return rows
    }
    func schedulePreview(for practice: PracticeDefinition, in range: DateInterval, limit: Int = 8) -> [PracticeOccurrence] {
        historyRead([]) { repository in
            ScheduleEngine.occurrences(for: practice, in: range, settings: data.grimoire.settings,
                actions: try completionAnchor(for: practice, repository: repository), events: data.grimoire.events, limit: limit)
        }
    }
    func grimoireOccurrences(in range: DateInterval, now: Date = Date(), practiceID: UUID? = nil) -> [PracticeOccurrence] {
        grimoireProjection(in: range, now: now, practiceID: practiceID).occurrences
    }
    func grimoireProjection(in range: DateInterval, now: Date = Date(), practiceID: UUID? = nil) -> GrimoireProjection {
        do { return try projectedHistory(in: range, now: now, practiceID: practiceID) }
        catch {
            let message = error.localizedDescription
            Task { @MainActor [weak self] in
                guard let self, !self.storageRecoveryRequired else { return }
                self.markHistoryUnavailable(message)
            }
            return GrimoireProjection(occurrences: [], warnings: ["History could not be read. No completion or missing action should be inferred. \(message)"])
        }
    }
    private func projectedHistory(in range: DateInterval, now: Date, practiceID: UUID?) throws -> GrimoireProjection {
        let repository = try requireHistory(), cache = grimoireQueryCache
        let key = GrimoireQueryCache.Key(start: range.start, end: range.end, minute: Int(now.timeIntervalSince1970 / 60),
            zone: TimeZone.current.identifier, practiceID: practiceID)
        if let saved = cache.projections[key] { return saved }
        let definitions = Dictionary(uniqueKeysWithValues: data.grimoire.practices.map { ($0.id, $0) })
        var result: [String: PracticeOccurrence] = [:], warnings: [String] = []
        for practice in data.grimoire.practices where !practice.archived && !practice.paused && (practiceID == nil || practice.id == practiceID) {
            let persistent = practice.schedule.policy == .persist || practice.schedule.hardDeadline || [.event, .once].contains(practice.schedule.kind)
            let retainsPast = persistent || [.unscheduled, .afterCompletion].contains(practice.schedule.kind)
            let zone = ScheduleEngine.zone(for: practice.schedule, settings: data.grimoire.settings)
            let cal = ScheduleEngine.calendar(zone: zone, weekStart: data.grimoire.settings.weekStartsOn)
            let anchor = ScheduleEngine.date(practice.schedule.startDate, in: cal) ?? practice.createdAt
            let query = DateInterval(start: persistent ? min(range.start, anchor) : range.start, end: range.end)
            let projected = ScheduleEngine.projection(for: practice, in: query, settings: data.grimoire.settings,
                actions: try completionAnchor(for: practice, repository: repository), events: data.grimoire.events)
            let ignored = try repository.ignoredOccurrenceIDs(projected.occurrences.map(\.id), before: range.start)
            let generated = projected.occurrences.filter { !ignored.contains($0.id) }
            let matching = try repository.occurrences(ids: generated.map(\.id))
            let retained = try repository.occurrences(for: practice.id, in: range, includeOverdue: retainsPast)
            if projected.truncated || retained.count > 20_000 {
                warnings.append("\(practice.title): this view reached its 20,000-occurrence limit. Earlier obligations are shown; later work may be outside this view. No saved records were removed.")
            }
            var stored = Dictionary(uniqueKeysWithValues: matching.map { ($0.id, $0) })
            for row in retained.prefix(20_000) { stored[row.id] = row }
            if [.weekly, .weeklyQuota].contains(practice.schedule.kind), let first = generated.map(\.availableAt).min() {
                let overlaps = try repository.overlappingPeriods(for: practice.id, version: practice.version, from: first, to: range.end)
                if overlaps.count > 20_000 { warnings.append("\(practice.title): too many overlapping stored periods to display in one view. No records were changed.") }
                for row in overlaps.prefix(20_000) { stored[row.id] = row }
            }
            for var occurrence in generated {
                if [.weekly, .weeklyQuota].contains(practice.schedule.kind) {
                    var suppressed = false
                    for prior in stored.values where !prior.superseded && prior.definitionVersion == occurrence.definitionVersion && prior.id != occurrence.id {
                        let oldCal = ScheduleEngine.calendar(zone: TimeZone(identifier: prior.timeZoneID) ?? zone)
                        guard let oldEnd = ScheduleEngine.date(prior.windowEnd, in: oldCal), let newEnd = ScheduleEngine.date(occurrence.windowEnd, in: cal),
                              prior.availableAt < newEnd, oldEnd > occurrence.availableAt else { continue }
                        if newEnd <= oldEnd { suppressed = true; break }
                        occurrence.availableAt = oldEnd; occurrence.windowStart = LocalDay(oldEnd, timeZone: zone)
                    }
                    if suppressed || occurrence.availableAt >= range.end { continue }
                }
                result[occurrence.id] = occurrence
            }
            for occurrence in stored.values {
                if occurrence.superseded { result.removeValue(forKey: occurrence.id); continue }
                let end = occurrence.deferredUntil ?? occurrence.dueAt ?? occurrence.availableAt
                let summary = try repository.summary(for: occurrence)
                cache.statuses[occurrence.id] = summary
                let unresolved = summary.0 != .completed && summary.0 != .skipped
                if (occurrence.availableAt < range.end && end >= range.start) ||
                    (unresolved && occurrence.availableAt < range.end && retainsPast) ||
                    (occurrence.reminderSnoozedUntil.map { $0 >= range.start && $0 < range.end } ?? false) {
                    result[occurrence.id] = occurrence
                } else { result.removeValue(forKey: occurrence.id) }
            }
        }
        let rows = result.values.sorted {
            let a = definitions[$0.practiceID]!, b = definitions[$1.practiceID]!
            let urgentA = $0.hardDeadline.map { $0 <= now } ?? (a.importance == .critical && ($0.dueAt ?? .distantFuture) <= now)
            let urgentB = $1.hardDeadline.map { $0 <= now } ?? (b.importance == .critical && ($1.dueAt ?? .distantFuture) <= now)
            if urgentA != urgentB { return urgentA }
            if a.importance.rank != b.importance.rank { return a.importance.rank < b.importance.rank }
            if ($0.dueAt ?? .distantFuture) != ($1.dueAt ?? .distantFuture) { return ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
            if a.id == data.grimoire.settings.focusPracticeID && b.id != a.id { return true }
            if b.id == data.grimoire.settings.focusPracticeID && a.id != b.id { return false }
            return $0.id < $1.id
        }
        let report = GrimoireProjection(occurrences: rows, warnings: warnings)
        if cache.projections.count >= 8 { cache.projections.removeAll() }
        cache.projections[key] = report
        return report
    }
    func reminderProjectionData(in range: DateInterval, now: Date = Date()) throws -> GrimoireData {
        let repository = try requireHistory()
        let snoozed = try repository.snoozedPracticeIDs(in: range)
        var value = data.grimoire
        value.actions = []; value.occurrences = []; value.revisions = []
        value.practices = value.practices.filter { !$0.archived && !$0.paused && ($0.schedule.reminderHour != nil || snoozed.contains($0.id)) }
        var actions: [UUID: ActionRecord] = [:]
        for practice in value.practices {
            let report = try projectedHistory(in: range, now: now, practiceID: practice.id)
            guard !report.truncated else { throw InvokeDataError.storageUnavailable(report.warnings.joined(separator: "\n")) }
            value.occurrences += report.occurrences
            for occurrence in report.occurrences {
                for row in try repository.activeActions(for: occurrence.id) { actions[row.id] = row }
            }
            for row in try completionAnchor(for: practice, repository: repository) { actions[row.id] = row }
        }
        value.actions = Array(actions.values)
        return value
    }
}
