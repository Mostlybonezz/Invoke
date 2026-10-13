import SwiftUI

struct StoriesView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @State private var search = ""
    @State private var filter = "All"
    @State private var archive = false
    @State private var newStory: UUID?
    private var visible: [Story] {
        store.data.stories.filter { $0.archived == archive && (filter == "All" || $0.status == filter) && (search.isEmpty || "\($0.title) \($0.premise) \($0.prose)".localizedCaseInsensitiveContains(search)) }.sorted { $0.updatedAt > $1.updatedAt }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Stories you are living").font(.largeTitle).fontDesign(.serif)
                Text("There is room for more than one becoming.").foregroundStyle(theme.secondary)
                Picker("Story status", selection: $filter) { ForEach(["All"] + StoryCatalog.storyStatuses, id: \.self) { Text($0) } }.pickerStyle(.menu)
                Toggle("Show archived stories", isOn: $archive)
                if visible.isEmpty { EmptyState(symbol: "book", title: archive ? "No archived stories" : "A beginning is enough", message: "Start with where you are, and one small thing you can do.") }
                ForEach(visible) { story in
                    NavigationLink { StoryDetailView(storyID: story.id) } label: { StoryCard(story: story) }.buttonStyle(.plain)
                }
            }.padding(20)
        }.navigationTitle("Stories").navigationBarTitleDisplayMode(.inline).invokeScreen()
            .searchable(text: $search, prompt: "Search your stories")
            .toolbar { ToolbarItem(placement: .primaryAction) { Button { newStory = store.beginStory() } label: { Label("New story", systemImage: "plus") } } }
            .navigationDestination(item: $newStory) { StoryAuthorView(storyID: $0) }
    }
}

struct StoryCard: View {
    let story: Story
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    var body: some View {
        InvokeCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack { StorySigil(shape: story.shape).frame(width: 28, height: 28); SectionEyebrow(text: story.status); Spacer(); if story.isExample { StatusPill(text: "Example") } }
                Text(story.title).font(.title2).fontDesign(.serif).multilineTextAlignment(.leading)
                if !story.premise.isEmpty { Text(story.premise).font(.subheadline).foregroundStyle(theme.secondary).lineLimit(3) }
                ViewThatFits(in: .horizontal) { HStack { StatusPill(text: story.shape); StatusPill(text: story.primaryMode) }; VStack(alignment: .leading) { StatusPill(text: story.shape); StatusPill(text: story.primaryMode) } }
                if story.id == store.data.preferences.pinnedStoryID { Label("Sanctuary focus", systemImage: "pin.fill").font(.caption).foregroundStyle(theme.secondary) }
            }
        }.foregroundStyle(theme.text)
    }
}

struct StoryDetailView: View {
    let storyID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var nextScene: UUID?
    @State private var reflectionID: UUID?
    @State private var confirmDelete = false
    @State private var chapterTrigger = 0
    var body: some View {
        Group {
            if let story = store.data.stories.first(where: { $0.id == storyID }) { contents(story) }
            else { EmptyState(symbol: "book.closed", title: "Story unavailable", message: "It may have been removed.") }
        }.navigationTitle("Your story").navigationBarTitleDisplayMode(.inline).invokeScreen()
            .navigationDestination(item: $nextScene) { SceneDetailView(sceneID: $0) }
            .navigationDestination(item: $reflectionID) { ReflectionEditorView(reflectionID: $0) }
            .alert("Permanently delete this story?", isPresented: $confirmDelete) {
                Button("Delete story", role: .destructive) { store.deleteStory(storyID); dismiss() }
                Button("Cancel", role: .cancel) { }
            } message: { Text("Its chapters, scenes, and story reflections will be removed. Shared Grimoire entries and relics will remain. This cannot be undone.") }
    }
    @ViewBuilder private func contents(_ story: Story) -> some View {
        let binding = store.recordBinding(\.stories, id: storyID, fallback: story)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let name = story.coverFile, let url = store.imageURL(name), let image = UIImage(contentsOfFile: url.path) { Image(uiImage: image).resizable().scaledToFill().frame(height: 190).clipped().clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityLabel("Story cover") }
                StoryCard(story: story)
                if let chapter = store.data.chapters.first(where: { $0.id == story.currentChapterID }) {
                    SectionEyebrow(text: "Current chapter")
                    TextField("Chapter title", text: store.recordBinding(\.chapters, id: chapter.id, fallback: chapter).title).font(.title2).fontDesign(.serif).accessibilityLabel("Current chapter title")
                }
                InvokeCard { ConstellationView(scenes: store.data.scenes.filter { $0.storyID == storyID }, trigger: store.data.scenes.filter { $0.storyID == storyID && $0.status == "Experienced" }.count) }
                NavigationLink { StoryAuthorView(storyID: storyID) } label: { Label(story.status == "Draft" ? "Resume authoring" : "Edit story & passage", systemImage: "square.and.pencil").frame(minHeight: 44) }
                if !story.prose.isEmpty { Text(story.prose).font(.body).lineSpacing(6).textSelection(.enabled) }
                Picker("Story status", selection: binding.status) { ForEach(StoryCatalog.storyStatuses, id: \.self) { Text($0).tag($0) } }
                Button { store.data.preferences.pinnedStoryID = storyID } label: { Label(story.id == store.data.preferences.pinnedStoryID ? "Pinned to Sanctuary" : "Pin to Sanctuary", systemImage: "pin").frame(minHeight: 44) }
                if let next = store.nextScene(for: story) {
                    NavigationLink { SceneDetailView(sceneID: next.id) } label: { Label(next.title, systemImage: "arrow.right.circle").font(.headline).frame(minHeight: 44) }
                }
                Button { nextScene = store.addScene(storyID: storyID) } label: { Label("Add a scene", systemImage: "plus").frame(minHeight: 44) }
                NavigationLink { StoryConnectionsView(storyID: storyID) } label: { Label("Connect beliefs, rituals & relics", systemImage: "link").frame(minHeight: 44) }
                ForEach(store.data.entries.filter { story.entryIDs.contains($0.id) }) { entry in
                    NavigationLink { EntryDetailView(entryID: entry.id) } label: { Label(entry.title + (entry.archived ? " Ãƒâ€šÃ‚Â· Archived" : ""), systemImage: entry.kind.symbol).frame(minHeight: 44) }
                }
                ForEach(store.data.relics.filter { story.relicIDs.contains($0.id) }) { relic in
                    NavigationLink { RelicDetailView(relicID: relic.id) } label: { Label(relic.name + (relic.archived ? " Ãƒâ€šÃ‚Â· Archived" : ""), systemImage: "sparkles.rectangle.stack").frame(minHeight: 44) }
                }
                Divider()
                Button("A plot twist occurred") { reflectionID = store.existingReflection(storyID: storyID, sceneID: nil, kind: "Plot twist draft") }.frame(minHeight: 44)
                Button("This role no longer fits") { reflectionID = store.existingReflection(storyID: storyID, sceneID: nil, kind: "Role revision draft") }.frame(minHeight: 44)
                Button("Close this chapter") { reflectionID = store.existingReflection(storyID: storyID, sceneID: nil, kind: "Chapter closing draft") }.frame(minHeight: 44)
                let closed = store.data.chapters.filter { $0.storyID == storyID && $0.closedAt != nil }
                if !closed.isEmpty {
                    SectionEyebrow(text: "Chapter keepsakes")
                    ForEach(closed) { chapter in NavigationLink { ChapterKeepsakeView(chapterID: chapter.id) } label: { Label(chapter.title, systemImage: "book.closed").frame(minHeight: 44) } }
                }
                let reflections = store.data.reflections.filter { $0.storyID == storyID && !$0.archived && (!$0.text.isEmpty || $0.answers.values.contains { !$0.isEmpty }) }.sorted { $0.updatedAt > $1.updatedAt }
                if !reflections.isEmpty {
                    SectionEyebrow(text: "Reflections & earlier words")
                    ForEach(reflections) { reflection in
                        NavigationLink { ReflectionEditorView(reflectionID: reflection.id) } label: {
                            VStack(alignment: .leading, spacing: 6) { Text(reflection.kind).font(.headline); Text(reflection.text.isEmpty ? reflection.answers.filter { !$0.key.hasPrefix("_") }.values.filter { !$0.isEmpty }.joined(separator: " Ãƒâ€šÃ‚Â· ") : reflection.text).lineLimit(2).foregroundStyle(theme.secondary); Text(reflection.createdAt, style: .date).font(.caption) }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                    }
                }
                Divider()
                Button(story.archived ? "Restore from archive" : "Archive story") { binding.wrappedValue.archived.toggle() }.frame(minHeight: 44)
                Button("Permanently delete story", role: .destructive) { confirmDelete = true }.frame(minHeight: 44)
            }.padding(20)
        }.scrollDismissesKeyboard(.interactively)
    }
}

struct ChapterKeepsakeView: View {
    let chapterID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @State private var trigger = 0
    var body: some View {
        ScrollView {
            if let chapter = store.data.chapters.first(where: { $0.id == chapterID }) {
                VStack(alignment: .leading, spacing: 24) {
                    InvokeCard {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionEyebrow(text: "Invoke Ãƒâ€šÃ‚Â· Chapter keepsake")
                            Text(chapter.title).font(.largeTitle).fontDesign(.serif)
                            if let date = chapter.closedAt { Text(date, style: .date).foregroundStyle(theme.secondary) }
                            CelestialOrnament()
                        }.background(EffectSurface(theme: InvokeEffectTheme(rawValue: theme.id) ?? .ink, level: InvokeEffectLevel(rawValue: store.data.preferences.effects) ?? .subtle, trigger: trigger, kind: .chapter))
                    }
                    Text("This chapter is preserved. The story may continue.").italic().foregroundStyle(theme.secondary)
                    ForEach(store.data.scenes.filter { chapter.sceneIDs.contains($0.id) }) { scene in
                        NavigationLink { SceneDetailView(sceneID: scene.id) } label: { InvokeCard { VStack(alignment: .leading, spacing: 10) { StatusPill(text: scene.status); Text(scene.title).font(.title3).fontDesign(.serif); Text(scene.action).font(.body) } } }.buttonStyle(.plain)
                    }
                    ForEach(store.data.reflections.filter { chapter.reflectionIDs.contains($0.id) }) { reflection in
                        InvokeCard { VStack(alignment: .leading, spacing: 12) { SectionEyebrow(text: reflection.kind); ForEach(reflection.answers.keys.filter { !$0.hasPrefix("_") }.sorted(), id: \.self) { key in if let value = reflection.answers[key], !value.isEmpty { Text(key).font(.headline); Text(value).textSelection(.enabled) } }; if !reflection.text.isEmpty { Text(reflection.text).textSelection(.enabled) } } }
                    }
                    ForEach(store.data.relics.filter { chapter.relicIDs.contains($0.id) }) { relic in NavigationLink { RelicDetailView(relicID: relic.id) } label: { Label(relic.name, systemImage: "sparkles.rectangle.stack").frame(minHeight: 44) } }
                }.padding(20)
            }
        }.navigationTitle("Keepsake").navigationBarTitleDisplayMode(.inline).invokeScreen().onAppear { trigger += 1 }
    }
}
