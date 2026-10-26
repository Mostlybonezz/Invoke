import SwiftUI

enum ChronicleCategory: String, CaseIterable, Identifiable {
    case actions, reflections, arcana, echoes, assets, invocations, revisions, events, unrecorded
    var id: String { rawValue }
    var title: String { self == .unrecorded ? "Not recorded" : rawValue.capitalized }
    var symbol: String {
        switch self {
        case .actions: "checkmark.seal"; case .reflections: "text.book.closed"; case .arcana: "moon.stars"
        case .echoes: "link"; case .assets: "shippingbox"; case .invocations: "sparkles"
        case .revisions: "clock.arrow.circlepath"; case .events: "calendar.badge.clock"; case .unrecorded: "circle.dashed"
        }
    }
}

struct ChronicleItem: Identifiable {
    var id: String
    var date: Date
    var category: ChronicleCategory
    var title: String
    var summary: String
    var route: String
    var recordID: UUID
    var contextID: UUID? = nil
    var undone = false
    var occurrence: PracticeOccurrence? = nil
    var timeZoneID: String? = nil
    var actionKind: ActionKind? = nil
}

/// A read-only projection of canonical records; viewing the Chronicle creates no credit.
enum ChronicleTimeline {
    static func items(data: AppData, range: DateInterval, practiceID: UUID? = nil) -> [ChronicleItem] {
        let grimoire = data.grimoire
        let practice = grimoire.practices.first { $0.id == practiceID }
        let reversed = Set(grimoire.actions.compactMap(\.reversesActionID))
        let titles = Dictionary(uniqueKeysWithValues: grimoire.practices.map { ($0.id, $0.title) })
        func contains(_ date: Date) -> Bool { date >= range.start && date < range.end }
        var items: [ChronicleItem] = []
        for action in grimoire.actions where contains(action.occurredAt) && (practiceID == nil || action.practiceID == practiceID) {
            let title = action.titleSnapshot.isEmpty ? titles[action.practiceID] ?? "Practice record" : action.titleSnapshot
            let state = reversed.contains(action.id) ? "Undone · \(action.kind.title)" : action.kind.title
            items.append(ChronicleItem(id: "action:\(action.id)", date: action.occurredAt, category: .actions, title: title,
                                       summary: state + (action.notes.isEmpty ? "" : " · " + action.notes), route: "action", recordID: action.id,
                                       contextID: action.practiceID, undone: reversed.contains(action.id), timeZoneID: action.timeZoneID, actionKind: action.kind))
        }
        for record in grimoire.arcana where contains(record.occurredAt ?? record.createdAt) && practiceID == nil {
            let summary = record.kind + " · " + record.beliefStatus + (record.observedResult.isEmpty ? "" : " · " + record.observedResult)
            items.append(ChronicleItem(id: "arcana:\(record.id)", date: record.occurredAt ?? record.createdAt,
                                       category: record.kind == "Reflection" ? .reflections : .arcana, title: record.title,
                                       summary: summary, route: "arcana", recordID: record.id))
        }
        for record in grimoire.echoes where contains(record.createdAt) && practiceID == nil {
            items.append(ChronicleItem(id: "echo:\(record.id)", date: record.createdAt, category: .echoes,
                                       title: record.title, summary: record.similarities + " · Differences: " + record.differences,
                                       route: "echo", recordID: record.id))
        }
        for asset in grimoire.assets where practiceID == nil || asset.id == practice?.assetID {
            for inspection in asset.inspections where contains(inspection.date) {
                items.append(ChronicleItem(id: "inspection:\(inspection.id)", date: inspection.date, category: .assets,
                                           title: asset.name, summary: inspection.condition + (inspection.notes.isEmpty ? "" : " · " + inspection.notes),
                                           route: "asset", recordID: asset.id, contextID: inspection.id))
            }
        }
        for invocation in grimoire.invocations where practiceID == nil || invocation.id == practice?.invocationID {
            for observation in invocation.observations where contains(observation.observedAt) {
                let measure = observation.measurement.map { " · \($0.formatted()) \(observation.unit)" } ?? ""
                items.append(ChronicleItem(id: "outcome:\(observation.id)", date: observation.observedAt, category: .invocations,
                                           title: invocation.title, summary: "Observed outcome · " + observation.text + measure,
                                           route: "invocation", recordID: invocation.id, contextID: observation.id))
            }
            for milestone in invocation.milestones {
                if let date = milestone.completedAt, contains(date) {
                    items.append(ChronicleItem(id: "milestone:\(milestone.id)", date: date, category: .invocations,
                                               title: milestone.title, summary: "Milestone recorded · " + invocation.title,
                                               route: "invocation", recordID: invocation.id, contextID: milestone.id))
                }
            }
        }
        for revision in grimoire.revisions where contains(revision.changedAt) {
            let linked = practiceID == nil || revision.recordID == practiceID || revision.recordID == practice?.assetID
                || revision.recordID == practice?.invocationID || practice?.spellIDs.contains(revision.recordID) == true
            if linked {
                items.append(ChronicleItem(id: "revision:\(revision.id)", date: revision.changedAt, category: .revisions,
                                           title: revision.title, summary: revision.summary, route: "revision", recordID: revision.id))
            }
        }
        for event in grimoire.events where contains(event.occurredAt) && practiceID == nil {
            items.append(ChronicleItem(id: "event:\(event.id)", date: event.occurredAt, category: .events,
                                       title: event.name, summary: event.notes, route: "event", recordID: event.id, timeZoneID: event.timeZoneID))
        }
        for reflection in data.reflections where contains(reflection.createdAt) {
            let linked = practiceID == nil || (practice?.legacySceneID != nil && reflection.sceneID == practice?.legacySceneID)
            if linked {
                items.append(ChronicleItem(id: "legacy-reflection:\(reflection.id)", date: reflection.createdAt, category: .reflections,
                                           title: reflection.kind, summary: reflection.text, route: "legacyReflection", recordID: reflection.id))
            }
        }
        for log in data.ritualLogs where contains(log.date) && (practiceID == nil || log.ritualID == practice?.legacyEntryID) {
            let title = data.entries.first { $0.id == log.ritualID }?.title ?? "Original ritual"
            items.append(ChronicleItem(id: "legacy-ritual:\(log.id)", date: log.date, category: .actions,
                                       title: title, summary: "Original ritual log · " + log.notes + (log.reflection.isEmpty ? "" : " · " + log.reflection),
                                       route: "legacyRitual", recordID: log.ritualID, contextID: log.id))
        }
        return items.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date > $1.date }
    }
}

struct ChronicleView: View {
    var practiceID: UUID? = nil
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @State private var search = ""
    @State private var category = "all"
    @State private var period = "30 days"
    @State private var from = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var through = Date()
    @State private var showUnrecorded = false
    @State private var pageSize = 100

    private var calendar: Calendar { GrimoirePresentation.calendar(store.data.grimoire.settings) }
    private var range: DateInterval {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: period == "Custom" ? through : Date())) ?? Date()
        let start: Date
        switch period {
        case "7 days": start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
        case "Year": start = calendar.date(byAdding: .year, value: -1, to: end) ?? end
        case "All recorded": start = Date.distantPast
        case "Custom": start = min(calendar.startOfDay(for: from), end.addingTimeInterval(-1))
        default: start = calendar.date(byAdding: .day, value: -30, to: end) ?? end
        }
        return DateInterval(start: start, end: max(start, end))
    }
    private var items: [ChronicleItem] {
        var result = ChronicleTimeline.items(data: store.data, range: range, practiceID: practiceID)
        if showUnrecorded && period != "All recorded" {
            let boundedStart = max(range.start, calendar.date(byAdding: .year, value: -1, to: range.end) ?? range.start)
            let boundedRange = DateInterval(start: boundedStart, end: range.end)
            let occurrences = store.grimoireOccurrences(in: boundedRange).filter {
                (practiceID == nil || $0.practiceID == practiceID) && $0.availableAt <= Date()
                && store.occurrenceStatus($0) == .unrecorded
            }
            for occurrence in occurrences {
                result.append(ChronicleItem(id: "unrecorded:\(occurrence.id)", date: occurrence.availableAt,
                                            category: .unrecorded, title: occurrence.title,
                                            summary: "No action recorded for this opportunity. It is not a recorded skip or failure.",
                                            route: "occurrence", recordID: occurrence.practiceID, occurrence: occurrence, timeZoneID: occurrence.timeZoneID))
            }
        }
        return result.filter {
            (category == "all" || $0.category.rawValue == category)
            && (search.isEmpty || ($0.title + " " + $0.summary + " " + $0.category.title).localizedCaseInsensitiveContains(search))
        }.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date > $1.date }
    }
    var body: some View {
        let filtered = items
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text("What was recorded. What changed.").font(.title2).fontDesign(.serif)
                Text("Actions and observed outcomes are separate. Undo keeps the original record with its correction.").foregroundStyle(theme.secondary)
                filters
                Text("\(filtered.count) matching entries · \(min(pageSize, filtered.count)) shown").font(.caption).foregroundStyle(theme.secondary)
                    .accessibilityIdentifier("chronicle-count")
                if filtered.isEmpty {
                    EmptyState(symbol: "text.book.closed", title: "No matching entries", message: "Choose another date range or record a reflection. An empty history makes no claim about what happened in your life.")
                }
                ForEach(Array(filtered.prefix(pageSize).enumerated()), id: \.element.id) { index, item in
                    if index == 0 || dayKey(item) != dayKey(filtered[index - 1]) {
                        Text(GrimoireHistoryDate.string(item.date, zoneID: item.timeZoneID ?? calendar.timeZone.identifier)).font(.headline).padding(.top, 8)
                    }
                    NavigationLink { destination(item) } label: {
                        GrimoireRecordRow(title: item.title, subtitle: item.summary, symbol: item.category.symbol,
                                          status: item.undone ? "Undone · original retained" : item.actionKind == .correction ? "Correction" : item.category.title)
                    }.buttonStyle(.plain).accessibilityIdentifier("chronicle-\(item.id)")
                }
                if filtered.count > pageSize { Button("Show 100 more") { pageSize += 100 }.frame(minHeight: 44) }
            }.padding(20).accessibilityIdentifier("chronicle-list")
        }
        .navigationTitle("Chronicle")
        .searchable(text: $search, prompt: "Search your recorded history")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink { ChronicleReflectionEditorView() } label: { Image(systemName: "square.and.pencil") }.accessibilityLabel("Record a reflection") } }
        .onChange(of: search) { _, _ in pageSize = 100 }
        .onChange(of: category) { _, _ in pageSize = 100 }
        .onChange(of: period) { _, _ in pageSize = 100 }
        .onChange(of: from) { _, value in if through < value { through = value } }
        .invokeScreen()
    }
    private func dayKey(_ item: ChronicleItem) -> String {
        LocalDay(item.date, timeZone: item.timeZoneID.flatMap(TimeZone.init(identifier:)) ?? calendar.timeZone).description
    }
    private var filters: some View {
        DisclosureGroup("Dates and record types") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Date range", selection: $period) {
                    ForEach(["7 days", "30 days", "Year", "All recorded", "Custom"], id: \.self) { Text($0).tag($0) }
                }
                if period == "Custom" {
                    DatePicker("From", selection: $from, displayedComponents: .date)
                    DatePicker("Through", selection: $through, in: from..., displayedComponents: .date)
                }
                Picker("Record type", selection: $category) {
                    Text("All types").tag("all")
                    ForEach(ChronicleCategory.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Toggle("Include opportunities with no record", isOn: $showUnrecorded).disabled(period == "All recorded")
                if showUnrecorded {
                    Text("Unrecorded opportunities are a calendar view of retained definitions, not invented events. This optional view is bounded to one year; select a date range to explore it.").font(.footnote).foregroundStyle(theme.secondary)
                }
            }.padding(.vertical, 8)
        }
    }
    @ViewBuilder private func destination(_ item: ChronicleItem) -> some View {
        switch item.route {
        case "action": ChronicleActionDetailView(actionID: item.recordID)
        case "asset": CareAssetDetailView(assetID: item.recordID)
        case "invocation": InvocationDetailView(invocationID: item.recordID)
        case "legacyReflection": ReflectionEditorView(reflectionID: item.recordID)
        case "legacyRitual": EntryDetailView(entryID: item.recordID)
        case "arcana":
            if let value = store.data.grimoire.arcana.first(where: { $0.id == item.recordID }) { ArcanaEditorView(draft: value) }
        case "echo":
            if let value = store.data.grimoire.echoes.first(where: { $0.id == item.recordID }) { EchoEditorView(draft: value) }
        case "revision": ChronicleRevisionView(revisionID: item.recordID)
        case "occurrence":
            if let occurrence = item.occurrence { OccurrenceDetailView(occurrence: occurrence) }
        case "event":
            if let value = store.data.grimoire.events.first(where: { $0.id == item.recordID }) {
                ScrollView { VStack(alignment: .leading, spacing: 20) {
                    Text(value.name).font(.title).fontDesign(.serif)
                    Text(GrimoireHistoryDate.string(value.occurredAt, zoneID: value.timeZoneID, includeTime: true))
                    Text("Recorded time zone: \(value.timeZoneID)").font(.caption)
                    Text(value.notes).textSelection(.enabled)
                }.padding(20) }.navigationTitle("Recorded event").invokeScreen()
            }
        default: EmptyState(symbol: "book", title: "Record unavailable", message: "Return to the Chronicle to choose another entry.")
        }
    }
}

struct ChronicleActionDetailView: View {
    let actionID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @State private var feedback = ""
    private var action: ActionRecord? { store.data.grimoire.actions.first { $0.id == actionID } }
    private var undone: Bool { store.data.grimoire.actions.contains { $0.reversesActionID == actionID } }
    var body: some View {
        Group {
            if let action {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(action.titleSnapshot.isEmpty ? "Practice record" : action.titleSnapshot).font(.largeTitle).fontDesign(.serif)
                        StatusPill(text: undone ? "Undone · original retained" : action.kind.title)
                        if undone { Text("Correction").font(.headline).accessibilityIdentifier("chronicle-correction") }
                        InvokeCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Occurred: \(GrimoireHistoryDate.string(action.occurredAt, zoneID: action.timeZoneID, includeTime: true))")
                                Text("Recorded: \(GrimoireHistoryDate.string(action.recordedAt, zoneID: action.timeZoneID, includeTime: true))")
                                Text("Event time zone: \(action.timeZoneID)").font(.caption)
                                GrimoireDetailText(title: "Notes", text: action.notes)
                                if let measure = action.measurement { Text("User-recorded measure: \(measure.formatted()) \(action.measurementUnit)") }
                                if let target = action.targetDate { Text("Recorded target: \(target.formatted(date: .abbreviated, time: .shortened))") }
                                if let originalID = action.reversesActionID {
                                    NavigationLink("View the original record") { ChronicleActionDetailView(actionID: originalID) }
                                }
                            }
                        }
                        if let occurrence = store.data.grimoire.occurrences.first(where: { $0.id == action.occurrenceID }) {
                            if !action.completedStepIDs.isEmpty {
                                GrimoireDetailText(title: "Steps recorded in this action", text: occurrence.steps.filter { action.completedStepIDs.contains($0.id) }.map(\.title).joined(separator: "\n"))
                            }
                            NavigationLink("Open the occurrence") { OccurrenceDetailView(occurrence: occurrence) }
                        }
                        NavigationLink("Open the practice") { PracticeDetailView(practiceID: action.practiceID) }
                        if action.kind != .correction && !undone {
                            Button("Undo this record") {
                                do { try store.undoAction(action.id); feedback = "Correction saved. The original record remains visible." }
                                catch { store.errorMessage = error.localizedDescription }
                            }.frame(minHeight: 44).accessibilityIdentifier("chronicle-undo")
                            Text("Undo removes this record’s effect on progress. It retains the record and adds a dated correction.").font(.footnote).foregroundStyle(theme.secondary)
                        }
                        SavedFeedback(message: feedback)
                    }.padding(20)
                }
            } else { EmptyState(symbol: "book", title: "Record unavailable", message: "This record is no longer available in the current data.") }
        }.navigationTitle("Action record").navigationBarTitleDisplayMode(.inline).invokeScreen()
    }
}

enum GrimoireHistoryDate {
    static func string(_ date: Date, zoneID: String, includeTime: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = includeTime ? .short : .none
        formatter.timeZone = TimeZone(identifier: zoneID) ?? .current
        return formatter.string(from: date)
    }
}

struct ChronicleReflectionEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = "Reflection"
    @State private var text = ""
    @State private var date = Date()
    @State private var recordID = UUID()
    var body: some View {
        Form {
            Section("A sentence is enough") {
                TextField("Title", text: $title)
                GrimoireTextField(label: "Your reflection", text: $text, lines: 6, identifier: "chronicle-reflection-text")
                DatePicker("Reflection date", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
            }
            Section { Text("This is a private observation, not a task completion. You can find and revise it in Chronicle or Grimoire → Arcana.").font(.footnote) }
        }.navigationTitle("Record a reflection")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save") {
            var value = ArcanaRecord()
            value.id = recordID
            value.title = title.isEmpty ? "Reflection" : title; value.kind = "Reflection"
            value.observedResult = text; value.occurredAt = date
            do { try store.saveArcana(value); dismiss() } catch { store.errorMessage = error.localizedDescription }
        }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("chronicle-reflection-save") } }
        .invokeScreen()
    }
}

struct ChronicleRevisionView: View {
    let revisionID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    private var revision: GrimoireRevision? { store.data.grimoire.revisions.first { $0.id == revisionID } }
    var body: some View {
        ScrollView {
            if let revision {
                VStack(alignment: .leading, spacing: 20) {
                    Text(revision.title).font(.title).fontDesign(.serif)
                    Text(revision.summary).font(.headline)
                    Text(revision.changedAt.formatted(date: .complete, time: .shortened)).foregroundStyle(theme.secondary)
                    Text("This preserved revision is read-only. Open the current record to make another change.").font(.footnote)
                    currentRecord(revision)
                    DisclosureGroup("Before this change") { snapshot(revision.before) }
                    DisclosureGroup("After this change") { snapshot(revision.after) }
                }.padding(20)
            } else { EmptyState(symbol: "clock.arrow.circlepath", title: "Revision unavailable", message: "This revision is no longer available in the current data.") }
        }.navigationTitle("Preserved revision").invokeScreen()
    }
    @ViewBuilder private func currentRecord(_ revision: GrimoireRevision) -> some View {
        if store.data.grimoire.practices.contains(where: { $0.id == revision.recordID }) {
            NavigationLink("Open current practice") { PracticeDetailView(practiceID: revision.recordID) }
        } else if let value = store.data.grimoire.arcana.first(where: { $0.id == revision.recordID }) {
            NavigationLink("Open current Arcana record") { ArcanaEditorView(draft: value) }
        } else if let value = store.data.grimoire.echoes.first(where: { $0.id == revision.recordID }) {
            NavigationLink("Open current Echo") { EchoEditorView(draft: value) }
        } else if store.data.grimoire.assets.contains(where: { $0.id == revision.recordID }) {
            NavigationLink("Open current asset") { CareAssetDetailView(assetID: revision.recordID) }
        } else if store.data.grimoire.invocations.contains(where: { $0.id == revision.recordID }) {
            NavigationLink("Open current Invocation") { InvocationDetailView(invocationID: revision.recordID) }
        } else if let value = store.data.grimoire.spells.first(where: { $0.id == revision.recordID }) {
            NavigationLink("Open current method") { SpellEditorView(draft: value) }
        } else if let value = store.data.grimoire.enchantments.first(where: { $0.id == revision.recordID }) {
            NavigationLink("Open current arrangement") { EnchantmentEditorView(draft: value) }
        }
    }
    @ViewBuilder private func snapshot(_ data: Data) -> some View {
        if let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(value.keys.sorted().filter(showSnapshotField), id: \.self) { key in
                    if let text = humanValue(value[key], key: key), !text.isEmpty {
                        GrimoireDetailText(title: readableKey(key), text: text)
                    }
                }
            }.padding(.top, 12)
        } else { Text("The original snapshot is preserved in your export; this view cannot display its format.").font(.footnote) }
    }
    private func showSnapshotField(_ key: String) -> Bool {
        !["id", "createdAt", "updatedAt"].contains(key)
            && (!key.hasSuffix("ID") && !key.hasSuffix("IDs") || key == "sourceIDs")
    }
    private func humanValue(_ value: Any?, key: String = "") -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber {
            if ["occurredAt", "observedAt", "completedAt", "changedAt", "purchasedAt", "installedAt", "expiresAt", "reviewDate", "reserveTargetDate", "effectiveFrom", "lastActualCompletion", "startedAt", "endedAt", "date"].contains(key) {
                return Date(timeIntervalSince1970: value.doubleValue / 1000).formatted(date: .abbreviated, time: .shortened)
            }
            return String(cString: value.objCType) == "c" ? (value.boolValue ? "Yes" : "No") : value.stringValue
        }
        if let list = value as? [String] { return list.joined(separator: "\n") }
        if let list = value as? [[String: Any]] {
            return list.compactMap { row in
                let words = [row["title"], row["text"], row["notes"], row["instructions"]].compactMap { $0 as? String }.filter { !$0.isEmpty }
                return words.isEmpty ? nil : words.joined(separator: " · ")
            }.joined(separator: "\n")
        }
        if let dictionary = value as? [String: Any] {
            if let year = dictionary["year"] as? Int, let month = dictionary["month"] as? Int, let day = dictionary["day"] as? Int {
                return LocalDay(year: year, month: month, day: day).description
            }
            return dictionary.keys.sorted().filter(showSnapshotField).compactMap { key in humanValue(dictionary[key], key: key).map { "\(readableKey(key)): \($0)" } }.joined(separator: "\n")
        }
        return nil
    }
    private func readableKey(_ value: String) -> String {
        value.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized
    }
}
