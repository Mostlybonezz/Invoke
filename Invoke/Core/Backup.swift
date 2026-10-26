import Foundation
import SwiftUI
import UniformTypeIdentifiers
import CryptoKit
import ImageIO

extension UTType {
    static let invokeBackup = UTType(exportedAs: "app.invoke.backup", conformingTo: .json)
}

struct BackupAsset: Codable, Equatable {
    var bytes: Data
    var sha256: String

    init(bytes: Data) {
        self.bytes = bytes
        self.sha256 = Self.digest(bytes)
    }

    static func digest(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}

/// A single portable file, including every referenced photograph and cover.
struct BackupPayload: Codable, Equatable {
    static let currentFormatVersion = 1
    var format = "Invoke portable backup"
    var formatVersion = currentFormatVersion
    var exportedAt = Date()
    var data: AppData
    var images: [String: BackupAsset]
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.invokeBackup, .json] }
    static var writableContentTypes: [UTType] { [.invokeBackup] }
    var payload: BackupPayload

    init(payload: BackupPayload) { self.payload = payload }

    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents else {
            throw InvokeDataError.invalidBackup("Choose a complete Invoke backup file.")
        }
        self.payload = try BackupValidation.decode(bytes)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try BackupValidation.validate(payload)
        return FileWrapper(regularFileWithContents: try PersistenceCoding.encoder().encode(payload))
    }
}

enum InvokeDataError: LocalizedError {
    case unsupportedVersion(Int)
    case invalidBackup(String)
    case missingPhoto(String)
    case invalidPhoto
    case storageUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            "This file uses data version \(version). Update Invoke before restoring it. Your current writing is unchanged."
        case .invalidBackup(let reason):
            "This backup could not be restored. \(reason) Your current writing is unchanged."
        case .missingPhoto:
            "A photograph is missing from local storage. The backup was not created; your writing is still here."
        case .invalidPhoto:
            "That image could not be imported. Choose a JPEG, PNG, HEIC, or other photo supported by this iPhone, smaller than 40 MB."
        case .storageUnavailable(let reason):
            "Invoke could not save to this device. \(reason) Your current writing remains in memory; keep the app open and export a backup."
        }
    }
}

enum PersistenceCoding {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}

enum BackupValidation {
    static let maximumBackupBytes = 512 * 1_024 * 1_024
    static let maximumImageBytes = 20 * 1_024 * 1_024

    static func decode(_ bytes: Data) throws -> BackupPayload {
        guard bytes.count <= maximumBackupBytes else {
            throw InvokeDataError.invalidBackup("This backup exceeds the 512 MB import limit.")
        }
        let payload: BackupPayload
        do { payload = try PersistenceCoding.decoder().decode(BackupPayload.self, from: bytes) }
        catch { throw InvokeDataError.invalidBackup("The file is incomplete or is not an Invoke backup.") }
        try validate(payload)
        return payload
    }

    static func imageNames(in data: AppData) -> Set<String> {
        Set(data.relics.flatMap(\.photoFiles) + data.stories.compactMap(\.coverFile))
    }

    static func isSafeImageName(_ name: String) -> Bool {
        // Only names produced by our importer are accepted. No path components or traversal.
        guard name.hasSuffix(".jpg") else { return false }
        return UUID(uuidString: String(name.dropLast(4))) != nil
    }

    static func validate(_ payload: BackupPayload) throws {
        guard payload.format == "Invoke portable backup" else {
            throw InvokeDataError.invalidBackup("The backup format is not recognized.")
        }
        guard payload.formatVersion == BackupPayload.currentFormatVersion else {
            throw InvokeDataError.unsupportedVersion(payload.formatVersion)
        }
        try validateRecords(payload.data)
        let names = imageNames(in: payload.data)
        guard names == Set(payload.images.keys) else {
            throw InvokeDataError.invalidBackup("The image manifest is incomplete or contains unexpected files.")
        }
        var total = 0
        for (name, asset) in payload.images {
            guard isSafeImageName(name), !asset.bytes.isEmpty,
                  asset.bytes.count <= maximumImageBytes,
                  BackupAsset.digest(asset.bytes) == asset.sha256 else {
                throw InvokeDataError.invalidBackup("A photograph failed its integrity check.")
            }
            total += asset.bytes.count
            guard total <= maximumBackupBytes / 4 * 3,
                  let source = CGImageSourceCreateWithData(asset.bytes as CFData, nil),
                  CGImageSourceGetCount(source) == 1,
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int,
                  width > 0, height > 0, width <= 2_048, height <= 2_048,
                  CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else {
                throw InvokeDataError.invalidBackup("A photograph is damaged or exceeds the supported image size.")
            }
        }
    }

    static func validateRecords(_ data: AppData) throws {
        guard (1...AppData.currentSchemaVersion).contains(data.schemaVersion) else {
            throw InvokeDataError.unsupportedVersion(data.schemaVersion)
        }
        guard ["ink", "velvet", "astral"].contains(data.preferences.theme),
              ["subtle", "full", "off"].contains(data.preferences.effects),
              ["theme", "ripple", "beam", "sparkle"].contains(data.preferences.shaderStyle),
              ["system", "tinted", "solid"].contains(data.preferences.glassStyle),
              data.preferences.effectIntensity.isFinite,
              (0.35...1.5).contains(data.preferences.effectIntensity),
              data.preferences.effectSpeed.isFinite,
              (0.6...1.4).contains(data.preferences.effectSpeed) else {
            throw InvokeDataError.invalidBackup("Appearance preferences are invalid.")
        }
        func unique<T: Identifiable>(_ records: [T]) throws where T.ID == UUID {
            guard records.count <= 100_000, Set(records.map(\.id)).count == records.count else {
                throw InvokeDataError.invalidBackup("Some records have duplicate identifiers or exceed the supported collection size.")
            }
        }
        try unique(data.stories); try unique(data.chapters); try unique(data.scenes)
        try unique(data.entries); try unique(data.relics); try unique(data.reflections); try unique(data.ritualLogs)
        for entry in data.entries { try unique(entry.history) }
        for relic in data.relics { try unique(relic.checklist) }
        let stories = Dictionary(uniqueKeysWithValues: data.stories.map { ($0.id, $0) })
        let chapters = Dictionary(uniqueKeysWithValues: data.chapters.map { ($0.id, $0) })
        let scenes = Dictionary(uniqueKeysWithValues: data.scenes.map { ($0.id, $0) })
        let entries = Set(data.entries.map(\.id))
        let relics = Set(data.relics.map(\.id))
        let reflections = Set(data.reflections.map(\.id))
        let reflectionLookup = Dictionary(uniqueKeysWithValues: data.reflections.map { ($0.id, $0) })
        func require(_ valid: Bool) throws {
            if !valid { throw InvokeDataError.invalidBackup("Some linked records are missing or inconsistent.") }
        }
        func links(_ ids: [UUID], in available: Set<UUID>) -> Bool {
            Set(ids).isSubset(of: available) && Set(ids).count == ids.count
        }
        for story in data.stories {
            try require(story.secondaryModes.count <= 2 && (0...6).contains(story.authoringStep))
            try require(StoryCatalog.storyStatuses.contains(story.status) && StoryCatalog.shapes.contains(story.shape))
            try require(links(story.entryIDs, in: entries) && links(story.relicIDs, in: relics))
            if let chapterID = story.currentChapterID { try require(chapters[chapterID]?.storyID == story.id) }
        }
        for chapter in data.chapters {
            try require(stories[chapter.storyID] != nil && links(chapter.relicIDs, in: relics))
            try require(links(chapter.reflectionIDs, in: reflections))
            for id in chapter.reflectionIDs {
                try require(reflectionLookup[id]?.chapterID == chapter.id)
                if let storyID = reflectionLookup[id]?.storyID { try require(storyID == chapter.storyID) }
            }
            try require(Set(chapter.sceneIDs).count == chapter.sceneIDs.count)
            for id in chapter.sceneIDs { try require(scenes[id]?.chapterID == chapter.id && scenes[id]?.storyID == chapter.storyID) }
        }
        for scene in data.scenes {
            try require(StoryCatalog.sceneStatuses.contains(scene.status))
            try require(stories[scene.storyID] != nil && chapters[scene.chapterID]?.storyID == scene.storyID)
            try require(links(scene.entryIDs, in: entries) && links(scene.relicIDs, in: relics))
        }
        for entry in data.entries {
            try require(links(entry.linkedEntryIDs, in: entries))
            let allowed = entry.kind == .belief ? StoryCatalog.beliefStatuses : ["Active", "Resting", "Complete"]
            try require(allowed.contains(entry.status))
        }
        for relic in data.relics {
            try require(links(relic.entryIDs, in: entries))
            try require(StoryCatalog.relicStatuses.contains(relic.status))
        }
        for reflection in data.reflections {
            if let id = reflection.storyID { try require(stories[id] != nil) }
            if let id = reflection.chapterID {
                try require(chapters[id] != nil)
                if let storyID = reflection.storyID { try require(chapters[id]?.storyID == storyID) }
            }
            if let id = reflection.sceneID {
                try require(scenes[id] != nil)
                if let chapterID = reflection.chapterID { try require(scenes[id]?.chapterID == chapterID) }
                if let storyID = reflection.storyID { try require(scenes[id]?.storyID == storyID) }
            }
        }
        let rituals = Set(data.entries.filter { $0.kind == .ritual }.map(\.id))
        for log in data.ritualLogs { try require(rituals.contains(log.ritualID)) }
        if let id = data.preferences.pinnedStoryID { try require(stories[id] != nil) }
        try require(imageNames(in: data).allSatisfy(isSafeImageName))
        if data.schemaVersion == 2 { try GrimoireValidation.validate(data.grimoire, legacy: data) }
    }
}
