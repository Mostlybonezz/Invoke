import SwiftUI

private enum GrimoireShelf: String, CaseIterable, Identifiable {
    case codex, practices, spells, enchantments, assets, arcana, echoes
    var id: String { rawValue }
    var title: String {
        switch self {
        case .codex: "Codex library"; case .practices: "My practices"; case .spells: "Spells & methods"
        case .enchantments: "Enabling arrangements"; case .assets: "Assets & supplies"
        case .arcana: "Arcana & beliefs"; case .echoes: "Echoes & comparisons"
        }
    }
}

struct LivingGrimoireView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @State private var shelf: GrimoireShelf = .codex
    @State private var discipline = "all"
    @State private var search = ""
    @State private var archive = false
    @State private var templates: [CodexTemplate] = []
    @State private var loadingError: String?

    private var fantasy: Bool { store.data.grimoire.settings.fantasyLanguage }
    private var codexResults: [CodexTemplate] {
        templates.filter { $0.matches(search) && (discipline == "all" || $0.disciplines.contains(discipline)) }
    }
    private func matches(_ texts: [String]) -> Bool {
        search.isEmpty || texts.joined(separator: " ").localizedCaseInsensitiveContains(search)
    }
    private func matches(_ value: Discipline) -> Bool { discipline == "all" || value.rawValue == discipline }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text(fantasy ? "The Living Grimoire" : "Your library").font(.title2).fontDesign(.serif)
                Text("Choose what supports your life. Library suggestions stay inactive until you configure and save a practice.")
                    .foregroundStyle(theme.secondary)
                Picker("Library shelf", selection: $shelf) {
                    ForEach(GrimoireShelf.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.menu).accessibilityIdentifier("grimoire-shelf")
                Picker("Discipline", selection: $discipline) {
                    Text("All ten disciplines").tag("all")
                    ForEach(Discipline.allCases) { Label($0.title, systemImage: $0.symbol).tag($0.rawValue) }
                }.pickerStyle(.menu).accessibilityIdentifier("grimoire-discipline")
                if shelf != .codex {
                    Toggle("Show archived records", isOn: $archive).accessibilityIdentifier("grimoire-archive")
                }
                shelfContent
                Divider().padding(.vertical, 4)
                SectionEyebrow(text: "Familiar pages")
                NavigationLink { GrimoireView() } label: {
                    GrimoireRecordRow(title: "Original Grimoire", subtitle: "Your manifestations, beliefs, rituals and their original history", symbol: "book")
                }.buttonStyle(.plain)
                NavigationLink { RelicCabinetView() } label: {
                    GrimoireRecordRow(title: "Relic Cabinet", subtitle: "Your objects, photographs, dedications and keepsakes", symbol: "sparkles")
                }.buttonStyle(.plain)
            }.padding(20)
        }
        .navigationTitle("Grimoire")
        .searchable(text: $search, prompt: "Names, meanings, instructions, source IDs")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { creationMenu } }
        .task { loadTemplates() }
        .invokeScreen()
    }

    @ViewBuilder private var shelfContent: some View {
        switch shelf {
        case .codex: codexShelf
        case .practices: practiceShelf
        case .spells: spellShelf
        case .enchantments: enchantmentShelf
        case .assets: assetShelf
        case .arcana: arcanaShelf
        case .echoes: echoShelf
        }
    }
    private var creationMenu: some View {
        Menu {
            NavigationLink("Custom practice") { PracticeEditorView(draft: PracticeDefinition()) }
            NavigationLink("Spell or saved method") { SpellEditorView(draft: Spell()) }
            NavigationLink("Enabling arrangement") { EnchantmentEditorView(draft: Enchantment()) }
            NavigationLink("Asset or supply") { CareAssetEditorView(draft: CareAsset()) }
            NavigationLink("Arcana record or belief") { ArcanaEditorView(draft: ArcanaRecord()) }
            NavigationLink("Echo or comparison") { EchoEditorView(draft: Echo()) }
        } label: { Image(systemName: "plus") }.accessibilityLabel("Add to Grimoire")
    }
    @ViewBuilder private var codexShelf: some View {
        if let error = loadingError {
            InvokeCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Codex unavailable").font(.headline)
                    Text(error).foregroundStyle(theme.secondary)
                    Button("Try loading again", action: loadTemplates)
                }
            }
        } else {
            Text("\(codexResults.count) library entries · no automatic activation").font(.caption).foregroundStyle(theme.secondary)
            if discipline == "all" || discipline == "bonds" {
                NavigationLink { BondsPlanningView(templates: templates) } label: {
                    GrimoireRecordRow(title: fantasy ? "Tend & widen the circle" : "Social planning preferences", subtitle: "Review editable suggestions for maintaining or expanding connection", symbol: "person.2")
                }.buttonStyle(.plain)
            }
            if codexResults.isEmpty { noResults("Try another discipline, source ID or phrase.") }
            ForEach(codexResults) { template in
                NavigationLink { CodexPreviewView(template: template, library: templates) } label: {
                    GrimoireRecordRow(title: template.displayTitle(fantasy: fantasy), subtitle: template.plainTitle,
                                      symbol: Discipline(rawValue: template.disciplines.first ?? "")?.symbol ?? "book",
                                      status: template.referenceOnly ? "Reference" : template.suggestedSchedule == "configured" ? "Configure your schedule" : "Inactive template")
                }.buttonStyle(.plain).accessibilityIdentifier("codex-\(template.sourceIDs.first ?? template.id)")
            }
        }
    }
    @ViewBuilder private var practiceShelf: some View {
        let values = store.data.grimoire.practices.filter { $0.archived == archive && matches($0.discipline) && matches([$0.title, $0.plainTitle, $0.instructions] + $0.sourceIDs) }
        if values.isEmpty { noResults("Your activated and custom practices appear here. Use the Codex or add a custom practice.") }
        ForEach(values) { value in
            NavigationLink { PracticeDetailView(practiceID: value.id) } label: {
                GrimoireRecordRow(title: GrimoirePresentation.title(value, settings: store.data.grimoire.settings), subtitle: ScheduleEngine.summary(value.schedule), symbol: value.discipline.symbol, status: value.archived ? "Archived" : value.paused ? "Paused" : value.importance.title)
            }.buttonStyle(.plain)
        }
    }
    @ViewBuilder private var spellShelf: some View {
        let values = store.data.grimoire.spells.filter { $0.archived == archive && matches($0.discipline) && matches([$0.title, $0.plainTitle, $0.method, $0.source, $0.notes]) }
        if values.isEmpty { noResults("Save techniques with their method, source and notes. Link a technique to any practice.") }
        ForEach(values) { value in
            NavigationLink { SpellEditorView(draft: value) } label: {
                GrimoireRecordRow(title: fantasy || value.plainTitle.isEmpty ? value.title : value.plainTitle, subtitle: value.purpose, symbol: "wand.and.stars", status: archive ? "Archived" : "Saved method")
            }.buttonStyle(.plain)
        }
    }
    @ViewBuilder private var enchantmentShelf: some View {
        let values = store.data.grimoire.enchantments.filter { value in
            value.archived == archive && matches([value.title, value.supports, value.notes, value.establishmentEvidence])
            && (discipline == "all" || store.data.grimoire.invocations.first(where: { $0.id == value.invocationID })?.discipline.rawValue == discipline)
        }
        if values.isEmpty { noResults("Record arrangements that support later actions: a prepared bag, workspace, backup setup or gathering. Discipline follows a linked Invocation.") }
        ForEach(values) { value in
            NavigationLink { EnchantmentEditorView(draft: value) } label: {
                GrimoireRecordRow(title: value.title, subtitle: value.supports, symbol: "sparkles", status: archive ? "Archived" : value.status)
            }.buttonStyle(.plain)
        }
    }
    @ViewBuilder private var assetShelf: some View {
        let values = store.data.grimoire.assets.filter { $0.archived == archive && matches($0.discipline) && matches([$0.name, $0.category, $0.careInstructions, $0.notes]) }
        if values.isEmpty { noResults("Track only useful possessions or supplies. Unknown purchase dates stay unknown; condition decides what needs attention.") }
        ForEach(values) { value in
            NavigationLink { CareAssetDetailView(assetID: value.id) } label: {
                GrimoireRecordRow(title: value.name, subtitle: value.resourceKind + (value.category.isEmpty ? "" : " · " + value.category), symbol: "shippingbox", status: archive ? "Archived" : value.condition)
            }.buttonStyle(.plain)
        }
    }
    @ViewBuilder private var arcanaShelf: some View {
        let values = store.data.grimoire.arcana.filter { $0.archived == archive && (discipline == "all" || discipline == "arcana") && matches([$0.title, $0.kind, $0.source, $0.observedResult, $0.interpretation, $0.notes]) }
        Text("Private sources, experiences and interpretations. Invoke keeps this writing in its local library; a data export includes it.").font(.footnote).foregroundStyle(theme.secondary)
        if values.isEmpty { noResults("Keep a practice, belief, dream, symbolic record, intention or study note.") }
        ForEach(values) { value in
            NavigationLink { ArcanaEditorView(draft: value) } label: {
                GrimoireRecordRow(title: value.title, subtitle: value.kind, symbol: "moon.stars", status: archive ? "Archived" : value.beliefStatus)
            }.buttonStyle(.plain)
        }
    }
    @ViewBuilder private var echoShelf: some View {
        let values = store.data.grimoire.echoes.filter { $0.archived == archive && (discipline == "all" || discipline == "arcana") && matches([$0.title, $0.sourceA, $0.sourceB, $0.similarities, $0.differences, $0.interpretation]) }
        if values.isEmpty { noResults("Compare ideas with sources, similarities, differences and context. Keep open questions and changes of view.") }
        ForEach(values) { value in
            NavigationLink { EchoEditorView(draft: value) } label: {
                GrimoireRecordRow(title: value.title, subtitle: value.questions.isEmpty ? "A comparison with room for difference" : value.questions, symbol: "link", status: archive ? "Archived" : "Private comparison")
            }.buttonStyle(.plain)
        }
    }
    private func noResults(_ text: String) -> some View {
        EmptyState(symbol: "book.closed", title: search.isEmpty ? "A page is waiting" : "No matching pages", message: text)
    }
    private func loadTemplates() {
        do { templates = try CodexLibrary.load(bundle: .main); loadingError = nil }
        catch { loadingError = error.localizedDescription }
    }
}

struct GrimoireRecordRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    var status = ""
    @Environment(\.invokeTheme) private var theme
    var body: some View {
        InvokeCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol).foregroundStyle(theme.accent).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(title.isEmpty ? "Untitled record" : title).font(.headline).multilineTextAlignment(.leading)
                    if !subtitle.isEmpty && subtitle != title { Text(subtitle).font(.subheadline).foregroundStyle(theme.secondary).lineLimit(3).multilineTextAlignment(.leading) }
                    if !status.isEmpty { StatusPill(text: status) }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).accessibilityHidden(true)
            }.frame(minHeight: 44).foregroundStyle(theme.text)
        }
    }
}

struct CodexPreviewView: View {
    let template: CodexTemplate
    let library: [CodexTemplate]
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    private var fantasy: Bool { store.data.grimoire.settings.fantasyLanguage }
    private var owned: [PracticeDefinition] { store.data.grimoire.practices.filter { $0.templateID == template.id && !$0.archived } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(template.displayTitle(fantasy: fantasy)).font(.largeTitle).fontDesign(.serif).accessibilityIdentifier("codex-preview-title")
                if template.plainTitle != template.displayTitle(fantasy: fantasy) { Text(template.plainTitle).foregroundStyle(theme.secondary) }
                InvokeCard {
                    VStack(alignment: .leading, spacing: 16) {
                        GrimoireDetailText(title: "When it applies", text: template.applicability)
                        GrimoireDetailText(title: "Responsibility", text: template.responsibleParty)
                        GrimoireDetailText(title: "Instructions", text: template.instructions.joined(separator: "\n\n"))
                        GrimoireDetailText(title: "Record honestly", text: template.completionCriteria)
                        GrimoireDetailText(title: "Follow-up", text: template.followOnTrigger)
                    }
                }
                if !template.referenceOnly {
                    InvokeCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Review before activation").font(.headline)
                            Text(template.reviewStatus)
                            Text("Suggested cadence: \(cadenceMeaning). Importance: \(template.suggestedImportance.capitalized). Both are editable.").foregroundStyle(theme.secondary)
                            NavigationLink {
                                PracticeEditorView(draft: template.practiceDraft(fantasy: fantasy, timeZone: GrimoirePresentation.calendar(store.data.grimoire.settings).timeZone))
                            } label: {
                                Label(owned.isEmpty ? "Configure this practice" : "Create another customized copy", systemImage: "plus.circle")
                                    .frame(minHeight: 44)
                            }.accessibilityIdentifier("codex-activate")
                            Text("Nothing is scheduled until you review and save. Existing personalized copies are never overwritten.").font(.footnote).foregroundStyle(theme.secondary)
                        }
                    }
                }
                ForEach(owned) { practice in
                    NavigationLink { PracticeDetailView(practiceID: practice.id) } label: {
                        GrimoireRecordRow(title: practice.title, subtitle: "Your existing customized practice", symbol: practice.discipline.symbol)
                    }.buttonStyle(.plain)
                }
                ForEach(library.filter { template.relatedTemplateIDs.contains($0.id) }) { related in
                    NavigationLink { CodexPreviewView(template: related, library: library) } label: {
                        GrimoireRecordRow(title: related.displayTitle(fantasy: fantasy), subtitle: "Related practice · one action, one record", symbol: "link")
                    }.buttonStyle(.plain)
                }
                DisclosureGroup("Source and complete original wording") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(template.provenance).font(.footnote)
                        ForEach(Array(template.sourceIDs.enumerated()), id: \.offset) { index, sourceID in
                            GrimoireDetailText(title: sourceID, text: template.sourceTexts[index])
                        }
                        Text("Content version \(template.contentVersion). These cadence suggestions do not replace your actual professional, product or legal instructions.").font(.footnote).foregroundStyle(theme.secondary)
                    }.padding(.top, 12)
                }
            }.padding(20)
        }.navigationTitle(template.referenceOnly ? "Codex reference" : "Practice preview").navigationBarTitleDisplayMode(.inline).invokeScreen()
    }
    private var cadenceMeaning: String {
        switch template.suggestedSchedule {
        case "configured": "your specified schedule"
        case "oneOff": "your actual date"
        case "condition": "when the recorded condition warrants attention"
        case "event": "after a matching event you record"
        default: template.suggestedSchedule
        }
    }
}

struct BondsPlanningView: View {
    let templates: [CodexTemplate]
    @EnvironmentObject private var store: AppStore
    @State private var pace = "Maintenance"
    private var proposedIDs: [String] {
        pace == "Maintenance" ? ["codex.C14.01", "codex.C14.04"] : ["codex.C14.01", "codex.C14.07", "codex.C14.09", "codex.C14.11"]
    }
    var body: some View {
        List {
            Section {
                Text("A contact rhythm you choose").font(.title2).fontDesign(.serif)
                Text("These are editable planning suggestions, not social minimums. Invitations record your action; another person’s response is an independent observation.")
                Picker("Planning pace", selection: $pace) {
                    ForEach(["Maintenance", "Moderate", "Active growth"], id: \.self) { Text($0).tag($0) }
                }
            }
            Section("Review each practice") {
                ForEach(templates.filter { proposedIDs.contains($0.id) }) { template in
                    NavigationLink { PracticeEditorView(draft: draft(template)) } label: {
                        VStack(alignment: .leading) {
                            Text(template.displayTitle(fantasy: store.data.grimoire.settings.fantasyLanguage))
                            Text(template.plainTitle).font(.caption)
                        }.padding(.vertical, 6)
                    }
                }
            }
            Section { Text("Nothing activates when you choose a pace. Open a suggestion, adjust the plan to your preferences and save it explicitly.").font(.footnote) }
        }.navigationTitle("Bonds planning").invokeScreen()
    }
    private func draft(_ template: CodexTemplate) -> PracticeDefinition {
        var value = template.practiceDraft(fantasy: store.data.grimoire.settings.fantasyLanguage, timeZone: GrimoirePresentation.calendar(store.data.grimoire.settings).timeZone)
        value.schedule.kind = .weeklyQuota
        value.schedule.quota = pace == "Active growth" && template.id == "codex.C14.07" ? 2 : 1
        value.schedule.policy = .flexible
        value.context += "\nPlanning suggestion: \(pace). Change the frequency, person reference and expectations to your own preference."
        return value
    }
}
