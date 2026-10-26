import SwiftUI

struct InvocationsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @State private var search = ""
    @State private var archived = false
    @State private var adding = false
    private var values: [Invocation] {
        store.data.grimoire.invocations.filter { $0.archived == archived && (search.isEmpty || "\($0.title) \($0.intention) \($0.outcome)".localizedCaseInsensitiveContains(search)) }.sorted { $0.updatedAt > $1.updatedAt }
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Text(store.data.grimoire.settings.fantasyLanguage ? "What are you calling into your life?" : "Goals and chosen directions").font(.title2).fontDesign(.serif)
                Text("Choose a direction. Connect actions within your control. Observe what actually changes.").foregroundStyle(theme.secondary)
                Toggle("Show archived Invocations", isOn: $archived)
                ForEach(values) { invocation in
                    NavigationLink { InvocationDetailView(invocationID: invocation.id) } label: {
                        InvokeCard { VStack(alignment: .leading, spacing: 10) {
                            HStack { Label(invocation.discipline.title, systemImage: invocation.discipline.symbol).font(.caption); Spacer(); StatusPill(text: invocation.status) }
                            Text(invocation.title).font(.title2).fontDesign(.serif)
                            Text(invocation.intention).lineLimit(3).foregroundStyle(theme.secondary)
                            if let date = invocation.reviewDate { Text("Review \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption) }
                        } }
                    }.buttonStyle(.plain)
                }
                if values.isEmpty { ContentUnavailableView("A direction of your own", systemImage: "sparkles", description: Text("Add an Invocation. An exploratory intention does not need a numerical target.")) }
                SectionEyebrow(text: "Your original collection")
                NavigationLink { StoriesView() } label: { Label("Stories, scenes & constellations", systemImage: "book") }.accessibilityIdentifier("legacy-stories")
                NavigationLink { GrimoireView() } label: { Label("Original manifestations & beliefs", systemImage: "moon") }
            }.padding(20)
        }.navigationTitle("Invocations").searchable(text: $search).invokeScreen()
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("New Invocation").accessibilityIdentifier("invocation-add") } }
            .sheet(isPresented: $adding) { NavigationStack { InvocationEditorView() } }
    }
}

struct InvocationEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Invocation
    init(draft: Invocation = Invocation()) { _draft = State(initialValue: draft) }
    var body: some View {
        Form {
            Section("1 · Name and intention") {
                TextField("Name", text: $draft.title).accessibilityIdentifier("invocation-title")
                GrimoireTextField(label: "What are you calling into your life?", text: $draft.intention)
                DisciplinePicker(value: $draft.discipline)
            }
            Section("2 · Meaning and outcome") { GrimoireTextField(label: "What would this change look or feel like?", text: $draft.outcome) }
            Section("3 · Evidence") { GrimoireTextField(label: "Chosen observations or measures (optional)", text: $draft.evidence); Text("Exploration and experience are valid. Recording actions never guarantees an outcome.").font(.footnote) }
            Section("4 · Influence") { GrimoireTextField(label: "Actions and preparations within your control", text: $draft.influence) }
            Section("5 · Obstacles") { GrimoireTextField(label: "What may interfere?", text: $draft.obstacles) }
            Section("6 · Counterspells / practical responses") { GrimoireTextField(label: "When X happens, I will do Y", text: $draft.counterspells) }
            Section("7 · Questline milestones") {
                ForEach($draft.milestones) { $milestone in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Milestone", text: $milestone.title)
                        TextField("Meaning / notes", text: $milestone.notes, axis: .vertical)
                        Toggle("Milestone reached", isOn: Binding(get: { milestone.completedAt != nil }, set: { milestone.completedAt = $0 ? Date() : nil }))
                        if let date = milestone.completedAt { Text("Recorded \(date.formatted(date: .abbreviated, time: .shortened))").font(.caption) }
                    }
                }
                Button("Add milestone") { draft.milestones.append(InvocationMilestone()) }
                Text("Link quests and rituals after saving. Milestones are explicitly recorded; effort alone does not complete them.").font(.footnote)
            }
            Section("8 · Review") {
                OptionalDateField(title: "Choose a review date", date: $draft.reviewDate)
                Picker("Status", selection: $draft.status) { ForEach(["Active", "Paused", "Completed", "Revised", "Archived"], id: \.self) { Text($0).tag($0) } }
                GrimoireTextField(label: "Notes", text: $draft.notes)
            }
        }.navigationTitle("Shape an Invocation").navigationBarTitleDisplayMode(.inline).invokeScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { store.presentGrimoireError { try store.saveInvocation(draft); dismiss() } }.disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("invocation-save") }
            }
    }
}

struct InvocationDetailView: View {
    let invocationID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @State private var editing = false
    @State private var addPractice = false
    @State private var observing = false
    private var invocation: Invocation? { store.data.grimoire.invocations.first { $0.id == invocationID } }
    private var practices: [PracticeDefinition] { store.data.grimoire.practices.filter { $0.invocationID == invocationID } }
    private var actions: [ActionRecord] {
        let ids = Set(practices.map(\.id))
        return ScheduleEngine.activeActions(store.data.grimoire.actions).filter { ids.contains($0.practiceID) && $0.kind == .complete }
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if let invocation {
                    SectionEyebrow(text: invocation.status)
                    Text(invocation.title).font(.largeTitle).fontDesign(.serif)
                    GrimoireDetailText(title: "Intention", text: invocation.intention)
                    GrimoireDetailText(title: "What it would mean", text: invocation.outcome)
                    Text("\(actions.count) linked actions recorded").font(.headline).accessibilityIdentifier("invocation-action-count")
                    Text("Action history and observed outcomes are kept separately.").font(.footnote).foregroundStyle(theme.secondary)
                    ForEach(invocation.milestones) { milestone in
                        Label { VStack(alignment: .leading, spacing: 4) { Text(milestone.title); if !milestone.notes.isEmpty { Text(milestone.notes).font(.caption) } } } icon: { Image(systemName: milestone.completedAt == nil ? "circle" : "checkmark.circle.fill") }
                    }
                    SectionEyebrow(text: "Linked practices / next actions")
                    ForEach(practices.filter { !$0.archived }) { practice in
                        NavigationLink { PracticeDetailView(practiceID: practice.id) } label: { Label(practice.title, systemImage: practice.discipline.symbol) }
                    }
                    Button("Add a linked quest or ritual") { addPractice = true }.buttonStyle(.bordered).accessibilityIdentifier("invocation-add-practice")
                    GrimoireDetailText(title: "Evidence you chose", text: invocation.evidence)
                    GrimoireDetailText(title: "Within your influence", text: invocation.influence)
                    GrimoireDetailText(title: "Obstacles", text: invocation.obstacles)
                    GrimoireDetailText(title: "Counterspells / responses", text: invocation.counterspells)
                    if let date = invocation.reviewDate { Label("Review \(date.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar") }
                    SectionEyebrow(text: "Actual observations")
                    ForEach(invocation.observations.sorted { $0.observedAt > $1.observedAt }) { observation in
                        InvokeCard { VStack(alignment: .leading, spacing: 8) { Text(observation.observedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption); Text(observation.text); if let value = observation.measurement { Text("\(value.formatted()) \(observation.unit)") } } }
                    }
                    Button("Record an observation") { observing = true }.buttonStyle(.bordered)
                    if let id = invocation.legacyStoryID { NavigationLink("Original story") { StoryDetailView(storyID: id) } }
                    if let id = invocation.legacyEntryID { NavigationLink("Original manifestation") { EntryDetailView(entryID: id) } }
                    GrimoireDetailText(title: "Notes", text: invocation.notes)
                    DisclosureGroup("Changes to this Invocation") {
                        ForEach(store.data.grimoire.revisions.filter { $0.recordID == invocationID }.sorted { $0.changedAt > $1.changedAt }) { revision in
                            VStack(alignment: .leading) { Text(revision.changedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption); Text(revision.summary) }.padding(.vertical, 6)
                        }
                    }
                    Button(invocation.archived ? "Restore Invocation" : "Archive Invocation") { var changed = invocation; changed.archived.toggle(); store.presentGrimoireError { try store.saveInvocation(changed) } }
                } else { ContentUnavailableView("Invocation unavailable", systemImage: "sparkles") }
            }.padding(20)
        }.navigationTitle("Invocation").navigationBarTitleDisplayMode(.inline).invokeScreen()
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { editing = true }.disabled(invocation == nil) } }
            .sheet(isPresented: $editing) { if let invocation { NavigationStack { InvocationEditorView(draft: invocation) } } }
            .sheet(isPresented: $addPractice) { NavigationStack { PracticeEditorView(draft: PracticeDefinition(invocationID: invocationID)) } }
            .sheet(isPresented: $observing) { NavigationStack { InvocationObservationEditor(invocationID: invocationID) } }
    }
}

struct InvocationObservationEditor: View {
    let invocationID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var value = InvocationObservation()
    var body: some View {
        Form {
            GrimoireTextField(label: "What did you actually observe?", text: $value.text)
            DatePicker("Observed at", selection: $value.observedAt, in: ...Date())
            OptionalNumberField(title: "Measurement (optional)", number: $value.measurement)
            TextField("Unit / meaning", text: $value.unit)
        }.navigationTitle("Record observation").invokeScreen().toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { store.presentGrimoireError {
                guard var invocation = store.data.grimoire.invocations.first(where: { $0.id == invocationID }) else { return }
                invocation.observations.append(value); try store.saveInvocation(invocation); dismiss()
            } }.disabled(value.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
    }
}
