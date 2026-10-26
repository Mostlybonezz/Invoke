import SwiftUI

struct SpellEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Spell
    init(draft: Spell) { _draft = State(initialValue: draft) }
    var body: some View {
        Form {
            Group {
                Section("Saved technique") {
                    TextField("Name", text: $draft.title).accessibilityIdentifier("spell-title")
                    TextField("Plain-language name", text: $draft.plainTitle)
                    DisciplinePicker(value: $draft.discipline)
                    GrimoireTextField(label: "Purpose", text: $draft.purpose)
                }
                Section("Method and provenance") {
                    GrimoireTextField(label: "Steps or method", text: $draft.method, lines: 5, identifier: "spell-method")
                    GrimoireTextField(label: "Origin, source or reference", text: $draft.source)
                    GrimoireTextField(label: "Your notes", text: $draft.notes)
                }
            }.disabled(draft.archived)
            Section("Practices using this method") {
                let linked = store.data.grimoire.practices.filter { $0.spellIDs.contains(draft.id) }
                if linked.isEmpty { Text("Link this method from a practice’s Connections section.").font(.footnote) }
                ForEach(linked) { practice in
                    NavigationLink(practice.title) { PracticeDetailView(practiceID: practice.id) }
                }
            }
            if store.data.grimoire.spells.contains(where: { $0.id == draft.id }) {
                archiveSection(archived: draft.archived) { changeArchive() }
            }
            recordDates(created: draft.createdAt, updated: draft.updatedAt)
        }
        .navigationTitle(draft.archived ? "Archived method" : "Spell & method")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(draft.archived || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("spell-save") } }
        .invokeScreen()
    }
    private func save() {
        do { try store.saveSpell(draft); dismiss() } catch { store.errorMessage = error.localizedDescription }
    }
    private func changeArchive() {
        var value = draft; value.archived.toggle()
        do { try store.saveSpell(value); dismiss() } catch { store.errorMessage = error.localizedDescription }
    }
}

struct EnchantmentEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Enchantment
    init(draft: Enchantment) { _draft = State(initialValue: draft) }
    var body: some View {
        Form {
            Group {
                Section("An arrangement that supports you") {
                    TextField("Name", text: $draft.title).accessibilityIdentifier("enchantment-title")
                    GrimoireTextField(label: "What this supports", text: $draft.supports)
                    Picker("Status", selection: $draft.status) {
                        ForEach(["Planned", "Established", "Needs attention", "Retired"], id: \.self) { Text($0).tag($0) }
                    }
                    GrimoireTextField(label: "What was established or observed", text: $draft.establishmentEvidence)
                    Text("A saved confirmation is your own record. Invoke does not verify an external payment, backup or service automatically.").font(.footnote)
                }
                Section("Connections and upkeep") {
                    Picker("Linked Invocation", selection: $draft.invocationID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(store.data.grimoire.invocations.filter { !$0.archived }) { Text($0.title).tag(Optional($0.id)) }
                    }
                    Picker("Maintenance practice", selection: $draft.maintenancePracticeID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(store.data.grimoire.practices.filter { !$0.archived }) { Text($0.title).tag(Optional($0.id)) }
                    }
                    OptionalDateField(title: "Choose a review date", date: $draft.reviewDate)
                    GrimoireTextField(label: "Notes", text: $draft.notes)
                }
            }.disabled(draft.archived)
            if let id = draft.maintenancePracticeID {
                Section { NavigationLink("Open maintenance practice") { PracticeDetailView(practiceID: id) } }
            }
            if store.data.grimoire.enchantments.contains(where: { $0.id == draft.id }) {
                archiveSection(archived: draft.archived) { changeArchive() }
            }
            recordDates(created: draft.createdAt, updated: draft.updatedAt)
        }
        .navigationTitle(draft.archived ? "Archived arrangement" : "Enchantment")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(draft.archived || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("enchantment-save") } }
        .invokeScreen()
    }
    private func save() {
        do { try store.saveEnchantment(draft); dismiss() } catch { store.errorMessage = error.localizedDescription }
    }
    private func changeArchive() {
        var value = draft; value.archived.toggle()
        do { try store.saveEnchantment(value); dismiss() } catch { store.errorMessage = error.localizedDescription }
    }
}

struct CareAssetEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CareAsset
    init(draft: CareAsset) { _draft = State(initialValue: draft) }
    var body: some View {
        Form {
            Group {
                Section("Only what is useful to track") {
                    TextField("Name", text: $draft.name).accessibilityIdentifier("asset-name")
                    TextField("Category", text: $draft.category)
                    DisciplinePicker(value: $draft.discipline)
                    Picker("Resource kind", selection: $draft.resourceKind) {
                        ForEach(["Consumable", "Wear item", "Durable asset", "Living system or obligation"], id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Responsible person", text: $draft.responsiblePerson)
                }
                Section("Care and condition") {
                    LabeledContent("Recorded condition", value: draft.condition)
                    GrimoireTextField(label: "Care instructions and source", text: $draft.careInstructions)
                    GrimoireTextField(label: "Repair or replacement criteria", text: $draft.replacementCriteria)
                    Text("Record a condition observation from the asset page. Age alone does not create a replacement task.").font(.footnote)
                }
                Section("Known dates only") {
                    OptionalDateField(title: "Purchase date is known", date: $draft.purchasedAt)
                    OptionalDateField(title: "Installation date is known", date: $draft.installedAt)
                    OptionalDateField(title: "Labeled expiry or end of service is known", date: $draft.expiresAt)
                    Text("Leave unknown dates off. Use actual labeled or authoritative dates, not a guessed lifespan.").font(.footnote)
                }
                Section("Optional supply quantities") {
                    OptionalNumberField(title: "Quantity", number: $draft.quantity)
                    TextField("Unit, such as bottles or pairs", text: $draft.quantityUnit)
                    OptionalNumberField(title: "Consider replenishment below", number: $draft.replenishBelow)
                    Text("This is a review threshold; it does not purchase supplies or claim an automatic stock count.").font(.footnote)
                }
                Section("Optional replacement reserve") {
                    OptionalNumberField(title: "Estimated target cost", number: $draft.estimatedCost)
                    OptionalNumberField(title: "Amount already reserved", number: $draft.reservedAmount)
                    if let cost = draft.estimatedCost, let reserved = draft.reservedAmount {
                        LabeledContent("Remaining target", value: max(0, cost - reserved).formatted(.number.precision(.fractionLength(0...2))))
                    }
                    OptionalDateField(title: "Choose a reserve target date", date: $draft.reserveTargetDate)
                    Text("Use the same currency for both amounts. Remaining target is simply estimated cost minus the amount you entered as reserved.").font(.footnote)
                }
                Section { GrimoireTextField(label: "Notes", text: $draft.notes) }
            }.disabled(draft.archived)
            if store.data.grimoire.assets.contains(where: { $0.id == draft.id }) {
                archiveSection(archived: draft.archived) { changeArchive() }
            }
        }
        .navigationTitle(draft.archived ? "Archived asset" : "Asset & supply")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(draft.archived || draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("asset-save") } }
        .invokeScreen()
    }
    private func save() {
        do { try store.saveAsset(draft); dismiss() } catch { store.errorMessage = error.localizedDescription }
    }
    private func changeArchive() {
        var value = draft; value.archived.toggle()
        do { try store.saveAsset(value); dismiss() } catch { store.errorMessage = error.localizedDescription }
    }
}

struct CareAssetDetailView: View {
    let assetID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    private var asset: CareAsset? { store.data.grimoire.assets.first { $0.id == assetID } }
    var body: some View {
        Group {
            if let asset {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(asset.name).font(.largeTitle).fontDesign(.serif)
                        StatusPill(text: asset.archived ? "Archived" : asset.condition)
                        if !asset.archived {
                            NavigationLink { AssetInspectionEditorView(assetID: asset.id) } label: {
                                Label("Record a condition observation", systemImage: "checklist").frame(minHeight: 44)
                            }.accessibilityIdentifier("asset-inspect")
                        }
                        InvokeCard {
                            VStack(alignment: .leading, spacing: 16) {
                                GrimoireDetailText(title: "Kind", text: asset.resourceKind)
                                GrimoireDetailText(title: "Care", text: asset.careInstructions)
                                GrimoireDetailText(title: "Replacement criteria", text: asset.replacementCriteria)
                                GrimoireDetailText(title: "Responsibility", text: asset.responsiblePerson)
                                Text("Purchase: \(asset.purchasedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")")
                                Text("Installed: \(asset.installedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")")
                                if let expiry = asset.expiresAt { Text("Recorded expiry/end of service: \(expiry.formatted(date: .abbreviated, time: .omitted))") }
                                if let quantity = asset.quantity { Text("Quantity: \(quantity.formatted()) \(asset.quantityUnit)") }
                                if let threshold = asset.replenishBelow, let quantity = asset.quantity, quantity < threshold {
                                    Label("Below your replenishment review threshold", systemImage: "shippingbox").foregroundStyle(theme.accent)
                                }
                                if let cost = asset.estimatedCost, let reserve = asset.reservedAmount {
                                    Text("Reserve target remaining: \(max(0, cost - reserve).formatted(.number.precision(.fractionLength(0...2))))")
                                }
                                GrimoireDetailText(title: "Notes", text: asset.notes)
                            }
                        }
                        if !asset.archived {
                            NavigationLink { PracticeEditorView(draft: careDraft(asset)) } label: {
                                Label("Configure a care or inspection practice", systemImage: "calendar.badge.plus").frame(minHeight: 44)
                            }
                        }
                        let linked = store.data.grimoire.practices.filter { $0.assetID == asset.id }
                        ForEach(linked) { practice in
                            NavigationLink { PracticeDetailView(practiceID: practice.id) } label: {
                                GrimoireRecordRow(title: practice.title, subtitle: ScheduleEngine.summary(practice.schedule), symbol: practice.discipline.symbol, status: practice.archived ? "Archived" : "Linked practice")
                            }.buttonStyle(.plain)
                        }
                        SectionEyebrow(text: "Inspection and service history")
                        if asset.inspections.isEmpty { Text("No observations recorded yet.").foregroundStyle(theme.secondary) }
                        ForEach(asset.inspections.sorted { $0.date > $1.date }) { inspection in
                            InvokeCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(inspection.condition).font(.headline)
                                    Text(inspection.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(theme.secondary)
                                    if !inspection.notes.isEmpty { Text(inspection.notes).textSelection(.enabled) }
                                    if let id = inspection.followUpPracticeID {
                                        NavigationLink("Open recorded follow-up") { PracticeDetailView(practiceID: id) }
                                    }
                                }
                            }
                        }
                    }.padding(20)
                }
                .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink(asset.archived ? "Restore / details" : "Edit") { CareAssetEditorView(draft: asset) } } }
            } else { EmptyState(symbol: "shippingbox", title: "Asset unavailable", message: "This record is no longer available in the current data.") }
        }.navigationTitle("Asset care").navigationBarTitleDisplayMode(.inline).invokeScreen()
    }
    private func careDraft(_ asset: CareAsset) -> PracticeDefinition {
        var value = PracticeDefinition()
        value.title = "Inspect \(asset.name)"; value.plainTitle = "Condition review"
        value.assetID = asset.id; value.discipline = asset.discipline
        value.instructions = asset.careInstructions
        value.context = "Configure the inspection cadence from the item’s instructions and your needs. Serviceable items remain in service."
        value.schedule.kind = .unscheduled
        return value
    }
}

struct AssetInspectionEditorView: View {
    let assetID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = AssetInspection()
    @State private var createFollowUp = false
    @State private var followUpTitle = ""
    @State private var followUpDate: Date?
    private var asset: CareAsset? { store.data.grimoire.assets.first { $0.id == assetID } }
    private var warrantsFollowUp: Bool { ["Needs repair", "Needs replacement", "Needs replenishment"].contains(draft.condition) }
    var body: some View {
        Form {
            Section("What you actually observed") {
                Text(asset?.name ?? "Asset unavailable").font(.headline)
                Picker("Condition", selection: $draft.condition) {
                    ForEach(["Serviceable", "Needs repair", "Needs replacement", "Needs replenishment", "Monitor", "Retired"], id: \.self) { Text($0).tag($0) }
                }.accessibilityIdentifier("asset-condition")
                DatePicker("Observation date", selection: $draft.date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                GrimoireTextField(label: "Observation or service notes", text: $draft.notes)
                Text("A serviceable result keeps the item in use. An observation does not automatically complete a linked care practice.").font(.footnote)
            }
            if warrantsFollowUp {
                Section("Optional follow-up") {
                    Toggle("Create a linked follow-up quest", isOn: $createFollowUp).accessibilityIdentifier("asset-follow-up")
                    if createFollowUp {
                        TextField("Follow-up title", text: $followUpTitle)
                        OptionalDateField(title: "Choose a target date", date: $followUpDate)
                        Text("This creates one separate action to consider repair, replacement or replenishment. It does not buy or dispose of anything.").font(.footnote)
                    }
                }
            }
        }
        .navigationTitle("Condition observation")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Record", action: save).disabled(asset == nil || asset?.archived == true || (createFollowUp && warrantsFollowUp && followUpTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)).accessibilityIdentifier("asset-observation-save") } }
        .onChange(of: draft.condition) { _, condition in
            if !warrantsFollowUp { createFollowUp = false }
            followUpTitle = "\(condition == "Needs repair" ? "Arrange repair for" : condition == "Needs replenishment" ? "Review replenishment of" : "Review replacement of") \(asset?.name ?? "item")"
        }
        .invokeScreen()
    }
    private func save() {
        guard let asset, !asset.archived else { return }
        var followUp: PracticeDefinition?
        if createFollowUp && warrantsFollowUp {
            var practice = PracticeDefinition()
            practice.title = followUpTitle; practice.plainTitle = followUpTitle
            practice.assetID = asset.id; practice.discipline = asset.discipline
            practice.instructions = draft.notes; practice.context = "From a recorded condition observation: \(draft.condition)."
            practice.schedule.policy = .persist
            if let date = followUpDate {
                practice.schedule.kind = .once
                practice.schedule.startDate = LocalDay(date, timeZone: GrimoirePresentation.calendar(store.data.grimoire.settings).timeZone)
            }
            followUp = practice
        }
        do { try store.recordInspection(assetID: asset.id, inspection: draft, followUp: followUp); dismiss() }
        catch { store.errorMessage = error.localizedDescription }
    }
}

struct ArcanaEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ArcanaRecord
    init(draft: ArcanaRecord) { _draft = State(initialValue: draft) }
    var body: some View {
        Form {
            Group {
                Section("Your private record") {
                    TextField("Title", text: $draft.title).accessibilityIdentifier("arcana-title")
                    Picker("Record kind", selection: $draft.kind) {
                        ForEach(["Practice", "Belief", "Reflection", "Dream", "Symbolic record", "Intention", "Study", "Celestial observance"], id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Your relationship to this belief or practice", selection: $draft.beliefStatus) {
                        ForEach(["Exploring", "Practicing", "Personally Accepted", "Questioning", "Archived"], id: \.self) { Text($0).tag($0) }
                    }.accessibilityIdentifier("arcana-belief-status")
                    OptionalDateField(title: "Record a known experience date", date: $draft.occurredAt, components: [.date, .hourAndMinute])
                    Text("Sources, experiences and interpretations are distinct parts of your record. Exports include this private writing only when you choose to export your data.").font(.footnote)
                }
                Section("Origin and method") {
                    Picker("Original belief (optional)", selection: $draft.legacyEntryID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(store.data.entries.filter { $0.kind == .belief || $0.id == draft.legacyEntryID }) { entry in
                            Text(entry.title + (entry.archived ? " · Archived" : "")).tag(Optional(entry.id))
                        }
                    }.accessibilityIdentifier("arcana-original-belief")
                    Text("A link keeps the original belief and its revisions available alongside this record.").font(.footnote)
                    GrimoireTextField(label: "Origin or tradition", text: $draft.origin)
                    GrimoireTextField(label: "Source, quotation or reference", text: $draft.source)
                    GrimoireTextField(label: "Purpose", text: $draft.purpose)
                    GrimoireTextField(label: "Method or practice", text: $draft.method)
                    GrimoireTextField(label: "Optional materials", text: $draft.materials, lines: 2)
                    GrimoireTextField(label: "Context", text: $draft.context)
                }
                Section("Expectation and experience") {
                    GrimoireTextField(label: "Expected result, if relevant", text: $draft.expectedResult)
                    GrimoireTextField(label: "What you observed", text: $draft.observedResult)
                    GrimoireTextField(label: "Your interpretation", text: $draft.interpretation)
                    GrimoireTextField(label: "Alternative explanations and questions", text: $draft.alternatives)
                }
                Section("Next decision") {
                    Picker("What comes next", selection: $draft.nextDecision) {
                        ForEach(["Repeat", "Modify", "Study", "Retire"], id: \.self) { Text($0).tag($0) }
                    }
                    GrimoireTextField(label: "Notes", text: $draft.notes)
                }
            }.disabled(draft.archived)
            if draft.kind == "Celestial observance" && !draft.archived {
                Section {
                    NavigationLink("Configure an observance date you supply") { PracticeEditorView(draft: observanceDraft) }
                    Text("Dates are entered by you; this app does not calculate transits or lunar events.").font(.footnote)
                }
            }
            if let legacy = draft.legacyEntryID {
                Section { NavigationLink("Open the original Grimoire entry") { EntryDetailView(entryID: legacy) } }
            }
            if store.data.grimoire.arcana.contains(where: { $0.id == draft.id }) {
                archiveSection(archived: draft.archived) { changeArchive() }
            }
            recordDates(created: draft.createdAt, updated: draft.updatedAt)
        }
        .navigationTitle(draft.archived ? "Archived Arcana" : "Arcana")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(draft.archived || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("arcana-save") } }
        .invokeScreen()
    }
    private var observanceDraft: PracticeDefinition {
        var value = PracticeDefinition()
        value.title = draft.title; value.plainTitle = "User-scheduled observance"
        value.instructions = draft.method; value.discipline = .arcana; value.purpose = .discovery
        value.importance = .optional; value.schedule.kind = .unscheduled
        return value
    }
    private func save() {
        var value = draft
        if value.beliefStatus == "Archived" { value.archived = true }
        do { try store.saveArcana(value); dismiss() } catch { store.errorMessage = error.localizedDescription }
    }
    private func changeArchive() {
        var value = draft; value.archived.toggle()
        if !value.archived && value.beliefStatus == "Archived" { value.beliefStatus = "Exploring" }
        do { try store.saveArcana(value); dismiss() } catch { store.errorMessage = error.localizedDescription }
    }
}

struct EchoEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Echo
    init(draft: Echo) { _draft = State(initialValue: draft) }
    var body: some View {
        Form {
            Group {
                Section("A comparison with context") {
                    TextField("Title", text: $draft.title).accessibilityIdentifier("echo-title")
                    GrimoireTextField(label: "First source or tradition", text: $draft.sourceA, identifier: "echo-source-a")
                    GrimoireTextField(label: "Second source or tradition", text: $draft.sourceB, identifier: "echo-source-b")
                    Text("Keep links, references or quotations with their attribution. Similarity does not require equivalence.").font(.footnote)
                }
                Section("What connects and what differs") {
                    GrimoireTextField(label: "Perceived similarities", text: $draft.similarities)
                    GrimoireTextField(label: "Meaningful differences", text: $draft.differences)
                    GrimoireTextField(label: "Original context", text: $draft.originalContext)
                    GrimoireTextField(label: "Historical connections and evidence", text: $draft.historicalConnections)
                }
                Section("Your evolving interpretation") {
                    GrimoireTextField(label: "Personal interpretation", text: $draft.interpretation)
                    GrimoireTextField(label: "Unanswered questions", text: $draft.questions)
                    GrimoireTextField(label: "Changes of view", text: $draft.changesOfView)
                }
            }.disabled(draft.archived)
            if store.data.grimoire.echoes.contains(where: { $0.id == draft.id }) {
                archiveSection(archived: draft.archived) { changeArchive() }
            }
            recordDates(created: draft.createdAt, updated: draft.updatedAt)
        }
        .navigationTitle(draft.archived ? "Archived Echo" : "Echo")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(draft.archived || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("echo-save") } }
        .invokeScreen()
    }
    private func save() {
        do { try store.saveEcho(draft); dismiss() } catch { store.errorMessage = error.localizedDescription }
    }
    private func changeArchive() {
        var value = draft; value.archived.toggle()
        do { try store.saveEcho(value); dismiss() } catch { store.errorMessage = error.localizedDescription }
    }
}

private func archiveSection(archived: Bool, action: @escaping () -> Void) -> some View {
    Section {
        if archived { Text("Archived records are read-only. Restore this record to edit it.").font(.footnote) }
        Button(archived ? "Restore record" : "Archive record", action: action)
        Text("Archiving keeps existing records and history; it does not delete them.").font(.footnote)
    }
}

private func recordDates(created: Date, updated: Date) -> some View {
    Section("Record dates") {
        LabeledContent("Created", value: created.formatted(date: .abbreviated, time: .shortened))
        LabeledContent("Last saved", value: updated.formatted(date: .abbreviated, time: .shortened))
    }
}
