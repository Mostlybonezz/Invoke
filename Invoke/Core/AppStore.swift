import Foundation
import Combine
import ImageIO
import UniformTypeIdentifiers

private struct DiskSnapshot: Codable {
    var formatVersion = 1
    var writtenAt = Date()
    var data: AppData
}

/// All mutations originate on the main actor. Short text edits are coalesced;
/// scene-phase changes call flush() to commit immediately before suspension.
@MainActor
final class AppStore: ObservableObject {
    @Published var data: AppData {
        didSet {
            guard data != oldValue else { return }
            grimoireQueryCache.invalidate()
            guard !suppressAutosave else { return }
            saveState = "Saving…"
            scheduleSave()
        }
    }
    @Published private(set) var saveState = "Saved on this iPhone"
    @Published var errorMessage: String? = nil
    @Published private(set) var lastRecoveryBackupURL: URL? = nil
    @Published private(set) var recoveryBackupURLs: [URL] = []

    let directory: URL
    private var generationName: String
    private var scheduledSave: Task<Void, Never>?
    private var suppressAutosave = false
    private var diskWritesBlocked = false
    var storageRecoveryRequired: Bool { diskWritesBlocked }
    let grimoireQueryCache = GrimoireQueryCache()
    private var lastPersisted: AppData
    private var lastSnapshotBytes: Data?
    private var pendingImportFiles: Set<String> = []
    private let fileManager = FileManager.default

    private var generationURL: URL {
        directory.appendingPathComponent("generations", isDirectory: true)
            .appendingPathComponent(generationName, isDirectory: true)
    }
    private var imagesURL: URL { generationURL.appendingPathComponent("images", isDirectory: true) }
    private var pointerURL: URL { directory.appendingPathComponent("CURRENT") }

    init(directory: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.directory = directory ?? support.appendingPathComponent("Invoke", isDirectory: true)
        self.generationName = UUID().uuidString
        let initial = AppData()
        self.data = initial
        self.lastPersisted = initial
        defer { discoverRecoveryBackups() }
        do {
            try fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: pointerURL.path) {
                let name = try String(contentsOf: pointerURL, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard UUID(uuidString: name) != nil else {
                    throw InvokeDataError.invalidBackup("The local storage pointer is damaged.")
                }
                generationName = name
                do {
                    try loadSnapshot(at: generationURL.appendingPathComponent("data.json"))
                } catch {
                    // A newer app's valid format must never be silently downgraded.
                    if let dataError = error as? InvokeDataError, case .unsupportedVersion = dataError { throw error }
                    // Retain the damaged latest file for recovery before permitting later saves.
                    let originalError = error
                    do {
                        try loadSnapshot(at: generationURL.appendingPathComponent("previous.json"))
                        let damaged = generationURL.appendingPathComponent("data.json")
                        if fileManager.fileExists(atPath: damaged.path) {
                            try fileManager.copyItem(at: damaged, to: generationURL.appendingPathComponent("damaged-\(UUID().uuidString).json"))
                        }
                        if let recovered = lastSnapshotBytes { try writeProtected(recovered, to: damaged) }
                        errorMessage = "Invoke recovered the previous saved version because the latest file was damaged. Export a backup now. The damaged file has been retained."
                    } catch {
                        throw originalError
                    }
                }
            } else {
                try fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)
                let bytes = try PersistenceCoding.encoder().encode(DiskSnapshot(data: data))
                try writeProtected(bytes, to: generationURL.appendingPathComponent("data.json"))
                try writeProtected(Data(generationName.utf8), to: pointerURL)
                lastSnapshotBytes = bytes
            }
            lastPersisted = data
        } catch {
            // Do not silently overwrite corrupt or inaccessible writing with an empty collection.
            diskWritesBlocked = true
            saveState = "Storage needs attention"
            errorMessage = "Invoke could not open its saved data. Existing files were preserved. You can restore a complete backup in Settings. Details: \(error.localizedDescription)"
        }
    }

    private func discoverRecoveryBackups() {
        let folder = directory.appendingPathComponent("recovery", isDirectory: true)
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        let files = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(keys))) ?? []
        let valid: [(URL, Date)] = files.compactMap { url in
            guard url.pathExtension == "invoke", let info = try? url.resourceValues(forKeys: keys),
                  info.isRegularFile == true, let size = info.fileSize, size <= BackupValidation.maximumBackupBytes,
                  let bytes = try? Data(contentsOf: url, options: .mappedIfSafe),
                  (try? BackupValidation.decode(bytes)) != nil else { return nil }
            return (url, info.contentModificationDate ?? .distantPast)
        }
        recoveryBackupURLs = valid.sorted { $0.1 > $1.1 }.map(\.0)
        lastRecoveryBackupURL = recoveryBackupURLs.first
    }

    private func loadSnapshot(at url: URL) throws {
        let bytes = try Data(contentsOf: url)
        let snapshot = try PersistenceCoding.decoder().decode(DiskSnapshot.self, from: bytes)
        guard snapshot.formatVersion == 1 else { throw InvokeDataError.unsupportedVersion(snapshot.formatVersion) }
        try BackupValidation.validateRecords(snapshot.data)
        for name in BackupValidation.imageNames(in: snapshot.data) {
            guard fileManager.fileExists(atPath: imagesURL.appendingPathComponent(name).path) else {
                throw InvokeDataError.missingPhoto(name)
            }
        }
        if snapshot.data.schemaVersion == 1 {
            // Preserve the complete original generation, including fields this version
            // does not understand, before committing an additive upgrade.
            var upgraded = snapshot.data
            upgraded.schemaVersion = AppData.currentSchemaVersion
            try BackupValidation.validateRecords(upgraded)
            let oldGeneration = generationURL
            let nextName = UUID().uuidString
            let staged = directory.appendingPathComponent("generations", isDirectory: true).appendingPathComponent(nextName, isDirectory: true)
            try fileManager.createDirectory(at: staged, withIntermediateDirectories: true)
            do {
                let stagedImages = staged.appendingPathComponent("images", isDirectory: true)
                try fileManager.createDirectory(at: stagedImages, withIntermediateDirectories: true)
                var assets: [String: BackupAsset] = [:]
                for name in BackupValidation.imageNames(in: snapshot.data) {
                    let imageBytes = try Data(contentsOf: oldGeneration.appendingPathComponent("images").appendingPathComponent(name))
                    try writeProtected(imageBytes, to: stagedImages.appendingPathComponent(name))
                    assets[name] = BackupAsset(bytes: imageBytes)
                }
                let recovery = directory.appendingPathComponent("recovery", isDirectory: true)
                try fileManager.createDirectory(at: recovery, withIntermediateDirectories: true)
                let recoveryURL = recovery.appendingPathComponent("Before-2.0-\(nextName).invoke")
                try writeProtected(try PersistenceCoding.encoder().encode(BackupPayload(data: snapshot.data, images: assets)), to: recoveryURL)
                try writeProtected(bytes, to: staged.appendingPathComponent("legacy-schema-1.json"))
                let upgradedBytes = try PersistenceCoding.encoder().encode(DiskSnapshot(data: upgraded))
                try writeProtected(upgradedBytes, to: staged.appendingPathComponent("data.json"))
                let verified = try PersistenceCoding.decoder().decode(DiskSnapshot.self, from: Data(contentsOf: staged.appendingPathComponent("data.json")))
                try BackupValidation.validateRecords(verified.data)
                guard try Data(contentsOf: staged.appendingPathComponent("data.json")) == upgradedBytes else { throw InvokeDataError.invalidBackup("Upgrade verification failed.") }
                // Only this atomic pointer change commits the migration. Old storage is retained.
                try writeProtected(Data(nextName.utf8), to: pointerURL)
                generationName = nextName
                lastRecoveryBackupURL = recoveryURL
                suppressAutosave = true; data = upgraded; suppressAutosave = false
                lastSnapshotBytes = upgradedBytes
            } catch {
                try? fileManager.removeItem(at: staged)
                throw error
            }
        } else {
            suppressAutosave = true
            data = snapshot.data
            suppressAutosave = false
            lastSnapshotBytes = bytes
        }
    }

    private func scheduleSave() {
        scheduledSave?.cancel()
        scheduledSave = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 300_000_000) }
            catch { return }
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    /// Never discards the in-memory draft when the filesystem reports an error.
    func flush() {
        scheduledSave?.cancel()
        scheduledSave = nil
        guard data != lastPersisted else {
            if !diskWritesBlocked { saveState = "Saved on this iPhone" }
            return
        }
        do {
            try commitSnapshot(data)
        } catch {
            saveState = "Not saved — tap to retry"
            errorMessage = error.localizedDescription
        }
    }

    /// New discrete actions publish success only after the durable atomic write.
    /// The legacy prose autosave still retains its draft when this throws.
    func commitSnapshot(_ candidate: AppData) throws {
        guard !diskWritesBlocked else {
            throw InvokeDataError.storageUnavailable("Existing files need recovery in Settings before autosaving can resume.")
        }
        var next = candidate
        next.schemaVersion = AppData.currentSchemaVersion
        try BackupValidation.validateRecords(next)
        Self.stampChanges(in: &next, comparedWith: lastPersisted)
        for name in BackupValidation.imageNames(in: next) {
            guard fileManager.fileExists(atPath: imagesURL.appendingPathComponent(name).path) else { throw InvokeDataError.missingPhoto(name) }
        }
        let bytes = try PersistenceCoding.encoder().encode(DiskSnapshot(data: next))
        if let previous = lastSnapshotBytes { try writeProtected(previous, to: generationURL.appendingPathComponent("previous.json")) }
        try writeProtected(bytes, to: generationURL.appendingPathComponent("data.json"))
        let previousData = lastPersisted
        lastPersisted = next; lastSnapshotBytes = bytes
        scheduledSave?.cancel(); scheduledSave = nil
        suppressAutosave = true; data = next; suppressAutosave = false
        pendingImportFiles.subtract(BackupValidation.imageNames(in: next))
        removeUnusedPhotos(keeping: BackupValidation.imageNames(in: next)
            .union(BackupValidation.imageNames(in: previousData)).union(pendingImportFiles))
        saveState = "Saved on this iPhone"
    }

    func imageURL(_ fileName: String) -> URL? {
        guard BackupValidation.isSafeImageName(fileName) else { return nil }
        let url = imagesURL.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    /// ImageIO downsamples before rasterization and applies orientation. Re-encoding
    /// a fresh JPEG omits imported EXIF/GPS metadata and keeps backups manageable.
    func importPhoto(_ bytes: Data) throws -> String {
        guard !diskWritesBlocked else { throw InvokeDataError.storageUnavailable("Restore or recover local storage first.") }
        guard !bytes.isEmpty, bytes.count <= 40 * 1_024 * 1_024,
              let source = CGImageSourceCreateWithData(bytes as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, Double(width) * Double(height) <= 100_000_000 else {
            throw InvokeDataError.invalidPhoto
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2_048,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw InvokeDataError.invalidPhoto
        }
        let result = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(result as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw InvokeDataError.invalidPhoto
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.86] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw InvokeDataError.invalidPhoto }
        let name = UUID().uuidString + ".jpg"
        try fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        try writeProtected(result as Data, to: imagesURL.appendingPathComponent(name))
        pendingImportFiles.insert(name)
        return name
    }

    /// Exports current memory as well as saved data so a disk error does not erase a draft.
    func makeBackup() throws -> BackupDocument {
        guard !diskWritesBlocked else {
            throw InvokeDataError.invalidBackup("Saved data needs recovery. A complete backup cannot be exported from the empty recovery screen. Share an existing recovery copy or restore a validated backup in Settings; existing storage remains untouched.")
        }
        var assets: [String: BackupAsset] = [:]
        for name in BackupValidation.imageNames(in: data) {
            guard let url = imageURL(name) else { throw InvokeDataError.missingPhoto(name) }
            assets[name] = BackupAsset(bytes: try Data(contentsOf: url))
        }
        let payload = BackupPayload(data: data, images: assets)
        try BackupValidation.validate(payload)
        let encodedSize = try PersistenceCoding.encoder().encode(payload).count
        guard encodedSize <= BackupValidation.maximumBackupBytes else {
            throw InvokeDataError.invalidBackup("This collection exceeds the 512 MB portable backup limit.")
        }
        return BackupDocument(payload: payload)
    }

    /// This operation is read-only; the UI shows its result before asking to replace data.
    func validateBackup(_ bytes: Data) throws -> BackupPayload {
        try BackupValidation.decode(bytes)
    }

    /// Stage a complete new generation, preserve a recovery backup, then atomically
    /// switch a tiny pointer. Any validation or write failure leaves the old generation active.
    func restore(_ payload: BackupPayload) throws {
        try BackupValidation.validate(payload)
        var restoredData = payload.data
        restoredData.schemaVersion = AppData.currentSchemaVersion
        try BackupValidation.validateRecords(restoredData)
        let nextName = UUID().uuidString
        let nextDirectory = directory.appendingPathComponent("generations", isDirectory: true)
            .appendingPathComponent(nextName, isDirectory: true)
        let nextImages = nextDirectory.appendingPathComponent("images", isDirectory: true)
        let recoveryDirectory = directory.appendingPathComponent("recovery", isDirectory: true)
        try fileManager.createDirectory(at: nextImages, withIntermediateDirectories: true)
        do {
            for (name, asset) in payload.images { try writeProtected(asset.bytes, to: nextImages.appendingPathComponent(name)) }
            let bytes = try PersistenceCoding.encoder().encode(DiskSnapshot(data: restoredData))
            try writeProtected(bytes, to: nextDirectory.appendingPathComponent("data.json"))
            try fileManager.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)
            let recoveryURL = recoveryDirectory.appendingPathComponent("Before-restore-\(UUID().uuidString).invoke")
            if !diskWritesBlocked {
                let previous = try makeBackup()
                try writeProtected(try PersistenceCoding.encoder().encode(previous.payload), to: recoveryURL)
            }
            // The only commit point. The prior generation remains available on disk.
            try writeProtected(Data(nextName.utf8), to: pointerURL)
            scheduledSave?.cancel()
            scheduledSave = nil
            generationName = nextName
            lastSnapshotBytes = bytes
            lastPersisted = restoredData
            pendingImportFiles = []
            suppressAutosave = true
            data = restoredData
            suppressAutosave = false
            if !diskWritesBlocked {
                recoveryBackupURLs = [recoveryURL] + recoveryBackupURLs.filter { $0 != recoveryURL }
                lastRecoveryBackupURL = recoveryURL
            }
            diskWritesBlocked = false
            saveState = "Restored and saved on this iPhone"
            errorMessage = nil
        } catch {
            // The stage is uniquely owned by this attempt and cannot be the active generation.
            try? fileManager.removeItem(at: nextDirectory)
            throw error
        }
    }

    func deleteEntry(id: UUID) {
        data.entries.removeAll { $0.id == id }
        data.ritualLogs.removeAll { $0.ritualID == id }
        cleanLinks()
        flush()
    }

    func deleteRelic(id: UUID) {
        data.relics.removeAll { $0.id == id }
        cleanLinks()
        flush()
    }

    func removePhoto(file: String, fromRelic id: UUID) {
        guard let index = data.relics.firstIndex(where: { $0.id == id }) else { return }
        data.relics[index].photoFiles.removeAll { $0 == file }
        flush()
    }

    func deleteStory(id: UUID) {
        let chapterIDs = Set(data.chapters.filter { $0.storyID == id }.map(\.id))
        let sceneIDs = Set(data.scenes.filter { $0.storyID == id }.map(\.id))
        data.stories.removeAll { $0.id == id }
        data.chapters.removeAll { $0.storyID == id }
        data.scenes.removeAll { $0.storyID == id }
        data.reflections.removeAll {
            $0.storyID == id || $0.chapterID.map(chapterIDs.contains) == true || $0.sceneID.map(sceneIDs.contains) == true
        }
        cleanLinks()
        flush()
    }

    func deleteStory(_ id: UUID) { deleteStory(id: id) }

    func deleteScene(id: UUID) {
        data.scenes.removeAll { $0.id == id }
        // Standalone reflections preserve the user's description of their attempt.
        for index in data.reflections.indices where data.reflections[index].sceneID == id {
            data.reflections[index].sceneID = nil
        }
        cleanLinks()
        flush()
    }

    func deleteReflection(id: UUID) {
        data.reflections.removeAll { $0.id == id }
        cleanLinks()
        flush()
    }

    func archiveStory(id: UUID, archived: Bool = true) {
        guard let index = data.stories.firstIndex(where: { $0.id == id }) else { return }
        data.stories[index].archived = archived
    }

    func archiveEntry(id: UUID, archived: Bool = true) {
        guard let index = data.entries.firstIndex(where: { $0.id == id }) else { return }
        data.entries[index].archived = archived
    }

    func archiveRelic(id: UUID, archived: Bool = true) {
        guard let index = data.relics.firstIndex(where: { $0.id == id }) else { return }
        data.relics[index].archived = archived
    }

    /// Shared objects are looked up by stable ID, never copied into connected records.
    func cleanLinks() {
        let storyIDs = Set(data.stories.map(\.id))
        let chapters = Dictionary(uniqueKeysWithValues: data.chapters.map { ($0.id, $0) })
        let sceneIDs = Set(data.scenes.map(\.id))
        let entryIDs = Set(data.entries.map(\.id))
        let relicIDs = Set(data.relics.map(\.id))
        let reflectionIDs = Set(data.reflections.map(\.id))
        for i in data.stories.indices {
            data.stories[i].entryIDs = Self.unique(data.stories[i].entryIDs.filter(entryIDs.contains))
            data.stories[i].relicIDs = Self.unique(data.stories[i].relicIDs.filter(relicIDs.contains))
            if let id = data.stories[i].currentChapterID, chapters[id]?.storyID != data.stories[i].id { data.stories[i].currentChapterID = nil }
        }
        for i in data.chapters.indices {
            data.chapters[i].sceneIDs = Self.unique(data.chapters[i].sceneIDs.filter(sceneIDs.contains))
            data.chapters[i].reflectionIDs = Self.unique(data.chapters[i].reflectionIDs.filter(reflectionIDs.contains))
            data.chapters[i].relicIDs = Self.unique(data.chapters[i].relicIDs.filter(relicIDs.contains))
        }
        for i in data.scenes.indices {
            data.scenes[i].entryIDs = Self.unique(data.scenes[i].entryIDs.filter(entryIDs.contains))
            data.scenes[i].relicIDs = Self.unique(data.scenes[i].relicIDs.filter(relicIDs.contains))
        }
        for i in data.entries.indices { data.entries[i].linkedEntryIDs = Self.unique(data.entries[i].linkedEntryIDs.filter(entryIDs.contains)) }
        for i in data.relics.indices { data.relics[i].entryIDs = Self.unique(data.relics[i].entryIDs.filter(entryIDs.contains)) }
        for i in data.reflections.indices {
            if let id = data.reflections[i].storyID, !storyIDs.contains(id) { data.reflections[i].storyID = nil }
            if let id = data.reflections[i].chapterID, chapters[id] == nil { data.reflections[i].chapterID = nil }
            if let id = data.reflections[i].sceneID, !sceneIDs.contains(id) { data.reflections[i].sceneID = nil }
        }
        let ritualIDs = Set(data.entries.filter { $0.kind == .ritual }.map(\.id))
        data.ritualLogs.removeAll { !ritualIDs.contains($0.ritualID) }
        if let id = data.preferences.pinnedStoryID, !storyIDs.contains(id) { data.preferences.pinnedStoryID = nil }
        for i in data.grimoire.practices.indices {
            if let id = data.grimoire.practices[i].legacyEntryID, !entryIDs.contains(id) { data.grimoire.practices[i].legacyEntryID = nil }
            if let id = data.grimoire.practices[i].legacySceneID, !sceneIDs.contains(id) { data.grimoire.practices[i].legacySceneID = nil }
        }
        for i in data.grimoire.invocations.indices {
            if let id = data.grimoire.invocations[i].legacyEntryID, !entryIDs.contains(id) { data.grimoire.invocations[i].legacyEntryID = nil }
            if let id = data.grimoire.invocations[i].legacyStoryID, !storyIDs.contains(id) { data.grimoire.invocations[i].legacyStoryID = nil }
        }
        for i in data.grimoire.arcana.indices {
            if let id = data.grimoire.arcana[i].legacyEntryID, !entryIDs.contains(id) { data.grimoire.arcana[i].legacyEntryID = nil }
        }
    }

    private static func unique(_ ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return ids.filter { seen.insert($0).inserted }
    }

    private func writeProtected(_ bytes: Data, to url: URL) throws {
        try bytes.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private func removeUnusedPhotos(keeping names: Set<String>) {
        guard let files = try? fileManager.contentsOfDirectory(at: imagesURL, includingPropertiesForKeys: nil) else { return }
        for file in files where BackupValidation.isSafeImageName(file.lastPathComponent) && !names.contains(file.lastPathComponent) {
            try? fileManager.removeItem(at: file)
        }
    }

    private static func stampChanges(in next: inout AppData, comparedWith old: AppData) {
        let now = Date()
        func stamp<T: Identifiable & Equatable>(_ records: inout [T], _ previous: [T], _ key: WritableKeyPath<T, Date>) where T.ID == UUID {
            let lookup = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
            for index in records.indices where lookup[records[index].id] != records[index] {
                records[index][keyPath: key] = now
            }
        }
        stamp(&next.stories, old.stories, \Story.updatedAt)
        stamp(&next.chapters, old.chapters, \Chapter.updatedAt)
        stamp(&next.scenes, old.scenes, \Scene.updatedAt)
        stamp(&next.entries, old.entries, \LibraryEntry.updatedAt)
        stamp(&next.relics, old.relics, \Relic.updatedAt)
        stamp(&next.reflections, old.reflections, \Reflection.updatedAt)
        stamp(&next.ritualLogs, old.ritualLogs, \RitualLog.updatedAt)
    }
}
