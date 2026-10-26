import SwiftUI

struct PracticeEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PracticeDefinition
    @State private var effectiveFrom = Date()
    init(draft: PracticeDefinition = PracticeDefinition()) { _draft = State(initialValue: draft) }
    private var existing: Bool { store.data.grimoire.practices.contains { $0.id == draft.id } }
    private var previews: [PracticeOccurrence] {
        let calendar = GrimoirePresentation.calendar(store.data.grimoire.settings)
        let start = GrimoirePresentation.date(draft.schedule.startDate, settings: store.data.grimoire.settings)
        return Array(ScheduleEngine.occurrences(for: draft, in: DateInterval(start: start, end: calendar.date(byAdding: .year, value: 3, to: start)!), settings: store.data.grimoire.settings, actions: store.data.grimoire.actions, events: store.data.grimoire.events, limit: 8).prefix(3))
    }
    var body: some View {
        Form {
            Section("Your practice") {
                TextField("Title", text: $draft.title).accessibilityIdentifier("quest-title")
                TextField("Plain-language subtitle", text: $draft.plainTitle)
                Picker("Importance", selection: $draft.importance) { ForEach(Importance.allCases) { Text($0.title).tag($0) } }
                if draft.importance == .critical { TextField("Why this needs attention", text: $draft.importanceReason, axis: .vertical) }
                Picker("Linked Invocation", selection: $draft.invocationID) {
                    Text("None").tag(nil as UUID?)
                    ForEach(store.data.grimoire.invocations.filter { !$0.archived }) { Text($0.title).tag(Optional($0.id)) }
                }
                DisciplinePicker(value: $draft.discipline)
                Picker("Purpose", selection: $draft.purpose) { ForEach(PracticePurpose.allCases) { Text($0.title).tag($0) } }
            }
            ScheduleEditorFields(rule: $draft.schedule, settings: store.data.grimoire.settings)
            Section("Schedule preview") {
                Text(ScheduleEngine.summary(draft.schedule)).accessibilityIdentifier("quest-schedule-preview")
                if previews.isEmpty {
                    Text(draft.schedule.kind == .event ? "An occurrence becomes available when you record the matching event." : draft.schedule.kind == .afterCompletion && draft.schedule.lastActualCompletion == nil ? "No previous completion is assumed. Record an actual session to anchor the next interval." : "No occurrences in this preview. Review the dates and selected weekdays.").font(.footnote)
                }
                ForEach(previews) { item in
                    VStack(alignment: .leading) {
                        Text(item.availableAt.formatted(date: .abbreviated, time: draft.schedule.slots.isEmpty ? .omitted : .shortened))
                        if item.requiredSessions > 1 { Text("\(item.requiredSessions) distinct sessions in this period").font(.caption) }
                    }
                }
            }
            Section {
                DisclosureGroup("Instructions, steps and smaller version") {
                    GrimoireTextField(label: "Instructions", text: $draft.instructions)
                    GrimoireTextField(label: "Trigger or context", text: $draft.context, lines: 2)
                    GrimoireTextField(label: "Materials", text: $draft.materials, lines: 2)
                    ForEach($draft.steps) { $step in
                        VStack(alignment: .leading) {
                            TextField("Step title", text: $step.title)
                            TextField("Step instructions", text: $step.instructions, axis: .vertical)
                            Button("Remove step", role: .destructive) { draft.steps.removeAll { $0.id == step.id } }
                        }
                    }
                    Button("Add a step") { draft.steps.append(PracticeStep()) }
                    GrimoireTextField(label: "A smaller version", text: $draft.smallerVersion, lines: 2)
                    Text("A smaller version is recorded as partial scope. It does not silently complete the full routine.").font(.footnote)
                    TextField("Effort in minutes (optional)", value: $draft.effortMinutes, format: .number).keyboardType(.numberPad)
                    TextField("Responsible person (optional)", text: $draft.responsiblePerson)
                }
                DisclosureGroup("Connections") {
                    Picker("Asset or supply", selection: $draft.assetID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(store.data.grimoire.assets.filter { !$0.archived }) { Text($0.name).tag(Optional($0.id)) }
                    }
                    ForEach(store.data.grimoire.spells.filter { !$0.archived }) { spell in
                        Toggle(spell.title, isOn: Binding(get: { draft.spellIDs.contains(spell.id) }, set: { value in
                            draft.spellIDs.removeAll { $0 == spell.id }; if value { draft.spellIDs.append(spell.id) }
                        }))
                    }
                    Toggle("Ward / protective practice", isOn: Binding(get: { draft.tags.contains("ward") }, set: { value in draft.tags.removeAll { $0 == "ward" }; if value { draft.tags.append("ward") } }))
                }
            }
            if existing {
                Section("Apply changes to future occurrences") {
                    DatePicker("Effective from", selection: $effectiveFrom, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    Text("Recorded occurrences keep their original title, steps and schedule. To change one planned occurrence, use Reschedule on its detail page.").font(.footnote)
                }
            }
            if !draft.sourceIDs.isEmpty {
                Section("Template origin") {
                    Text(draft.sourceIDs.joined(separator: ", "))
                    Text("This is your copy. Library updates will not replace your wording or schedule.").font(.footnote)
                }
            }
        }.navigationTitle(existing ? "Edit practice" : "New quest or ritual").navigationBarTitleDisplayMode(.inline).invokeScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.presentGrimoireError { try store.savePractice(draft, effectiveFrom: effectiveFrom); dismiss() } }
                        .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("quest-save")
                }
            }
    }
}

struct ScheduleEditorFields: View {
    @Binding var rule: ScheduleRule
    let settings: GrimoireSettings
    @State private var advanced = false
    private var calendar: Calendar { GrimoirePresentation.calendar(settings) }
    private var start: Binding<Date> { Binding(get: { GrimoirePresentation.date(rule.startDate, settings: settings) }, set: { rule.startDate = LocalDay($0, timeZone: calendar.timeZone) }) }
    private var monthlyFamily: Bool { [.monthly, .quarterly, .semiannual, .annual].contains(rule.kind) }
    var body: some View {
        Section("Schedule") {
            Picker("Repeats", selection: $rule.kind) { ForEach(ScheduleKind.allCases) { Text($0.title).tag($0) } }.accessibilityIdentifier("quest-schedule-kind")
            if rule.kind != .unscheduled { DatePicker(rule.kind == .once ? "Date" : "Starts / anchor", selection: start, displayedComponents: .date) }
            if rule.kind == .weekdays {
                ForEach(1...7, id: \.self) { day in
                    Toggle(calendar.weekdaySymbols[day - 1], isOn: Binding(get: { rule.weekdays.contains(day) }, set: { selected in
                        rule.weekdays.removeAll { $0 == day }; if selected { rule.weekdays.append(day) }
                    }))
                }
            }
            if rule.kind == .weeklyQuota { Stepper("\(rule.quota) sessions per week", value: $rule.quota, in: 1...50) }
            if monthlyFamily {
                Toggle("Last day of month", isOn: $rule.lastDayOfMonth)
                if !rule.lastDayOfMonth {
                    Toggle("Selected weekday", isOn: Binding(get: { rule.weekdayOrdinal != nil }, set: { rule.weekdayOrdinal = $0 ? 1 : nil }))
                    if rule.weekdayOrdinal != nil {
                        Picker("Weekday occurrence", selection: Binding(get: { rule.weekdayOrdinal ?? 1 }, set: { rule.weekdayOrdinal = $0 })) {
                            Text("First").tag(1); Text("Second").tag(2); Text("Third").tag(3); Text("Fourth").tag(4); Text("Fifth").tag(5); Text("Last").tag(-1)
                        }
                        Picker("Weekday", selection: $rule.ordinalWeekday) { ForEach(1...7, id: \.self) { Text(calendar.weekdaySymbols[$0 - 1]).tag($0) } }
                    } else { Stepper("Day \(rule.dayOfMonth)", value: $rule.dayOfMonth, in: 1...31) }
                }
                Text("If that day is unavailable, use the month's last valid day. A February 29 annual schedule uses February 28 in non-leap years.").font(.footnote)
                if rule.kind == .quarterly { Toggle("Use calendar-quarter review windows", isOn: $rule.calendarQuarter) }
            }
            if [.custom, .afterCompletion, .condition].contains(rule.kind) {
                Stepper("Every \(rule.interval)", value: $rule.interval, in: 1...365)
                Picker("Calendar unit", selection: $rule.intervalUnit) { ForEach(CalendarUnit.allCases) { Text($0.title).tag($0) } }
            }
            if rule.kind == .afterCompletion {
                OptionalDateField(title: "Known last actual completion", date: $rule.lastActualCompletion, components: [.date, .hourAndMinute])
            }
            if rule.kind == .event { TextField("Event name, e.g. Move or Trip", text: $rule.eventName) }
            if rule.kind == .condition { GrimoireTextField(label: "What will you inspect?", text: $rule.conditionPrompt, lines: 2) }
            Picker("If unrecorded", selection: $rule.policy) { ForEach(OverduePolicy.allCases) { Text($0.title).tag($0) } }
        }
        Section {
            DisclosureGroup("Times, deadlines and reminders", isExpanded: $advanced) {
                if [.daily, .weekdays].contains(rule.kind) {
                    ForEach($rule.slots) { $slot in
                        TextField("Instance name", text: $slot.name)
                        Stepper("Hour: \(slot.hour)", value: $slot.hour, in: 0...23)
                        Stepper("Minute: \(slot.minute)", value: $slot.minute, in: 0...59)
                        Button("Remove \(slot.name)", role: .destructive) { rule.slots.removeAll { $0.id == slot.id } }
                    }
                    Button("Add a distinct daily instance") { rule.slots.append(TimeSlot()) }
                }
                Toggle("Hard deadline", isOn: $rule.hardDeadline)
                Toggle("Specific due time", isOn: Binding(get: { rule.deadlineHour != nil }, set: { rule.deadlineHour = $0 ? 17 : nil }))
                if rule.deadlineHour != nil {
                    Stepper("Due hour: \(rule.deadlineHour ?? 17)", value: Binding(get: { rule.deadlineHour ?? 17 }, set: { rule.deadlineHour = $0 }), in: 0...23)
                    Stepper("Due minute: \(rule.deadlineMinute)", value: $rule.deadlineMinute, in: 0...59)
                }
                Toggle("Remind me at a chosen time", isOn: Binding(get: { rule.reminderHour != nil }, set: { rule.reminderHour = $0 ? 9 : nil }))
                if rule.reminderHour != nil {
                    Stepper("Reminder hour: \(rule.reminderHour ?? 9)", value: Binding(get: { rule.reminderHour ?? 9 }, set: { rule.reminderHour = $0 }), in: 0...23)
                    Stepper("Reminder minute: \(rule.reminderMinute)", value: $rule.reminderMinute, in: 0...59)
                    Text("Enable reminders in Settings. Snoozing a reminder does not move a deadline.").font(.footnote)
                }
                Text("Availability, due time, hard deadline and reminder are separate. Changing a date here does not change an external obligation.").font(.footnote)
                Text("Times use \(ScheduleEngine.zone(for: rule, settings: settings).identifier). In a daylight-saving gap, use the next valid local time; a repeated time occurs once.").font(.footnote)
                Toggle("End this schedule", isOn: Binding(get: { rule.endDate != nil }, set: { rule.endDate = $0 ? rule.startDate : nil }))
                if rule.endDate != nil {
                    DatePicker("End date", selection: Binding(get: { GrimoirePresentation.date(rule.endDate ?? rule.startDate, settings: settings) }, set: { rule.endDate = LocalDay($0, timeZone: calendar.timeZone) }), displayedComponents: .date)
                }
            }
        }
    }
}
