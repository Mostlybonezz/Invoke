import SwiftUI
import PhotosUI
import UIKit
import ImageIO

struct RelicCabinetView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var search = ""
    @State private var stage = "All stages"
    @State private var showArchive = false
    @State private var createdRelic: LibrarySelection?

    private var relics: [Relic] {
        store.data.relics.filter {
            $0.archived == showArchive && (stage == "All stages" || stage == $0.status)
            && (search.isEmpty || [$0.name, $0.meaning, $0.intention, $0.materials, $0.memories].joined(separator: " ").localizedCaseInsensitiveContains(search))
        }.sorted { $0.updatedAt > $1.updatedAt }
    }
    private var columns: [GridItem] { [GridItem(.adaptive(minimum: dynamicType.isAccessibilitySize ? 280 : 150), spacing: 14)] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Meaning, made tangible.").font(.title2).fontDesign(.serif)
                Text("Made, found, inherited, or chosen. Objects can remember what you are becoming.").foregroundStyle(theme.secondary)
                Picker("Lifecycle", selection: $stage) {
                    Text("All stages").tag("All stages")
                    ForEach(StoryCatalog.relicStatuses, id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.menu)
                if showArchive { StatusPill(text: "Archive") }
                if relics.isEmpty {
                    EmptyState(symbol: "sparkles.rectangle.stack", title: search.isEmpty ? "Your collection begins here" : "No matching relics", message: search.isEmpty ? "Add an object with the plus button. You can begin at any stage." : "Try another word or lifecycle stage.")
                }
                LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                    ForEach(relics) { relic in
                        NavigationLink { RelicDetailView(relicID: relic.id) } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                RelicPhotograph(file: relic.photoFiles.first, name: relic.name, pixelSize: 600)
                                    .frame(height: dynamicType.isAccessibilitySize ? 240 : 180).clipped()
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(relic.name).font(.headline).fontDesign(.serif).multilineTextAlignment(.leading)
                                    Text(relic.status).font(.caption).foregroundStyle(theme.secondary)
                                    if relic.isExample { StatusPill(text: "Example") }
                                }.padding([.horizontal, .bottom], 14)
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.border, lineWidth: 0.7))
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(20)
        }
        .navigationTitle("Relic Cabinet")
        .searchable(text: $search, prompt: "Find an object or intention")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showArchive.toggle() } label: { Image(systemName: showArchive ? "tray.full.fill" : "archivebox") }
                    .accessibilityLabel(showArchive ? "Show current relics" : "Show archived relics")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let relic = Relic()
                    store.data.relics.append(relic)
                    createdRelic = LibrarySelection(id: relic.id)
                } label: { Image(systemName: "plus") }.accessibilityLabel("Add a relic")
            }
        }
        .navigationDestination(item: $createdRelic) { RelicDetailView(relicID: $0.id) }
        .invokeScreen()
    }
}

struct RelicDetailView: View {
    let relicID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var importingPhotos = false
    @State private var photoError: String?
    @State private var confirmingDelete = false
    @State private var photoToRemove: String?
    @State private var dedicationTrigger = 0
    @State private var dedicationMessage = false
    @State private var sharedCard: RelicShareItem?
    @State private var exportError: String?

    private var relic: Relic? { store.data.relics.first { $0.id == relicID } }

    var body: some View {
        Group {
            if let relic {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        photoGallery(relic)
                        HStack {
                            SectionEyebrow(text: "Personal collection")
                            Spacer()
                            if relic.isExample { StatusPill(text: "Example") }
                            if relic.archived { StatusPill(text: "Archived") }
                        }
                        TextField("Name your relic", text: field(\.name), axis: .vertical)
                            .font(.largeTitle).fontDesign(.serif).accessibilityLabel("Relic name")
                        Picker("Lifecycle", selection: field(\.status)) {
                            ForEach(StoryCatalog.relicStatuses, id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.menu)
                        ProseField(title: "Object type", text: field(\.objectType), prompt: "Pendant, stone, notebook, painted cup…")
                        ProseField(title: "Origin or creation story", text: field(\.origin))
                        ProseField(title: "What it means to me", text: field(\.meaning))
                        ProseField(title: "The intention it carries", text: field(\.intention))
                        workshop(relic)
                        dedication(relic)
                        ProseField(title: "Where it lives and how I use it", text: field(\.location))
                        ProseField(title: "Care notes", text: field(\.care))
                        ProseField(title: "Memories and later reflections", text: field(\.memories), prompt: "Let the museum label grow into a journal.")
                        RecordConnectionsView(relicID: relicID)
                        sceneHistory(relic)
                        InvokeCard {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionEyebrow(text: "A keepsake in the world")
                                Text("Share or print a card with this relic's photograph, meaning, and dedication, in your selected appearance.")
                                    .font(.subheadline).foregroundStyle(theme.secondary)
                                Button("Share relic card", systemImage: "square.and.arrow.up") { share(relic) }.buttonStyle(.bordered)
                                Button("Print relic card", systemImage: "printer") { printCard(relic) }.buttonStyle(.bordered)
                            }
                        }
                        Text("Photographs and writing are stored on this device and included in your Invoke backups.")
                            .font(.caption).foregroundStyle(theme.secondary)
                    }.padding(20)
                }.scrollDismissesKeyboard(.interactively)
            } else {
                EmptyState(symbol: "archivebox", title: "This relic is no longer here", message: "It may have been removed or replaced by a restored backup.")
            }
        }
        .navigationTitle("Relic workshop").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let relic {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(relic.archived ? "Restore from archive" : "Archive relic", systemImage: "archivebox") { update { $0.archived.toggle() } }
                        Button("Delete permanently", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                    } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("Relic actions")
                }
            }
        }
        .confirmationDialog("Permanently delete this relic?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete relic", role: .destructive) { store.deleteRelic(id: relicID); dismiss() }
        } message: { Text("The object record and its photographs will be removed. Stories remain. This cannot be undone.") }
        .confirmationDialog("Remove this photograph?", isPresented: Binding(get: { photoToRemove != nil }, set: { if !$0 { photoToRemove = nil } }), titleVisibility: .visible) {
            Button("Remove photograph", role: .destructive) {
                if let file = photoToRemove { store.removePhoto(file: file, fromRelic: relicID) }
                photoToRemove = nil
            }
        } message: { Text("This removes the imported copy from Invoke. Your original in Photos is unchanged.") }
        .alert("Photo import", isPresented: Binding(get: { photoError != nil }, set: { if !$0 { photoError = nil } })) {
            Button("OK", role: .cancel) { photoError = nil }
        } message: { Text(photoError ?? "") }
        .alert("Could not create the card", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: { Text(exportError ?? "") }
        .sheet(item: $sharedCard) { item in NativeShareSheet(items: [item.url]) }
        .onChange(of: photoSelection) { _, items in
            if !items.isEmpty { Task { await importPhotos(items) } }
        }
        .invokeScreen()
    }

    private func photoGallery(_ relic: Relic) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RelicPhotograph(file: relic.photoFiles.first, name: relic.name).frame(height: 290).clipped()
                EffectSurface(theme: InvokeEffectTheme(rawValue: theme.id) ?? .ink,
                              level: InvokeEffectLevel(rawValue: store.data.preferences.effects) ?? .subtle,
                              trigger: dedicationTrigger, kind: .relic)
            }.clipShape(RoundedRectangle(cornerRadius: 18))
            if !relic.photoFiles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(relic.photoFiles, id: \.self) { file in
                            VStack(spacing: 6) {
                                RelicPhotograph(file: file, name: relic.name, pixelSize: 300).frame(width: 100, height: 100).clipped().clipShape(RoundedRectangle(cornerRadius: 10))
                                Menu {
                                    Button("Make cover", systemImage: "photo") {
                                        update { $0.photoFiles.removeAll { $0 == file }; $0.photoFiles.insert(file, at: 0) }
                                    }
                                    Button("Remove photograph", systemImage: "trash", role: .destructive) { photoToRemove = file }
                                } label: { Label(file == relic.photoFiles.first ? "Cover" : "Photo", systemImage: "ellipsis.circle").font(.caption).frame(minHeight: 44) }
                                .accessibilityLabel("Actions for photograph \((relic.photoFiles.firstIndex(of: file) ?? 0) + 1)")
                            }
                        }
                    }
                }
            }
            PhotosPicker(selection: $photoSelection, maxSelectionCount: 8, matching: .images, photoLibrary: .shared()) {
                Label(importingPhotos ? "Importing photographs…" : "Add photographs", systemImage: "photo.badge.plus").frame(minHeight: 44)
            }.buttonStyle(.bordered).disabled(importingPhotos)
            if importingPhotos { ProgressView("Saving to Invoke") }
        }
    }

    private func workshop(_ relic: Relic) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionEyebrow(text: "Making room for magic")
            ProseField(title: "Materials", text: field(\.materials))
            Text("Making checklist").font(.headline)
            ForEach(relic.checklist) { item in
                HStack(alignment: .top, spacing: 12) {
                    Button {
                        update { value in
                            if let index = value.checklist.firstIndex(where: { $0.id == item.id }) { value.checklist[index].isDone.toggle() }
                        }
                    } label: {
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle").font(.title2).frame(width: 44, height: 44)
                    }.accessibilityLabel((item.isDone ? "Mark unfinished: " : "Mark complete: ") + item.text)
                    TextField("Making step", text: Binding(get: {
                        self.relic?.checklist.first { $0.id == item.id }?.text ?? ""
                    }, set: { text in
                        update { value in
                            if let index = value.checklist.firstIndex(where: { $0.id == item.id }) { value.checklist[index].text = text }
                        }
                    }), axis: .vertical).strikethrough(item.isDone).frame(minHeight: 44)
                    Button(role: .destructive) { update { $0.checklist.removeAll { $0.id == item.id } } } label: {
                        Image(systemName: "minus.circle").frame(width: 44, height: 44)
                    }.accessibilityLabel("Remove step: \(item.text)")
                }
            }
            Button("Add a making step", systemImage: "plus.circle") { update { $0.checklist.append(ChecklistItem()) } }.buttonStyle(.bordered)
        }
    }

    private func dedication(_ relic: Relic) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ProseField(title: "Dedication", text: field(\.dedication), prompt: "Words or a practice that give this object its intention.")
            Button {
                let note = "Dedicated \(Date().formatted(date: .abbreviated, time: .shortened))" + (relic.dedication.isEmpty ? "." : ": \(relic.dedication)")
                update { $0.memories += ($0.memories.isEmpty ? "" : "\n\n") + note }
                dedicationTrigger += 1
                dedicationMessage = true
            } label: {
                Label("Dedicate this relic", systemImage: "sparkles")
                    .font(.headline).padding(18).frame(maxWidth: .infinity, minHeight: 54)
                    .background {
                        ZStack {
                            theme.surface
                            EffectSurface(theme: InvokeEffectTheme(rawValue: theme.id) ?? .ink,
                                          level: InvokeEffectLevel(rawValue: store.data.preferences.effects) ?? .subtle,
                                          trigger: dedicationTrigger, kind: .relic)
                        }.clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.border, lineWidth: 0.7))
            }.buttonStyle(.plain)
            if dedicationMessage {
                Label("Dedication recorded in its memories.", systemImage: "checkmark.circle")
                    .font(.subheadline).foregroundStyle(theme.secondary).accessibilityAddTraits(.updatesFrequently)
            }
        }
    }

    @ViewBuilder private func sceneHistory(_ relic: Relic) -> some View {
        let scenes = store.data.scenes.filter { $0.relicIDs.contains(relic.id) }
        let chapters = store.data.chapters.filter { $0.relicIDs.contains(relic.id) }
        if !scenes.isEmpty || !chapters.isEmpty {
            DisclosureGroup("Scenes and chapters it has witnessed") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(scenes) { scene in
                        VStack(alignment: .leading, spacing: 4) { Text(scene.title).font(.headline); Text("Scene · \(scene.status)").font(.caption).foregroundStyle(theme.secondary) }
                    }
                    ForEach(chapters) { chapter in
                        VStack(alignment: .leading, spacing: 4) { Text(chapter.title).font(.headline); Text(chapter.closedAt == nil ? "Open chapter" : "Closed chapter").font(.caption).foregroundStyle(theme.secondary) }
                    }
                }.padding(.top, 12)
            }
        }
    }

    private func field(_ path: WritableKeyPath<Relic, String>) -> Binding<String> {
        Binding(get: { relic?[keyPath: path] ?? "" }, set: { value in update { $0[keyPath: path] = value } })
    }
    private func update(_ change: (inout Relic) -> Void) {
        guard let index = store.data.relics.firstIndex(where: { $0.id == relicID }) else { return }
        change(&store.data.relics[index])
        store.data.relics[index].updatedAt = Date()
    }
    @MainActor private func importPhotos(_ items: [PhotosPickerItem]) async {
        guard !importingPhotos else { return }
        importingPhotos = true
        defer { importingPhotos = false; photoSelection = [] }
        var failed = 0
        var failureMessage = ""
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw RelicCardError.unreadableImage }
                guard relic != nil else { return }
                let file = try store.importPhoto(data)
                update { $0.photoFiles.append(file) }
            } catch { failed += 1; failureMessage = error.localizedDescription }
        }
        if failed > 0 { photoError = "\(failed) photograph(s) could not be imported. Any successful imports are saved. \(failureMessage)" }
    }
    @MainActor private func share(_ relic: Relic) {
        do { sharedCard = RelicShareItem(url: try RelicCardExporter.create(relic: relic, theme: theme, imageURL: relic.photoFiles.first.flatMap(store.imageURL))) }
        catch { exportError = error.localizedDescription }
    }
    @MainActor private func printCard(_ relic: Relic) {
        do {
            let url = try RelicCardExporter.create(relic: relic, theme: theme, imageURL: relic.photoFiles.first.flatMap(store.imageURL))
            let controller = UIPrintInteractionController.shared
            let info = UIPrintInfo(dictionary: nil)
            info.jobName = "Invoke — \(relic.name)"
            info.outputType = .general
            controller.printInfo = info
            controller.printingItem = url
            controller.present(animated: true) { _, _, error in
                if let error { exportError = error.localizedDescription }
            }
        } catch { exportError = error.localizedDescription }
    }
}

struct RelicPhotograph: View {
    let file: String?
    let name: String
    var pixelSize: Int = 1_024
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                theme.surface
                if let image {
                    if theme.id == "velvet" {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: max(0, geometry.size.width - 34), height: max(0, geometry.size.height - 20)).clipShape(Ellipse())
                            .overlay(Ellipse().stroke(theme.border, lineWidth: 1).padding(.horizontal, 17).padding(.vertical, 10))
                    } else {
                        Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        if theme.id == "astral" { Rectangle().stroke(theme.border, lineWidth: 1).padding(10) }
                    }
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "sparkle").font(.system(size: 44, weight: .ultraLight))
                        Text("A place for an object").font(.caption).fontDesign(.serif)
                    }.foregroundStyle(theme.secondary).padding(12)
                    Circle().stroke(theme.border.opacity(0.6), lineWidth: 0.6).padding(22)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityLabel(image == nil ? "\(name), no photograph yet" : "Photograph of \(name)")
        .task(id: file.flatMap(store.imageURL)?.path) {
            image = nil
            if let file, let url = store.imageURL(file),
               let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
               let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: pixelSize
               ] as CFDictionary) {
                image = UIImage(cgImage: thumbnail)
            }
        }
    }
}
