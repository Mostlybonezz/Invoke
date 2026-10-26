import XCTest

final class LivingGrimoireUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // One isolated data directory per test, reused by explicit relaunches.
        app.launchArguments = ["--ui-testing", "--ui-testing-session=\(UUID().uuidString)"]
        app.launch()
        tap(element("onboarding-skip"))
        XCTAssertTrue(element("today-add-quest").waitForExistence(timeout: 10))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
    private func reveal(_ target: XCUIElement, upwards: Bool = true) {
        _ = target.waitForExistence(timeout: 3)
        for _ in 0..<8 {
            if target.isHittable { return }
            if upwards { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(target.isHittable, "Expected visible control: \(target)")
    }
    private func tap(_ target: XCUIElement, upwards: Bool = true) {
        reveal(target, upwards: upwards); target.tap()
    }
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func back() {
        let control = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(control.waitForExistence(timeout: 5)); control.tap()
    }
    private func savePractice(title: String) {
        let field = element("quest-title")
        tap(field); field.typeText(title)
        tap(element("quest-save"), upwards: false)
    }
    private func openOccurrence(title: String) {
        let row = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "quest-row-", title)).firstMatch
        tap(row)
        XCTAssertTrue(element("quest-complete").exists || element("quest-undo").exists)
    }
    private func relaunch() {
        app.terminate(); app.launch()
        XCTAssertTrue(element("today-add-quest").waitForExistence(timeout: 10))
        XCTAssertFalse(element("onboarding-skip").exists, "The same persisted test container must reopen.")
    }

    func testQuestCompletionUndoAndChronicleSurviveRelaunch() {
        let title = "A small durable step"
        tap(element("today-add-quest")); savePractice(title: title)
        openOccurrence(title: title)
        tap(element("quest-complete"))
        XCTAssertTrue(element("quest-undo").waitForExistence(timeout: 5))
        XCTAssertFalse(element("quest-complete").exists)
        screenshot("20-Quest-recorded")

        relaunch()
        openOccurrence(title: title)
        XCTAssertFalse(element("quest-complete").exists, "A completed occurrence must stay complete after reopening.")
        tap(element("quest-undo"))
        XCTAssertTrue(element("quest-complete").waitForExistence(timeout: 5))

        relaunch()
        openOccurrence(title: title)
        XCTAssertTrue(element("quest-complete").exists, "Undo must persist and restore the available action.")
        tap(app.buttons["View recorded history"])
        XCTAssertTrue(element("chronicle-list").waitForExistence(timeout: 5))
        let correction = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "chronicle-action:", "Correction")).firstMatch
        reveal(correction)
        screenshot("21-Chronicle-correction")
    }

    func testInvocationLinkedPracticeUpdatesActualActionHistory() {
        let intention = "Make room for creativity"
        let practice = "Spend a moment sketching"
        tap(app.tabBars.buttons["Invocations"])
        tap(element("invocation-add"))
        let field = element("invocation-title")
        tap(field); field.typeText(intention)
        tap(element("invocation-save"), upwards: false)
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", intention)).firstMatch)
        XCTAssertEqual(element("invocation-action-count").label, "0 linked actions recorded")
        tap(element("invocation-add-practice")); savePractice(title: practice)
        tap(app.buttons[practice])
        openOccurrence(title: practice)
        tap(element("quest-complete"))
        XCTAssertTrue(element("quest-undo").waitForExistence(timeout: 5))
        back(); back()
        XCTAssertTrue(element("invocation-action-count").waitForExistence(timeout: 5))
        XCTAssertEqual(element("invocation-action-count").label, "1 linked actions recorded")
        screenshot("22-Invocation-linked-action")

        relaunch()
        tap(app.tabBars.buttons["Invocations"])
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", intention)).firstMatch)
        XCTAssertEqual(element("invocation-action-count").label, "1 linked actions recorded")
        XCTAssertTrue(app.buttons[practice].exists)
        screenshot("23-Invocation-reopened")
    }

    func testCodexRequiresExplicitActivationBeforeAppearingToday() {
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "quest-row-")).firstMatch.exists)
        tap(app.tabBars.buttons["Grimoire"])
        tap(element("codex-C01.01"))
        XCTAssertEqual(element("codex-preview-title").label, "Oral care")
        screenshot("24-Codex-practice-preview")
        tap(element("codex-activate"))
        XCTAssertEqual(element("quest-title").value as? String, "Oral care")
        tap(element("quest-save"), upwards: false)
        tap(app.tabBars.buttons["Today"])
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "quest-row-", "Oral care")).firstMatch
        reveal(row)
        screenshot("25-Activated-practice-Today")
    }

    func testSpellMethodAndEchoSourcesRemainEditableAfterReopening() {
        let spellTitle = "A deliberate breathing method"
        let echoTitle = "Two ideas with useful differences"
        tap(app.tabBars.buttons["Grimoire"])
        tap(app.buttons["Add to Grimoire"])
        tap(app.buttons["Spell or saved method"])
        tap(element("spell-title")); element("spell-title").typeText(spellTitle)
        tap(element("spell-method")); element("spell-method").typeText("Pause, notice, and choose the next action.")
        tap(element("spell-save"), upwards: false)
        tap(element("grimoire-shelf"), upwards: false)
        tap(app.buttons["Spells & methods"])
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", spellTitle)).firstMatch)
        XCTAssertEqual(element("spell-method").value as? String, "Pause, notice, and choose the next action.")
        screenshot("26-Saved-method")
        back()
        tap(app.buttons["Add to Grimoire"])
        tap(app.buttons["Echo or comparison"])
        tap(element("echo-title")); element("echo-title").typeText(echoTitle)
        tap(element("echo-source-a")); element("echo-source-a").typeText("A personal notebook")
        tap(element("echo-source-b")); element("echo-source-b").typeText("A conversation remembered")
        tap(element("echo-save"), upwards: false)

        relaunch()
        tap(app.tabBars.buttons["Grimoire"])
        tap(element("grimoire-shelf"))
        tap(app.buttons["Echoes & comparisons"])
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", echoTitle)).firstMatch)
        XCTAssertEqual(element("echo-source-a").value as? String, "A personal notebook")
        XCTAssertEqual(element("echo-source-b").value as? String, "A conversation remembered")
        screenshot("27-Echo-sources-reopened")
    }
}
