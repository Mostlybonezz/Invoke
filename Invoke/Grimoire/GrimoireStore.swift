import Foundation

enum GrimoireLogic {
    static func sessionCount(for occurrence: PracticeOccurrence, actions: [ActionRecord]) -> Int {
        Set(ScheduleEngine.activeActions(actions).filter { $0.occurrenceID == occurrence.id && $0.kind == .complete }.map(\.sessionID)).count
    }
    static func status(of occurrence: PracticeOccurrence, actions: [ActionRecord]) -> OccurrenceStatus {
        let active = ScheduleEngine.activeActions(actions).filter { $0.occurrenceID == occurrence.id }
        if sessionCount(for: occurrence, actions: active) >= occurrence.requiredSessions { return .completed }
        if active.contains(where: { $0.kind == .skip }) { return .skipped }
        if active.contains(where: { $0.kind == .progress || $0.kind == .smaller || $0.kind == .complete }) { return .partial }
        if active.contains(where: { $0.kind == .begin }) { return .inProgress }
        if occurrence.deferredUntil != nil { return .deferred }
        return .unrecorded
    }
}

@MainActor
extension AppStore {
    func grimoireOccurrences(in range: DateInterval, now: Date = Date()) -> [PracticeOccurrence] {
        let definitions = Dictionary(uniqueKeysWithValues: data.grimoire.practices.map { ($0.id, $0) })
        var result: [String: PracticeOccurrence] = [:]
        for practice in data.grimoire.practices where !practice.archived && !practice.paused {
            let persistent = practice.schedule.policy == .persist || practice.schedule.hardDeadline || practice.schedule.kind == .event || practice.schedule.kind == .once
            let zone = ScheduleEngine.zone(for: practice.schedule, settings: data.grimoire.settings)
            let cal = ScheduleEngine.calendar(zone: zone, weekStart: data.grimoire.settings.weekStartsOn)
            let anchor = ScheduleEngine.date(practice.schedule.startDate, in: cal) ?? practice.createdAt
            let start = persistent ? min(range.start, anchor) : range.start
            let query = DateInterval(start: start, end: range.end)
            for occurrence in ScheduleEngine.occurrences(for: practice, in: query, settings: data.grimoire.settings,
                actions: data.grimoire.actions, events: data.grimoire.events) {
                result[occurrence.id] = occurrence
            }
        }
        // A stored occurrence retains its historical zone/title/steps and deliberate deferral.
        for occurrence in data.grimoire.occurrences {
            guard let practice = definitions[occurrence.practiceID], !practice.archived, !practice.paused, !occurrence.superseded else { continue }
            let end = occurrence.deferredUntil ?? occurrence.dueAt ?? occurrence.availableAt
            let status = occurrenceStatus(occurrence)
            let unresolved = status != .completed && status != .skipped
            if (occurrence.availableAt < range.end && end >= range.start) ||
                (unresolved && occurrence.availableAt < range.end && (practice.schedule.policy == .persist || occurrence.hardDeadline != nil ||
                    [.unscheduled, .afterCompletion, .event, .once].contains(practice.schedule.kind))) {
                result[occurrence.id] = occurrence
            } else { result.removeValue(forKey: occurrence.id) }
        }
        let suppressed = Set(data.grimoire.occurrences.filter(\.superseded).map(\.id))
        return result.values.filter { !suppressed.contains($0.id) }.sorted {
            let a = definitions[$0.practiceID]!, b = definitions[$1.practiceID]!
            let aUrgent = $0.hardDeadline.map { $0 <= now } ?? (a.importance == .critical && ($0.dueAt ?? .distantFuture) <= now)
            let bUrgent = $1.hardDeadline.map { $0 <= now } ?? (b.importance == .critical && ($1.dueAt ?? .distantFuture) <= now)
            if aUrgent != bUrgent { return aUrgent }
            if a.importance.rank != b.importance.rank { return a.importance.rank < b.importance.rank }
            if ($0.dueAt ?? .distantFuture) != ($1.dueAt ?? .distantFuture) { return ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
            if a.id == data.grimoire.settings.focusPracticeID && b.id != a.id { return true }
            if b.id == data.grimoire.settings.focusPracticeID && a.id != b.id { return false }
            return $0.id < $1.id
        }
    }
    func occurrenceStatus(_ occurrence: PracticeOccurrence) -> OccurrenceStatus { GrimoireLogic.status(of: occurrence, actions: data.grimoire.actions) }
    func sessionCount(for occurrence: PracticeOccurrence) -> Int { GrimoireLogic.sessionCount(for: occurrence, actions: data.grimoire.actions) }
    func activeActions(for occurrenceID: String) -> [ActionRecord] {
        ScheduleEngine.activeActions(data.grimoire.actions).filter { $0.occurrenceID == occurrenceID }.sorted { $0.recordedAt < $1.recordedAt }
    }
    func commitGrimoire(_ value: GrimoireData) throws {
        var candidate = data; candidate.grimoire = value
        try commitSnapshot(candidate)
    }
    func ensureOccurrence(_ occurrence: PracticeOccurrence) throws {
        guard !data.grimoire.occurrences.contains(where: { $0.id == occurrence.id }) else { return }
        guard data.grimoire.practices.contains(where: { $0.id == occurrence.practiceID && !$0.archived && !$0.paused }) else {
            throw InvokeDataError.invalidBackup("The practice is unavailable.")
        }
        var value = data.grimoire; value.occurrences.append(occurrence); try commitGrimoire(value)
    }
    func materializeOccurrences(in range: DateInterval, now: Date = Date()) throws {
        let generated = grimoireOccurrences(in: range, now: now)
        let known = Set(data.grimoire.occurrences.map(\.id))
        let additions = generated.filter { !known.contains($0.id) }
        guard !additions.isEmpty else { return }
        var value = data.grimoire; value.occurrences += additions; try commitGrimoire(value)
    }
    func activatePractice(_ practice: PracticeDefinition) throws {
        guard !data.grimoire.practices.contains(where: { $0.id == practice.id }) else { return }
        var value = data.grimoire; value.practices.append(practice); try commitGrimoire(value)
    }
    func savePractice(_ practice: PracticeDefinition, effectiveFrom: Date = Date()) throws {
        guard let index = data.grimoire.practices.firstIndex(where: { $0.id == practice.id }) else { try activatePractice(practice); return }
        var value = data.grimoire
        let old = value.practices[index]
        var edited = practice
        edited.createdAt = old.createdAt; edited.updatedAt = effectiveFrom
        // Snapshot existing past opportunities before changing the future rule. They remain available in Chronicle.
        let zone = ScheduleEngine.zone(for: old.schedule, settings: value.settings)
        let calendar = ScheduleEngine.calendar(zone: zone, weekStart: value.settings.weekStartsOn)
        let anchor = ScheduleEngine.date(old.schedule.startDate, in: calendar) ?? old.createdAt
        let historical = ScheduleEngine.occurrences(for: old, in: DateInterval(start: min(anchor, effectiveFrom), end: effectiveFrom),
            settings: value.settings, actions: value.actions, events: value.events)
        var known = Set(value.occurrences.map(\.id))
        for item in historical where known.insert(item.id).inserted { value.occurrences.append(item) }
        if old.schedule != edited.schedule || old.steps != edited.steps {
            edited.version = old.version + 1
            edited.effectiveFrom = effectiveFrom
            edited.revisions = old.revisions + [PracticeRevision(version: old.version, effectiveFrom: old.effectiveFrom,
                title: old.title, instructions: old.instructions, steps: old.steps, schedule: old.schedule)]
            for i in value.occurrences.indices where value.occurrences[i].practiceID == old.id && value.occurrences[i].availableAt >= effectiveFrom {
                if !value.actions.contains(where: { $0.occurrenceID == value.occurrences[i].id }) { value.occurrences[i].superseded = true }
            }
        } else { edited.version = old.version; edited.effectiveFrom = old.effectiveFrom; edited.revisions = old.revisions }
        value.practices[index] = edited
        try Self.audit(before: old, after: edited, type: "Practice", title: edited.title, summary: "Practice revised; completed history retained.", into: &value)
        try commitGrimoire(value)
    }
    func setPracticePaused(_ id: UUID, paused: Bool) throws {
        guard let index = data.grimoire.practices.firstIndex(where: { $0.id == id }) else { return }
        var value = data.grimoire
        guard value.practices[index].paused != paused else { return }
        let now = Date()
        value.practices[index].paused = paused; value.practices[index].updatedAt = now
        if paused { value.practices[index].pauses.append(PracticePause(startedAt: now)) }
        else if let i = value.practices[index].pauses.lastIndex(where: { $0.endedAt == nil }) { value.practices[index].pauses[i].endedAt = now }
        try commitGrimoire(value)
    }
    func archivePractice(_ id: UUID, archived: Bool = true) throws {
        guard let index = data.grimoire.practices.firstIndex(where: { $0.id == id }) else { return }
        var value = data.grimoire; value.practices[index].archived = archived; value.practices[index].updatedAt = Date()
        try commitGrimoire(value)
    }
    func beginSession(occurrenceID: String, newSession: Bool = false, now: Date = Date()) throws -> UUID {
        guard let occurrence = data.grimoire.occurrences.first(where: { $0.id == occurrenceID }), !occurrence.superseded else {
            throw InvokeDataError.invalidBackup("Open a current occurrence before beginning.")
        }
        let actions = activeActions(for: occurrenceID)
        let finished = Set(actions.filter { [.complete, .smaller, .skip].contains($0.kind) }.map(\.sessionID))
        if !newSession, let session = actions.last(where: { $0.kind == .begin && !finished.contains($0.sessionID) }) { return session.sessionID }
        if occurrence.requiredSessions == 1, let completed = actions.first(where: { $0.kind == .complete }) { return completed.sessionID }
        let session = UUID()
        _ = try recordAction(occurrenceID: occurrenceID, kind: .begin, sessionID: session, requestID: session, occurredAt: now, now: now)
        return session
    }
    @discardableResult
    func recordAction(occurrenceID: String, kind: ActionKind, sessionID: UUID, requestID: UUID, steps: [UUID] = [],
                      notes: String = "", measurement: Double? = nil, measurementUnit: String = "",
                      occurredAt: Date = Date(), now: Date = Date()) throws -> ActionRecord {
        if let existing = data.grimoire.actions.first(where: { $0.requestID == requestID }) {
            guard existing.occurrenceID == occurrenceID && existing.sessionID == sessionID && existing.kind == kind else {
                throw InvokeDataError.invalidBackup("This request identifier belongs to a different action.")
            }
            return existing
        }
        guard let occurrence = data.grimoire.occurrences.first(where: { $0.id == occurrenceID }), !occurrence.superseded,
              let practice = data.grimoire.practices.first(where: { $0.id == occurrence.practiceID }), !practice.archived, !practice.paused else {
            throw InvokeDataError.invalidBackup("This occurrence is unavailable.")
        }
        guard kind != .correction && kind != .deferAction else { throw InvokeDataError.invalidBackup("Use the correction or deferral action.") }
        let active = activeActions(for: occurrenceID)
        if kind == .complete, let duplicate = active.first(where: { $0.kind == .complete && ($0.sessionID == sessionID || occurrence.requiredSessions == 1) }) { return duplicate }
        if kind == .skip, let duplicate = active.first(where: { $0.kind == .skip }) { return duplicate }
        guard Set(steps).isSubset(of: Set(occurrence.steps.map(\.id))), Set(steps).count == steps.count,
              measurement?.isFinite != false, occurredAt.timeIntervalSince1970.isFinite,
              occurredAt <= now.addingTimeInterval(60) else { throw InvokeDataError.invalidBackup("The action has invalid steps, measurement, or time.") }
        if kind == .complete && !occurrence.steps.isEmpty && Set(steps) != Set(occurrence.steps.map(\.id)) {
            throw InvokeDataError.invalidBackup("Check every step for a full completion, or record partial progress/the smaller version.")
        }
        var record = ActionRecord(requestID: requestID, occurrenceID: occurrenceID, practiceID: occurrence.practiceID,
            sessionID: sessionID, kind: kind, occurredAt: occurredAt, recordedAt: now, timeZoneID: occurrence.timeZoneID,
            completedStepIDs: steps, notes: notes, measurement: measurement, measurementUnit: measurementUnit,
            titleSnapshot: occurrence.title)
        // If retrying a begun session, the request ID—not the timestamp—is its identity.
        if kind == .begin { record.id = sessionID }
        var value = data.grimoire; value.actions.append(record)
        Self.reconcileCompletionIntervals(&value, practiceID: occurrence.practiceID, now: now)
        try commitGrimoire(value)
        return record
    }
    func undoAction(_ id: UUID, now: Date = Date()) throws {
        guard let original = data.grimoire.actions.first(where: { $0.id == id }), original.kind != .correction,
              !data.grimoire.actions.contains(where: { $0.reversesActionID == id }) else { return }
        var value = data.grimoire
        value.actions.append(ActionRecord(occurrenceID: original.occurrenceID, practiceID: original.practiceID,
            sessionID: original.sessionID, kind: .correction, occurredAt: now, recordedAt: now,
            timeZoneID: original.timeZoneID, notes: "Undid \(original.kind.title.lowercased()).", reversesActionID: original.id,
            titleSnapshot: original.titleSnapshot))
        if original.kind == .deferAction, let i = value.occurrences.firstIndex(where: { $0.id == original.occurrenceID }) {
            value.occurrences[i].deferredUntil = ScheduleEngine.activeActions(value.actions).filter {
                $0.occurrenceID == original.occurrenceID && $0.kind == .deferAction
            }.last?.targetDate
        }
        Self.reconcileCompletionIntervals(&value, practiceID: original.practiceID, now: now)
        try commitGrimoire(value)
    }
    func deferOccurrence(_ id: String, to date: Date, now: Date = Date()) throws {
        guard let index = data.grimoire.occurrences.firstIndex(where: { $0.id == id }), date.timeIntervalSince1970.isFinite else { return }
        var value = data.grimoire
        let occurrence = value.occurrences[index]
        value.occurrences[index].deferredUntil = date
        value.actions.append(ActionRecord(occurrenceID: id, practiceID: occurrence.practiceID, kind: .deferAction,
            occurredAt: now, recordedAt: now, timeZoneID: occurrence.timeZoneID, targetDate: date, titleSnapshot: occurrence.title))
        try commitGrimoire(value)
    }
    func snoozeReminder(_ id: String, until date: Date) throws {
        guard let index = data.grimoire.occurrences.firstIndex(where: { $0.id == id }) else { return }
        var value = data.grimoire; value.occurrences[index].reminderSnoozedUntil = date
        try commitGrimoire(value)
    }
    func saveInvocation(_ record: Invocation) throws {
        var v = data.grimoire
        var revised = record
        if let old = v.invocations.first(where: { $0.id == record.id }) {
            let supplied = Set(record.observations.map(\.id))
            revised.observations += old.observations.filter { !supplied.contains($0.id) }
            try Self.audit(before: old, after: revised, type: "Invocation", title: record.title, summary: "Intention or milestones revised; outcomes remain user-recorded.", into: &v)
        }
        Self.upsert(revised, in: &v.invocations); try commitGrimoire(v)
    }
    func saveSpell(_ record: Spell) throws {
        var v = data.grimoire
        if let old = v.spells.first(where: { $0.id == record.id }) { try Self.audit(before: old, after: record, type: "Spell", title: record.title, summary: "Saved technique revised.", into: &v) }
        Self.upsert(record, in: &v.spells); try commitGrimoire(v)
    }
    func saveEnchantment(_ record: Enchantment) throws {
        var v = data.grimoire
        if let old = v.enchantments.first(where: { $0.id == record.id }) { try Self.audit(before: old, after: record, type: "Enchantment", title: record.title, summary: "Arrangement: \(old.status) → \(record.status).", into: &v) }
        Self.upsert(record, in: &v.enchantments); try commitGrimoire(v)
    }
    func saveAsset(_ record: CareAsset) throws {
        var v = data.grimoire; var revised = record
        if let existing = v.assets.first(where: { $0.id == record.id }) {
            let provided = Set(revised.inspections.map(\.id))
            revised.inspections += existing.inspections.filter { !provided.contains($0.id) }
            try Self.audit(before: existing, after: revised, type: "Asset", title: record.name, summary: "Asset care record revised.", into: &v)
        }
        Self.upsert(revised, in: &v.assets); try commitGrimoire(v)
    }
    func saveArcana(_ record: ArcanaRecord) throws {
        var v = data.grimoire
        if let old = v.arcana.first(where: { $0.id == record.id }) { try Self.audit(before: old, after: record, type: "Arcana", title: record.title,
            summary: old.beliefStatus == record.beliefStatus ? "Practice or observation revised." : "Belief position: \(old.beliefStatus) → \(record.beliefStatus).", into: &v) }
        Self.upsert(record, in: &v.arcana); try commitGrimoire(v)
    }
    func saveEcho(_ record: Echo) throws {
        var v = data.grimoire
        if let old = v.echoes.first(where: { $0.id == record.id }) { try Self.audit(before: old, after: record, type: "Echo", title: record.title, summary: "Comparative sources or interpretation revised.", into: &v) }
        Self.upsert(record, in: &v.echoes); try commitGrimoire(v)
    }
    func saveEvent(_ record: GrimoireEvent) throws { var v = data.grimoire; Self.upsert(record, in: &v.events); try commitGrimoire(v) }
    func recordInspection(assetID: UUID, inspection: AssetInspection, followUp: PracticeDefinition? = nil) throws {
        guard let index = data.grimoire.assets.firstIndex(where: { $0.id == assetID }) else { throw InvokeDataError.invalidBackup("The asset is unavailable.") }
        guard !data.grimoire.assets[index].inspections.contains(where: { $0.id == inspection.id }) else { return }
        var value = data.grimoire; var saved = inspection
        if var followUp {
            guard ["Needs repair", "Needs replacement"].contains(inspection.condition) else {
                throw InvokeDataError.invalidBackup("A serviceable inspection does not create replacement work.")
            }
            followUp.assetID = assetID; saved.followUpPracticeID = followUp.id
            Self.upsert(followUp, in: &value.practices)
        }
        value.assets[index].condition = inspection.condition
        value.assets[index].inspections.append(saved); value.assets[index].updatedAt = Date()
        try commitGrimoire(value)
    }
    private static func upsert<T: Identifiable>(_ item: T, in values: inout [T]) where T.ID == UUID {
        if let index = values.firstIndex(where: { $0.id == item.id }) { values[index] = item } else { values.append(item) }
    }
    private static func audit<T: Codable & Equatable & Identifiable>(before: T, after: T, type: String, title: String,
        summary: String, into value: inout GrimoireData) throws where T.ID == UUID {
        guard before != after else { return }
        value.revisions.append(GrimoireRevision(recordID: before.id, recordType: type, title: title, summary: summary,
            before: try PersistenceCoding.encoder().encode(before), after: try PersistenceCoding.encoder().encode(after)))
    }
    private static func reconcileCompletionIntervals(_ value: inout GrimoireData, practiceID: UUID, now: Date) {
        guard let practice = value.practices.first(where: { $0.id == practiceID }), practice.schedule.kind == .afterCompletion else { return }
        let future = now.addingTimeInterval(366 * 86_400 * 10)
        let current = Set(ScheduleEngine.occurrences(for: practice, in: DateInterval(start: practice.createdAt, end: future),
            settings: value.settings, actions: value.actions, events: value.events).map(\.id))
        let acted = Set(ScheduleEngine.activeActions(value.actions).filter { [.complete, .progress, .smaller, .observation].contains($0.kind) }.map(\.occurrenceID))
        for i in value.occurrences.indices where value.occurrences[i].practiceID == practiceID {
            if !acted.contains(value.occurrences[i].id) { value.occurrences[i].superseded = !current.contains(value.occurrences[i].id) }
        }
    }
    func mergeBackup(_ payload: BackupPayload) throws {
        try BackupValidation.validate(payload)
        var current = try makeBackup()
        let incoming = payload.data
        func merge<T: Identifiable>(_ from: [T], into to: inout [T]) where T.ID: Hashable {
            let ids = Set(to.map(\.id)); to += from.filter { !ids.contains($0.id) }
        }
        merge(incoming.stories, into: &current.data.stories); merge(incoming.chapters, into: &current.data.chapters)
        merge(incoming.scenes, into: &current.data.scenes); merge(incoming.entries, into: &current.data.entries)
        merge(incoming.relics, into: &current.data.relics); merge(incoming.reflections, into: &current.data.reflections)
        merge(incoming.ritualLogs, into: &current.data.ritualLogs)
        merge(incoming.grimoire.practices, into: &current.data.grimoire.practices)
        merge(incoming.grimoire.occurrences, into: &current.data.grimoire.occurrences)
        merge(incoming.grimoire.actions, into: &current.data.grimoire.actions)
        merge(incoming.grimoire.invocations, into: &current.data.grimoire.invocations)
        merge(incoming.grimoire.spells, into: &current.data.grimoire.spells)
        merge(incoming.grimoire.enchantments, into: &current.data.grimoire.enchantments)
        merge(incoming.grimoire.assets, into: &current.data.grimoire.assets)
        merge(incoming.grimoire.arcana, into: &current.data.grimoire.arcana)
        merge(incoming.grimoire.echoes, into: &current.data.grimoire.echoes)
        merge(incoming.grimoire.events, into: &current.data.grimoire.events)
        merge(incoming.grimoire.revisions, into: &current.data.grimoire.revisions)
        let referenced = BackupValidation.imageNames(in: current.data)
        for (name, image) in payload.images where referenced.contains(name) {
            if let existing = current.images[name], existing.sha256 != image.sha256 {
                throw InvokeDataError.invalidBackup("Two photos use the same identifier with different content. Choose a deliberate replacement instead.")
            }
            current.images[name] = image
        }
        current.images = current.images.filter { referenced.contains($0.key) }
        current.data.schemaVersion = AppData.currentSchemaVersion
        try BackupValidation.validate(current)
        try restore(current)
    }
}
