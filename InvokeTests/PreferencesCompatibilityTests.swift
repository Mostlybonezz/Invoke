import XCTest
@testable import Invoke

final class PreferencesCompatibilityTests: XCTestCase {
    private let newKeys = ["shaderStyle", "effectIntensity", "effectSpeed", "glassStyle"]

    @MainActor
    func testVersionOneSnapshotPreservesThemeAndWriting() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = AppStore(directory: directory)
        original.data.preferences.theme = "ink"
        original.data.stories.append(Story(title: "My own story", prose: "Keep every word."))
        original.flush()
        let generation = try String(contentsOf: directory.appendingPathComponent("CURRENT"), encoding: .utf8)
        let snapshot = directory.appendingPathComponent("generations/\(generation)/data.json")
        var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: snapshot)) as? [String: Any])
        var data = try XCTUnwrap(envelope["data"] as? [String: Any])
        var preferences = try XCTUnwrap(data["preferences"] as? [String: Any])
        for key in newKeys { preferences.removeValue(forKey: key) }
        data["preferences"] = preferences; envelope["data"] = data
        try JSONSerialization.data(withJSONObject: envelope).write(to: snapshot)
        let reopened = AppStore(directory: directory)
        XCTAssertNil(reopened.errorMessage)
        XCTAssertEqual(reopened.data.preferences.theme, "ink")
        XCTAssertEqual(reopened.data.preferences.shaderStyle, "theme")
        XCTAssertEqual(reopened.data.preferences.glassStyle, "system")
        XCTAssertEqual(reopened.data.preferences.effectIntensity, 1)
        XCTAssertEqual(reopened.data.stories.first?.prose, "Keep every word.")
    }

    func testVersionOneBackupAndNewCustomizationRoundTrip() throws {
        var data = AppData()
        data.preferences.theme = "velvet"
        data.stories = [Story(title: "A saved chapter", prose: "Still mine.")]
        let payload = BackupPayload(data: data, images: [:])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: PersistenceCoding.encoder().encode(payload)) as? [String: Any])
        var records = try XCTUnwrap(json["data"] as? [String: Any])
        var preferences = try XCTUnwrap(records["preferences"] as? [String: Any])
        for key in newKeys { preferences.removeValue(forKey: key) }
        records["preferences"] = preferences; json["data"] = records
        var restored = try BackupValidation.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored.data.preferences.theme, "velvet")
        XCTAssertEqual(restored.data.preferences.shaderStyle, "theme")
        XCTAssertEqual(restored.data.stories.first?.prose, "Still mine.")
        restored.data.preferences.shaderStyle = "sparkle"
        restored.data.preferences.effectIntensity = 1.4
        restored.data.preferences.effectSpeed = 0.7
        restored.data.preferences.glassStyle = "tinted"
        let roundTrip = try BackupValidation.decode(PersistenceCoding.encoder().encode(restored))
        XCTAssertEqual(roundTrip, restored)
    }

    @MainActor
    func testInvalidAppearanceCannotReplaceWriting() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(directory: directory)
        store.data.stories = [Story(title: "Untouched")]
        store.flush()
        let original = store.data
        var invalid = [Preferences]()
        var preferences = Preferences(); preferences.effectIntensity = 2; invalid.append(preferences)
        preferences = Preferences(); preferences.effectSpeed = 0; invalid.append(preferences)
        preferences = Preferences(); preferences.shaderStyle = "unknown"; invalid.append(preferences)
        preferences = Preferences(); preferences.glassStyle = "unknown"; invalid.append(preferences)
        preferences = Preferences(); preferences.effectIntensity = .nan; invalid.append(preferences)
        for appearance in invalid {
            var replacement = AppData(); replacement.preferences = appearance
            XCTAssertThrowsError(try store.restore(BackupPayload(data: replacement, images: [:])))
            XCTAssertEqual(store.data, original)
        }
        let reopened = AppStore(directory: directory)
        XCTAssertEqual(reopened.data.stories.first?.title, "Untouched")
        XCTAssertEqual(reopened.data.preferences.glassStyle, original.preferences.glassStyle)
    }
}
