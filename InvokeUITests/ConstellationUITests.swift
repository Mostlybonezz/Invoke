import XCTest

final class ConstellationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func reveal(_ target: XCUIElement, upwards: Bool = true) {
        XCTAssertTrue(target.waitForExistence(timeout: 10), "Missing element: \(target)")
        for _ in 0..<7 {
            if target.isHittable { return }
            if upwards { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(target.isHittable, "Element did not become tappable: \(target)")
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openExamples() {
        let examples = element("onboarding-examples")
        reveal(examples)
        examples.tap()
        XCTAssertTrue(element("constellation-preview").waitForExistence(timeout: 10))
    }

    private func goBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
    }

    func testAstralDefaultConstellationAndSceneEditing() {
        let appearance = element("appearance-current-theme")
        XCTAssertTrue(appearance.waitForExistence(timeout: 10))
        XCTAssertEqual(appearance.value as? String, "astral")
        screenshot("01-Astral-onboarding")
        openExamples()
        screenshot("02-Astral-sanctuary")

        let preview = element("constellation-preview")
        reveal(preview)
        preview.tap()
        let star = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "scene-star-")).firstMatch
        reveal(star)
        screenshot("03-Expanded-constellation")
        star.tap()
        XCTAssertTrue(element("scene-script-title").waitForExistence(timeout: 10))
        screenshot("04-Scene-script")

        let edit = element("scene-script-edit")
        reveal(edit)
        edit.tap()
        let editor = element("scene-action-editor")
        reveal(editor)
        editor.tap()
        let marker = "A small test step."
        editor.typeText("\n" + marker)
        goBack()
        XCTAssertTrue(element("scene-script-title").waitForExistence(timeout: 5))
        let savedText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", marker)).firstMatch
        XCTAssertTrue(savedText.waitForExistence(timeout: 5), "Edited scene action must appear in its script.")
        reveal(savedText, upwards: false)
        screenshot("05-Edited-scene-script")
    }

    func testAllThreeThemesRemainSelectable() {
        openExamples()
        for (index, theme) in ["ink", "velvet", "astral"].enumerated() {
            let settings = element("sanctuary-settings")
            reveal(settings, upwards: false)
            settings.tap()
            let appearanceLink = app.buttons["Appearance"]
            reveal(appearanceLink)
            appearanceLink.tap()
            let option = element("appearance-theme-" + theme)
            reveal(option)
            option.tap()
            XCTAssertTrue(option.label.contains("selected"))
            screenshot("0\(index + 6)-Appearance-\(theme)")
            goBack()
            XCTAssertEqual(element("appearance-current-theme").value as? String, theme)
            goBack()
            XCTAssertTrue(element("constellation-preview").waitForExistence(timeout: 5))
            screenshot("0\(index + 9)-Sanctuary-\(theme)")
        }
    }
}
