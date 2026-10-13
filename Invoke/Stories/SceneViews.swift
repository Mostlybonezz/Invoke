import SwiftUI

struct SceneDetailView: View {
    let sceneID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @State private var enter = false
    @State private var reflectionID: UUID?
    var body: some View {
        Group {
            if let scene = store.data.scenes.first(where: { $0.id == sceneID }) {
                let binding = store.recordBinding(\.scenes, id: sceneID, fallback: scene)
                let closed = store.data.chapters.first { $0.id == scene.chapterID }?.closedAt != nil
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        SectionEyebrow(text: closed ? "Preserved scene" : "One believable act")
                        TextField("Scene title", text: binding.title, axis: .vertical).font(.largeTitle).fontDesign(.serif).accessibilityLabel("Scene title").disabled(closed)
                        if closed { StatusPill(text: scene.status); Text("This scene belongs to a closed chapter.").foregroundStyle(theme.secondary) }
                        Group {
                            ProseField(title: "What I will do", text: binding.action)
                            ProseField(title: "Why it matters", text: binding.why)
                            ProseField(title: "When or where", text: binding.cue, prompt: "A date is optional. A situation can be your cue.")
                            TextField("Approximate effort or duration", text: binding.effort).accessibilityLabel("Approximate effort or duration")
                            ProseField(title: "A smaller version", text: binding.smallerVersion)
                            Picker("Scene status", selection: binding.status) { ForEach(StoryCatalog.sceneStatuses, id: \.self) { Text($0).tag($0) } }
                        }.disabled(closed)
                        if !closed {
                            DisclosureGroup("Preparation · rituals, beliefs & relics") {
                                VStack(alignment: .leading, spacing: 14) {
                                    ForEach(store.data.entries.filter { !$0.archived }) { entry in
                                        Toggle(entry.title, isOn: Binding(get: { binding.wrappedValue.entryIDs.contains(entry.id) }, set: { on in if on { binding.wrappedValue.entryIDs.append(entry.id) } else { binding.wrappedValue.entryIDs.removeAll { $0 == entry.id } } }))
                                    }
                                    ForEach(store.data.relics.filter { !$0.archived }) { relic in
                                        Toggle(relic.name, isOn: Binding(get: { binding.wrappedValue.relicIDs.contains(relic.id) }, set: { on in if on { binding.wrappedValue.relicIDs.append(relic.id) } else { binding.wrappedValue.relicIDs.removeAll { $0 == relic.id } } }))
                                    }
                                }.padding(.top, 14)
                            }
                            InvokePrimaryButton(title: "Enter the scene") { binding.wrappedValue.status = "In progress"; enter = true }
                            Button("Reflect on an attempt") { reflectionID = store.existingReflection(storyID: scene.storyID, sceneID: sceneID, kind: "Scene draft") }.frame(minHeight: 44)
                        }
                        ForEach(store.data.reflections.filter { $0.sceneID == sceneID && !$0.archived }) { reflection in
                            NavigationLink { ReflectionEditorView(reflectionID: reflection.id) } label: { Label(reflection.kind, systemImage: "text.book.closed").frame(minHeight: 44) }
                        }
                    }.padding(20)
                }.scrollDismissesKeyboard(.interactively)
            } else { EmptyState(symbol: "sparkle", title: "Scene unavailable", message: "It may have been removed.") }
        }.navigationTitle("Scene").navigationBarTitleDisplayMode(.inline).invokeScreen()
            .navigationDestination(isPresented: $enter) { SceneEntryView(sceneID: sceneID) }
            .navigationDestination(item: $reflectionID) { ReflectionEditorView(reflectionID: $0) }
    }
}

struct SceneEntryView: View {
    let sceneID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @State private var trigger = 0
    @State private var reflectionID: UUID?
    @State private var smaller = false
    var body: some View {
        ScrollView {
            if let scene = store.data.scenes.first(where: { $0.id == sceneID }) {
                let closed = store.data.chapters.first { $0.id == scene.chapterID }?.closedAt != nil
                VStack(alignment: .leading, spacing: 26) {
                    CelestialOrnament()
                    SectionEyebrow(text: "The scene is yours")
                    Text(scene.title).font(.largeTitle).fontDesign(.serif)
                    InvokeCard {
                        VStack(alignment: .leading, spacing: 18) {
                            if !scene.cue.isEmpty { Label(scene.cue, systemImage: "clock").foregroundStyle(theme.secondary) }
                            Text(smaller && !scene.smallerVersion.isEmpty ? scene.smallerVersion : scene.action).font(.title2).fontDesign(.serif)
                            if !scene.effort.isEmpty { Text(scene.effort).font(.subheadline).foregroundStyle(theme.secondary) }
                            if !scene.why.isEmpty { Text(scene.why).foregroundStyle(theme.secondary) }
                        }.background(EffectSurface(theme: InvokeEffectTheme(rawValue: theme.id) ?? .ink, level: InvokeEffectLevel(rawValue: store.data.preferences.effects) ?? .subtle, trigger: trigger, kind: .card).clipShape(RoundedRectangle(cornerRadius: 16)))
                    }.overlay(ThemeScenery().clipShape(RoundedRectangle(cornerRadius: 16)))
                    if !scene.smallerVersion.isEmpty { Toggle("Use the smaller version today", isOn: $smaller) }
                    ForEach(store.data.entries.filter { scene.entryIDs.contains($0.id) }) { entry in NavigationLink { EntryDetailView(entryID: entry.id) } label: { Label(entry.title, systemImage: entry.kind.symbol).frame(minHeight: 44) } }
                    ForEach(store.data.relics.filter { scene.relicIDs.contains($0.id) }) { relic in NavigationLink { RelicDetailView(relicID: relic.id) } label: { Label(relic.name, systemImage: "sparkles.rectangle.stack").frame(minHeight: 44) } }
                    Text("An attempt counts, even when the outcome develops opinions.").italic().foregroundStyle(theme.secondary)
                    if closed {
                        Label("This scene is preserved in a closed chapter.", systemImage: "lock")
                        NavigationLink("Revisit its chapter") { ChapterKeepsakeView(chapterID: scene.chapterID) }.frame(minHeight: 44)
                    } else {
                        InvokePrimaryButton(title: "Record what happened") { reflectionID = store.existingReflection(storyID: scene.storyID, sceneID: sceneID, kind: "Scene draft") }
                        Button("Leave this scene for another day") { if let i = store.data.scenes.firstIndex(where: { $0.id == sceneID }) { store.data.scenes[i].status = "Planned" } }.frame(minHeight: 44)
                    }
                }.padding(20)
            }
        }.navigationTitle("Enter the scene").navigationBarTitleDisplayMode(.inline).invokeScreen().onAppear { trigger += 1 }
            .navigationDestination(item: $reflectionID) { ReflectionEditorView(reflectionID: $0) }
    }
}
