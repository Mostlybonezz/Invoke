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
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    private var plotted: [Scene] { Array(scenes.filter { !$0.archived }.prefix(9)) }
    private func point(_ i: Int, width: CGFloat) -> CGPoint { CGPoint(x: 22 + CGFloat(i) / CGFloat(max(plotted.count - 1, 1)) * max(width - 44, 1), y: [64.0, 32.0, 54.0, 24.0, 69.0, 47.0, 22.0, 58.0, 36.0][i % 9]) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                ZStack {
                    Path { p in
                        for i in plotted.indices { let pt = point(i, width: geo.size.width); if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) } }
                    }.stroke(theme.border, lineWidth: 0.8)
                    ForEach(Array(plotted.enumerated()), id: \.element.id) { i, scene in
                        NavigationLink { SceneDetailView(sceneID: scene.id) } label: {
                            Image(systemName: scene.status == "Experienced" ? "sparkle" : "circle")
                                .font(.system(size: scene.status == "Experienced" ? 17 : 10))
                                .foregroundStyle(scene.status == "Experienced" ? theme.accent : theme.secondary)
                                .frame(width: 44, height: 44)
                        }.position(point(i, width: geo.size.width))
                            .accessibilityLabel("\(scene.title), \(scene.status)")
                    }
                    EffectSurface(theme: InvokeEffectTheme(rawValue: theme.id) ?? .ink, level: InvokeEffectLevel(rawValue: store.data.preferences.effects) ?? .subtle, trigger: trigger, kind: .record)
                }
            }.frame(height: 88)
            Text("\(scenes.filter { $0.status == "Experienced" && !$0.archived }.count) scenes lived").font(.subheadline).foregroundStyle(theme.secondary)
            if scenes.count > 9 { Text("Showing the first nine points. Every scene is in the list below.").font(.caption).foregroundStyle(theme.secondary) }
            DisclosureGroup("Scenes as a list") {
                ForEach(scenes.filter { !$0.archived }) { scene in
                    NavigationLink { SceneDetailView(sceneID: scene.id) } label: {
                        Label("\(scene.title) · \(scene.status)", systemImage: scene.status == "Experienced" ? "checkmark.circle" : "circle").font(.subheadline).padding(.vertical, 6)
                    }
                }
            }.font(.subheadline)
        }
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
