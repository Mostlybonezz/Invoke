import SwiftUI
import Combine

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date()
    @State private var adding = false
    @State private var allAttention = false
    private var settings: GrimoireSettings { store.data.grimoire.settings }
    private var calendar: Calendar { GrimoirePresentation.calendar(settings) }
    private var day: DateInterval { calendar.dateInterval(of: .day, for: now)! }
    private var rows: [PracticeOccurrence] { store.grimoireOccurrences(in: DateInterval(start: day.start, end: calendar.date(byAdding: .month, value: 1, to: day.end)!), now: now) }
    private func unresolved(_ item: PracticeOccurrence) -> Bool { ![.completed, .skipped].contains(store.occurrenceStatus(item)) }
    private func attention(in rows: [PracticeOccurrence]) -> [PracticeOccurrence] {
        rows.filter { item in
            guard unresolved(item), let practice = store.data.grimoire.practices.first(where: { $0.id == item.practiceID }) else { return false }
            return (item.hardDeadline.map { $0 < day.end } ?? false) || (practice.importance == .critical && item.availableAt < day.end)
        }.sorted { a, b in
            let ad = a.hardDeadline ?? a.dueAt ?? .distantFuture, bd = b.hardDeadline ?? b.dueAt ?? .distantFuture
            return ad == bd ? a.id < b.id : ad < bd
        }
    }
    private func today(in rows: [PracticeOccurrence], attention: [PracticeOccurrence]) -> [PracticeOccurrence] {
        rows.filter { item in
            let eligible = item.availableAt < day.end && (item.deferredUntil.map { $0 < day.end } ?? true)
            guard eligible, !attention.contains(where: { $0.id == item.id }) else { return false }
            if settings.restorationMode {
                return settings.essentialPracticeIDs.contains(item.practiceID) || item.hardDeadline != nil
            }
            return true
        }
    }
    private func daily(in rows: [PracticeOccurrence]) -> [PracticeOccurrence] {
        rows.filter { item in
            guard item.availableAt < day.end && item.availableAt >= day.start,
                  let practice = store.data.grimoire.practices.first(where: { $0.id == item.practiceID }) else { return false }
            return [.daily, .weekdays].contains(practice.schedule.kind)
        }
    }
    var body: some View {
        let rows = self.rows
        let attention = attention(in: rows)
        let today = today(in: rows, attention: attention)
        let daily = daily(in: rows)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).font(.subheadline).foregroundStyle(theme.secondary)
                        Text(settings.fantasyLanguage ? "The Sanctum" : "Today").font(.title).fontDesign(.serif)
                    }
                    Spacer()
                    Button { adding = true } label: { Image(systemName: "plus").frame(width: 44, height: 44) }.accessibilityLabel("Add quest or ritual").accessibilityIdentifier("today-add-quest")
                }
                if !attention.isEmpty {
                    DisclosureGroup(isExpanded: $allAttention) {
                        ForEach(attention) { OccurrenceRow(occurrence: $0) }
                    } label: { Label("Needs attention · \(attention.count)", systemImage: "exclamationmark.circle").font(.headline) }
                    if !allAttention, let first = attention.first { OccurrenceRow(occurrence: first) }
                }
                if settings.restorationMode { Label("Restoration Mode · essentials and consequential deadlines", systemImage: "leaf").font(.footnote); NavigationLink("View all scheduled work") { QuestsView() } }
                if !daily.isEmpty { Text("\(daily.filter { store.occurrenceStatus($0) == .completed }.count) of \(daily.count) planned daily practices recorded").font(.subheadline).foregroundStyle(theme.secondary).accessibilityIdentifier("today-progress") }
                if today.isEmpty && attention.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("A little room to begin.").font(.title2).fontDesign(.serif)
                        Text("Choose a practice from the Codex or add a quest. Only what you activate belongs to your day.").foregroundStyle(theme.secondary)
                        NavigationLink { LivingGrimoireView() } label: { Label("Browse the Life Maintenance Codex", systemImage: "books.vertical") }.accessibilityIdentifier("today-codex")
                    }.padding(.vertical, 12)
                }
                ForEach(today) { OccurrenceRow(occurrence: $0) }
                if let id = settings.focusPracticeID, let practice = store.data.grimoire.practices.first(where: { $0.id == id && !$0.archived }) {
                    SectionEyebrow(text: "Your chosen focus")
                    NavigationLink { PracticeDetailView(practiceID: id) } label: { InvokeCard { VStack(alignment: .leading, spacing: 6) { Text(practice.title).font(.title3).fontDesign(.serif); Text(practice.instructions).lineLimit(2).font(.subheadline) } } }.buttonStyle(.plain)
                }
                SectionEyebrow(text: "On the horizon")
                let upcoming = rows.filter { $0.availableAt >= day.end && unresolved($0) }
                ForEach(Array(upcoming.prefix(3))) { OccurrenceRow(occurrence: $0) }
                NavigationLink("This week, month and longer cycles") { QuestsView(initialPeriod: "Week") }
                let reviews = store.data.grimoire.invocations.filter { !$0.archived && $0.reviewDate != nil }.sorted { $0.reviewDate! < $1.reviewDate! }
                ForEach(Array(reviews.prefix(2))) { invocation in
                    NavigationLink { InvocationDetailView(invocationID: invocation.id) } label: { Label("Review \(invocation.title) · \(invocation.reviewDate!.formatted(date: .abbreviated, time: .omitted))", systemImage: "sparkles") }
                }
                NavigationLink { ChronicleView() } label: { Label("Reflect in the Chronicle", systemImage: "square.and.pencil") }
                if settings.recognitionEnabled {
                    let actual = ScheduleEngine.activeActions(store.data.grimoire.actions).filter { $0.kind == .complete }
                    let sessions = Set(actual.map(\.sessionID)).count
                    if sessions > 0 {
                        InvokeCard { VStack(alignment: .leading, spacing: 6) {
                            Label(sessions >= 25 ? "A practice taking shape" : sessions >= 10 ? "Ten moments witnessed" : "A recorded beginning", systemImage: "seal").font(.headline)
                            Text("\(sessions) distinct full sessions recorded. This seal marks your history; it does not measure outcomes or worth.").font(.footnote).foregroundStyle(theme.secondary)
                        } }
                    }
                }
                NavigationLink { SanctuaryView() } label: { Label("Story sanctuary & constellation", systemImage: "sparkle") }.accessibilityIdentifier("legacy-sanctuary")
                Text(store.saveState).font(.caption).foregroundStyle(theme.secondary)
            }.padding(20)
        }.navigationTitle("Today").navigationBarTitleDisplayMode(.inline).invokeScreen()
            .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink { SettingsView() } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44) }.accessibilityLabel("Settings").accessibilityIdentifier("today-settings") } }
            .sheet(isPresented: $adding) { NavigationStack { PracticeEditorView() } }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
            .onChange(of: scenePhase) { _, phase in if phase == .active { now = Date() } }
    }
}

struct QuestsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @State private var period: String
    @State private var search = ""
    @State private var discipline = "all"
    @State private var importance = "all"
    @State private var purpose = "all"
    @State private var status = "all"
    @State private var cycle = "all"
    @State private var archive = false
    @State private var customStart = Date()
    @State private var customEnd = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
    @State private var adding = false
    @State private var eventSheet = false
    init(initialPeriod: String = "Today") { _period = State(initialValue: initialPeriod) }
    private var range: DateInterval {
        let calendar = GrimoirePresentation.calendar(store.data.grimoire.settings), now = Date()
        if period == "Custom" { return DateInterval(start: min(customStart, customEnd), end: max(customEnd, customStart.addingTimeInterval(1))) }
        let component: Calendar.Component = period == "Week" ? .weekOfYear : period == "Month" ? .month : period == "Quarter" ? .quarter : period == "Year" ? .year : .day
        return calendar.dateInterval(of: component, for: now)!
    }
    private func matches(_ item: PracticeDefinition) -> Bool {
        item.archived == archive && (discipline == "all" || item.discipline.rawValue == discipline)
        && (importance == "all" || item.importance.rawValue == importance) && (purpose == "all" || item.purpose.rawValue == purpose)
        && (cycle == "all" || item.schedule.kind.rawValue == cycle)
        && (search.isEmpty || "\(item.title) \(item.plainTitle) \(item.instructions) \(item.tags.joined(separator: " "))".localizedCaseInsensitiveContains(search))
    }
    private var practices: [PracticeDefinition] { store.data.grimoire.practices.filter(matches).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending } }
    private var occurrences: [PracticeOccurrence] {
        let ids = Set(practices.map(\.id))
        return store.grimoireOccurrences(in: range).filter { ids.contains($0.practiceID) && (status == "all" || store.occurrenceStatus($0).rawValue == status) }
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Picker("Time horizon", selection: $period) { ForEach(["Today", "Week", "Month", "Quarter", "Year", "Custom"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
                if period == "Custom" { DatePicker("From", selection: $customStart, displayedComponents: .date); DatePicker("Through", selection: $customEnd, displayedComponents: .date) }
                DisclosureGroup("Filters") {
                    Picker("Discipline", selection: $discipline) { Text("All disciplines").tag("all"); ForEach(Discipline.allCases) { Text($0.title).tag($0.rawValue) } }
                    Picker("Importance", selection: $importance) { Text("All priorities").tag("all"); ForEach(Importance.allCases) { Text($0.title).tag($0.rawValue) } }
                    Picker("Purpose", selection: $purpose) { Text("All purposes").tag("all"); ForEach(PracticePurpose.allCases) { Text($0.title).tag($0.rawValue) } }
                    Picker("Status", selection: $status) { Text("All statuses").tag("all"); ForEach(OccurrenceStatus.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) } }
                    Picker("Recurrence", selection: $cycle) { Text("All cycles").tag("all"); ForEach(ScheduleKind.allCases) { Text($0.title).tag($0.rawValue) } }
                    Toggle("Archived practices", isOn: $archive)
                }
                if !archive {
                    SectionEyebrow(text: "Scheduled occurrences")
                    if occurrences.isEmpty { Text("No matching occurrences. Unscheduled, paused and event-driven practices remain available below.").foregroundStyle(theme.secondary) }
                    ForEach(occurrences) { OccurrenceRow(occurrence: $0) }
                }
                SectionEyebrow(text: "Practice definitions")
                if practices.isEmpty { ContentUnavailableView("No matching practices", systemImage: "list.bullet", description: Text("Add one, browse the Codex, or adjust the filters.")) }
                ForEach(practices) { practice in
                    NavigationLink { PracticeDetailView(practiceID: practice.id) } label: {
                        InvokeCard { VStack(alignment: .leading, spacing: 8) { Text(GrimoirePresentation.title(practice, settings: store.data.grimoire.settings)).font(.headline); Text(ScheduleEngine.summary(practice.schedule)).font(.caption).foregroundStyle(theme.secondary); if practice.paused { StatusPill(text: "Paused") } } }
                    }.buttonStyle(.plain)
                }
            }.padding(20)
        }.navigationTitle("Quests").searchable(text: $search, prompt: "Names, plain meanings, instructions").invokeScreen()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Record event") { eventSheet = true } }
                ToolbarItem(placement: .topBarTrailing) { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add quest").accessibilityIdentifier("quests-add") }
            }
            .sheet(isPresented: $adding) { NavigationStack { PracticeEditorView() } }
            .sheet(isPresented: $eventSheet) { NavigationStack { GrimoireEventEditor() } }
    }
}

struct GrimoireEventEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var event = GrimoireEvent()
    var body: some View {
        Form {
            TextField("Event name", text: $event.name)
            Text("Match the name configured on your event-driven practice, such as Move or Trip. Events are never inferred from your private data.").font(.footnote)
            DatePicker("When it happened", selection: $event.occurredAt, in: ...Date())
            GrimoireTextField(label: "Notes", text: $event.notes)
        }.navigationTitle("Record an event").invokeScreen().toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { store.presentGrimoireError { try store.saveEvent(event); dismiss() } }.disabled(event.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
    }
}
