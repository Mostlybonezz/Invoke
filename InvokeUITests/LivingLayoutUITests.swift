import XCTest

final class LivingLayoutUITests: XCTestCase {
    private var app: XCUIApplication!
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
    private func tap(_ target: XCUIElement, upwards: Bool = true) {
        _ = target.waitForExistence(timeout: 3)
        for _ in 0..<10 {
            if target.isHittable { target.tap(); return }
            if upwards { app.swipeUp() } else { app.swipeDown() }
        }
        XCTFail("Control was not reachable: \(target)")
    }
    private func launch(size: String) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-fixture=layout", "--ui-testing-dynamic-type=\(size)"]
        app.launch()
        tap(element("onboarding-skip"))
        XCTAssertTrue(element("today-add-quest").waitForExistence(timeout: 10))
    }
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func back() { app.navigationBars.buttons.element(boundBy: 0).tap() }

    func testAccessibilityTextKeepsImportantLongNamedTasksReachable() {
        launch(size: "accessibility3")
        let attention = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Needs attention · 6")).firstMatch
        tap(attention)
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "quest-row-", "practical support")).firstMatch
        _ = row.waitForExistence(timeout: 5)
        XCTAssertTrue(row.exists)
        XCTAssertGreaterThanOrEqual(row.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(row.frame.maxX, app.frame.maxX)
        screenshot("30-Today-accessibility-text")
        tap(row)
        tap(element("quest-complete"))
        XCTAssertTrue(element("quest-undo").waitForExistence(timeout: 5), "Large text must still allow recording an action.")
    }

    func testTodayInAllThemesWithSmallTextAndManyTasks() {
        launch(size: "small")
        for theme in ["ink", "velvet", "astral"] {
            tap(element("today-settings"), upwards: false)
            tap(app.buttons["Appearance"])
            let option = element("appearance-theme-" + theme)
            tap(option)
            XCTAssertTrue(option.label.contains("selected"))
            back(); back()
            XCTAssertTrue(element("today-add-quest").waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Needs attention · 6")).firstMatch.exists)
            screenshot("31-Today-small-" + theme)
        }
    }
}
