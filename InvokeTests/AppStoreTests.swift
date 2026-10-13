import XCTest
import UIKit
import ImageIO
@testable import Invoke

final class AppStoreTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("InvokeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func photo(width: CGFloat = 64, height: CGFloat = 48) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).jpegData(withCompressionQuality: 0.95) { context in
            UIColor(red: 0.4, green: 0.05, blue: 0.09, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    @MainActor
    func testDefaultsAndWritingSurviveReopening() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(directory: directory)
        XCTAssertEqual(store.data.preferences.theme, "astral")
        XCTAssertEqual(store.data.preferences.effects, "subtle")
        XCTAssertFalse(store.data.preferences.onboardingComplete)
        XCTAssertTrue(store.data.stories.isEmpty)
        store.data.stories.append(Story(title: "A beginning that can be quiet", prose: "Unfinished writing matters."))
        store.data.preferences.theme = "astral"
        store.flush()
        let reopened = AppStore(directory: directory)
        XCTAssertEqual(reopened.data.stories.first?.prose, "Unfinished writing matters.")
        XCTAssertEqual(reopened.data.preferences.theme, "astral")
        XCTAssertNil(reopened.errorMessage)
    }

    @MainActor
    func testNestedMutationAutosavesWithoutManualFlush() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(directory: directory)
        store.data.stories.append(Story(title: "Draft"))
        store.flush()
        store.data.stories[0].prose = "An interruption should not erase this paragraph."
        try await Task.sleep(nanoseconds: 650_000_000)
        let reopened = AppStore(directory: directory)
        XCTAssertEqual(reopened.data.stories.first?.prose, "An interruption should not erase this paragraph.")
    }

    @MainActor
    func testPhotosAreDownsampledAndPortableBackupRestoresThem() throws {
        let sourceDirectory = try temporaryDirectory()
        let targetDirectory = try temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: sourceDirectory)
            try? FileManager.default.removeItem(at: targetDirectory)
        }
        let source = AppStore(directory: sourceDirectory)
        let name = try source.importPhoto(photo(width: 4_000, height: 3_000))
        source.data.relics.append(Relic(name: "My real object", photoFiles: [name], meaning: "A personal memory"))
        source.flush()
        let importedURL = try XCTUnwrap(source.imageURL(name))
        let imported = try XCTUnwrap(CGImageSourceCreateWithURL(importedURL as CFURL, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(imported, 0, nil) as? [CFString: Any])
        XCTAssertLessThanOrEqual(try XCTUnwrap(properties[kCGImagePropertyPixelWidth] as? Int), 2_048)
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
        let backup = try source.makeBackup()
        let encoded = try PersistenceCoding.encoder().encode(backup.payload)
        let target = AppStore(directory: targetDirectory)
        target.data.stories.append(Story(title: "Writing before restore"))
        let checked = try target.validateBackup(encoded)
        try target.restore(checked)
        XCTAssertEqual(target.data.relics.first?.name, "My real object")
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(target.imageURL(name))), try Data(contentsOf: importedURL))
        let recoveryURL = try XCTUnwrap(target.lastRecoveryBackupURL)
        let recovered = try target.validateBackup(Data(contentsOf: recoveryURL))
        XCTAssertEqual(recovered.data.stories.first?.title, "Writing before restore")
        let reopened = AppStore(directory: targetDirectory)
        XCTAssertNotNil(reopened.imageURL(name))
        XCTAssertEqual(reopened.data.relics.first?.meaning, "A personal memory")
    }

    @MainActor
    func testIncompleteOrTamperedBackupsLeaveMemoryAndDiskUnchanged() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(directory: directory)
        let name = try store.importPhoto(photo())
        store.data.relics.append(Relic(name: "Keep me", photoFiles: [name]))
        store.flush()
        let before = store.data
        let pointer = try Data(contentsOf: directory.appendingPathComponent("CURRENT"))
        var incomplete = try store.makeBackup().payload
        incomplete.images = [:]
        XCTAssertThrowsError(try store.restore(incomplete))
        XCTAssertEqual(store.data, before)
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("CURRENT")), pointer)
        var corrupt = try store.makeBackup().payload
        corrupt.images[name]?.bytes = Data("damaged".utf8)
        XCTAssertThrowsError(try store.restore(corrupt))
        XCTAssertThrowsError(try store.validateBackup(Data("{partial".utf8)))
        XCTAssertEqual(store.data, before)
        XCTAssertEqual(try AppStore(directory: directory).makeBackup().payload.images[name]?.sha256,
                       try store.makeBackup().payload.images[name]?.sha256)
    }

    @MainActor
    func testFutureSchemaAndUnsafeImagePathAreRejected() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(directory: directory)
        var future = BackupPayload(data: AppData(), images: [:])
        future.data.schemaVersion = 99
        XCTAssertThrowsError(try store.restore(future))
        var unsafe = BackupPayload(data: AppData(), images: [:])
        unsafe.data.relics = [Relic(name: "Unsafe", photoFiles: ["../data.json"])]
        unsafe.images["../data.json"] = BackupAsset(bytes: photo())
        XCTAssertThrowsError(try store.restore(unsafe))
        XCTAssertTrue(store.data.relics.isEmpty)
    }

    @MainActor
    func testArchiveKeepsSharedConnectionsAndDeleteCleansThem() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(directory: directory)
        store.loadExamples()
        let belief = try XCTUnwrap(store.data.entries.first { $0.kind == .belief })
        let story = try XCTUnwrap(store.data.stories.first { $0.entryIDs.contains(belief.id) })
        store.archiveEntry(id: belief.id)
        XCTAssertTrue(try XCTUnwrap(store.data.stories.first { $0.id == story.id }).entryIDs.contains(belief.id))
        try BackupValidation.validateRecords(store.data)
        store.deleteEntry(id: belief.id)
        XCTAssertFalse(store.data.stories.flatMap(\.entryIDs).contains(belief.id))
        XCTAssertFalse(store.data.scenes.flatMap(\.entryIDs).contains(belief.id))
        XCTAssertFalse(store.data.entries.flatMap(\.linkedEntryIDs).contains(belief.id))
        XCTAssertFalse(store.data.relics.flatMap(\.entryIDs).contains(belief.id))
        let entryCount = store.data.entries.count
        let relicCount = store.data.relics.count
        store.deleteStory(id: story.id)
        XCTAssertFalse(store.data.chapters.contains { $0.storyID == story.id })
        XCTAssertFalse(store.data.scenes.contains { $0.storyID == story.id })
        XCTAssertFalse(store.data.reflections.contains { $0.storyID == story.id })
        XCTAssertEqual(store.data.entries.count, entryCount)
        XCTAssertEqual(store.data.relics.count, relicCount)
        XCTAssertNil(store.data.preferences.pinnedStoryID)
        try BackupValidation.validateRecords(store.data)
    }

    @MainActor
    func testRemovingExamplesPreservesPersonalSceneAndItsParents() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(directory: directory)
        store.loadExamples()
        let story = try XCTUnwrap(store.data.stories.first)
        let chapterID = try XCTUnwrap(story.currentChapterID)
        let personal = Scene(storyID: story.id, chapterID: chapterID, title: "My own new scene")
        store.data.scenes.append(personal)
        store.removeExamples()
        XCTAssertTrue(store.data.scenes.contains { $0.id == personal.id })
        XCTAssertTrue(store.data.stories.contains { $0.id == story.id && !$0.isExample })
        XCTAssertTrue(store.data.chapters.contains { $0.id == chapterID && !$0.isExample })
        XCTAssertFalse(store.data.stories.contains(where: \.isExample))
        try BackupValidation.validateRecords(store.data)
    }

    @MainActor
    func testDamagedLatestSaveRecoversPreviousSnapshot() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(directory: directory)
        store.data.stories.append(Story(title: "Previous version"))
        store.flush()
        store.data.stories[0].title = "Latest version"
        store.flush()
        let generation = try String(contentsOf: directory.appendingPathComponent("CURRENT"), encoding: .utf8)
        let latest = directory.appendingPathComponent("generations/\(generation)/data.json")
        try Data("incomplete".utf8).write(to: latest)
        let reopened = AppStore(directory: directory)
        XCTAssertEqual(reopened.data.stories.first?.title, "Previous version")
        XCTAssertNotNil(reopened.errorMessage)
        let files = try FileManager.default.contentsOfDirectory(atPath: latest.deletingLastPathComponent().path)
        XCTAssertTrue(files.contains { $0.hasPrefix("damaged-") })
    }

    func testExampleCollectionHasConsistentRelationships() throws {
        let data = SampleData.collection()
        try BackupValidation.validateRecords(data)
        XCTAssertEqual(data.stories.count, 3)
        XCTAssertEqual(data.scenes.filter { $0.status == "Experienced" }.count, 3)
        XCTAssertEqual(data.preferences.theme, "astral")
        XCTAssertEqual(data.preferences.effects, "subtle")
    }

    func testAllAppearanceCombinationsValidate() throws {
        for theme in ["ink", "velvet", "astral"] {
            for effects in ["subtle", "full", "off"] {
                var data = AppData()
                data.preferences.theme = theme
                data.preferences.effects = effects
                try BackupValidation.validateRecords(data)
            }
        }
        XCTAssertEqual(LibraryEntry(kind: .belief).status, "Held")
    }

    func testCrossChapterKeepsakeReferenceIsRejected() throws {
        var data = SampleData.collection()
        let reflectionID = try XCTUnwrap(data.reflections.first?.id)
        data.chapters[1].reflectionIDs.append(reflectionID)
        XCTAssertThrowsError(try BackupValidation.validateRecords(data))
    }

    @MainActor
    func testPhotoCleanupRetainsPreviousSnapshotThenRemovesOrphan() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(directory: directory)
        let name = try store.importPhoto(photo())
        store.data.relics.append(Relic(name: "A keepsake", photoFiles: [name]))
        store.flush()
        store.data.relics[0].photoFiles = []
        store.flush()
        XCTAssertNotNil(store.imageURL(name), "Previous snapshot still needs its photograph")
        store.data.relics[0].meaning = "A memory without a photograph"
        store.flush()
        XCTAssertNil(store.imageURL(name), "Both complete snapshots have released this photograph")
        XCTAssertNil(AppStore(directory: directory).errorMessage)
    }

    @MainActor
    func testRevertedEditDoesNotLeaveSavingIndicatorStuck() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(directory: directory)
        store.data.preferences.theme = "velvet"
        store.data.preferences.theme = "astral"
        store.flush()
        XCTAssertEqual(store.saveState, "Saved on this iPhone")
    }

    @MainActor
    func testFutureLocalSchemaIsPreservedInsteadOfDowngraded() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(directory: directory)
        store.data.stories.append(Story(title: "Future writing"))
        store.flush()
        let generation = try String(contentsOf: directory.appendingPathComponent("CURRENT"), encoding: .utf8)
        let latest = directory.appendingPathComponent("generations/\(generation)/data.json")
        var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: latest)) as? [String: Any])
        var futureData = try XCTUnwrap(envelope["data"] as? [String: Any])
        futureData["schemaVersion"] = 99
        envelope["data"] = futureData
        let futureBytes = try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
        try futureBytes.write(to: latest)
        let reopened = AppStore(directory: directory)
        XCTAssertNotNil(reopened.errorMessage)
        reopened.data.stories.append(Story(title: "Keep this draft in memory"))
        reopened.flush()
        XCTAssertEqual(try Data(contentsOf: latest), futureBytes)
        XCTAssertEqual(reopened.data.stories.first?.title, "Keep this draft in memory")
    }
}
