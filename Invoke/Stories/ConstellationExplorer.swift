import SwiftUI

/// Two independent namespaces let native navigation zoom from the Sanctuary card
/// into the map, and from a map star into a scene. iOS 17 keeps ordinary navigation.
struct ConstellationZoomSource: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    @InvokeReducedMotion private var reduceMotion

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18.0, *), !reduceMotion {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

struct ConstellationZoomDestination: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    @InvokeReducedMotion private var reduceMotion

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18.0, *), !reduceMotion {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}

private struct ConstellationPalette {
    let background: Color
    let haze: Color
    let text: Color
    let label: Color
    let line: Color
    let light: Color

    init(theme: InvokeTheme) {
        switch theme.id {
        case "velvet":
            background = Color(hex: 0x160F20)
            haze = Color(hex: 0x49304D)
            text = Color(hex: 0xF4E8DC)
            label = Color(hex: 0xCCB6CD)
            line = Color(hex: 0xA98CAA)
            light = Color(hex: 0xF2CCB2)
        case "astral":
            background = Color(hex: 0x11182F)
            haze = Color(hex: 0x3F365F)
            text = Color(hex: 0xFFF0E4)
            label = Color(hex: 0xC3BFD9)
            line = Color(hex: 0x958BBC)
            light = Color(hex: 0xFFB67C)
        default:
            background = Color(hex: 0xEEE6D8)
            haze = Color(hex: 0xDCCCB6)
            text = Color(hex: 0x332631)
            label = Color(hex: 0x6A5860)
            line = Color(hex: 0x8B7384)
            light = Color(hex: 0x862E37)
        }
    }
}

/// Static Canvas decoration has no timer, random animation, or idle GPU schedule.
private struct ConstellationSky: View {
    let palette: ConstellationPalette
    var body: some View {
        ZStack {
            palette.background
            RadialGradient(colors: [palette.haze.opacity(0.7), palette.background.opacity(0)], center: .init(x: 0.70, y: 0.35), startRadius: 10, endRadius: 340)
            Canvas { context, size in
                for index in 0..<100 {
                    let x = CGFloat((index * 137 + 43) % 997) / 997 * size.width
                    let y = CGFloat((index * 229 + 71) % 991) / 991 * size.height
                    let radius: CGFloat = index.isMultiple(of: 9) ? 1.2 : 0.55
                    let star = CGRect(x: x, y: y, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: star), with: .color(palette.label.opacity(index.isMultiple(of: 9) ? 0.48 : 0.25)))
                }
                for index in 0..<3 {
                    var orbit = Path()
                    let inset = CGFloat(index * 34)
                    orbit.addEllipse(in: CGRect(x: size.width * 0.30 - inset, y: 28 - inset, width: size.width * 0.88 + inset * 2, height: size.height * 0.8 + inset * 2))
                    context.stroke(orbit, with: .color(palette.line.opacity(0.10)), lineWidth: 0.6)
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// This preview is illustrative; its label explicitly opens every scene in the explorer.
struct ConstellationMiniature: View {
    let scenes: [Scene]
    @Environment(\.invokeTheme) private var theme
    private var palette: ConstellationPalette { ConstellationPalette(theme: theme) }

    var body: some View {
        Canvas { context, size in
            let count = max(1, min(scenes.count, 8))
            let heights: [CGFloat] = [0.62, 0.26, 0.55, 0.18, 0.73, 0.40, 0.61, 0.25]
            let points = (0..<count).map { index in
                CGPoint(x: 18 + CGFloat(index) / CGFloat(max(count - 1, 1)) * max(size.width - 36, 1), y: 12 + heights[index] * max(size.height - 24, 1))
            }
            var line = Path()
            for (index, point) in points.enumerated() {
                if index == 0 { line.move(to: point) } else { line.addLine(to: point) }
            }
            context.stroke(line, with: .color(palette.line.opacity(0.65)), lineWidth: 0.8)
            for (index, point) in points.enumerated() {
                let lived = index < scenes.count && scenes[index].status == "Experienced"
                let diameter: CGFloat = lived ? 10 : 6
                if lived {
                    for halo in 0..<3 {
                        let width = diameter + CGFloat((halo + 1) * 6)
                        context.fill(Path(ellipseIn: CGRect(x: point.x - width / 2, y: point.y - width / 2, width: width, height: width)), with: .color(palette.light.opacity(0.035)))
                    }
                }
                let circle = Path(ellipseIn: CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2, width: diameter, height: diameter))
                context.fill(circle, with: .color(lived ? palette.light : palette.label.opacity(0.6)))
            }
        }.frame(height: 88).accessibilityHidden(true)
    }
}

struct ConstellationExplorerView: View {
    let storyID: UUID?
    var fallbackSceneIDs: [UUID] = []
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Namespace private var sceneZoom
    @State private var chapterKey = "all"
    @State private var page = 0
    @State private var presentation = "Map"
    @State private var initialized = false
    @State private var revealTrigger = 0
    private let pageSize = 6

    private var story: Story? { store.data.stories.first { $0.id == storyID } }
    private var scenes: [Scene] {
        store.data.scenes.filter { scene in
            if let storyID { return scene.storyID == storyID }
            return fallbackSceneIDs.contains(scene.id)
        }.sorted { $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt }
    }
    private var chapters: [Chapter] {
        store.data.chapters.filter { chapter in
            if let storyID { return chapter.storyID == storyID }
            return scenes.contains { $0.chapterID == chapter.id }
        }.sorted { $0.createdAt < $1.createdAt }
    }
    private var filteredScenes: [Scene] { scenes.filter { chapterKey == "all" || $0.chapterID.uuidString == chapterKey } }
    private var pageCount: Int { max(1, (filteredScenes.count + pageSize - 1) / pageSize) }
    private var safePage: Int { min(max(0, page), pageCount - 1) }
    private var pageScenes: [Scene] { Array(filteredScenes.dropFirst(safePage * pageSize).prefix(pageSize)) }
    private var palette: ConstellationPalette { ConstellationPalette(theme: theme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                controls
                if filteredScenes.isEmpty {
                    EmptyState(symbol: "sparkles", title: "Room for another star", message: "Each scene you plan becomes a point here. Experienced scenes shine brighter.")
                    if let storyID { NavigationLink("Return to this story") { StoryDetailView(storyID: storyID) }.frame(minHeight: 44) }
                } else if presentation == "Scenes" || dynamicType.isAccessibilitySize {
                    sceneList
                } else {
                    map
                    pageControls
                    Text("Stars show scenes \(safePage * pageSize + 1)–\(min((safePage + 1) * pageSize, filteredScenes.count)) of \(filteredScenes.count). Open any star to read its scene.")
                        .font(.caption).foregroundStyle(theme.secondary)
                }
                legend
            }.padding(20)
        }
        .navigationTitle("Constellation").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .invokeScreen()
        .onAppear {
            if !initialized {
                if let current = story?.currentChapterID, scenes.contains(where: { $0.chapterID == current }) { chapterKey = current.uuidString }
                initialized = true
            }
            revealTrigger += 1
        }
        .onChange(of: chapterKey) { _, _ in page = 0 }
        .onChange(of: filteredScenes.count) { _, _ in page = min(page, pageCount - 1) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(text: "A sky you are writing")
            Text(story?.title ?? "Every scene belongs here").font(.largeTitle).fontDesign(.serif)
            Text("\(scenes.filter { $0.status == "Experienced" }.count) scenes lived · \(scenes.count) scenes in this story")
                .font(.subheadline).foregroundStyle(theme.secondary)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Chapter", selection: $chapterKey) {
                Text("All chapters · \(scenes.count) scenes").tag("all")
                ForEach(chapters) { chapter in
                    Text(chapter.title + (chapter.closedAt == nil ? "" : " · Closed")).tag(chapter.id.uuidString)
                }
            }.pickerStyle(.menu).frame(minHeight: 44).accessibilityIdentifier("constellation-chapter-picker")
            if dynamicType.isAccessibilitySize {
                Text("All scenes appear as a readable list at this text size.").font(.caption).foregroundStyle(theme.secondary)
            } else {
                Picker("Constellation presentation", selection: $presentation) {
                    Text("Star map").tag("Map")
                    Text("Scenes as a list").tag("Scenes")
                }.pickerStyle(.segmented).accessibilityIdentifier("constellation-presentation-picker")
            }
        }
    }

    private var map: some View {
        GeometryReader { geometry in
            ZStack {
                ConstellationSky(palette: palette)
                EffectSurface(theme: InvokeEffectTheme(rawValue: theme.id) ?? .ink,
                              level: InvokeEffectLevel(rawValue: store.data.preferences.effects) ?? .subtle,
                              trigger: revealTrigger, kind: .card)
                connectingLines(size: geometry.size)
                ForEach(Array(pageScenes.enumerated()), id: \.element.id) { index, scene in
                    NavigationLink {
                        ConstellationSceneScriptView(sceneID: scene.id)
                            .modifier(ConstellationZoomDestination(id: scene.id.uuidString, namespace: sceneZoom))
                    } label: {
                        ConstellationStarLabel(scene: scene, palette: palette)
                    }
                    .buttonStyle(.plain)
                    .modifier(ConstellationZoomSource(id: scene.id.uuidString, namespace: sceneZoom))
                    .position(point(index, size: geometry.size))
                    .accessibilityLabel("\(scene.title), \(scene.status)\(scene.archived ? ", archived" : "")")
                    .accessibilityHint("Opens the scene script")
                    .accessibilityIdentifier("scene-star-\(scene.id.uuidString)")
                }
            }
        }
        .frame(height: 480)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(theme.border.opacity(0.7), lineWidth: 0.8))
    }

    private func connectingLines(size: CGSize) -> some View {
        Canvas { context, _ in
            guard pageScenes.count > 1 else { return }
            for index in 1..<pageScenes.count {
                // A line never invents continuity between two different chapters.
                guard pageScenes[index - 1].chapterID == pageScenes[index].chapterID else { continue }
                var line = Path()
                let before = point(index - 1, size: size)
                let after = point(index, size: size)
                line.move(to: CGPoint(x: before.x, y: before.y - 18))
                line.addLine(to: CGPoint(x: after.x, y: after.y - 18))
                context.stroke(line, with: .color(palette.line.opacity(0.52)), style: StrokeStyle(lineWidth: 0.7, dash: [3, 5]))
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }

    private func point(_ index: Int, size: CGSize) -> CGPoint {
        let x: [CGFloat] = [0.06, 0.88, 0.20, 0.96, 0.03, 0.78]
        let y: [CGFloat] = [0.02, 0.17, 0.37, 0.52, 0.76, 0.94]
        return CGPoint(x: 63 + x[index % pageSize] * max(1, size.width - 126), y: 56 + y[index % pageSize] * max(1, size.height - 112))
    }

    private var pageControls: some View {
        HStack(spacing: 18) {
            Button { page = max(0, safePage - 1) } label: { Image(systemName: "chevron.left").frame(width: 48, height: 48) }
                .disabled(safePage == 0).accessibilityLabel("Previous constellation page")
                .accessibilityIdentifier("constellation-previous-page")
            Spacer(minLength: 0)
            Text("\(safePage + 1) / \(pageCount)").font(.subheadline.monospacedDigit())
                .accessibilityLabel("Constellation page \(safePage + 1) of \(pageCount)")
            Spacer(minLength: 0)
            Button { page = min(pageCount - 1, safePage + 1) } label: { Image(systemName: "chevron.right").frame(width: 48, height: 48) }
                .disabled(safePage == pageCount - 1).accessibilityLabel("Next constellation page")
                .accessibilityIdentifier("constellation-next-page")
        }
        .padding(.horizontal, 10)
        .invokeGlassControl(in: RoundedRectangle(cornerRadius: 18), interactive: true)
    }

    private var sceneList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredScenes) { scene in
                NavigationLink {
                    ConstellationSceneScriptView(sceneID: scene.id)
                        .modifier(ConstellationZoomDestination(id: scene.id.uuidString, namespace: sceneZoom))
                } label: {
                    InvokeCard {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: constellationSymbol(scene)).font(.title2).foregroundStyle(theme.accent)
                            VStack(alignment: .leading, spacing: 7) {
                                Text(scene.title).font(.headline).multilineTextAlignment(.leading)
                                Text(scene.action.isEmpty ? "A scene waiting for its script." : scene.action).font(.subheadline).foregroundStyle(theme.secondary).lineLimit(3).multilineTextAlignment(.leading)
                                Text(scene.status + (scene.archived ? " · Archived" : "")).font(.caption).foregroundStyle(theme.secondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .modifier(ConstellationZoomSource(id: scene.id.uuidString, namespace: sceneZoom))
                .accessibilityIdentifier("scene-star-\(scene.id.uuidString)")
            }
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Experienced scenes shine. Planned scenes hold a possibility.", systemImage: "sparkle")
            Text("Nothing disappears when a chapter closes. Choose All chapters to explore the whole story.")
        }.font(.caption).foregroundStyle(theme.secondary)
    }
}

private func constellationSymbol(_ scene: Scene) -> String {
    if scene.archived { return "archivebox" }
    switch scene.status {
    case "Experienced": return "sparkle"
    case "In progress": return "sun.max"
    case "Skipped": return "minus.circle"
    default: return "circle.dashed"
    }
}

private struct ConstellationStarLabel: View {
    let scene: Scene
    let palette: ConstellationPalette
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if scene.status == "Experienced" || scene.status == "In progress" {
                    Circle().fill(RadialGradient(colors: [palette.light.opacity(0.24), .clear], center: .center, startRadius: 2, endRadius: 23))
                }
                Image(systemName: constellationSymbol(scene))
                    .font(.system(size: scene.status == "Experienced" ? 28 : 20, weight: .light))
                    .foregroundStyle(scene.status == "Experienced" ? palette.light : palette.label)
            }.frame(width: 48, height: 48)
            Text(scene.title).font(.caption).lineLimit(2).multilineTextAlignment(.center)
                .foregroundStyle(contrast == .increased ? palette.text : palette.label)
                .frame(height: 32, alignment: .top)
        }.frame(width: 118, height: 88).contentShape(Rectangle())
    }
}

/// A readable script is the landing surface after star zoom. Editing continues to
/// use the existing autosaving model bindings, rather than introducing a copy.
struct ConstellationSceneScriptView: View {
    let sceneID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @State private var entering = false
    @State private var reflectionID: UUID?
    private var scene: Scene? { store.data.scenes.first { $0.id == sceneID } }
    private var closed: Bool {
        guard let scene else { return true }
        return store.data.chapters.first { $0.id == scene.chapterID }?.closedAt != nil
    }

    var body: some View {
        ScrollView {
            if let scene {
                VStack(alignment: .leading, spacing: 24) {
                    scriptHeader(scene)
                    scriptSection("The intended action", text: scene.action, fallback: "The next believable act is still taking shape.")
                    scriptSection("Why it matters", text: scene.why, fallback: "What would make this act meaningful?")
                    scriptSection("When or where", text: scene.cue, fallback: "No cue chosen yet. A situation can be enough.")
                    scriptSection("Effort or duration", text: scene.effort, fallback: "Leave room for the day you actually have.")
                    scriptSection("The smaller version", text: scene.smallerVersion, fallback: "A gentler version can be added any time.")
                    actions(scene)
                    connections(scene)
                    reflections
                }.padding(20)
            } else {
                EmptyState(symbol: "sparkle", title: "This scene is no longer here", message: "It may have been removed or replaced by a restored backup.")
            }
        }
        .navigationTitle("Scene script").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .invokeScreen()
        .navigationDestination(isPresented: $entering) { SceneEntryView(sceneID: sceneID) }
        .navigationDestination(item: $reflectionID) { ReflectionEditorView(reflectionID: $0) }
    }

    private func scriptHeader(_ scene: Scene) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: constellationSymbol(scene)).font(.title).foregroundStyle(theme.accent)
                Spacer()
                StatusPill(text: scene.status)
                if scene.archived { StatusPill(text: "Archived") }
            }
            if let chapter = store.data.chapters.first(where: { $0.id == scene.chapterID }) { SectionEyebrow(text: chapter.title) }
            Text(scene.title).font(.largeTitle).fontDesign(.serif).textSelection(.enabled).accessibilityIdentifier("scene-script-title")
            if closed { Label("Preserved in a closed chapter", systemImage: "lock").font(.subheadline).foregroundStyle(theme.secondary) }
        }
    }

    private func scriptSection(_ title: String, text: String, fallback: String) -> some View {
        InvokeCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(text: title)
                Text(text.isEmpty ? fallback : text)
                    .font(.body).lineSpacing(5).foregroundStyle(text.isEmpty ? theme.secondary : theme.text)
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func actions(_ scene: Scene) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !closed && !scene.archived {
                InvokePrimaryButton(title: "Enter the scene") {
                    guard !closed, let index = store.data.scenes.firstIndex(where: { $0.id == sceneID }) else { return }
                    store.data.scenes[index].status = "In progress"
                    store.data.scenes[index].updatedAt = Date()
                    entering = true
                }.accessibilityIdentifier("scene-script-enter")
                Button("Reflect on an attempt", systemImage: "text.book.closed") {
                    guard !closed else { return }
                    reflectionID = store.existingReflection(storyID: scene.storyID, sceneID: scene.id, kind: "Scene draft")
                }.frame(minHeight: 44).accessibilityIdentifier("scene-script-reflect")
            }
            NavigationLink {
                SceneDetailView(sceneID: scene.id)
            } label: {
                Label(closed ? "View preserved scene details" : "Edit this scene", systemImage: closed ? "book.closed" : "square.and.pencil").frame(minHeight: 44)
            }.accessibilityIdentifier("scene-script-edit")
            if closed {
                NavigationLink("Revisit the chapter keepsake") { ChapterKeepsakeView(chapterID: scene.chapterID) }.frame(minHeight: 44)
            }
        }
    }

    @ViewBuilder private func connections(_ scene: Scene) -> some View {
        let entries = store.data.entries.filter { scene.entryIDs.contains($0.id) }
        let relics = store.data.relics.filter { scene.relicIDs.contains($0.id) }
        if !entries.isEmpty || !relics.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(text: "Preparation & companions")
                ForEach(entries) { entry in
                    NavigationLink { EntryDetailView(entryID: entry.id) } label: { Label(entry.title, systemImage: entry.kind.symbol).frame(minHeight: 44) }
                }
                ForEach(relics) { relic in
                    NavigationLink { RelicDetailView(relicID: relic.id) } label: { Label(relic.name, systemImage: "sparkles.rectangle.stack").frame(minHeight: 44) }
                }
            }
        }
    }

    @ViewBuilder private var reflections: some View {
        let records = store.data.reflections.filter { $0.sceneID == sceneID && !$0.archived }.sorted { $0.createdAt > $1.createdAt }
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionEyebrow(text: "What happened here")
                ForEach(records) { reflection in
                    NavigationLink { ReflectionEditorView(reflectionID: reflection.id) } label: {
                        InvokeCard {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(reflection.kind).font(.headline)
                                Text(reflection.text.isEmpty ? "Open this reflection" : reflection.text).font(.subheadline).lineLimit(3).multilineTextAlignment(.leading)
                                Text(reflection.createdAt, style: .date).font(.caption).foregroundStyle(theme.secondary)
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}
