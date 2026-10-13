import SwiftUI

struct ReflectionEditorView: View {
    let reflectionID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @State private var trigger = 0
    @State private var recorded = false
    @State private var closeConfirm = false
    @State private var applyConfirm = false
    @State private var newChapterTitle = "A new beginning"
    @State private var keptSceneIDs: Set<UUID> = []
    @State private var keptRelicIDs: Set<UUID> = []
    @State private var keptReflectionIDs: Set<UUID> = []
    @State private var selectedInitial = false
    @State private var keepsakeID: UUID?
    private var reflection: Reflection? { store.data.reflections.first { $0.id == reflectionID } }
    var body: some View {
        Group {
            if let reflection { content(reflection) }
            else { EmptyState(symbol: "text.book.closed", title: "Reflection unavailable", message: "It may have been removed.") }
        }.navigationTitle("Reflect & revise").navigationBarTitleDisplayMode(.inline).invokeScreen()
            .navigationDestination(item: $keepsakeID) { ChapterKeepsakeView(chapterID: $0) }
    }
    private func prompts(_ kind: String) -> [String] {
        if kind.hasPrefix("Scene") { return ["What happened?", "What did I choose or try?", "What did I learn?", "What would I change next time?"] }
        if kind.hasPrefix("Plot twist") { return ["What changed?", "What does this mean for the story?", "What remains important?", "What becomes the next believable scene?"] }
        if kind.hasPrefix("Chapter closing") { return ["What happened?", "What did I learn?", "What am I carrying forward?", "What am I leaving behind?"] }
        if kind.hasPrefix("Role revision") { return ["What no longer fits?", "Which qualities still feel like mine?", "What belief might I revisit?", "What would I like to practice instead?"] }
        return []
    }
    private func field(_ binding: Binding<Reflection>, _ key: String) -> Binding<String> {
        Binding(get: { binding.wrappedValue.answers[key, default: ""] }, set: { binding.wrappedValue.answers[key] = $0; binding.wrappedValue.updatedAt = Date() })
    }
    @ViewBuilder private func content(_ reflection: Reflection) -> some View {
        let binding = store.recordBinding(\.reflections, id: reflectionID, fallback: reflection)
        let chapter = store.data.chapters.first { $0.id == reflection.chapterID }
        let locked = chapter?.closedAt != nil
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionEyebrow(text: reflection.kind.replacingOccurrences(of: " draft", with: ""))
                Text(headline(reflection.kind)).font(.largeTitle).fontDesign(.serif)
                if locked { Label("Preserved in a closed chapter", systemImage: "lock").foregroundStyle(theme.secondary) }
                if reflection.kind.hasPrefix("Scene") {
                    Text("Your choices and the outcome are different things. A meaningful attempt belongs here, whatever happened next.").foregroundStyle(theme.secondary)
                }
                Group {
                    ProseField(title: "A sentence is enough", text: binding.text, prompt: "Or use any of the prompts below. There is no required length.")
                    ForEach(prompts(reflection.kind), id: \.self) { prompt in ProseField(title: prompt, text: field(binding, prompt)) }
                }.disabled(locked)
                if !locked && !recorded && reflection.kind.hasSuffix("draft") {
                    if reflection.kind.hasPrefix("Chapter closing") {
                        TextField("Next chapter title", text: $newChapterTitle).accessibilityLabel("Next chapter title")
                        DisclosureGroup("Choose scenes for this keepsake") {
                            ForEach(store.data.scenes.filter { $0.chapterID == reflection.chapterID }) { scene in
                                Toggle(scene.title, isOn: Binding(get: { keptSceneIDs.contains(scene.id) }, set: { if $0 { keptSceneIDs.insert(scene.id) } else { keptSceneIDs.remove(scene.id) } }))
                            }
                        }
                        DisclosureGroup("Choose relics for this keepsake") {
                            ForEach(store.data.relics.filter { !$0.archived }) { relic in
                                Toggle(relic.name, isOn: Binding(get: { keptRelicIDs.contains(relic.id) }, set: { if $0 { keptRelicIDs.insert(relic.id) } else { keptRelicIDs.remove(relic.id) } }))
                            }
                        }
                        DisclosureGroup("Choose earlier reflections for this keepsake") {
                            ForEach(store.data.reflections.filter { $0.chapterID == reflection.chapterID && $0.id != reflectionID && !$0.archived }) { item in
                                Toggle(item.text.isEmpty ? item.kind : String(item.text.prefix(100)), isOn: Binding(get: { keptReflectionIDs.contains(item.id) }, set: { if $0 { keptReflectionIDs.insert(item.id) } else { keptReflectionIDs.remove(item.id) } }))
                            }
                        }
                        InvokePrimaryButton(title: "Close this chapter") { closeConfirm = true }.disabled(isEmpty(reflection))
                    } else {
                        InvokePrimaryButton(title: reflection.kind.hasPrefix("Scene") ? "Record this scene" : "Save this reflection") { record(binding) }.disabled(isEmpty(reflection))
                    }
                }
                if recorded || (!reflection.kind.hasSuffix("draft") && !locked) {
                    InvokeCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(store.saveState == "Saved on this iPhone" ? (reflection.kind == "Scene" ? "Your attempt is part of the story." : "Your words are saved.") : store.saveState, systemImage: store.saveState == "Saved on this iPhone" ? "checkmark.seal" : "exclamationmark.triangle").font(.headline)
                            if let id = reflection.storyID { NavigationLink("Return to your story") { StoryDetailView(storyID: id) }.frame(minHeight: 44) }
                        }.background(EffectSurface(theme: InvokeEffectTheme(rawValue: theme.id) ?? .ink, level: InvokeEffectLevel(rawValue: store.data.preferences.effects) ?? .subtle, trigger: trigger, kind: .record))
                    }
                    if reflection.kind == "Plot twist" {
                        Button("Use these words to revise the story") { applyConfirm = true }.frame(minHeight: 44)
                        Text("Adds the changed circumstances to your structured answers and creates a planned scene from your proposed next act. Your authored passage is preserved.").font(.footnote).foregroundStyle(theme.secondary)
                        if let id = reflection.storyID { NavigationLink("Review story, manifestation & connections") { StoryDetailView(storyID: id) }.frame(minHeight: 44) }
                    }
                    if reflection.kind == "Role revision", let id = reflection.storyID {
                        NavigationLink("Revisit qualities and beliefs") { StoryAuthorView(storyID: id) }.frame(minHeight: 44)
                        NavigationLink("Review connected beliefs") { StoryConnectionsView(storyID: id) }.frame(minHeight: 44)
                    }
                }
                Text(locked ? "This chapter stays as you left it." : "Saved as you write. You can leave and return.").font(.footnote).foregroundStyle(theme.secondary)
            }.padding(20)
        }.scrollDismissesKeyboard(.interactively)
            .onAppear {
                if !selectedInitial {
                    newChapterTitle = reflection.answers["_nextChapter", default: "A new beginning"]
                    keptSceneIDs = reflection.answers["_scenes"].map(decodeSelection) ?? Set(store.data.scenes.filter { $0.chapterID == reflection.chapterID && $0.status == "Experienced" }.map(\.id))
                    keptRelicIDs = reflection.answers["_relics"].map(decodeSelection) ?? Set(store.data.stories.first { $0.id == reflection.storyID }?.relicIDs ?? [])
                    keptReflectionIDs = reflection.answers["_reflections"].map(decodeSelection) ?? Set(store.data.reflections.filter { $0.chapterID == reflection.chapterID && $0.id != reflectionID && !$0.archived }.map(\.id))
                    selectedInitial = true
                }
            }
            .onChange(of: newChapterTitle) { _, value in if !locked { binding.wrappedValue.answers["_nextChapter"] = value } }
            .onChange(of: keptSceneIDs) { _, value in if !locked { binding.wrappedValue.answers["_scenes"] = value.map(\.uuidString).sorted().joined(separator: ",") } }
            .onChange(of: keptRelicIDs) { _, value in if !locked { binding.wrappedValue.answers["_relics"] = value.map(\.uuidString).sorted().joined(separator: ",") } }
            .onChange(of: keptReflectionIDs) { _, value in if !locked { binding.wrappedValue.answers["_reflections"] = value.map(\.uuidString).sorted().joined(separator: ",") } }
            .confirmationDialog("Close this chapter and begin the next?", isPresented: $closeConfirm, titleVisibility: .visible) {
                Button("Preserve chapter & continue") { closeChapter(binding) }
            } message: { Text("Scenes and reflections in this chapter become read-only. Your selected scenes and relics appear in its keepsake. You can continue the same story in a new chapter.") }
            .confirmationDialog("Apply the plot twist?", isPresented: $applyConfirm, titleVisibility: .visible) {
                Button("Revise answers & add next scene") {
                    guard let i = store.data.stories.firstIndex(where: { $0.id == reflection.storyID }) else { return }
                    let prior = store.data.stories[i]
                    store.data.reflections.append(Reflection(storyID: prior.id, chapterID: prior.currentChapterID, kind: "Before the plot twist", answers: prior.answers, text: prior.prose))
                    let changed = reflection.answers["What changed?", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
                    let meaning = reflection.answers["What does this mean for the story?", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !changed.isEmpty { store.data.stories[i].answers["now"] = changed }
                    if !meaning.isEmpty { store.data.stories[i].answers["tension"] = meaning }
                    store.data.stories[i].updatedAt = Date()
                    let next = reflection.answers["What becomes the next believable scene?", default: ""]
                    if !next.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { _ = store.addScene(storyID: store.data.stories[i].id, title: next, action: next) }
                }
            } message: { Text("Your previous words remain in this reflection. Review your other planned scenes afterward and skip or revise any that no longer fit.") }
    }
    private func decodeSelection(_ value: String) -> Set<UUID> { Set(value.split(separator: ",").compactMap { UUID(uuidString: String($0)) }) }
    private func isEmpty(_ r: Reflection) -> Bool { r.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && r.answers.filter { !$0.key.hasPrefix("_") }.values.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    private func headline(_ kind: String) -> String {
        if kind.hasPrefix("Scene") { return "A small act changes the page." }
        if kind.hasPrefix("Plot twist") { return "The plot has developed opinions." }
        if kind.hasPrefix("Chapter closing") { return "Some endings make room." }
        if kind.hasPrefix("Role revision") { return "You can outgrow the role." }
        return "A thought belongs here."
    }
    private func record(_ binding: Binding<Reflection>) {
        binding.wrappedValue.kind = binding.wrappedValue.kind.replacingOccurrences(of: " draft", with: "")
        binding.wrappedValue.updatedAt = Date()
        if binding.wrappedValue.kind == "Scene", let i = store.data.scenes.firstIndex(where: { $0.id == binding.wrappedValue.sceneID }) {
            store.data.scenes[i].status = "Experienced"; store.data.scenes[i].updatedAt = Date()
        }
        if let c = store.data.chapters.firstIndex(where: { $0.id == binding.wrappedValue.chapterID }), !store.data.chapters[c].reflectionIDs.contains(reflectionID) { store.data.chapters[c].reflectionIDs.append(reflectionID) }
        if let i = store.data.stories.firstIndex(where: { $0.id == binding.wrappedValue.storyID }) { store.data.stories[i].updatedAt = Date() }
        store.flush(); if store.saveState == "Saved on this iPhone" { trigger += 1 }; recorded = true
    }
    private func closeChapter(_ binding: Binding<Reflection>) {
        guard let storyID = binding.wrappedValue.storyID, let s = store.data.stories.firstIndex(where: { $0.id == storyID }),
              let c = store.data.chapters.firstIndex(where: { $0.id == binding.wrappedValue.chapterID }), store.data.chapters[c].closedAt == nil else { return }
        record(binding)
        let oldID = store.data.chapters[c].id
        store.data.chapters[c].closedAt = Date(); store.data.chapters[c].updatedAt = Date()
        store.data.chapters[c].sceneIDs = store.data.scenes.filter { keptSceneIDs.contains($0.id) }.map(\.id)
        store.data.chapters[c].relicIDs = Array(keptRelicIDs)
        store.data.chapters[c].reflectionIDs = store.data.reflections.filter { $0.chapterID == oldID && (keptReflectionIDs.contains($0.id) || $0.id == reflectionID) }.map(\.id)
        let next = Chapter(storyID: storyID, title: newChapterTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "A new beginning" : newChapterTitle)
        store.data.chapters.append(next); store.data.stories[s].currentChapterID = next.id
        store.flush(); keepsakeID = oldID
    }
}
