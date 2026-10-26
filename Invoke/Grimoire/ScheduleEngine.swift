import Foundation

struct ScheduleProjection {
    var occurrences: [PracticeOccurrence]
    var truncated: Bool
}

/// Pure calendar projection. Callers inject the query dates, records and zone policy.
enum ScheduleEngine {
    static func projection(for practice: PracticeDefinition, in range: DateInterval, settings: GrimoireSettings,
                           actions: [ActionRecord] = [], events: [GrimoireEvent] = [], currentZone: TimeZone = .current,
                           limit: Int = 20_000) -> ScheduleProjection {
        guard limit > 0 else { return ScheduleProjection(occurrences: [], truncated: true) }
        let rows = occurrences(for: practice, in: range, settings: settings, actions: actions, events: events,
                               currentZone: currentZone, limit: limit + 1)
        return ScheduleProjection(occurrences: Array(rows.prefix(limit)), truncated: rows.count > limit)
    }
    static func zone(for rule: ScheduleRule, settings: GrimoireSettings, currentZone: TimeZone = .current) -> TimeZone {
        if let value = rule.homeTimeZoneID, let zone = TimeZone(identifier: value) { return zone }
        return settings.followsTravelTimeZone ? currentZone : (TimeZone(identifier: settings.homeTimeZoneID) ?? currentZone)
    }
    static func calendar(zone: TimeZone, weekStart: Int = 2) -> Calendar {
        var value = Calendar(identifier: .gregorian); value.timeZone = zone
        value.firstWeekday = weekStart; value.minimumDaysInFirstWeek = 4
        return value
    }
    static func date(_ day: LocalDay, in calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day))
    }
    /// Missing wall times move to the next valid instant; repeated times use the first offset once.
    static func wallTime(day: LocalDay, hour: Int, minute: Int, calendar: Calendar) -> Date? {
        guard let start = date(day, in: calendar) else { return nil }
        if hour == 0 && minute == 0 { return start }
        return calendar.nextDate(after: start.addingTimeInterval(-1), matching: DateComponents(hour: hour, minute: minute),
                                 matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
    }
    static func activeActions(_ actions: [ActionRecord]) -> [ActionRecord] {
        let reversed = Set(actions.compactMap(\.reversesActionID))
        return actions.filter { $0.kind != .correction && !reversed.contains($0.id) }
    }
    static func occurrences(for practice: PracticeDefinition, in range: DateInterval, settings: GrimoireSettings,
                            actions: [ActionRecord] = [], events: [GrimoireEvent] = [], currentZone: TimeZone = .current,
                            limit: Int = 20_000) -> [PracticeOccurrence] {
        guard !practice.archived, !practice.paused, range.end > range.start, limit > 0 else { return [] }
        let rule = practice.schedule
        let zone = zone(for: rule, settings: settings, currentZone: currentZone)
        let cal = calendar(zone: zone, weekStart: settings.weekStartsOn)
        guard let anchor = date(rule.startDate, in: cal) else { return [] }
        let effectiveDay = cal.startOfDay(for: practice.effectiveFrom)
        // A newly entered past deadline is still real work. Only revisions impose
        // a future-effective boundary; creation time is not an invented due date.
        let beginning = practice.version > 1 ? max(anchor, effectiveDay) : anchor
        let endLimit = rule.endDate.flatMap { date($0, in: cal) }.flatMap { cal.date(byAdding: .day, value: 1, to: $0) }
        let queryEnd = min(range.end, endLimit ?? range.end)
        guard queryEnd > beginning else { return [] }
        var result: [PracticeOccurrence] = []
        func add(_ start: Date, end: Date? = nil, key: String? = nil, eventID: UUID? = nil, includePast: Bool = false) {
            guard result.count < limit, let finish = end ?? cal.date(byAdding: .day, value: 1, to: start) else { return }
            guard (includePast || finish > range.start), start < queryEnd, finish > beginning else { return }
            let startDay = LocalDay(start, timeZone: zone), endDay = LocalDay(finish, timeZone: zone)
            let slots: [(String, Date)] = rule.slots.isEmpty || [.weekly, .weeklyQuota, .unscheduled].contains(rule.kind) ? [("day", start)] : rule.slots.compactMap {
                guard let time = wallTime(day: startDay, hour: $0.hour, minute: $0.minute, calendar: cal) else { return nil }
                return ($0.id.uuidString, time)
            }
            for (slot, available) in slots where result.count < limit {
                if practice.version > 1 && available < practice.effectiveFrom { continue }
                if practice.pauses.contains(where: { available >= $0.startedAt && available < ($0.endedAt ?? .distantFuture) }) { continue }
                // A window's selected deadline time belongs to its final calendar day,
                // not the first day (which might precede a midweek activation).
                let deadlineDay = LocalDay(cal.date(byAdding: .day, value: -1, to: finish)!, timeZone: zone)
                let target = rule.deadlineHour.flatMap { wallTime(day: deadlineDay, hour: $0, minute: rule.deadlineMinute, calendar: cal) }
                let due = target ?? finish.addingTimeInterval(-1)
                let identity = "\(practice.id.uuidString):v\(practice.version):\(key ?? startDay.description):\(slot)"
                result.append(PracticeOccurrence(id: identity, practiceID: practice.id, definitionVersion: practice.version,
                    title: practice.title, steps: practice.steps, windowStart: startDay, windowEnd: endDay,
                    availableAt: max(available, beginning), dueAt: due, hardDeadline: rule.hardDeadline ? due : nil,
                    timeZoneID: zone.identifier, slotKey: slot, requiredSessions: rule.kind == .weeklyQuota ? rule.quota : 1,
                    eventID: eventID, instructions: practice.instructions, context: practice.context,
                    materials: practice.materials, smallerVersion: practice.smallerVersion))
            }
        }
        let lower = max(cal.startOfDay(for: range.start), beginning)
        switch rule.kind {
        case .unscheduled:
            // A stable timeless opportunity; query bounds do not invent a due date.
            if beginning < queryEnd {
                let finish = cal.date(byAdding: .day, value: 1, to: beginning)!
                result.append(PracticeOccurrence(id: "\(practice.id):v\(practice.version):unscheduled:day", practiceID: practice.id,
                    definitionVersion: practice.version, title: practice.title, steps: practice.steps,
                    windowStart: LocalDay(beginning, timeZone: zone), windowEnd: LocalDay(finish, timeZone: zone),
                    availableAt: beginning, dueAt: nil, hardDeadline: nil, timeZoneID: zone.identifier, slotKey: "day",
                    instructions: practice.instructions, context: practice.context, materials: practice.materials, smallerVersion: practice.smallerVersion))
            }
        case .once:
            add(anchor)
        case .daily, .weekdays:
            var day = lower
            while day < queryEnd && result.count < limit {
                if rule.kind == .daily || rule.weekdays.contains(cal.component(.weekday, from: day)) { add(day) }
                guard let next = cal.date(byAdding: .day, value: 1, to: day), next > day else { break }; day = next
            }
        case .weekly, .weeklyQuota:
            guard let firstWeek = cal.dateInterval(of: .weekOfYear, for: anchor)?.start,
                  let queryWeek = cal.dateInterval(of: .weekOfYear, for: lower)?.start else { return [] }
            let elapsedWeeks = max(0, cal.dateComponents([.weekOfYear], from: firstWeek, to: queryWeek).weekOfYear ?? 0)
            let interval = max(1, rule.interval)
            guard var week = cal.date(byAdding: .weekOfYear, value: elapsedWeeks / interval * interval, to: firstWeek) else { return [] }
            while week < queryEnd && result.count < limit {
                guard let next = cal.date(byAdding: .weekOfYear, value: max(1, rule.interval), to: week) else { break }
                add(week, end: next, key: "week-\(LocalDay(week, timeZone: zone))"); week = next
            }
        case .monthly, .quarterly, .semiannual, .annual:
            let stride = rule.kind == .monthly ? 1 : rule.kind == .quarterly ? 3 : rule.kind == .semiannual ? 6 : 12
            let anchorMonth = cal.date(from: cal.dateComponents([.year, .month], from: anchor))!
            let lowerMonth = cal.date(from: cal.dateComponents([.year, .month], from: lower))!
            let distance = max(0, cal.dateComponents([.month], from: anchorMonth, to: lowerMonth).month ?? 0)
            var index = max(0, distance / stride * stride)
            while result.count < limit {
                guard let month = cal.date(byAdding: .month, value: index, to: anchorMonth), month < queryEnd else { break }
                if rule.kind == .quarterly && rule.calendarQuarter {
                    let parts = cal.dateComponents([.year, .month], from: month)
                    let quarterMonth = ((parts.month! - 1) / 3) * 3 + 1
                    let start = cal.date(from: DateComponents(year: parts.year, month: quarterMonth, day: 1))!
                    let end = cal.date(byAdding: .month, value: 3, to: start)!
                    add(start, end: end, key: "quarter-\(LocalDay(start, timeZone: zone))")
                } else if let candidate = monthDate(month: month, preferredDay: rule.dayOfMonth,
                                                      lastDay: rule.lastDayOfMonth, ordinal: rule.weekdayOrdinal,
                                                      weekday: rule.ordinalWeekday, calendar: cal) {
                    if candidate >= beginning { add(candidate) }
                }
                index += stride
            }
        case .afterCompletion:
            let actual = activeActions(actions).filter { $0.practiceID == practice.id && $0.kind == .complete }.map(\.occurredAt).max()
                ?? rule.lastActualCompletion
            // No invented "last done" date: explicitly configured start is the first opportunity.
            let next = actual.flatMap { addInterval(rule.interval, unit: rule.intervalUnit, to: $0, calendar: cal) } ?? anchor
            let day = cal.startOfDay(for: next)
            let key = actual.map { "after-\(Int($0.timeIntervalSince1970 * 1_000))" } ?? "initial"
            // Keep the same slot identities and deadlines when this eligibility becomes overdue.
            add(day, key: key, includePast: true)
        case .event:
            for event in events where event.name.localizedCaseInsensitiveCompare(rule.eventName) == .orderedSame {
                if event.occurredAt >= beginning {
                    add(cal.startOfDay(for: event.occurredAt), key: "event-\(event.id)", eventID: event.id)
                }
            }
        case .condition, .custom:
            var cursor = anchor
            var iterations = 0
            if rule.intervalUnit == .day || rule.intervalUnit == .week {
                let days = cal.dateComponents([.day], from: anchor, to: lower).day ?? 0
                let stride = max(1, rule.interval) * (rule.intervalUnit == .week ? 7 : 1)
                iterations = max(0, days / stride)
                cursor = cal.date(byAdding: .day, value: iterations * stride, to: anchor)!
            } else {
                let months = cal.dateComponents([.month], from: anchor, to: lower).month ?? 0
                iterations = max(0, months / (max(1, rule.interval) * (rule.intervalUnit == .year ? 12 : 1)))
                cursor = addInterval(iterations * max(1, rule.interval), unit: rule.intervalUnit, to: anchor, calendar: cal)!
            }
            while cursor < queryEnd && result.count < limit {
                if cursor >= beginning { add(cursor) }
                iterations += 1
                // Always calculate from the original anchor to avoid Jan 31 -> Feb 28 -> Mar 28 drift.
                guard let next = addInterval(iterations * max(1, rule.interval), unit: rule.intervalUnit, to: anchor, calendar: cal), next > cursor else {
                    if let next = addInterval(max(1, rule.interval), unit: rule.intervalUnit, to: cursor, calendar: cal), next > cursor { cursor = next; continue }
                    break
                }
                cursor = next
            }
        }
        var seen = Set<String>()
        return result.filter { seen.insert($0.id).inserted }.sorted { $0.availableAt == $1.availableAt ? $0.id < $1.id : $0.availableAt < $1.availableAt }
    }
    static func addInterval(_ count: Int, unit: CalendarUnit, to date: Date, calendar: Calendar) -> Date? {
        switch unit {
        case .day: return calendar.date(byAdding: .day, value: count, to: date)
        case .week: return calendar.date(byAdding: .weekOfYear, value: count, to: date)
        case .month, .year:
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            let month = calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1))!
            guard let targetMonth = calendar.date(byAdding: .month, value: count * (unit == .year ? 12 : 1), to: month),
                  let target = monthDate(month: targetMonth, preferredDay: components.day!, lastDay: false, ordinal: nil, weekday: 1, calendar: calendar) else { return nil }
            return wallTime(day: LocalDay(target, timeZone: calendar.timeZone), hour: components.hour ?? 0, minute: components.minute ?? 0, calendar: calendar)
        }
    }
    private static func monthDate(month: Date, preferredDay: Int, lastDay: Bool, ordinal: Int?, weekday: Int, calendar: Calendar) -> Date? {
        guard let days = calendar.range(of: .day, in: .month, for: month) else { return nil }
        let base = calendar.dateComponents([.year, .month], from: month)
        if let ordinal {
            if ordinal == -1 {
                let last = calendar.date(from: DateComponents(year: base.year, month: base.month, day: days.count))!
                let delta = (calendar.component(.weekday, from: last) - weekday + 7) % 7
                return calendar.date(byAdding: .day, value: -delta, to: last)
            }
            let first = calendar.date(from: DateComponents(year: base.year, month: base.month, day: 1))!
            let target = 1 + (weekday - calendar.component(.weekday, from: first) + 7) % 7 + (ordinal - 1) * 7
            guard target <= days.count else { return nil } // An absent fifth weekday is skipped, not shifted.
            return calendar.date(from: DateComponents(year: base.year, month: base.month, day: target))
        }
        return calendar.date(from: DateComponents(year: base.year, month: base.month, day: lastDay ? days.count : min(max(1, preferredDay), days.count)))
    }
    static func summary(_ rule: ScheduleRule) -> String {
        switch rule.kind {
        case .unscheduled: return "Available when you choose; no date assumed."
        case .once: return "One occurrence on \(rule.startDate)."
        case .daily: return "Every day" + (rule.slots.isEmpty ? "." : ", \(rule.slots.count) distinct times.")
        case .weekdays: return "Selected weekdays: " + rule.weekdays.map { ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][min(7, max(1, $0))] }.joined(separator: ", ")
        case .weekly: return "One flexible weekly window."
        case .weeklyQuota: return "\(rule.quota) distinct sessions per week; progress belongs to the week."
        case .monthly: return rule.weekdayOrdinal.map { "Monthly weekday ordinal \($0); absent fifth weekdays are skipped." } ?? (rule.lastDayOfMonth ? "Last day of each month." : "Monthly on day \(rule.dayOfMonth), clamped to the last valid day.")
        case .quarterly: return rule.calendarQuarter ? "One review per calendar quarter." : "Every three calendar months from \(rule.startDate)."
        case .semiannual: return "Every six calendar months from \(rule.startDate)."
        case .annual: return "Every year in month \(rule.startDate.month), day \(rule.dayOfMonth), clamped to the last valid day."
        case .afterCompletion: return "\(rule.interval) \(rule.intervalUnit.rawValue)(s) after an actual full completion; skips do not advance it."
        case .event: return "After you record the event “\(rule.eventName)”."
        case .condition: return "Inspect every \(rule.interval) \(rule.intervalUnit.rawValue)(s); repair or replace only when warranted."
        case .custom: return "Every \(rule.interval) \(rule.intervalUnit.rawValue)(s) from \(rule.startDate)."
        }
    }
}
