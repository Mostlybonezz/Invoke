import SwiftUI

struct LivingSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var reminders: ReminderCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GrimoireSettings
    @State private var showingSetup = false
    init(settings: GrimoireSettings) { _draft = State(initialValue: settings) }
    var body: some View {
        Form {
            Section("Presentation") {
                Toggle("Fantasy names with plain meanings", isOn: $draft.fantasyLanguage)
                Toggle("Decorative motion", isOn: $draft.motionEnabled)
                Toggle("Optional record recognition", isOn: $draft.recognitionEnabled)
                Text("System Reduce Motion and contrast settings always take precedence. Recognition describes records, never health, power, or personal worth.").font(.footnote)
            }
            Section("Calendar and travel") {
                Picker("Week starts on", selection: $draft.weekStartsOn) { ForEach(1...7, id: \.self) { Text(Calendar.current.weekdaySymbols[$0 - 1]).tag($0) } }
                Toggle("Follow my device's time zone", isOn: $draft.followsTravelTimeZone)
                if !draft.followsTravelTimeZone {
                    Picker("Home time zone", selection: $draft.homeTimeZoneID) { ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0).tag($0) } }
                }
                Text("Future calendar windows follow this policy. Saved occurrences and earlier action records retain their original zone and identity.").font(.footnote)
            }
            Section("Focus and restoration") {
                Picker("Chosen focus", selection: $draft.focusPracticeID) {
                    Text("None").tag(nil as UUID?)
                    ForEach(store.data.grimoire.practices.filter { !$0.archived }) { Text($0.title).tag(Optional($0.id)) }
                }
                Toggle("Restoration Mode", isOn: $draft.restorationMode)
                Text("Show chosen essentials and consequential deadlines. All other work remains accessible in Quests; nothing is completed or erased.").font(.footnote)
                ForEach(store.data.grimoire.practices.filter { !$0.archived }) { practice in
                    Toggle(practice.title, isOn: Binding(get: { draft.essentialPracticeIDs.contains(practice.id) }, set: { value in draft.essentialPracticeIDs.removeAll { $0 == practice.id }; if value { draft.essentialPracticeIDs.append(practice.id) } }))
                }
            }
            Section("Optional reminders") {
                Text(reminders.authorizationDescription)
                Toggle("Schedule local reminders", isOn: $draft.remindersEnabled)
                Button("Allow notifications on this device") { Task { if await reminders.requestPermission() { draft.remindersEnabled = true } } }
                Toggle("Private notification text", isOn: $draft.privateNotificationPreviews)
                Toggle("Notification sound", isOn: $draft.soundEnabled)
                Stepper("Quiet hours start: \(draft.quietHoursStart):00", value: $draft.quietHoursStart, in: 0...23)
                Stepper("Quiet hours end: \(draft.quietHoursEnd):00", value: $draft.quietHoursEnd, in: 0...23)
                Text("Equal start and end disables quiet hours. Reminders move out of quiet hours; deadlines do not move.").font(.footnote)
                Toggle("Daily review digest", isOn: $draft.digestEnabled)
                if draft.digestEnabled { Stepper("Digest hour: \(draft.digestHour):00", value: $draft.digestHour, in: 0...23) }
                Text(reminders.statusMessage).font(.footnote)
                Text("Invoke schedules up to 48 local reminders for the next 30 days and refreshes them when used. Delivery depends on iOS and the host. In LiveContainer, enable its Fix Local Notifications setting if needed. Today always provides in-app reminders.").font(.footnote)
            }
            Section("Responsibilities and setup") {
                Button("Review applicable domains and starting practices") { showingSetup = true }
                Text("No vehicle, home ownership, pet, or dependent-care responsibility is assigned automatically.").font(.footnote)
            }
        }.navigationTitle("Living Grimoire").navigationBarTitleDisplayMode(.inline).invokeScreen()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save") {
                store.presentGrimoireError { var data = store.data.grimoire; data.settings = draft; try store.commitGrimoire(data); reminders.schedule(store: store); dismiss() }
            } } }
            .task { await reminders.refreshAuthorization() }
            .sheet(isPresented: $showingSetup, onDismiss: { draft = store.data.grimoire.settings }) { NavigationStack { LivingSetupView(isUpgrade: false, revisiting: true) } }
    }
}

struct LivingSetupView: View {
    var isUpgrade: Bool
    var revisiting = false
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var disciplines: Set<Discipline> = []
    @State private var responsibilities: Set<String> = []
    @State private var developments = ""
    @State private var selected: Set<String> = []
    @State private var templates: [CodexTemplate] = []
    @State private var libraryError = ""
    private var proposed: [CodexTemplate] {
        // Show a small invitation to review, never automatically activate a library.
        let safeIDs = ["codex.C17.01", "codex.C21.01", "codex.C12.03", "codex.C14.01", "codex.C16.01"]
        return Array(templates.filter { safeIDs.contains($0.id) && (disciplines.isEmpty || $0.disciplines.contains(where: { value in disciplines.contains(where: { $0.rawValue == value }) })) }.prefix(3))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack { Image(systemName: "sparkle"); Text("Invoke").font(.largeTitle).fontDesign(.serif) }
                    .accessibilityElement(children: .combine).accessibilityIdentifier("appearance-current-theme").accessibilityValue(theme.id)
                if isUpgrade && !revisiting {
                    SectionEyebrow(text: "Welcome to 2.0")
                    Text("Your living grimoire.").font(.largeTitle).fontDesign(.serif)
                    Text("Your stories, scenes, writing, photos and appearance are still here. Today brings your chosen actions forward; Quests holds schedules; Chronicle keeps truthful records.")
                    Text("Find the original Sanctuary from Today, Stories from Invocations, and the original Grimoire and Relic Cabinet from Grimoire.").foregroundStyle(theme.secondary)
                    Text("No practices were activated and no past actions were invented. Your pre-upgrade data is retained for recovery.").font(.footnote)
                    InvokePrimaryButton(title: "Continue to Today") { finish(activate: false) }.accessibilityIdentifier("upgrade-continue")
                } else if step == 0 {
                    SectionEyebrow(text: "The Living Grimoire")
                    Text("Care for what matters. Make room for what comes next.").font(.title).fontDesign(.serif)
                    Text("State an intention. Connect it to real actions. Practice, observe, and revise. Choose your responsibilities; the rest of the Codex stays in the library.")
                    InvokePrimaryButton(title: "Choose my starting point") { step = 1 }
                    Button("Skip setup and open Today") { finish(activate: false) }.frame(minHeight: 44).accessibilityIdentifier("onboarding-skip")
                    if !revisiting {
                        Button("Explore the original example stories") {
                            store.loadExamples(); finish(activate: false)
                        }.frame(minHeight: 44).accessibilityIdentifier("onboarding-examples")
                    }
                    Text("Local, private writing. No account, analytics, or runtime AI. Export backups in Settings.").font(.footnote).foregroundStyle(theme.secondary)
                } else if step == 1 {
                    Text("Choose what belongs in your life.").font(.title2).fontDesign(.serif)
                    ForEach(Discipline.allCases) { value in
                        Toggle(isOn: Binding(get: { disciplines.contains(value) }, set: { if $0 { disciplines.insert(value) } else { disciplines.remove(value) } })) { Label(value.title, systemImage: value.symbol) }
                    }
                    SectionEyebrow(text: "Responsibilities · optional")
                    ForEach(["Vehicle", "Home systems I maintain", "Pets", "Plants or garden", "Dependents I care for", "Shared household"], id: \.self) { value in
                        Toggle(value, isOn: Binding(get: { responsibilities.contains(value) }, set: { if $0 { responsibilities.insert(value) } else { responsibilities.remove(value) } }))
                    }
                    GrimoireTextField(label: "What would you like to develop?", text: $developments)
                    InvokePrimaryButton(title: "Review a small starting set") { step = 2 }
                } else {
                    Text("Only activate what you choose.").font(.title2).fontDesign(.serif)
                    Text("These are editable planning suggestions. They are not requirements. You can start with none.").foregroundStyle(theme.secondary)
                    if !libraryError.isEmpty { Text(libraryError).foregroundStyle(theme.accent) }
                    ForEach(proposed) { item in
                        InvokeCard { VStack(alignment: .leading, spacing: 12) {
                            Toggle(item.plainTitle, isOn: Binding(get: { selected.contains(item.id) }, set: { if $0 { selected.insert(item.id) } else { selected.remove(item.id) } }))
                            Text(item.instructions.joined(separator: "\n")).font(.subheadline)
                            Text("Suggested: \(item.cadenceDescription). Customize in Quests.").font(.footnote).foregroundStyle(theme.secondary)
                        } }
                    }
                    InvokePrimaryButton(title: selected.isEmpty ? "Begin with an open page" : "Activate \(selected.count) selected practices") { finish(activate: true) }
                    Button("Back") { step = 1 }
                }
            }.padding(24)
        }.invokeScreen().navigationTitle(revisiting ? "Starting practices" : "Welcome").navigationBarTitleDisplayMode(.inline)
            .task {
                disciplines = Set(store.data.grimoire.settings.applicableDisciplines)
                responsibilities = Set(store.data.grimoire.settings.responsibilities)
                developments = store.data.grimoire.settings.desiredDevelopments
                do { templates = try CodexLibrary.templates } catch { libraryError = error.localizedDescription }
            }
    }
    private func finish(activate: Bool) {
        store.presentGrimoireError {
            var data = store.data.grimoire
            data.setupCompleted = true; data.upgradeIntroductionSeen = true
            if !isUpgrade || revisiting {
                data.settings.applicableDisciplines = Array(disciplines).sorted { $0.rawValue < $1.rawValue }
                data.settings.responsibilities = Array(responsibilities).sorted(); data.settings.desiredDevelopments = developments
            }
            if activate {
                for item in proposed where selected.contains(item.id) && !data.practices.contains(where: { $0.templateID == item.id && !$0.archived }) {
                    data.practices.append(item.practiceDraft(fantasy: data.settings.fantasyLanguage))
                }
            }
            try store.commitGrimoire(data)
            store.data.preferences.onboardingComplete = true; store.flush()
            if store.saveState == "Saved on this iPhone" { dismiss() }
        }
    }
}
