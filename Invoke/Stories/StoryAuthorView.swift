import SwiftUI
import PhotosUI

struct StoryAuthorView: View {
    let storyID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @State private var replacePassage = false
    @State private var customMode = ""
    @State private var sceneID: UUID?
    @State private var selectedCover: PhotosPickerItem?
    private let headings = ["Where am I now?", "What am I writing toward?", "What kind of story is this?", "Who am I practicing becoming?", "What makes this difficult?", "The next believable scene"]
    var body: some View {
        Group {
            if let story = store.data.stories.first(where: { $0.id == storyID }) {
                editor(store.recordBinding(\.stories, id: storyID, fallback: story))
            } else { EmptyState(symbol: "book.closed", title: "Story unavailable", message: "It may have been removed.") }
        }.navigationTitle("Author your story").navigationBarTitleDisplayMode(.inline).invokeScreen()
            .navigationDestination(item: $sceneID) { SceneDetailView(sceneID: $0) }
            .task(id: selectedCover) {
                guard let selectedCover else { return }
                do {
                    if let data = try await selectedCover.loadTransferable(type: Data.self) {
                        let file = try store.importPhoto(data)
                        if let i = store.data.stories.firstIndex(where: { $0.id == storyID }) { store.data.stories[i].coverFile = file }
                    }
                } catch { store.errorMessage = "Could not add the cover: \(error.localizedDescription)" }
            }
    }
    private func answer(_ story: Binding<Story>, _ key: String) -> Binding<String> {
        Binding(get: { story.wrappedValue.answers[key, default: ""] }, set: { story.wrappedValue.answers[key] = $0; story.wrappedValue.updatedAt = Date() })
    }
    @ViewBuilder private func editor(_ story: Binding<Story>) -> some View {
        let step = min(max(story.wrappedValue.authoringStep, 0), 5)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack { SectionEyebrow(text: "\(step + 1) / 6 · Short answers are welcome"); Spacer(); Image(systemName: "pencil").accessibilityHidden(true) }
                ProgressView(value: Double(step + 1), total: 6).accessibilityLabel("Authoring step \(step + 1) of 6")
                Text(headings[step]).font(.largeTitle).fontDesign(.serif)
                switch step {
                case 0:
                    TextField("Story title", text: story.title).font(.title2).fontDesign(.serif).accessibilityLabel("Story title")
                    ProseField(title: "My current circumstances", text: answer(story, "now"), prompt: "For example: I make things in private, and sharing them feels exposing.")
                    ProseField(title: "A short premise", text: story.premise, prompt: "One or two sentences about this chapter of your life.")
                    PhotosPicker(selection: $selectedCover, matching: .images) { Label(story.wrappedValue.coverFile == nil ? "Add an optional cover" : "Replace cover", systemImage: "photo") }.frame(minHeight: 44)
                case 1:
                    ProseField(title: "What I desire", text: answer(story, "toward"), prompt: "What would a believable, meaningful change look like?")
                    ForEach(store.data.entries.filter { $0.kind == .manifestation && !$0.archived }) { entry in
                        Button {
                            if !story.wrappedValue.entryIDs.contains(entry.id) { story.wrappedValue.entryIDs.append(entry.id) }
                            story.wrappedValue.answers["toward"] = entry.title
                        } label: { Label(entry.title, systemImage: story.wrappedValue.entryIDs.contains(entry.id) ? "checkmark.circle.fill" : "circle").frame(minHeight: 44) }
                    }
                    Text("Continue to create a connected manifestation from this desire. You can develop it fully in the Grimoire.").font(.footnote).foregroundStyle(theme.secondary)
                case 2:
                    Picker("Story shape", selection: story.shape) { ForEach(StoryCatalog.shapes, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
                    Text("Shape describes the movement. Mode describes the voice.").foregroundStyle(theme.secondary)
                    Picker("Primary mode", selection: story.primaryMode) {
                        ForEach(Array(Set(StoryCatalog.modes + [story.wrappedValue.primaryMode])).sorted(), id: \.self) { Text($0).tag($0) }
                    }
                    Text("Secondary modes · choose up to two").font(.headline)
                    ForEach(StoryCatalog.modes.filter { $0 != story.wrappedValue.primaryMode }, id: \.self) { mode in
                        Toggle(mode, isOn: Binding(get: { story.wrappedValue.secondaryModes.contains(mode) }, set: { on in
                            if on && story.wrappedValue.secondaryModes.count < 2 { story.wrappedValue.secondaryModes.append(mode) }
                            else if !on { story.wrappedValue.secondaryModes.removeAll { $0 == mode } }
                        })).disabled(!story.wrappedValue.secondaryModes.contains(mode) && story.wrappedValue.secondaryModes.count == 2)
                    }
                    HStack { TextField("Custom mode", text: $customMode).accessibilityLabel("Custom primary mode"); Button("Use") { story.wrappedValue.primaryMode = customMode.trimmingCharacters(in: .whitespacesAndNewlines); customMode = "" }.disabled(customMode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                case 3:
                    ProseField(title: "Qualities and visible behaviors", text: answer(story, "becoming"), prompt: "Try: someone who acts with courage by sharing unfinished work with one trusted person.")
                    Text(modePrompt(story.wrappedValue.primaryMode)).italic().foregroundStyle(theme.secondary)
                case 4:
                    ProseField(title: "Tensions, beliefs, and constraints", text: answer(story, "tension"), prompt: "What is difficult? What is outside your influence?")
                    ProseField(title: "Support I can draw on", text: answer(story, "support"), prompt: "People, time, resources, or practices already available to you.")
                default:
                    ProseField(title: "One action within my influence", text: answer(story, "next"), prompt: "Small enough for your actual life. Try: share one imperfect sketch with a friend.")
                    ProseField(title: "A smaller version", text: answer(story, "smaller"), prompt: "On a difficult day, what would still count as an attempt?")
                    ProseField(title: "When or where", text: answer(story, "cue"), prompt: "Dates are optional. Try: the next time I hesitate to share.")
                }
                HStack {
                    if step > 0 { Button("Back") { story.wrappedValue.authoringStep -= 1 }.frame(minHeight: 44) }
                    Spacer()
                    if step < 5 { Button("Continue →") { if step == 1 { connectManifestation(story) }; story.wrappedValue.authoringStep += 1 }.buttonStyle(.borderedProminent).tint(theme.button).foregroundStyle(theme.buttonText).frame(minHeight: 44) }
                }
                Divider()
                DisclosureGroup("Write freely · your authored passage") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("This transparent template uses your answers. Editing an answer never replaces your own writing.").font(.footnote).foregroundStyle(theme.secondary)
                        ProseField(title: "My story, in my words", text: story.prose)
                        Button(story.wrappedValue.prose.isEmpty ? "Assemble from my answers" : "Preview refreshed passage") { replacePassage = true }.frame(minHeight: 44)
                    }.padding(.top, 14)
                }
                if step == 5 {
                    InvokePrimaryButton(title: "Choose this scene") {
                        connectManifestation(story)
                        if story.wrappedValue.prose.isEmpty { story.wrappedValue.prose = narrativeTemplate(story.wrappedValue) }
                        story.wrappedValue.status = "Active"
                        let next = story.wrappedValue.answers["next", default: ""]
                        if let existing = store.nextScene(for: story.wrappedValue) {
                            if let i = store.data.scenes.firstIndex(where: { $0.id == existing.id }) {
                                store.data.scenes[i].title = next; store.data.scenes[i].action = next
                                if let value = story.wrappedValue.answers["smaller"] { store.data.scenes[i].smallerVersion = value }
                                if let value = story.wrappedValue.answers["cue"] { store.data.scenes[i].cue = value }
                            }
                            sceneID = existing.id
                        }
                        else if let id = store.addScene(storyID: storyID, title: next.isEmpty ? "My next believable scene" : next, action: next) {
                            if let i = store.data.scenes.firstIndex(where: { $0.id == id }) {
                                store.data.scenes[i].smallerVersion = story.wrappedValue.answers["smaller", default: ""]
                                store.data.scenes[i].cue = story.wrappedValue.answers["cue", default: ""]
                                store.data.scenes[i].entryIDs = story.wrappedValue.entryIDs
                            }
                            sceneID = id
                        }
                    }.disabled(story.wrappedValue.answers["next", default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if store.nextScene(for: story.wrappedValue) != nil { Text("These answers will update your next planned scene.").font(.footnote).foregroundStyle(theme.secondary) }
                }
                Text("Your draft saves automatically. You can leave and return at any step.").font(.footnote).foregroundStyle(theme.secondary)
            }.padding(20)
        }.scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $replacePassage) {
                NavigationStack {
                    ScrollView { VStack(alignment: .leading, spacing: 24) {
                        Text("Proposed passage").font(.title).fontDesign(.serif); Text(narrativeTemplate(story.wrappedValue)).font(.body)
                        Text("Your current passage stays as it is until you accept. Accepting also saves the old version as a reflection.").foregroundStyle(theme.secondary)
                        InvokePrimaryButton(title: "Use this passage") {
                            if !story.wrappedValue.prose.isEmpty { store.data.reflections.append(Reflection(storyID: storyID, kind: "Earlier passage", text: story.wrappedValue.prose)) }
                            story.wrappedValue.prose = narrativeTemplate(story.wrappedValue); replacePassage = false
                        }
                    }.padding(20) }.invokeScreen().toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { replacePassage = false } } }
                }.environment(\.invokeTheme, theme).preferredColorScheme(theme.scheme)
            }
            .onChange(of: story.wrappedValue.primaryMode) { _, new in story.wrappedValue.secondaryModes.removeAll { $0 == new } }
    }
    private func connectManifestation(_ story: Binding<Story>) {
        let desire = story.wrappedValue.answers["toward", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desire.isEmpty else { return }
        if !store.data.entries.contains(where: { $0.kind == .manifestation && story.wrappedValue.entryIDs.contains($0.id) }) {
            let entry = LibraryEntry(kind: .manifestation, title: desire, fields: ["desire": desire])
            store.data.entries.append(entry); story.wrappedValue.entryIDs.append(entry.id)
        }
    }
    private func modePrompt(_ mode: String) -> String {
        switch mode { case "Comic": "What would a lovingly awkward first attempt look like?"; case "Mythic": "What quality would help you cross this threshold?"; case "Satiric": "Which inherited script deserves a raised eyebrow?"; case "Romantic": "Where could a little more beauty become a real choice?"; case "Tragic": "What matters even when the outcome has a cost?"; case "Epic": "What small act can sustain a long journey?"; default: "What would someone see you doing differently?" }
    }
}
