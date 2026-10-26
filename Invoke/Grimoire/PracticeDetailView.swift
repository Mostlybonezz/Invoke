import SwiftUI

struct PracticeDetailView: View {
    let practiceID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @State private var editing = false
    @State private var duplicate: PracticeDefinition?
    private var practice: PracticeDefinition? { store.data.grimoire.practices.first { $0.id == practiceID } }
    private var occurrences: [PracticeOccurrence] {
        let now = Date(), calendar = GrimoirePresentation.calendar(store.data.grimoire.settings)
        return Array(store.grimoireOccurrences(in: DateInterval(start: calendar.startOfDay(for: now), end: calendar.date(byAdding: .year, value: 1, to: now)!), practiceID: practiceID).prefix(12))
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if let practice {
                    Text(GrimoirePresentation.title(practice, settings: store.data.grimoire.settings)).font(.largeTitle).fontDesign(.serif)
                    if !practice.plainTitle.isEmpty && practice.plainTitle != practice.title { Text(practice.plainTitle).foregroundStyle(theme.secondary) }
                    HStack { StatusPill(text: practice.importance.title); StatusPill(text: practice.purpose.title) }
                    Label(practice.discipline.title, systemImage: practice.discipline.symbol)
                    Text(ScheduleEngine.summary(practice.schedule)).foregroundStyle(theme.secondary)
                    if practice.archived { StatusPill(text: "Archived") }
                    if practice.paused { StatusPill(text: "Paused") }
                    GrimoireDetailText(title: "Instructions", text: practice.instructions)
                    GrimoireDetailText(title: "Context", text: practice.context)
                    GrimoireDetailText(title: "Materials", text: practice.materials)
                    GrimoireDetailText(title: "Smaller version", text: practice.smallerVersion)
                    if let id = practice.invocationID { NavigationLink { InvocationDetailView(invocationID: id) } label: { Label("Linked Invocation", systemImage: "sparkles") } }
                    if let id = practice.assetID { NavigationLink { CareAssetDetailView(assetID: id) } label: { Label("Linked asset or supply", systemImage: "shippingbox") } }
                    if let id = practice.legacyEntryID { NavigationLink("Original Grimoire entry") { EntryDetailView(entryID: id) } }
                    if let id = practice.legacySceneID { NavigationLink("Original scene") { SceneDetailView(sceneID: id) } }
                    ForEach(practice.spellIDs, id: \.self) { id in
                        if let spell = store.data.grimoire.spells.first(where: { $0.id == id }) { GrimoireDetailText(title: spell.title, text: spell.method) }
                    }
                    if !practice.archived && !practice.paused {
                        SectionEyebrow(text: "Occurrences")
                        if occurrences.isEmpty { Text("No scheduled occurrence yet. Review the schedule or record the matching event in Quests.").foregroundStyle(theme.secondary) }
                        ForEach(occurrences) { item in OccurrenceRow(occurrence: item) }
                    }
                    SectionEyebrow(text: "Practice controls")
                    Button("Edit future practice") { editing = true }.buttonStyle(.bordered)
                    Button("Make a customized copy") {
                        var copy = practice
                        copy.id = UUID(); copy.title += " · copy"; copy.version = 1; copy.revisions = []; copy.pauses = []
                        copy.createdAt = Date(); copy.updatedAt = Date(); copy.effectiveFrom = Date(); copy.archived = false; copy.paused = false
                        copy.steps = copy.steps.map { var step = $0; step.id = UUID(); return step }
                        copy.schedule.lastActualCompletion = nil
                        duplicate = copy
                    }
                    Button(practice.paused ? "Resume practice" : "Pause practice") { store.presentGrimoireError { try store.setPracticePaused(practiceID, paused: !practice.paused) } }
                    Button(practice.archived ? "Restore from archive" : "Archive practice") { store.presentGrimoireError { try store.archivePractice(practiceID, archived: !practice.archived) } }
                    NavigationLink("View its recorded history") { ChronicleView(practiceID: practiceID) }
                    if !practice.revisions.isEmpty {
                        DisclosureGroup("Previous practice versions") {
                            ForEach(practice.revisions.sorted { $0.version > $1.version }) { revision in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Version \(revision.version) · \(revision.title)").font(.headline)
                                    Text(revision.effectiveFrom.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                                    Text(ScheduleEngine.summary(revision.schedule)).font(.subheadline)
                                    Text(revision.instructions)
                                }.padding(.vertical, 8)
                            }
                        }
                    }
                } else { ContentUnavailableView("Practice unavailable", systemImage: "book.closed", description: Text("It may have been replaced by a restored backup.")) }
            }.padding(20)
        }.navigationTitle("Practice").navigationBarTitleDisplayMode(.inline).invokeScreen()
            .sheet(isPresented: $editing) { if let practice { NavigationStack { PracticeEditorView(draft: practice) } } }
            .sheet(item: $duplicate) { draft in NavigationStack { PracticeEditorView(draft: draft) } }
    }
}

struct OccurrenceRow: View {
    let occurrence: PracticeOccurrence
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    var body: some View {
        NavigationLink { OccurrenceDetailView(occurrence: occurrence) } label: {
            InvokeCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(occurrence.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Image(systemName: store.occurrenceStatus(occurrence) == .completed ? "checkmark.seal.fill" : "chevron.right")
                    }
                    if let practice = store.data.grimoire.practices.first(where: { $0.id == occurrence.practiceID }) {
                        Text("\(practice.importance.title) · \(practice.purpose.title)\(practice.effortMinutes.map { " · \($0) min" } ?? "")").font(.caption).foregroundStyle(theme.secondary)
                    }
                    HStack {
                        Text(store.occurrenceStatus(occurrence).title)
                        Spacer()
                        if occurrence.requiredSessions > 1 { Text("\(store.sessionCount(for: occurrence))/\(occurrence.requiredSessions) sessions") }
                    }.font(.subheadline)
                    if occurrence.slotKey != "day" {
                        Label("Available \(GrimoireHistoryDate.string(occurrence.availableAt, zoneID: occurrence.timeZoneID, includeTime: true))", systemImage: "clock").font(.caption).foregroundStyle(theme.secondary)
                    }
                    if let deadline = occurrence.hardDeadline { Label("Deadline \(GrimoireHistoryDate.string(deadline, zoneID: occurrence.timeZoneID, includeTime: true))", systemImage: "exclamationmark.circle").font(.caption) }
                    else if let due = occurrence.dueAt { Text("Due \(GrimoireHistoryDate.string(due, zoneID: occurrence.timeZoneID))").font(.caption).foregroundStyle(theme.secondary) }
                    if let deferred = occurrence.deferredUntil { Text("Rescheduled to \(GrimoireHistoryDate.string(deferred, zoneID: occurrence.timeZoneID, includeTime: true))").font(.caption) }
                    if occurrence.timeZoneID != TimeZone.current.identifier { Text(occurrence.timeZoneID).font(.caption2).foregroundStyle(theme.secondary) }
                }.foregroundStyle(theme.text)
            }
        }.buttonStyle(.plain).accessibilityIdentifier("quest-row-\(occurrence.id)")
    }
}

struct OccurrenceDetailView: View {
    let occurrence: PracticeOccurrence
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @State private var sessionID: UUID?
    @State private var requestID = UUID()
    @State private var checked: Set<UUID> = []
    @State private var notes = ""
    @State private var measurement: Double?
    @State private var measurementUnit = ""
    @State private var occurredAt = Date()
    @State private var recordedEarlier = false
    @State private var feedback = ""
    @State private var rescheduling = false
    @State private var rescheduleDate = Date()
    @State private var showingTimer = false
    private var current: PracticeOccurrence { store.occurrence(id: occurrence.id) ?? occurrence }
    private var practice: PracticeDefinition? { store.data.grimoire.practices.first { $0.id == occurrence.practiceID } }
    private var status: OccurrenceStatus { store.occurrenceStatus(current) }
    private var latest: ActionRecord? { store.activeActions(for: current.id).filter { ![.begin, .progress].contains($0.kind) }.max { $0.recordedAt < $1.recordedAt } }
    private var canRecord: Bool { practice?.archived == false && practice?.paused == false && !current.superseded }
    private var fullSteps: Bool { Set(current.steps.map(\.id)).isSubset(of: checked) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionEyebrow(text: "A real action, honestly recorded")
                Text(current.title).font(.largeTitle).fontDesign(.serif)
                HStack { StatusPill(text: status.title); if current.requiredSessions > 1 { Text("\(store.sessionCount(for: current))/\(current.requiredSessions) sessions this period") } }
                GrimoireDetailText(title: "Instructions", text: current.instructions)
                GrimoireDetailText(title: "Trigger", text: current.context)
                GrimoireDetailText(title: "Materials", text: current.materials)
                GrimoireDetailText(title: "Smaller version", text: current.smallerVersion)
                if let deadline = current.hardDeadline { Label("Hard deadline: \(GrimoireHistoryDate.string(deadline, zoneID: current.timeZoneID, includeTime: true))", systemImage: "exclamationmark.circle") }
                if practice?.schedule.kind == .unscheduled {
                    Text("Open practice · no scheduled deadline").font(.caption).foregroundStyle(theme.secondary)
                } else {
                    let cal = ScheduleEngine.calendar(zone: TimeZone(identifier: current.timeZoneID) ?? .current, weekStart: store.data.grimoire.settings.weekStartsOn)
                    let start = ScheduleEngine.date(current.windowStart, in: cal) ?? current.availableAt
                    let end = ScheduleEngine.date(current.windowEnd, in: cal).flatMap { cal.date(byAdding: .day, value: -1, to: $0) } ?? start
                    Text("\(GrimoireHistoryDate.string(start, zoneID: current.timeZoneID)) – \(GrimoireHistoryDate.string(end, zoneID: current.timeZoneID)) · \(current.timeZoneID)").font(.caption).foregroundStyle(theme.secondary)
                    Label("Available \(GrimoireHistoryDate.string(current.availableAt, zoneID: current.timeZoneID, includeTime: current.slotKey != "day"))", systemImage: "clock").font(.caption)
                    if current.hardDeadline == nil, let due = current.dueAt {
                        Text("Due \(GrimoireHistoryDate.string(due, zoneID: current.timeZoneID, includeTime: true))").font(.caption)
                    }
                }
                SavedFeedback(message: feedback)
                if canRecord && status != .skipped {
                    if sessionID == nil && status != .completed {
                        InvokePrimaryButton(title: "Begin / resume ritual") { begin() }.accessibilityIdentifier("quest-begin")
                    }
                    if sessionID != nil {
                        ForEach(current.steps) { step in
                            Toggle(isOn: Binding(get: { checked.contains(step.id) }, set: { selected in
                                let before = checked
                                if selected { checked.insert(step.id) } else { checked.remove(step.id) }
                                do { try save(.progress, request: UUID()); feedback = "Step progress saved." }
                                catch { checked = before; store.errorMessage = error.localizedDescription }
                            })) { VStack(alignment: .leading, spacing: 4) { Text(step.title).font(.headline); if !step.instructions.isEmpty { Text(step.instructions).font(.subheadline).foregroundStyle(theme.secondary) } } }
                        }
                        Toggle("Show elapsed time", isOn: $showingTimer)
                        if showingTimer, let began = store.activeActions(for: current.id).first(where: { $0.sessionID == sessionID && $0.kind == .begin }) {
                            Text(began.occurredAt, style: .timer).monospacedDigit()
                            Text("Elapsed since this session began, including time away. The timer does not record completion.").font(.caption).foregroundStyle(theme.secondary)
                        }
                    }
                    if status != .completed || current.requiredSessions > 1 {
                        GrimoireTextField(label: "Notes / actual observation", text: $notes)
                        HStack { OptionalNumberField(title: "Measurement (optional)", number: $measurement); TextField("Unit", text: $measurementUnit) }
                        Toggle("Record an earlier action", isOn: $recordedEarlier)
                        if recordedEarlier { DatePicker("Actual action time", selection: $occurredAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute]); Text("The action stays attached to this occurrence and retains its original time zone.").font(.caption) }
                        if status != .completed {
                            InvokePrimaryButton(title: current.steps.isEmpty ? "Mark complete" : "Record full ritual") { record(.complete) }
                                .disabled(!fullSteps).accessibilityIdentifier("quest-complete")
                            if !fullSteps { Text("Check the steps performed, or save partial progress below.").font(.footnote) }
                        }
                        if !current.smallerVersion.isEmpty, status != .completed { Button("Record smaller version") { record(.smaller) }.buttonStyle(.bordered) }
                        if status != .completed { Button("Save partial progress & notes") { record(.progress) }.buttonStyle(.bordered).accessibilityIdentifier("quest-partial") }
                        if current.requiredSessions > 1 && store.sessionCount(for: current) < current.requiredSessions && latest?.kind == .complete {
                            Button("Begin a separate session") { begin(newSession: true) }.buttonStyle(.bordered)
                        }
                    }
                }
                if let latest {
                    Button("Undo \(latest.kind.title.lowercased())") { store.presentGrimoireError { try store.undoAction(latest.id); feedback = "Record corrected. Progress recalculated."; requestID = UUID(); sessionID = nil } }
                        .accessibilityIdentifier("quest-undo")
                }
                if canRecord && status != .completed {
                    HStack {
                        Button("Skip this occurrence") { record(.skip) }
                        Spacer()
                        Button("Reschedule") { rescheduling = true }
                    }.font(.subheadline)
                    Button("Snooze reminder for one hour") { store.presentGrimoireError { try store.ensureOccurrence(current); try store.snoozeReminder(current.id, until: Date().addingTimeInterval(3600)); feedback = "Reminder snoozed. Deadline unchanged." } }
                }
                NavigationLink("Open practice and future schedule") { PracticeDetailView(practiceID: current.practiceID) }
                NavigationLink("View recorded history") { ChronicleView(practiceID: current.practiceID) }
            }.padding(20)
        }.navigationTitle("Ritual / quest").navigationBarTitleDisplayMode(.inline).invokeScreen()
            .sheet(isPresented: $rescheduling) {
                NavigationStack {
                    Form {
                        DatePicker("New availability", selection: $rescheduleDate, displayedComponents: [.date, .hourAndMinute])
                        Text("This defers one occurrence. Its original hard deadline remains unchanged. Edit the practice deliberately to change future deadlines.")
                        Button("Save reschedule") { store.presentGrimoireError { try store.ensureOccurrence(current); try store.deferOccurrence(current.id, to: rescheduleDate); rescheduling = false } }
                    }.navigationTitle("Reschedule").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { rescheduling = false } } }.invokeScreen()
                }
            }
            .onAppear { restoreProgress() }
            .onDisappear { persistDraftIfNeeded() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { persistDraftIfNeeded() } }
    }
    private func persistDraftIfNeeded() {
        guard canRecord, status != .completed, status != .skipped else { return }
        guard sessionID != nil || !notes.isEmpty || measurement != nil else { return }
        let last = store.activeActions(for: current.id).last { $0.sessionID == sessionID && [.progress, .smaller].contains($0.kind) }
        guard (last?.notes ?? "") != notes || (last?.measurement != measurement) || (last?.measurementUnit ?? "") != measurementUnit || Set(last?.completedStepIDs ?? []) != checked else { return }
        store.presentGrimoireError { try save(.progress, request: UUID()) }
    }
    private func begin(newSession: Bool = false) {
        store.presentGrimoireError {
            try store.ensureOccurrence(current)
            sessionID = try store.beginSession(occurrenceID: current.id, newSession: newSession)
            requestID = UUID()
            if newSession { checked = []; notes = ""; measurement = nil }
            else { restoreProgress() }
            feedback = "Session ready. Record what you actually do."
        }
    }
    private func save(_ kind: ActionKind, request: UUID) throws {
        try store.ensureOccurrence(current)
        if sessionID == nil { sessionID = try store.beginSession(occurrenceID: current.id) }
        guard let sessionID else { return }
        try store.recordAction(occurrenceID: current.id, kind: kind, sessionID: sessionID, requestID: request, steps: Array(checked), notes: notes, measurement: measurement, measurementUnit: measurementUnit, occurredAt: recordedEarlier ? occurredAt : Date())
    }
    private func record(_ kind: ActionKind) {
        store.presentGrimoireError {
            try save(kind, request: kind == .complete ? requestID : UUID())
            feedback = kind == .complete ? "Ritual recorded." : kind == .smaller ? "Smaller version recorded as partial scope." : kind == .skip ? "Explicit skip recorded." : "Partial progress and notes saved."
        }
    }
    private func restoreProgress() {
        let records = store.activeActions(for: current.id).sorted { $0.recordedAt < $1.recordedAt }
        if sessionID == nil, let began = records.last(where: { $0.kind == .begin }), !records.contains(where: { $0.sessionID == began.sessionID && $0.kind == .complete }) { sessionID = began.sessionID }
        if let record = records.last(where: { $0.sessionID == sessionID && [.progress, .smaller].contains($0.kind) }) { checked = Set(record.completedStepIDs); notes = record.notes; measurement = record.measurement; measurementUnit = record.measurementUnit }
    }
}
