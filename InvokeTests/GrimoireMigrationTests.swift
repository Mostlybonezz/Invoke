import XCTest
import UIKit
@testable import Invoke

final class GrimoireMigrationTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MigrationTests-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    private func writeLegacy(_ data: AppData, at root: URL, extras: Bool = false) throws -> (String, Data) {
        let generation = UUID().uuidString
        let path = root.appendingPathComponent("generations/\(generation)")
        try FileManager.default.createDirectory(at: path.appendingPathComponent("images"), withIntermediateDirectories: true)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: PersistenceCoding.encoder().encode(data)) as? [String: Any])
        json["schemaVersion"] = 1; json.removeValue(forKey: "grimoire")
        if extras { json["unknownFutureField"] = ["text": "Retain in raw recovery source"] }
        let bytes = try JSONSerialization.data(withJSONObject: ["formatVersion": 1, "writtenAt": 1_700_000_000_000, "data": json], options: [.sortedKeys])
        try bytes.write(to: path.appendingPathComponent("data.json"), options: .atomic)
        try Data(generation.utf8).write(to: root.appendingPathComponent("CURRENT"), options: .atomic)
        return (generation, bytes)
    }
    @MainActor func testActualSchemaOneFixturePreservesEveryLegacyCollectionAndIDs() throws {
        let root = try directory(); var original = SampleData.collection()
        original.preferences.theme = "velvet"; original.preferences.onboardingComplete = true
        original.stories[0].prose = "Synthetic legacy prose, preserved exactly."
        let (old, bytes) = try writeLegacy(original, at: root, extras: true)
        let store = AppStore(directory: root)
        XCTAssertNil(store.errorMessage); XCTAssertEqual(store.data.schemaVersion, 2)
        XCTAssertEqual(store.data.stories.map(\.id), original.stories.map(\.id))
        XCTAssertEqual(store.data.chapters.map(\.id), original.chapters.map(\.id))
        XCTAssertEqual(store.data.scenes.map(\.id), original.scenes.map(\.id))
        XCTAssertEqual(store.data.entries.map(\.id), original.entries.map(\.id))
        XCTAssertEqual(store.data.relics.map(\.id), original.relics.map(\.id))
        XCTAssertEqual(store.data.reflections.map(\.id), original.reflections.map(\.id))
        XCTAssertEqual(store.data.ritualLogs.map(\.id), original.ritualLogs.map(\.id))
        XCTAssertEqual(store.data.stories[0].prose, original.stories[0].prose)
        XCTAssertEqual(store.data.preferences.theme, "velvet"); XCTAssertTrue(store.data.preferences.onboardingComplete)
        XCTAssertTrue(store.data.grimoire.actions.isEmpty); XCTAssertTrue(store.data.grimoire.practices.isEmpty)
        let active = try String(contentsOf: root.appendingPathComponent("CURRENT"), encoding: .utf8)
        XCTAssertNotEqual(old, active)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("generations/\(old)/data.json")), bytes)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("generations/\(active)/legacy-schema-1.json")), bytes)
        XCTAssertNotNil(store.lastRecoveryBackupURL)
        try BackupValidation.validateRecords(store.data)
    }
    @MainActor func testSecondMigrationIsNoOpAndDoesNotDuplicateRecordsOrRecoveryCopies() throws {
        let root = try directory(); _ = try writeLegacy(SampleData.collection(), at: root)
        let first = AppStore(directory: root)
        XCTAssertNil(first.errorMessage)
        let pointer = try Data(contentsOf: root.appendingPathComponent("CURRENT"))
        let recoveryBefore = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("recovery"), includingPropertiesForKeys: nil).count
        let second = AppStore(directory: root)
        XCTAssertNil(second.errorMessage)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("CURRENT")), pointer)
        XCTAssertEqual(second.data.stories.map(\.id), first.data.stories.map(\.id))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("recovery"), includingPropertiesForKeys: nil).count, recoveryBefore)
    }
    @MainActor func testInterruptedUncommittedMigrationStageDoesNotReplaceValidLegacyPointer() throws {
        let root = try directory(); let (old, _) = try writeLegacy(SampleData.collection(), at: root)
        let abandoned = root.appendingPathComponent("generations/\(UUID())")
        try FileManager.default.createDirectory(at: abandoned, withIntermediateDirectories: true)
        try Data("partial stage".utf8).write(to: abandoned.appendingPathComponent("data.json"))
        let reopened = AppStore(directory: root)
        XCTAssertNil(reopened.errorMessage); XCTAssertFalse(reopened.data.stories.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("generations/\(old)/data.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: abandoned.path))
    }
    @MainActor func testCorruptLegacyInputBlocksWritesAndKeepsRawSource() throws {
        let root = try directory(); let (old, _) = try writeLegacy(AppData(), at: root)
        let corrupt = Data("{ incomplete".utf8)
        try corrupt.write(to: root.appendingPathComponent("generations/\(old)/data.json"))
        let store = AppStore(directory: root)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertThrowsError(try store.activatePractice(PracticeDefinition(title: "Must not overwrite")))
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("CURRENT"), encoding: .utf8), old)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("generations/\(old)/data.json")), corrupt)
    }
    @MainActor func testOldPortableBackupIsAcceptedAndRestoredAsSchemaTwo() throws {
        var original = SampleData.collection(); original.schemaVersion = 1
        let backup = BackupPayload(data: original, images: [:])
        let bytes = try PersistenceCoding.encoder().encode(backup)
        let validated = try BackupValidation.decode(bytes)
        let root = try directory(), store = AppStore(directory: root)
        try store.restore(validated)
        XCTAssertEqual(store.data.schemaVersion, 2)
        XCTAssertEqual(store.data.stories.map(\.id), original.stories.map(\.id))
        XCTAssertEqual(AppStore(directory: root).data.schemaVersion, 2)
    }
    @MainActor func testMissingSchemaTwoGrimoireIsCorruptionNotEmptyReset() throws {
        let root = try directory(); let store = AppStore(directory: root)
        try store.saveSpell(Spell(title: "Keep this record"))
        let generation = try String(contentsOf: root.appendingPathComponent("CURRENT"), encoding: .utf8)
        let snapshot = root.appendingPathComponent("generations/\(generation)/data.json")
        var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: snapshot)) as? [String: Any])
        var data = try XCTUnwrap(envelope["data"] as? [String: Any]); data.removeValue(forKey: "grimoire"); envelope["data"] = data
        let missing = try JSONSerialization.data(withJSONObject: envelope)
        XCTAssertThrowsError(try PersistenceCoding.decoder().decode(AppData.self, from: JSONSerialization.data(withJSONObject: data)))
        try missing.write(to: snapshot)
        // Previous snapshot is the honest recovery source, never a silently accepted empty v2 payload.
        let reopened = AppStore(directory: root)
        XCTAssertNotNil(reopened.errorMessage)
    }
    @MainActor func testPhotoAndLegacyLinksSurviveShadowMigration() throws {
        let root = try directory(), first = AppStore(directory: root)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).jpegData(withCompressionQuality: 0.8) { context in
            UIColor.orange.setFill(); context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let name = try first.importPhoto(image)
        first.data.relics.append(Relic(name: "Synthetic keepsake", photoFiles: [name])); first.flush()
        let sourceImage = try Data(contentsOf: XCTUnwrap(first.imageURL(name)))
        let generation = try String(contentsOf: root.appendingPathComponent("CURRENT"), encoding: .utf8)
        let snapshot = root.appendingPathComponent("generations/\(generation)/data.json")
        var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: snapshot)) as? [String: Any])
        var data = try XCTUnwrap(envelope["data"] as? [String: Any]); data["schemaVersion"] = 1; data.removeValue(forKey: "grimoire"); envelope["data"] = data
        try JSONSerialization.data(withJSONObject: envelope).write(to: snapshot)
        let upgraded = AppStore(directory: root)
        XCTAssertNil(upgraded.errorMessage); XCTAssertEqual(upgraded.data.relics[0].photoFiles, [name])
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(upgraded.imageURL(name))), sourceImage)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("generations/\(generation)/images/\(name)").path))
    }
    @MainActor func testVersionTwoBackupRoundTripsAllNewCoreRelationships() throws {
        let source = AppStore(directory: try directory())
        let goal = Invocation(title: "An exploratory intention", observations: [InvocationObservation(text: "An observation")])
        let spell = Spell(title: "Method", source: "Source"); let asset = CareAsset(name: "An item", quantity: 2, estimatedCost: 20)
        try source.saveInvocation(goal); try source.saveSpell(spell); try source.saveAsset(asset)
        var p = PracticeDefinition(title: "My custom ritual", invocationID: goal.id, spellIDs: [spell.id], assetID: asset.id)
        p.schedule.kind = .unscheduled; try source.activatePractice(p)
        try source.saveEnchantment(Enchantment(title: "Arrangement", invocationID: goal.id, maintenancePracticeID: p.id))
        try source.saveArcana(ArcanaRecord(title: "A dream", kind: "Dream", interpretation: "Personal meaning"))
        try source.saveEcho(Echo(title: "Comparison", sourceA: "A", sourceB: "B", differences: "Different contexts"))
        let target = AppStore(directory: try directory()); try target.restore(source.makeBackup().payload)
        XCTAssertEqual(target.data.grimoire.practices[0].invocationID, goal.id)
        XCTAssertEqual(target.data.grimoire.practices[0].spellIDs, [spell.id])
        XCTAssertEqual(target.data.grimoire.practices[0].assetID, asset.id)
        XCTAssertEqual(target.data.grimoire.enchantments[0].maintenancePracticeID, p.id)
        XCTAssertEqual(target.data.grimoire.arcana[0].interpretation, "Personal meaning")
        XCTAssertEqual(target.data.grimoire.echoes[0].differences, "Different contexts")
        XCTAssertEqual(target.data.grimoire.invocations[0].observations.count, 1)
        try BackupValidation.validateRecords(target.data)
    }
}
