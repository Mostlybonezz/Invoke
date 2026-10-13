import SwiftUI

extension AppStore {
    func recordBinding<T: Identifiable>(_ path: WritableKeyPath<AppData, [T]>, id: T.ID, fallback: T) -> Binding<T> {
        Binding(get: { self.data[keyPath: path].first { $0.id == id } ?? fallback }, set: { value in
            guard let index = self.data[keyPath: path].firstIndex(where: { $0.id == id }) else { return }
            self.data[keyPath: path][index] = value
        })
    }
    @discardableResult func beginStory() -> UUID {
        var story = Story(title: "Untitled story")
        let chapter = Chapter(storyID: story.id)
        story.currentChapterID = chapter.id
        data.chapters.append(chapter); data.stories.append(story)
        if data.preferences.pinnedStoryID == nil { data.preferences.pinnedStoryID = story.id }
        return story.id
    }
    @discardableResult func addScene(storyID: UUID, title: String = "My next believable scene", action: String = "") -> UUID? {
        guard let i = data.stories.firstIndex(where: { $0.id == storyID }), let chapterID = data.stories[i].currentChapterID,
              let c = data.chapters.firstIndex(where: { $0.id == chapterID }), data.chapters[c].closedAt == nil else { return nil }
        let scene = Scene(storyID: storyID, chapterID: chapterID, title: title, action: action)
        data.scenes.append(scene); data.chapters[c].sceneIDs.append(scene.id); data.chapters[c].updatedAt = Date()
        data.stories[i].updatedAt = Date()
        return scene.id
    }
    func currentStory() -> Story? {
        data.stories.first { $0.id == data.preferences.pinnedStoryID && !$0.archived }
        ?? data.stories.first { !$0.archived && $0.status == "Active" }
        ?? data.stories.first { !$0.archived && $0.status != "Closed" }
    }
    func nextScene(for story: Story) -> Scene? {
        data.scenes.first { $0.storyID == story.id && $0.chapterID == story.currentChapterID && !$0.archived && ["Planned", "In progress"].contains($0.status) }
    }
    func existingReflection(storyID: UUID?, sceneID: UUID?, kind: String) -> UUID {
        let chapterID = sceneID.flatMap { id in data.scenes.first { $0.id == id }?.chapterID }
            ?? data.stories.first { $0.id == storyID }?.currentChapterID
        if let existing = data.reflections.first(where: { $0.storyID == storyID && $0.sceneID == sceneID && $0.chapterID == chapterID && $0.kind == kind && !$0.archived }) { return existing.id }
        let reflection = Reflection(storyID: storyID, chapterID: chapterID, sceneID: sceneID, kind: kind)
        data.reflections.append(reflection)
        return reflection.id
    }
}

func narrativeTemplate(_ story: Story) -> String {
    let a = story.answers
    return "I am in a chapter where \(a["now", default: "…"]). I want to move toward \(a["toward", default: "…"]). I am practicing being someone who \(a["becoming", default: "…"]). The tension I am working with is \(a["tension", default: "…"]). My next believable act is \(a["next", default: "…"])."
}

struct ConstellationView: View {
    let scenes: [Scene]
    var trigger = 0
    var storyID: UUID? = nil
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @Namespace private var constellationZoom

    var body: some View {
        NavigationLink {
            ConstellationExplorerView(storyID: storyID ?? scenes.first?.storyID, fallbackSceneIDs: scenes.map(\.id))
                .modifier(ConstellationZoomDestination(id: "story-constellation", namespace: constellationZoom))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionEyebrow(text: "Your constellation")
                    Spacer()
                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(.caption).foregroundStyle(theme.secondary)
                }
                ConstellationMiniature(scenes: scenes)
                    .background(EffectSurface(theme: InvokeEffectTheme(rawValue: theme.id) ?? .ink, level: InvokeEffectLevel(rawValue: store.data.preferences.effects) ?? .subtle, trigger: trigger, kind: .record))
                Text("\(scenes.filter { $0.status == "Experienced" }.count) scenes lived · \(scenes.count) scenes in your sky")
                    .font(.subheadline).foregroundStyle(theme.secondary)
                HStack {
                    Text("Explore every scene").font(.headline)
                    Spacer()
                    Image(systemName: "arrow.up.right").accessibilityHidden(true)
                }.frame(minHeight: 44)
            }.foregroundStyle(theme.text).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(ConstellationZoomSource(id: "story-constellation", namespace: constellationZoom))
        .accessibilityIdentifier("constellation-preview")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Explore constellation, \(scenes.count) scenes, \(scenes.filter { $0.status == "Experienced" }.count) experienced")
        .accessibilityHint("Opens the full star map and an accessible scene list")
    }
}

struct StoryConnectionsView: View {
    let storyID: UUID
    @EnvironmentObject private var store: AppStore
    var body: some View {
        if let story = store.data.stories.first(where: { $0.id == storyID }) {
            let binding = store.recordBinding(\.stories, id: storyID, fallback: story)
            Form {
                Section("Grimoire") {
                    ForEach(store.data.entries.filter { !$0.archived }) { entry in
                        Toggle(isOn: Binding(get: { binding.wrappedValue.entryIDs.contains(entry.id) }, set: { selected in
                            if selected { binding.wrappedValue.entryIDs.append(entry.id) } else { binding.wrappedValue.entryIDs.removeAll { $0 == entry.id } }
                        })) { Label(entry.title, systemImage: entry.kind.symbol) }
                    }
                    if store.data.entries.isEmpty { Text("Create entries in the Grimoire, then connect them here.") }
                }
                Section("Relics") {
                    ForEach(store.data.relics.filter { !$0.archived }) { relic in
                        Toggle(relic.name, isOn: Binding(get: { binding.wrappedValue.relicIDs.contains(relic.id) }, set: { selected in
                            if selected { binding.wrappedValue.relicIDs.append(relic.id) } else { binding.wrappedValue.relicIDs.removeAll { $0 == relic.id } }
                        }))
                    }
                }
            }.navigationTitle("Connections").invokeScreen()
        }
    }
}
