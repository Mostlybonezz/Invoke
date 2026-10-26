import Foundation

enum GrimoireValidation {
    static func validate(_ value: GrimoireData, legacy: AppData) throws {
        func require(_ condition: Bool, _ reason: String = "Living Grimoire records contain invalid or missing links.") throws {
            guard condition else { throw InvokeDataError.invalidBackup(reason) }
        }
        func unique<T: Identifiable>(_ records: [T], maximum: Int = 100_000) throws where T.ID: Hashable {
            try require(records.count <= maximum && Set(records.map(\.id)).count == records.count, "Grimoire record IDs are duplicated or the collection exceeds its supported size.")
        }
        func validDate(_ date: Date?) -> Bool { date?.timeIntervalSince1970.isFinite != false }
        func validDay(_ day: LocalDay) -> Bool {
            guard (1900...9999).contains(day.year), (1...12).contains(day.month), (1...31).contains(day.day) else { return false }
            let calendar = ScheduleEngine.calendar(zone: TimeZone(secondsFromGMT: 0)!)
            guard let date = ScheduleEngine.date(day, in: calendar) else { return false }
            return LocalDay(date, timeZone: calendar.timeZone) == day
        }
        func validSchedule(_ rule: ScheduleRule) throws {
            try require(validDay(rule.startDate) && (rule.endDate.map(validDay) ?? true))
            try require(rule.endDate.map { $0 >= rule.startDate } ?? true)
            try require((1...10_000).contains(rule.interval) && (1...100).contains(rule.quota))
            try require((1...31).contains(rule.dayOfMonth) && (1...7).contains(rule.ordinalWeekday))
            try require(rule.weekdayOrdinal.map { [-1, 1, 2, 3, 4, 5].contains($0) } ?? true)
            try require(rule.weekdays.allSatisfy { (1...7).contains($0) } && Set(rule.weekdays).count == rule.weekdays.count)
            try require(rule.kind != .weekdays || !rule.weekdays.isEmpty)
            try unique(rule.slots, maximum: 24)
            for slot in rule.slots { try require((0...23).contains(slot.hour) && (0...59).contains(slot.minute)) }
            try require(rule.deadlineHour.map { (0...23).contains($0) } ?? true)
            try require(rule.reminderHour.map { (0...23).contains($0) } ?? true)
            try require((0...59).contains(rule.deadlineMinute) && (0...59).contains(rule.reminderMinute))
            try require(rule.homeTimeZoneID.map { TimeZone(identifier: $0) != nil } ?? true)
            try require(validDate(rule.lastActualCompletion))
            try require(rule.kind != .event || !rule.eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        try unique(value.practices); try unique(value.occurrences, maximum: 250_000); try unique(value.actions, maximum: 500_000)
        try unique(value.invocations); try unique(value.spells); try unique(value.enchantments); try unique(value.assets)
        try unique(value.arcana); try unique(value.echoes); try unique(value.events); try unique(value.revisions)
        try require(Set(value.actions.map(\.requestID)).count == value.actions.count, "An action retry has duplicate identity.")
        let practices = Dictionary(uniqueKeysWithValues: value.practices.map { ($0.id, $0) })
        let occurrences = Dictionary(uniqueKeysWithValues: value.occurrences.map { ($0.id, $0) })
        let actions = Dictionary(uniqueKeysWithValues: value.actions.map { ($0.id, $0) })
        let invocations = Set(value.invocations.map(\.id)), spells = Set(value.spells.map(\.id)), assets = Set(value.assets.map(\.id))
        let entries = Set(legacy.entries.map(\.id)), scenes = Set(legacy.scenes.map(\.id)), stories = Set(legacy.stories.map(\.id))
        for practice in value.practices {
            try require(!practice.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && practice.title.count <= 10_000)
            try require(practice.version > 0 && validDate(practice.createdAt) && validDate(practice.updatedAt) && validDate(practice.effectiveFrom))
            try validSchedule(practice.schedule); try unique(practice.steps); try unique(practice.revisions)
            try unique(practice.pauses)
            for pause in practice.pauses { try require(validDate(pause.startedAt) && validDate(pause.endedAt) && (pause.endedAt.map { $0 >= pause.startedAt } ?? true)) }
            for revision in practice.revisions { try validSchedule(revision.schedule); try unique(revision.steps); try require(revision.version < practice.version) }
            try require(practice.invocationID.map(invocations.contains) ?? true)
            try require(practice.assetID.map(assets.contains) ?? true)
            try require(Set(practice.spellIDs).isSubset(of: spells) && Set(practice.spellIDs).count == practice.spellIDs.count)
            try require(practice.legacyEntryID.map(entries.contains) ?? true)
            try require(practice.legacySceneID.map(scenes.contains) ?? true)
            try require(practice.effortMinutes.map { (1...100_000).contains($0) } ?? true)
        }
        for occurrence in value.occurrences {
            try require(practices[occurrence.practiceID] != nil && !occurrence.id.isEmpty && occurrence.id.count <= 500)
            try require(occurrence.definitionVersion > 0 && occurrence.definitionVersion <= practices[occurrence.practiceID]!.version)
            try require(validDay(occurrence.windowStart) && validDay(occurrence.windowEnd) && occurrence.windowEnd > occurrence.windowStart)
            try require(validDate(occurrence.availableAt) && validDate(occurrence.dueAt) && validDate(occurrence.hardDeadline))
            try require(validDate(occurrence.deferredUntil) && validDate(occurrence.reminderSnoozedUntil))
            try require(TimeZone(identifier: occurrence.timeZoneID) != nil && (1...100).contains(occurrence.requiredSessions))
            try unique(occurrence.steps)
        }
        var corrected = Set<UUID>()
        for action in value.actions {
            guard let occurrence = occurrences[action.occurrenceID] else { throw InvokeDataError.invalidBackup("An action's occurrence is missing.") }
            try require(action.practiceID == occurrence.practiceID && validDate(action.occurredAt) && validDate(action.recordedAt))
            try require(action.measurement?.isFinite != false && TimeZone(identifier: action.timeZoneID) != nil && validDate(action.targetDate))
            try require(Set(action.completedStepIDs).isSubset(of: Set(occurrence.steps.map(\.id))) && Set(action.completedStepIDs).count == action.completedStepIDs.count)
            if let targetID = action.reversesActionID {
                let target = actions[targetID]
                try require(action.kind == .correction && target?.kind != .correction && target?.occurrenceID == action.occurrenceID && corrected.insert(targetID).inserted)
            } else { try require(action.kind != .correction) }
        }
        var completedSessions = Set<String>()
        var singleCompletions = Set<String>()
        for action in ScheduleEngine.activeActions(value.actions) where action.kind == .complete {
            try require(completedSessions.insert("\(action.occurrenceID):\(action.sessionID)").inserted, "One session has duplicate completion records.")
            if occurrences[action.occurrenceID]!.requiredSessions == 1 { try require(singleCompletions.insert(action.occurrenceID).inserted, "One occurrence has duplicate completion records.") }
        }
        for invocation in value.invocations {
            try unique(invocation.milestones)
            try unique(invocation.observations)
            try require(["Active", "Paused", "Completed", "Revised", "Archived"].contains(invocation.status))
            try require(invocation.legacyEntryID.map(entries.contains) ?? true)
            try require(invocation.legacyStoryID.map(stories.contains) ?? true)
            try require(validDate(invocation.reviewDate))
            for milestone in invocation.milestones { try require(validDate(milestone.completedAt)) }
            for observation in invocation.observations { try require(validDate(observation.observedAt) && observation.measurement?.isFinite != false) }
        }
        for enchantment in value.enchantments {
            try require(["Planned", "Established", "Needs attention", "Retired"].contains(enchantment.status))
            try require(enchantment.invocationID.map(invocations.contains) ?? true)
            try require(enchantment.maintenancePracticeID.map { practices[$0] != nil } ?? true)
            try require(validDate(enchantment.reviewDate))
        }
        for asset in value.assets {
            try unique(asset.inspections)
            try require(validDate(asset.purchasedAt) && validDate(asset.installedAt) && validDate(asset.expiresAt) && validDate(asset.reserveTargetDate))
            for amount in [asset.quantity, asset.replenishBelow, asset.estimatedCost, asset.reservedAmount].compactMap({ $0 }) { try require(amount.isFinite && amount >= 0) }
            for inspection in asset.inspections {
                try require(validDate(inspection.date))
                try require(inspection.followUpPracticeID.map { practices[$0]?.assetID == asset.id } ?? true)
                try require(inspection.actionID.map { actions[$0] != nil } ?? true)
            }
        }
        for record in value.arcana {
            try require(["Exploring", "Practicing", "Personally Accepted", "Questioning", "Archived"].contains(record.beliefStatus))
            try require(record.legacyEntryID.map(entries.contains) ?? true)
            try require(validDate(record.occurredAt))
        }
        for event in value.events { try require(validDate(event.occurredAt) && TimeZone(identifier: event.timeZoneID) != nil) }
        for revision in value.revisions {
            try require(validDate(revision.changedAt) && revision.before.count <= 10_000_000 && revision.after.count <= 10_000_000)
        }
        let settings = value.settings
        try require((1...7).contains(settings.weekStartsOn) && TimeZone(identifier: settings.homeTimeZoneID) != nil)
        try require((0...23).contains(settings.quietHoursStart) && (0...23).contains(settings.quietHoursEnd) && (0...23).contains(settings.digestHour))
        try require(settings.focusPracticeID.map { practices[$0] != nil } ?? true)
        try require(Set(settings.essentialPracticeIDs).isSubset(of: Set(practices.keys)))
    }
}
