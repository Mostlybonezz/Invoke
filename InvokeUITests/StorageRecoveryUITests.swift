import XCTest

final class StorageRecoveryUITests: XCTestCase {
    private func element(_ identifier: String, app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
    private func reveal(_ target: XCUIElement, app: XCUIApplication) {
        _ = target.waitForExistence(timeout: 3)
        for _ in 0..<8 {
            if target.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(target.isHittable)
    }
    private func dismissStartupError(_ app: XCUIApplication) {
        if app.alerts.firstMatch.waitForExistence(timeout: 4) { app.alerts.buttons["OK"].tap() }
    }
    func testCorruptStorageOpensRecoveryAndNeverExportsEmptyDefaults() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-session=\(UUID().uuidString)", "--ui-testing-fixture=corrupt-storage"]
        app.launch()
        dismissStartupError(app)
        XCTAssertTrue(element("storage-recovery", app: app).waitForExistence(timeout: 10))
        XCTAssertFalse(element("onboarding-skip", app: app).exists)
        XCTAssertFalse(element("today-add-quest", app: app).exists)
        let recovery = element("storage-open-recovery", app: app)
        reveal(recovery, app: app)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "32-Corrupt-storage-recovery"; attachment.lifetime = .keepAlways; add(attachment)
        recovery.tap()
        let restore = app.buttons["Restore from backup"]
        reveal(restore, app: app)
        XCTAssertTrue(restore.isEnabled, "A retained backup must remain reachable without onboarding.")
        let export = app.buttons["Export complete backup"]
        reveal(export, app: app); export.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5), "Corrupt storage must not be exported as a valid empty collection.")
        app.alerts.buttons["OK"].tap()
        app.terminate(); app.launch()
        dismissStartupError(app)
        XCTAssertTrue(element("storage-recovery", app: app).waitForExistence(timeout: 10), "Opening recovery settings must not overwrite the damaged generation.")
        XCTAssertFalse(element("onboarding-skip", app: app).exists)
    }
}
