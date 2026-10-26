import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @State private var backup: BackupDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var validating = false
    @State private var proposedRestore: BackupPayload?
    @State private var reviewRestore = false
    @State private var confirmRestore = false
    @State private var removeExamples = false
    @State private var exportMessage = ""
    @State private var exportAfterReview = false
    var body: some View {
        Form {
            Section {
                NavigationLink { AppearanceView() } label: { Label("Appearance", systemImage: "paintpalette") }
                NavigationLink { LivingSettingsView(settings: store.data.grimoire.settings) } label: { Label("Calendar, reminders & restoration", systemImage: "calendar.badge.clock") }.accessibilityIdentifier("living-settings")
                Text("\(theme.name) · \(store.data.preferences.effects.capitalized) effects").foregroundStyle(theme.secondary)
                    .accessibilityIdentifier("appearance-current-theme").accessibilityValue(theme.id)
            }
            Section("Your writing, on this iPhone") {
                Label(store.saveState, systemImage: "internaldrive")
                Text("Invoke works offline. It does not use an account, analytics, an AI service, or cloud synchronization. Writing and imported photographs are stored in the app’s protected local storage.")
                Text("Deleting Invoke can delete its local data. Export a complete backup regularly to a location you choose in Files. Device backups depend on your iPhone settings.").font(.footnote).foregroundStyle(theme.secondary)
                Button { exportBackup() } label: { Label("Export complete backup", systemImage: "square.and.arrow.up") }
                Button { importing = true } label: { Label(validating ? "Validating backup…" : "Restore from backup", systemImage: "square.and.arrow.down") }.disabled(validating)
                if !exportMessage.isEmpty { Text(exportMessage).font(.footnote).foregroundStyle(theme.secondary) }
                if let url = store.lastRecoveryBackupURL {
                    ShareLink(item: url) { Label("Save retained recovery copy", systemImage: "arrow.uturn.backward") }
                    Button("Review retained recovery copy") { validateImport(url) }.accessibilityIdentifier("recovery-review-copy")
                }
                Button("Retry saving now") { store.flush() }
            }
            Section("Example collection") {
                Text("A creative visibility quest, an intentional home, and a discovery story. All example records are labeled.").font(.subheadline)
                Button("Add example collection") { store.loadExamples() }
                Button("Remove example collection", role: .destructive) { removeExamples = true }
            }
            Section("About Invoke") {
                Text("Author → Rehearse → Act → Reflect → Revise")
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))").font(.footnote)
                Text("Running on iOS \(UIDevice.current.systemVersion)").font(.footnote)
                Text("Minimum supported iOS: \(Bundle.main.object(forInfoDictionaryKey: "MinimumOSVersion") as? String ?? "17.0")").font(.footnote).foregroundStyle(theme.secondary)
                NavigationLink("Shader acknowledgments") { ShaderAcknowledgmentsView() }
            }
        }.navigationTitle("Settings").invokeScreen()
            .fileExporter(isPresented: $exporting, document: backup, contentType: .invokeBackup, defaultFilename: "Invoke-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash)))") { result in
                switch result {
                case .success: exportMessage = "Backup exported, including every referenced photograph."
                case .failure(let error): store.errorMessage = "Could not export the backup: \(error.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.invokeBackup, .json]) { result in
                switch result {
                case .success(let url): validateImport(url)
                case .failure(let error): store.errorMessage = "Could not open the backup: \(error.localizedDescription)"
                }
            }
            .sheet(isPresented: $reviewRestore, onDismiss: {
                if exportAfterReview { exportAfterReview = false; exportBackup() }
            }) {
                NavigationStack {
                    ScrollView { VStack(alignment: .leading, spacing: 22) {
                        Text("Review this restoration").font(.largeTitle).fontDesign(.serif)
                        if let payload = proposedRestore {
                            Text("Backup from \(payload.exportedAt.formatted(date: .abbreviated, time: .shortened))")
                            Text("\(payload.data.stories.count) stories · \(payload.data.entries.count) Grimoire entries · \(payload.data.relics.count) relics · \(payload.images.count) images")
                            Text("\(payload.data.grimoire.practices.count) practices · \(payload.data.grimoire.actions.count) action records · \(payload.data.grimoire.invocations.count) Invocations · \(payload.data.grimoire.assets.count) assets")
                            Text("\(payload.data.grimoire.spells.count) Spells · \(payload.data.grimoire.enchantments.count) Enchantments · \(payload.data.grimoire.arcana.count) Arcana records · \(payload.data.grimoire.echoes.count) Echoes · \(payload.data.grimoire.revisions.count) revisions")
                            Text(mergeSummary(payload)).font(.footnote).foregroundStyle(theme.secondary)
                            Button("Merge new records into my collection") {
                                do { try store.mergeBackup(payload); reviewRestore = false; proposedRestore = nil; exportMessage = "Merged new records. Existing records and preferences were kept." }
                                catch { store.errorMessage = error.localizedDescription }
                            }.buttonStyle(.bordered).frame(minHeight: 44)
                        }
                        Text("Merge adds records with new identities and keeps your current records on every identity conflict. Current preferences are kept. Replace instead restores the complete backup, including all records, history, photos, and preferences.")
                        Text("Export your current collection first. Invoke also creates a local recovery copy before replacing anything.").foregroundStyle(theme.secondary)
                        Button("Export current collection first") { exportAfterReview = true; reviewRestore = false }.buttonStyle(.bordered).frame(minHeight: 44)
                        Text("After export, choose Restore from backup again to continue.").font(.footnote).foregroundStyle(theme.secondary)
                        Button("Replace with this backup", role: .destructive) { confirmRestore = true }.buttonStyle(.borderedProminent).frame(minHeight: 44)
                    }.padding(24) }.invokeScreen()
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { reviewRestore = false; proposedRestore = nil } } }
                        .alert("Replace your current collection?", isPresented: $confirmRestore) {
                            Button("Replace & restore", role: .destructive) {
                                guard let payload = proposedRestore else { return }
                                do { try store.restore(payload); reviewRestore = false; proposedRestore = nil; exportMessage = store.lastRecoveryBackupURL == nil ? "Restored. The previous local files were preserved for recovery." : "Restored. A pre-restore recovery backup is available below." }
                                catch { reviewRestore = false; store.errorMessage = error.localizedDescription }
                            }
                            Button("Cancel", role: .cancel) { }
                        } message: { Text("The validated backup will replace the current collection. A recovery backup is saved first.") }
                }.environment(\.invokeTheme, theme).preferredColorScheme(theme.scheme)
            }
            .confirmationDialog("Remove all example records?", isPresented: $removeExamples, titleVisibility: .visible) {
                Button("Remove examples", role: .destructive) { store.removeExamples() }
            } message: { Text("Example stories and their example entries, relics, and reflections will be removed, including changes you made to them. Personal records remain; links to removed examples will be cleared.") }
    }
    private func exportBackup() {
        do { backup = try store.makeBackup(); exporting = true }
        catch { store.errorMessage = error.localizedDescription }
    }
    private func mergeSummary(_ payload: BackupPayload) -> String {
        func overlap<T: Identifiable>(_ current: [T], _ incoming: [T]) -> Int where T.ID: Hashable { Set(current.map(\.id)).intersection(Set(incoming.map(\.id))).count }
        let a = store.data, b = payload.data
        var counts = [overlap(a.stories, b.stories), overlap(a.chapters, b.chapters), overlap(a.scenes, b.scenes), overlap(a.entries, b.entries), overlap(a.relics, b.relics), overlap(a.reflections, b.reflections), overlap(a.ritualLogs, b.ritualLogs)]
        let x = a.grimoire, y = b.grimoire
        counts += [overlap(x.practices, y.practices), overlap(x.occurrences, y.occurrences), overlap(x.actions, y.actions), overlap(x.invocations, y.invocations), overlap(x.spells, y.spells), overlap(x.enchantments, y.enchantments), overlap(x.assets, y.assets), overlap(x.arcana, y.arcana), overlap(x.echoes, y.echoes), overlap(x.events, y.events), overlap(x.revisions, y.revisions)]
        let duplicates = counts.reduce(0, +)
        return "Merge preview: \(duplicates) record identities already exist here and will keep their current values. Conflicting image contents are rejected before anything changes. A recovery copy is saved before import."
    }
    private func validateImport(_ url: URL) {
        validating = true
        Task { @MainActor in
            do {
                let payload = try await Task.detached(priority: .userInitiated) {
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= BackupValidation.maximumBackupBytes else { throw InvokeDataError.invalidBackup("The selected file exceeds the 512 MB limit.") }
                    return try BackupValidation.decode(Data(contentsOf: url, options: .mappedIfSafe))
                }.value
                proposedRestore = payload; reviewRestore = true
            } catch { store.errorMessage = error.localizedDescription }
            validating = false
        }
    }
}

struct AppearanceView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var previewTrigger = 0
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Three ways to hold a story.").font(.largeTitle).fontDesign(.serif)
                Text("Your stories stay yours. Only the atmosphere changes.").foregroundStyle(theme.secondary)
                ForEach(InvokeTheme.all) { option in
                    Button { store.data.preferences.theme = option.id; store.flush() } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Text(option.name).font(.title3).fontDesign(.serif); Spacer(); Image(systemName: theme.id == option.id ? "checkmark.circle.fill" : "circle") }
                            HStack(spacing: 14) {
                                Image(systemName: option.id == "ink" ? "leaf" : option.id == "velvet" ? "moon.stars" : "theatermasks").font(.largeTitle).foregroundStyle(option.accent)
                                VStack(alignment: .leading, spacing: 8) { Text("Your next chapter").font(.title2).fontDesign(.serif); Text("Enter the scene →").font(.caption.weight(.semibold)).padding(10).background(option.button, in: Capsule()).foregroundStyle(option.buttonText) }
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(option.surface, in: RoundedRectangle(cornerRadius: 10)).overlay(ThemeScenery().environment(\.invokeTheme, option))
                            Text(option.subtitle).font(.subheadline).foregroundStyle(option.secondary)
                        }.padding(18).foregroundStyle(option.text).background(option.background, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.id == option.id ? option.accent : option.border, lineWidth: theme.id == option.id ? 2 : 0.8))
                    }.buttonStyle(.plain).accessibilityLabel(option.name + (theme.id == option.id ? ", selected" : ""))
                        .accessibilityAddTraits(theme.id == option.id ? .isSelected : [])
                        .accessibilityIdentifier("appearance-theme-\(option.id)")
                }.accessibilityElement(children: .contain).accessibilityIdentifier("appearance-theme-picker")
                glassControls
                effectControls
                preview
                NavigationLink { EffectsLabView(theme: InvokeEffectTheme(rawValue: theme.id) ?? .astral, level: InvokeEffectLevel(rawValue: store.data.preferences.effects) ?? .subtle) } label: { Label("Open effects studio", systemImage: "sparkles").frame(minHeight: 44) }
            }.padding(20)
        }.navigationTitle("Appearance").invokeScreen()
    }

    private var glassControls: some View {
        InvokeCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionEyebrow(text: "Interface material")
                Picker("Interface material", selection: $store.data.preferences.glassStyle) {
                    ForEach(InvokeGlassStyle.allCases) { Text($0.title).tag($0.rawValue) }
                }.pickerStyle(.menu).accessibilityIdentifier("appearance-glass-style")
                Text("Liquid Glass brings light and depth to navigation and compact controls on iOS 26 and later. Your pages and writing fields keep an opaque, readable surface.")
                    .font(.footnote).foregroundStyle(theme.secondary)
                if #available(iOS 26.0, *) {
                    if reduceTransparency || contrast == .increased {
                        Label("Accessibility settings are using solid surfaces.", systemImage: "accessibility").font(.footnote)
                    }
                } else {
                    Label("This iOS version uses solid surfaces.", systemImage: "square.stack").font(.footnote)
                }
            }
        }
    }

    private var effectControls: some View {
        InvokeCard {
            VStack(alignment: .leading, spacing: 18) {
                SectionEyebrow(text: "Moment effects")
                Picker("Effects", selection: $store.data.preferences.effects) {
                    ForEach(InvokeEffectLevel.allCases) { Text($0.title).tag($0.rawValue) }
                }.pickerStyle(.menu).accessibilityIdentifier("appearance-effects-level")
                Picker("Effect style", selection: $store.data.preferences.shaderStyle) {
                    ForEach(InvokeShaderStyle.allCases) { Text($0.title).tag($0.rawValue) }
                }.pickerStyle(.menu).accessibilityIdentifier("appearance-shader-style")
                Text((InvokeShaderStyle(rawValue: store.data.preferences.shaderStyle) ?? .theme).detail)
                    .font(.subheadline).foregroundStyle(theme.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Intensity · \(store.data.preferences.effectIntensity, format: .percent.precision(.fractionLength(0)))")
                    Slider(value: $store.data.preferences.effectIntensity, in: 0.35...1.5, step: 0.05,
                           onEditingChanged: { editing in if !editing { previewTrigger += 1 } }) {
                        Text("Effect intensity")
                    }
                    .accessibilityValue(store.data.preferences.effectIntensity.formatted(.percent.precision(.fractionLength(0))))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Speed · \(store.data.preferences.effectSpeed, format: .number.precision(.fractionLength(1)))×")
                    Slider(value: $store.data.preferences.effectSpeed, in: 0.6...1.4, step: 0.1,
                           onEditingChanged: { editing in if !editing { previewTrigger += 1 } }) {
                        Text("Effect speed")
                    }
                    .accessibilityValue("\(store.data.preferences.effectSpeed.formatted(.number.precision(.fractionLength(1)))) times")
                }
                Text("Your chosen style, intensity, and speed apply to buttons, scene recordings, relics, and chapter moments. Effects remain brief; they never delay saving or navigation.")
                    .font(.footnote).foregroundStyle(theme.secondary)
                if reduceMotion || reduceTransparency {
                    Label("Accessibility settings are using static decoration.", systemImage: "accessibility").font(.footnote)
                } else {
                    Text("Off and Low Power Mode use static decoration. Inactive and offscreen moments stop rendering.").font(.footnote).foregroundStyle(theme.secondary)
                }
            }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionEyebrow(text: "Your atmosphere, in miniature")
            VStack(alignment: .leading, spacing: 18) {
                InvokeGlassGroup(spacing: 12) {
                    HStack {
                        Label("Invoke", systemImage: "sparkle")
                            .font(.subheadline.weight(.semibold)).padding(12)
                            .invokeGlassControl(in: Capsule(), interactive: false)
                        Spacer()
                        Button { previewTrigger += 1 } label: {
                            Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                        }.buttonStyle(.plain)
                            .invokeGlassControl(in: Circle())
                            .accessibilityLabel("Replay appearance preview")
                    }
                }
                Text("A small act still changes the page.").font(.title2).fontDesign(.serif)
                Text("Your next chapter").foregroundStyle(theme.secondary)
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 22).fill(theme.surface)
                ThemeScenery().clipShape(RoundedRectangle(cornerRadius: 22))
                EffectSurface(theme: InvokeEffectTheme(rawValue: theme.id) ?? .astral,
                    level: InvokeEffectLevel(rawValue: store.data.preferences.effects) ?? .subtle,
                    trigger: previewTrigger, kind: .card)
            }
            InvokePrimaryButton(title: "Try this moment") { previewTrigger += 1 }
            Button("Reset motion & material") {
                store.data.preferences.effects = "subtle"
                store.data.preferences.shaderStyle = "theme"
                store.data.preferences.effectIntensity = 1
                store.data.preferences.effectSpeed = 1
                store.data.preferences.glassStyle = "system"
                store.flush()
            }.frame(minHeight: 44)
        }
    }
}

struct ShaderAcknowledgmentsView: View {
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) {
            Text("Native adaptations").font(.title).fontDesign(.serif)
            Text("Invoke’s decorative Metal effects adapt Ripples, Beam, and Sparkle from shader-effects-inc/shaders. The web package itself is not embedded. Revision: 81fd4ece5d493ca6c424a2af41f0e2c361ec8258.")
            Link("Original shader repository", destination: URL(string: "https://github.com/shader-effects-inc/shaders")!)
            Text((try? String(contentsOf: Bundle.main.url(forResource: "ShaderLicense", withExtension: "txt") ?? URL(fileURLWithPath: "/unavailable"), encoding: .utf8)) ?? "See ThirdParty/shader-effects-inc/shaders/LICENSE in the source project.").font(.footnote).textSelection(.enabled)
        }.padding(20) }.navigationTitle("Acknowledgments").invokeScreen()
    }
}
