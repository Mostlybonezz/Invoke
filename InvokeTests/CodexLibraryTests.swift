import XCTest
@testable import Invoke

final class CodexLibraryTests: XCTestCase {
    func testEverySourceLineIsReachableExactlyOnce() throws {
        let library = try CodexLibrary.templates
        XCTAssertEqual(library.count, 252)
        let sources = library.flatMap(\.sourceIDs)
        XCTAssertEqual(sources.count, 254)
        XCTAssertEqual(Set(sources), CodexLibrary.expectedSourceIDs)
        XCTAssertEqual(library.filter(\.referenceOnly).count, 8)
        XCTAssertEqual(Set(library.flatMap(\.disciplines)), Set(Discipline.allCases.map(\.rawValue)))
    }

    func testConsolidationAndRelatedPracticesDoNotDuplicateCoverage() throws {
        let library = try CodexLibrary.templates
        let meals = try XCTUnwrap(library.first { $0.id == "codex.C06.03" })
        XCTAssertEqual(Set(meals.sourceIDs), ["C06.03", "C01.09"])
        let seasonal = try XCTUnwrap(library.first { $0.id == "codex.C20.03" })
        XCTAssertTrue(seasonal.referenceOnly)
        XCTAssertEqual(Set(seasonal.relatedTemplateIDs), ["codex.C08.09", "codex.C09.06"])
        for item in library { XCTAssertEqual(item.sourceTexts.count, item.sourceIDs.count) }
    }

    func testSearchFindsPlainFantasyAndFullSourceText() throws {
        let library = try CodexLibrary.templates
        let backup = try XCTUnwrap(library.first { $0.id == "codex.C12.08" })
        XCTAssertTrue(backup.matches("Ward of Continuity"))
        XCTAssertTrue(backup.matches("representative backup"))
        XCTAssertTrue(backup.matches("C12.08"))
        let inquiry = try XCTUnwrap(library.first { $0.id == "codex.C16.21" })
        XCTAssertTrue(inquiry.matches("consciousness"))
        XCTAssertTrue(inquiry.referenceOnly)
    }

    func testConfiguredSchedulesDoNotInventDatesOrCompletions() throws {
        let library = try CodexLibrary.templates
        for key in ["codex.C01.05", "codex.C08.01", "codex.C09.06", "codex.C11.04"] {
            let template = try XCTUnwrap(library.first { $0.id == key })
            XCTAssertTrue(template.requiresScheduleConfiguration)
            let draft = template.practiceDraft()
            XCTAssertEqual(draft.schedule.kind, .unscheduled)
            XCTAssertNil(draft.schedule.lastActualCompletion)
            XCTAssertFalse(draft.schedule.hardDeadline)
        }
    }

    func testTemplateCopiesKeepOriginWithoutOverwritingPersonalization() throws {
        let template = try XCTUnwrap(try CodexLibrary.templates.first { $0.id == "codex.C03.03" })
        var owned = template.practiceDraft()
        owned.title = "My laundry sequence"
        owned.instructions = "My machine, my care labels."
        owned.schedule.kind = .weekdays; owned.schedule.weekdays = [3, 7]
        let another = template.practiceDraft()
        XCTAssertNotEqual(owned.id, another.id)
        XCTAssertEqual(owned.title, "My laundry sequence")
        XCTAssertEqual(owned.schedule.weekdays, [3, 7])
        XCTAssertEqual(owned.templateID, template.id)
        XCTAssertEqual(owned.templateVersion, 1)
        XCTAssertEqual(owned.sourceIDs, template.sourceIDs)
    }

    func testMalformedOrIncompleteLibraryHasExplicitFailure() throws {
        XCTAssertThrowsError(try CodexLibrary.decode(Data("invalid".utf8)))
        let url = try XCTUnwrap(Bundle.main.url(forResource: "Codex", withExtension: "json"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var records = try XCTUnwrap(json["templates"] as? [[String: Any]])
        records.removeLast(); json["templates"] = records
        XCTAssertThrowsError(try CodexLibrary.decode(JSONSerialization.data(withJSONObject: json)))
        XCTAssertThrowsError(try CodexLibrary.decode(Data(repeating: 0, count: 2_000_001)))
    }
}
