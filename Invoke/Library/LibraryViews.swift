import SwiftUI

struct LibrarySelection: Identifiable, Hashable {
    let id: UUID
}

struct GrimoireView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @State private var search = ""
    @State private var kind = "all"
    @State private var showArchive = false
    @State private var createdEntry: LibrarySelection?

    private var entries: [LibraryEntry] {
        store.data.entries.filter {
            $0.archived == showArchive && (kind == "all" || $0.kind.rawValue == kind)
            && (search.isEmpty || ([$0.title] + Array($0.fields.values)).joined(separator: " ").localizedCaseInsensitiveContains(search))
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("A place for what calls to you.").font(.title2).fontDesign(.serif)
                Text("Desires, beliefs, and practices can belong to more than one story.")
                    .foregroundStyle(theme.secondary)
                Picker("Category", selection: $kind) {
                    Text("All entries").tag("all")
                    ForEach(EntryKind.allCases) { item in Text(item.plural).tag(item.rawValue) }
                }.pickerStyle(.menu).accessibilityLabel("Grimoire category")
                if showArchive { StatusPill(text: "Archive") }
                if entries.isEmpty {
                    EmptyState(symbol: "book.closed", title: search.isEmpty ? "A page is waiting" : "No matching entries", message: search.isEmpty ? "Add a manifestation, belief, or ritual with the plus button." : "Try another word or category.")
                }
                ForEach(entries) { entry in
                    NavigationLink { EntryDetailView(entryID: entry.id) } label: {
                        InvokeCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label(entry.kind.title, systemImage: entry.kind.symbol).font(.caption)
                                    Spacer()
                                    if entry.isExample { StatusPill(text: "Example") }
                                }.foregroundStyle(theme.secondary)
                                Text(entry.title.isEmpty ? "Untitled \(entry.kind.rawValue)" : entry.title)
                                    .font(.title3).fontDesign(.serif).multilineTextAlignment(.leading)
                                if let excerpt = entry.fields[entry.kind == .belief ? "belief" : entry.kind == .ritual ? "intention" : "desire"], !excerpt.isEmpty {
                                    Text(excerpt).font(.subheadline).foregroundStyle(theme.secondary).lineLimit(3).multilineTextAlignment(.leading)
                                }
                                HStack { StatusPill(text: entry.status); Spacer(); Image(systemName: "chevron.right").accessibilityHidden(true) }
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }.padding(20)
        }
        .navigationTitle("Grimoire")
        .searchable(text: $search, prompt: "Find words, intentions, practices")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showArchive.toggle() } label: {
                    Image(systemName: showArchive ? "tray.full.fill" : "archivebox")
                }.accessibilityLabel(showArchive ? "Show current entries" : "Show archived entries")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(EntryKind.allCases) { item in
                        Button { create(item) } label: { Label("New \(item.rawValue)", systemImage: item.symbol) }
                    }
                } label: { Image(systemName: "plus") }.accessibilityLabel("Add Grimoire entry")
            }
        }
        .navigationDestination(item: $createdEntry) { EntryDetailView(entryID: $0.id) }
        .invokeScreen()
    }

    private func create(_ kind: EntryKind) {
        var entry = LibraryEntry(kind: kind)
        entry.status = kind == .belief ? "Held" : "Active"
        store.data.entries.append(entry)
        createdEntry = LibrarySelection(id: entry.id)
    }
}

struct EntryDetailView: View {
    let entryID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false
    @State private var revisingBelief = false
    @State private var selectedLog: LibrarySelection?

    private var entry: LibraryEntry? { store.data.entries.first { $0.id == entryID } }
    private var logs: [RitualLog] { store.data.ritualLogs.filter { $0.ritualID == entryID }.sorted { $0.date > $1.date } }

    var body: some View {
        Group {
            if let entry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            SectionEyebrow(text: entry.kind.title)
                            Spacer()
                            if entry.isExample { StatusPill(text: "Example") }
                            if entry.archived { StatusPill(text: "Archived") }
                        }
                        TextField("Name this \(entry.kind.rawValue)", text: titleBinding, axis: .vertical)
                            .font(.largeTitle).fontDesign(.serif).accessibilityLabel("Entry title")
                        Picker("Status", selection: statusBinding) {
                            ForEach(entry.kind == .belief ? StoryCatalog.beliefStatuses : ["Active", "Resting", "Complete"], id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.menu)
                        entryFields(entry)
                        RecordConnectionsView(entryID: entryID)
                        if entry.kind == .belief { revisionHistory(entry) }
                        if entry.kind == .ritual { performances }
                        Text("Created \(entry.createdAt.formatted(date: .abbreviated, time: .omitted)). Changes save automatically.")
                            .font(.caption).foregroundStyle(theme.secondary)
                    }.padding(20)
                }.scrollDismissesKeyboard(.interactively)
            } else {
                EmptyState(symbol: "book.closed", title: "This page is no longer here", message: "The entry may have been removed or replaced by a restored backup.")
            }
        }
        .navigationTitle(entry?.kind.title ?? "Grimoire")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let entry {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(entry.archived ? "Restore from archive" : "Archive entry", systemImage: "archivebox") {
                            update { $0.archived.toggle() }
                        }
                        Button("Delete permanently", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                    } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("Entry actions")
                }
            }
        }
        .confirmationDialog("Permanently delete this entry?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete entry", role: .destructive) { store.deleteEntry(id: entryID); dismiss() }
        } message: { Text("Its revision history and ritual logs will also be removed. Linked stories and relics will remain. This cannot be undone.") }
        .sheet(item: $selectedLog) { selection in
            NavigationStack { RitualLogEditor(logID: selection.id) }.environment(\.invokeTheme, theme)
        }
        .onAppear {
            if entry?.kind == .belief && entry?.fields["belief", default: ""].isEmpty == true { revisingBelief = true }
        }
        .invokeScreen()
    }

    @ViewBuilder private func entryFields(_ entry: LibraryEntry) -> some View {
        switch entry.kind {
        case .manifestation:
            ProseField(title: "What I desire", text: field("desire"), prompt: "A future you want to move toward, in your own words.")
            ProseField(title: "Why it matters", text: field("why"))
            ProseField(title: "How I hope life will feel", text: field("feeling"))
            ProseField(title: "An ordinary day in that life", text: field("everyday"))
            ProseField(title: "Within my influence", text: field("influence"), prompt: "Choices, effort, and support you can draw on.")
            ProseField(title: "Signs of progress", text: field("progress"), prompt: "Meaningful changes, milestones, or a measurable goal.")
            ProseField(title: "Constraints and uncertainties", text: field("constraints"), prompt: "Leave room for circumstances and other people's choices.")
            ProseField(title: "Moments, signs, and coincidences", text: field("moments"), prompt: "Your observations and your interpretation belong here.")
        case .belief:
            if revisingBelief || entry.fields["belief", default: ""].isEmpty {
                ProseField(title: "The belief itself", text: field("belief"))
                if revisingBelief {
                    Label(entry.history.isEmpty ? "Your wording saves as you write." : "Earlier wording is preserved below. Your revision saves as you write.", systemImage: "clock.arrow.circlepath")
                        .font(.caption).foregroundStyle(theme.secondary)
                    Button("Finish revising") { revisingBelief = false }.buttonStyle(.bordered)
                }
            } else {
                InvokeCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionEyebrow(text: "The belief itself")
                        Text(entry.fields["belief", default: ""]).font(.title3).fontDesign(.serif)
                        Button("Preserve wording & revise", systemImage: "pencil.line") { beginBeliefRevision() }
                            .buttonStyle(.bordered)
                    }
                }
            }
            ProseField(title: "Where it came from", text: field("origin"))
            ProseField(title: "Why it matters", text: field("why"))
            ProseField(title: "How it affects my choices", text: field("choices"))
            ProseField(title: "What supports or complicates it", text: field("experiences"))
            ProseField(title: "An alternative I am exploring", text: field("alternative"))
            ProseField(title: "A small experiment", text: field("action"), prompt: "An action within your influence that could help you explore the alternative.")
        case .ritual:
            ProseField(title: "Intention", text: field("intention"))
            ProseField(title: "Materials", text: field("materials"), prompt: "Only what the practice actually needs.")
            TextField("For example, 5 minutes", text: field("duration"))
                .textFieldStyle(.roundedBorder).accessibilityLabel("Estimated duration")
            ProseField(title: "Opening words", text: field("opening"))
            ProseField(title: "Steps", text: field("steps"), prompt: "Give each step its own line. You can change this reusable practice any time.")
            ProseField(title: "Closing words", text: field("closing"))
        }
    }

    @ViewBuilder private func revisionHistory(_ entry: LibraryEntry) -> some View {
        if !entry.history.isEmpty {
            DisclosureGroup("Earlier wording · \(entry.history.count)") {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(entry.history.reversed()) { revision in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(revision.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(theme.secondary)
                            Text(revision.title).font(.headline)
                            Text(revision.fields["belief", default: ""])
                            StatusPill(text: revision.status)
                            DisclosureGroup("Full entry at this revision") {
                                ForEach(revision.fields.keys.sorted(), id: \.self) { key in
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(key.capitalized).font(.caption.weight(.semibold))
                                        Text(revision.fields[key, default: ""])
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5)
                                }
                            }
                        }
                        Divider()
                    }
                }.padding(.top, 16)
            }
        }
    }

    private var performances: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionEyebrow(text: "Practice journal")
            Text("The ritual is reusable. Each time you practice has its own record.").font(.subheadline).foregroundStyle(theme.secondary)
            Button("Record a practice", systemImage: "plus.circle") {
                let log = RitualLog(ritualID: entryID)
                store.data.ritualLogs.append(log)
                selectedLog = LibrarySelection(id: log.id)
            }.buttonStyle(.bordered)
            ForEach(logs) { log in
                Button { selectedLog = LibrarySelection(id: log.id) } label: {
                    InvokeCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(log.date.formatted(date: .abbreviated, time: .shortened)).font(.headline)
                            Text(log.notes.isEmpty ? "A practice, ready for reflection" : log.notes).lineLimit(3).foregroundStyle(theme.secondary)
                        }
                    }
                }.buttonStyle(.plain)
            }
        }
    }

    private var titleBinding: Binding<String> { Binding(get: { entry?.title ?? "" }, set: { value in update { $0.title = value } }) }
    private var statusBinding: Binding<String> { Binding(get: { entry?.status ?? "Active" }, set: { value in update { $0.status = value } }) }
    private func field(_ key: String) -> Binding<String> {
        Binding(get: { entry?.fields[key] ?? "" }, set: { value in update { $0.fields[key] = value } })
    }
    private func update(_ change: (inout LibraryEntry) -> Void) {
        guard let index = store.data.entries.firstIndex(where: { $0.id == entryID }) else { return }
        change(&store.data.entries[index])
        store.data.entries[index].updatedAt = Date()
    }
    private func beginBeliefRevision() {
        guard let entry else { return }
        update {
            $0.history.append(Revision(title: entry.title, fields: entry.fields, status: entry.status))
            $0.status = "Rewriting"
        }
        revisingBelief = true
    }
}

/// Relationships always refer to the shared record. Archived records remain connected.
struct RecordConnectionsView: View {
    var entryID: UUID? = nil
    var relicID: UUID? = nil
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionEyebrow(text: "Connections")
            DisclosureGroup("Stories") {
                if store.data.stories.isEmpty { Text("Create a story to connect this page.").font(.subheadline).foregroundStyle(theme.secondary) }
                ForEach(store.data.stories.filter { !$0.archived || storyLinked($0) }) { story in
                    Toggle(isOn: storyBinding(story.id)) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(story.title)
                            if story.archived { Text("Archived").font(.caption).foregroundStyle(theme.secondary) }
                        }
                    }.padding(.vertical, 6)
                }
            }
            DisclosureGroup("Grimoire entries") {
                let choices = store.data.entries.filter { $0.id != entryID && (!$0.archived || entryLinked($0.id)) }
                if choices.isEmpty { Text("Add another Grimoire entry to make a connection.").font(.subheadline).foregroundStyle(theme.secondary) }
                ForEach(choices) { entry in
                    Toggle(isOn: entryBinding(entry.id)) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.title.isEmpty ? "Untitled \(entry.kind.rawValue)" : entry.title)
                            Text(entry.kind.title + (entry.archived ? " · Archived" : "")).font(.caption).foregroundStyle(theme.secondary)
                        }
                    }.padding(.vertical, 6)
                }
            }
            if let entryID {
                DisclosureGroup("Relics") {
                    let relics = store.data.relics.filter { !$0.archived || $0.entryIDs.contains(entryID) }
                    if relics.isEmpty { Text("A relic can hold this intention in the world.").font(.subheadline).foregroundStyle(theme.secondary) }
                    ForEach(relics) { relic in
                        Toggle(relic.name + (relic.archived ? " · Archived" : ""), isOn: Binding(get: {
                            store.data.relics.first { $0.id == relic.id }?.entryIDs.contains(entryID) ?? false
                        }, set: { connected in
                            guard let index = store.data.relics.firstIndex(where: { $0.id == relic.id }) else { return }
                            if connected { if !store.data.relics[index].entryIDs.contains(entryID) { store.data.relics[index].entryIDs.append(entryID) } }
                            else { store.data.relics[index].entryIDs.removeAll { $0 == entryID } }
                            store.data.relics[index].updatedAt = Date()
                        })).padding(.vertical, 6)
                    }
                }
            }
        }
    }

    private func storyLinked(_ story: Story) -> Bool {
        if let entryID { return story.entryIDs.contains(entryID) }
        if let relicID { return story.relicIDs.contains(relicID) }
        return false
    }
    private func storyBinding(_ id: UUID) -> Binding<Bool> {
        Binding(get: { store.data.stories.first(where: { $0.id == id }).map(storyLinked) ?? false }, set: { connected in
            guard let index = store.data.stories.firstIndex(where: { $0.id == id }) else { return }
            if let entryID {
                if connected { if !store.data.stories[index].entryIDs.contains(entryID) { store.data.stories[index].entryIDs.append(entryID) } }
                else { store.data.stories[index].entryIDs.removeAll { $0 == entryID } }
            }
            if let relicID {
                if connected { if !store.data.stories[index].relicIDs.contains(relicID) { store.data.stories[index].relicIDs.append(relicID) } }
                else { store.data.stories[index].relicIDs.removeAll { $0 == relicID } }
            }
            store.data.stories[index].updatedAt = Date()
        })
    }
    private func entryLinked(_ id: UUID) -> Bool {
        if let entryID { return store.data.entries.first { $0.id == entryID }?.linkedEntryIDs.contains(id) ?? false }
        if let relicID { return store.data.relics.first { $0.id == relicID }?.entryIDs.contains(id) ?? false }
        return false
    }
    private func entryBinding(_ id: UUID) -> Binding<Bool> {
        Binding(get: { entryLinked(id) }, set: { connected in
            if let entryID, let index = store.data.entries.firstIndex(where: { $0.id == entryID }) {
                if connected { if !store.data.entries[index].linkedEntryIDs.contains(id) { store.data.entries[index].linkedEntryIDs.append(id) } }
                else { store.data.entries[index].linkedEntryIDs.removeAll { $0 == id } }
                store.data.entries[index].updatedAt = Date()
                if let other = store.data.entries.firstIndex(where: { $0.id == id }) {
                    if connected { if !store.data.entries[other].linkedEntryIDs.contains(entryID) { store.data.entries[other].linkedEntryIDs.append(entryID) } }
                    else { store.data.entries[other].linkedEntryIDs.removeAll { $0 == entryID } }
                    store.data.entries[other].updatedAt = Date()
                }
            }
            if let relicID, let index = store.data.relics.firstIndex(where: { $0.id == relicID }) {
                if connected { if !store.data.relics[index].entryIDs.contains(id) { store.data.relics[index].entryIDs.append(id) } }
                else { store.data.relics[index].entryIDs.removeAll { $0 == id } }
                store.data.relics[index].updatedAt = Date()
            }
        })
    }
}

private struct RitualLogEditor: View {
    let logID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false
    private var log: RitualLog? { store.data.ritualLogs.first { $0.id == logID } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if log != nil {
                    DatePicker("Practiced on", selection: Binding(get: { log?.date ?? Date() }, set: { value in update { $0.date = value } }))
                    ProseField(title: "What I did", text: Binding(get: { log?.notes ?? "" }, set: { value in update { $0.notes = value } }))
                    ProseField(title: "What I noticed", text: Binding(get: { log?.reflection ?? "" }, set: { value in update { $0.reflection = value } }), prompt: "How did the practice meet you today?")
                    Text("This record saves automatically. Your reusable ritual stays available.").font(.caption)
                    Button("Delete this practice record", role: .destructive) { confirmingDelete = true }.buttonStyle(.bordered)
                } else {
                    EmptyState(symbol: "flame", title: "Record unavailable", message: "It may have been removed.")
                }
            }.padding(20)
        }
        .navigationTitle("Practice journal").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .confirmationDialog("Delete this practice record?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete permanently", role: .destructive) { store.data.ritualLogs.removeAll { $0.id == logID }; dismiss() }
        } message: { Text("The ritual remains. This practice record cannot be recovered.") }
        .invokeScreen()
    }

    private func update(_ change: (inout RitualLog) -> Void) {
        guard let index = store.data.ritualLogs.firstIndex(where: { $0.id == logID }) else { return }
        change(&store.data.ritualLogs[index])
        store.data.ritualLogs[index].updatedAt = Date()
    }
}
