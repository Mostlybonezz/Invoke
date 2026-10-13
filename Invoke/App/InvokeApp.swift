import SwiftUI

@main
struct InvokeApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some SwiftUI.Scene {
        WindowGroup {
            InvokeRootView().environmentObject(store)
                .environment(\.invokeTheme, InvokeTheme.named(store.data.preferences.theme))
                .preferredColorScheme(InvokeTheme.named(store.data.preferences.theme).scheme)
                .tint(InvokeTheme.named(store.data.preferences.theme).accent)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { store.flush() }
                }
        }
    }
}

struct InvokeRootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @State private var tab = 0
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { SanctuaryView() }.tabItem { Label("Sanctuary", systemImage: "sparkle") }.tag(0)
            NavigationStack { StoriesView() }.tabItem { Label("Stories", systemImage: "book") }.tag(1)
            NavigationStack { GrimoireView() }.tabItem { Label("Grimoire", systemImage: "moon") }.tag(2)
            NavigationStack { RelicCabinetView() }.tabItem { Label("Relic Cabinet", systemImage: "sparkles.rectangle.stack") }.tag(3)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if store.saveState != "Saved on this iPhone" {
                HStack(spacing: 8) { Image(systemName: store.errorMessage == nil ? "arrow.triangle.2.circlepath" : "exclamationmark.triangle"); Text(store.saveState).font(.caption); if store.errorMessage != nil { Button("Retry saving") { store.flush() }.font(.caption) } }.padding(8).frame(maxWidth: .infinity).foregroundStyle(theme.text).background(theme.surface)
            }
        }
        .sheet(isPresented: Binding(get: { !store.data.preferences.onboardingComplete }, set: { _ in })) {
            OnboardingView().interactiveDismissDisabled().environment(\.invokeTheme, theme).preferredColorScheme(theme.scheme)
        }
        .alert("Your writing matters", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
}

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack { Image(systemName: "sparkle"); Text("Invoke").font(.largeTitle).fontDesign(.serif) }
                    CelestialOrnament()
                    SectionEyebrow(text: "A little authorship. A little magic.")
                    Text("Your next chapter can begin quietly.").font(.largeTitle).fontDesign(.serif)
                    Text("Imagine a believable next chapter. Rehearse who you want to be. Live one small scene, then make room for what actually happens.").font(.title3)
                    Text("Author → Rehearse → Act → Reflect → Revise").font(.subheadline).foregroundStyle(theme.secondary)
                    Text("Your beliefs and interpretations belong to you. Your writing and photographs stay on this device; export a backup to keep a portable copy.").foregroundStyle(theme.secondary)
                    InvokePrimaryButton(title: "Begin my story") { _ = store.beginStory(); store.data.preferences.onboardingComplete = true; store.flush() }
                    Button("Explore an example collection") { store.loadExamples(); store.data.preferences.onboardingComplete = true; store.flush() }.frame(maxWidth: .infinity, minHeight: 44)
                    Text("Examples are labeled and can be removed in Settings.").font(.footnote).foregroundStyle(theme.secondary)
                }.padding(26)
            }.invokeScreen()
        }
    }
}

struct SanctuaryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @State private var storyID: UUID?
    @State private var sceneID: UUID?
    @State private var editSceneID: UUID?
    @State private var captureID: UUID?
    @State private var capture = ""
    @State private var captureKind = "Thought"
    @State private var welcomeBack = false
    @State private var appeared = false
    @State private var featureTrigger = 0
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack { Image(systemName: "sparkle").foregroundStyle(theme.accent); Text("Invoke").font(.title).fontDesign(.serif); Spacer(); NavigationLink { SettingsView() } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44).accessibilityLabel("Settings") } }
                SectionEyebrow(text: welcomeBack ? "Welcome back · right where you left off" : "A more intentional tomorrow")
                if let story = store.currentStory() {
                    NavigationLink { StoryDetailView(storyID: story.id) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { SectionEyebrow(text: "Current story"); Spacer(); if story.isExample { StatusPill(text: "Example") } }
                            Text(story.title).font(.title2).fontDesign(.serif).foregroundStyle(theme.text)
                            if let chapter = store.data.chapters.first(where: { $0.id == story.currentChapterID }) { Text(chapter.title).font(.subheadline).foregroundStyle(theme.secondary) }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain)
                    InvokeCard { ConstellationView(scenes: store.data.scenes.filter { $0.storyID == story.id }, trigger: featureTrigger) }
                    if let next = store.nextScene(for: story) {
                        InvokeCard {
                            VStack(alignment: .leading, spacing: 20) {
                                SectionEyebrow(text: "Your next scene")
                                Text(next.title).font(.largeTitle).fontDesign(.serif).fixedSize(horizontal: false, vertical: true)
                                Text("A small act still changes the page.").font(.subheadline).foregroundStyle(theme.secondary)
                                InvokePrimaryButton(title: "Enter the scene") {
                                    if let i = store.data.scenes.firstIndex(where: { $0.id == next.id }) { store.data.scenes[i].status = "In progress" }
                                    sceneID = next.id
                                }
                            }.background(ThemeScenery())
                        }
                    } else {
                        InvokeCard { VStack(alignment: .leading, spacing: 18) {
                            Text(story.status == "Draft" ? "A story is taking shape." : "What becomes possible next?").font(.title).fontDesign(.serif)
                            Text("One believable act is enough to begin.").foregroundStyle(theme.secondary)
                            InvokePrimaryButton(title: story.status == "Draft" ? "Continue authoring" : "Choose the next scene") {
                                if story.status == "Draft" { storyID = story.id }
                                else { editSceneID = store.addScene(storyID: story.id) }
                            }
                        } }
                    }
                    quickCapture
                    if let ritual = store.data.entries.first(where: { story.entryIDs.contains($0.id) && $0.kind == .ritual && !$0.archived }) {
                        NavigationLink { EntryDetailView(entryID: ritual.id) } label: {
                            InvokeCard { VStack(alignment: .leading, spacing: 12) { SectionEyebrow(text: "A ritual for this chapter"); Label(ritual.title, systemImage: "flame").font(.title3).fontDesign(.serif); Text("A moment to prepare →").font(.subheadline).foregroundStyle(theme.secondary) } }
                        }.buttonStyle(.plain)
                    }
                    if let relic = store.data.relics.first(where: { story.relicIDs.contains($0.id) && !$0.archived }) {
                        NavigationLink { RelicDetailView(relicID: relic.id) } label: {
                            InvokeCard { HStack(spacing: 16) { Image(systemName: "sparkles.rectangle.stack").font(.largeTitle).accessibilityHidden(true); VStack(alignment: .leading, spacing: 8) { SectionEyebrow(text: "From your relic cabinet"); Text(relic.name).font(.title3).fontDesign(.serif); Text(relic.meaning).font(.subheadline).lineLimit(2).foregroundStyle(theme.secondary) } } }
                        }.buttonStyle(.plain)
                    }
                    if let latest = store.data.reflections.filter({ $0.storyID == story.id && !$0.kind.hasSuffix("draft") && !$0.archived }).max(by: { $0.updatedAt < $1.updatedAt }) {
                        NavigationLink { ReflectionEditorView(reflectionID: latest.id) } label: { Label { Text("Last \(latest.kind.lowercased()) · \(latest.updatedAt.formatted(date: .abbreviated, time: .omitted))") } icon: { Image(systemName: "clock") }.font(.footnote).foregroundStyle(theme.secondary).frame(minHeight: 44) }
                    }
                } else {
                    EmptyState(symbol: "sparkle", title: "Your next chapter", message: "Begin with your real circumstances and a possibility you want to explore.")
                    InvokePrimaryButton(title: "Author a story") { storyID = store.beginStory() }
                    quickCapture
                }
                Text(store.saveState).font(.caption).foregroundStyle(theme.secondary)
            }.padding(20)
        }.toolbar(.hidden, for: .navigationBar).invokeScreen()
            .navigationDestination(item: $storyID) { StoryAuthorView(storyID: $0) }
            .navigationDestination(item: $sceneID) { SceneEntryView(sceneID: $0) }
            .navigationDestination(item: $editSceneID) { SceneDetailView(sceneID: $0) }
            .navigationDestination(item: $captureID) { ReflectionEditorView(reflectionID: $0) }
            .onAppear {
                if !appeared { welcomeBack = Date().timeIntervalSince(store.data.preferences.lastOpenedAt) > 86_400; store.data.preferences.lastOpenedAt = Date(); appeared = true }
                featureTrigger += 1
            }
            .onChange(of: store.data.preferences.onboardingComplete) { _, complete in
                if complete, let story = store.currentStory(), story.status == "Draft", !story.isExample { storyID = story.id }
            }
    }
    private var quickCapture: some View {
        InvokeCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionEyebrow(text: "Capture a thought")
                Text("Ideas also belong here.").font(.subheadline).foregroundStyle(theme.secondary)
                Menu {
                    Button("Thought") { newCapture("Thought") }
                    Button("Desire") { newCapture("Desire") }
                    Button("Unexpected event") { newCapture("Unexpected event") }
                } label: { HStack { Image(systemName: "square.and.pencil"); Text("Write in your own words…"); Spacer(); Image(systemName: "arrow.right") }.frame(minHeight: 44) }
                NavigationLink { CapturesView() } label: { Text("Revisit captured thoughts").font(.footnote).frame(minHeight: 44) }
            }
        }
    }
    private func newCapture(_ kind: String) {
        let reflection = Reflection(storyID: store.currentStory()?.id, chapterID: store.currentStory()?.currentChapterID, kind: kind)
        store.data.reflections.append(reflection); captureID = reflection.id
    }
}

struct CapturesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var search = ""
    var body: some View {
        List {
            ForEach(store.data.reflections.filter { ["Thought", "Desire", "Unexpected event"].contains($0.kind) && !$0.archived && (search.isEmpty || $0.text.localizedCaseInsensitiveContains(search)) }.sorted { $0.updatedAt > $1.updatedAt }) { reflection in
                NavigationLink { ReflectionEditorView(reflectionID: reflection.id) } label: { VStack(alignment: .leading) { Text(reflection.kind).font(.caption); Text(reflection.text.isEmpty ? "An unfinished thought" : reflection.text).lineLimit(3); Text(reflection.updatedAt, style: .date).font(.caption) } }
            }
        }.navigationTitle("Captured thoughts").searchable(text: $search).invokeScreen()
    }
}
