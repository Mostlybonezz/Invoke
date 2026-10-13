import XCTest
@testable import Invoke

/// Integration checks for the same store helpers used by native story screens.
/// These tests require the iOS XCTest host; they were not run on Windows.
final class StoryFlowTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("InvokeStoryTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @MainActor
    func testBeginStoryAndAddScenePersistAConnectedFirstChapter() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(directory: directory)
        let storyID = store.beginStory()
        let sceneID = try XCTUnwrap(store.addScene(storyID: storyID, title: "Share one imperfect sketch", action: "Send a sketch to a trusted friend."))
        let story = try XCTUnwrap(store.data.stories.first { $0.id == storyID })
        let chapterID = try XCTUnwrap(story.currentChapterID)
        let chapter = try XCTUnwrap(store.data.chapters.first { $0.id == chapterID })
        let scene = try XCTUnwrap(store.data.scenes.first { $0.id == sceneID })
        XCTAssertEqual(story.status, "Draft")
        XCTAssertEqual(chapter.storyID, storyID)
        XCTAssertEqual(chapter.sceneIDs, [sceneID])
        XCTAssertEqual(scene.storyID, storyID)
        XCTAssertEqual(scene.chapterID, chapterID)
        XCTAssertEqual(store.data.preferences.pinnedStoryID, storyID)
        store.flush()
        let reopened = AppStore(directory: directory)
        XCTAssertNil(reopened.errorMessage)
        XCTAssertEqual(reopened.currentStory()?.id, storyID)
        XCTAssertEqual(reopened.data.chapters.first?.sceneIDs, [sceneID])
        let reopenedStory = try XCTUnwrap(reopened.currentStory())
        XCTAssertEqual(reopened.nextScene(for: reopenedStory)?.action, "Send a sketch to a trusted friend.")
        try BackupValidation.validateRecords(reopened.data)
    }

    @MainActor
    func testAddingSceneToMissingStoryOrClosedChapterDoesNotMutateCollection() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(directory: directory)
        XCTAssertNil(store.addScene(storyID: UUID()))
        XCTAssertTrue(store.data.stories.isEmpty)
        let storyID = store.beginStory()
        let chapterID = try XCTUnwrap(store.data.stories.first?.currentChapterID)
        let index = try XCTUnwrap(store.data.chapters.firstIndex { $0.id == chapterID })
        store.data.chapters[index].closedAt = Date()
        let before = store.data
        XCTAssertNil(store.addScene(storyID: storyID, title: "A closed keepsake must stay closed"))
        XCTAssertEqual(store.data, before)
        store.flush()
    }

    @MainActor
    func testSceneReflectionUsesOriginalSceneChapterAfterStoryAdvances() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(directory: directory)
        let storyID = store.beginStory()
        let sceneID = try XCTUnwrap(store.addScene(storyID: storyID))
        let originalChapterID = try XCTUnwrap(store.data.stories.first?.currentChapterID)
        let nextChapter = Chapter(storyID: storyID, title: "The story continues")
        store.data.chapters.append(nextChapter)
        store.data.stories[0].currentChapterID = nextChapter.id
        let reflectionID = store.existingReflection(storyID: storyID, sceneID: sceneID, kind: "Scene draft")
        let reflection = try XCTUnwrap(store.data.reflections.first { $0.id == reflectionID })
        XCTAssertEqual(reflection.chapterID, originalChapterID)
        XCTAssertEqual(reflection.sceneID, sceneID)
        XCTAssertEqual(store.existingReflection(storyID: storyID, sceneID: sceneID, kind: "Scene draft"), reflectionID)
        XCTAssertEqual(store.data.reflections.count, 1)
        store.flush()
        let reopened = AppStore(directory: directory)
        XCTAssertEqual(reopened.data.reflections.first?.chapterID, originalChapterID)
        try BackupValidation.validateRecords(reopened.data)
    }

    @MainActor
    func testChapterDraftsAreResumableAndSeparateAcrossChapters() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(directory: directory)
        let storyID = store.beginStory()
        let originalChapterID = try XCTUnwrap(store.data.stories.first?.currentChapterID)
        let firstDraftID = store.existingReflection(storyID: storyID, sceneID: nil, kind: "Plot twist draft")
        store.data.reflections[0].text = "The first chapter's unexpected turn."
        XCTAssertEqual(store.existingReflection(storyID: storyID, sceneID: nil, kind: "Plot twist draft"), firstDraftID)
        store.data.chapters[0].closedAt = Date()
        let nextChapter = Chapter(storyID: storyID, title: "Another beginning")
        store.data.chapters.append(nextChapter)
        store.data.stories[0].currentChapterID = nextChapter.id
        let secondDraftID = store.existingReflection(storyID: storyID, sceneID: nil, kind: "Plot twist draft")
        XCTAssertNotEqual(secondDraftID, firstDraftID)
        let secondIndex = try XCTUnwrap(store.data.reflections.firstIndex { $0.id == secondDraftID })
        store.data.reflections[secondIndex].text = "This turn belongs to the next chapter."
        store.flush()
        let reopened = AppStore(directory: directory)
        XCTAssertEqual(reopened.existingReflection(storyID: storyID, sceneID: nil, kind: "Plot twist draft"), secondDraftID)
        XCTAssertEqual(reopened.data.reflections.first { $0.id == firstDraftID }?.chapterID, originalChapterID)
        XCTAssertEqual(reopened.data.reflections.first { $0.id == firstDraftID }?.text, "The first chapter's unexpected turn.")
        XCTAssertEqual(reopened.data.reflections.first { $0.id == secondDraftID }?.chapterID, nextChapter.id)
        XCTAssertEqual(reopened.data.reflections.count, 2)
        reopened.flush()
    }

    func testRefreshingNarrativeReturnsProposalWithoutOverwritingAuthoredProse() {
        let originalProse = "This is my own sentence, with a rhythm the template did not choose."
        var story = Story(title: "An authored life", answers: [
            "now": "I keep my drawings hidden", "toward": "a more visible creative practice",
            "becoming": "shares unfinished work", "tension": "fear of judgment",
            "next": "send one sketch"
        ], prose: originalProse)
        let firstProposal = narrativeTemplate(story)
        XCTAssertTrue(firstProposal.contains("My next believable act is send one sketch."))
        XCTAssertEqual(story.prose, originalProse)
        story.answers["next"] = "invite a friend to draw with me"
        let secondProposal = narrativeTemplate(story)
        XCTAssertNotEqual(firstProposal, secondProposal)
        XCTAssertTrue(secondProposal.contains("invite a friend to draw with me"))
        XCTAssertEqual(story.prose, originalProse, "A proposal only replaces prose through the explicit UI acceptance action")
    }

    @MainActor
    func testSharedArchiveKeepsBothStoriesAndScenesConnectedAfterReopening() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(directory: directory)
        let firstStory = store.beginStory()
        let secondStory = store.beginStory()
        let belief = LibraryEntry(kind: .belief, title: "Small attempts can count")
        let relic = Relic(name: "A familiar stone", entryIDs: [belief.id])
        store.data.entries.append(belief)
        store.data.relics.append(relic)
        for index in store.data.stories.indices {
            store.data.stories[index].entryIDs = [belief.id]
            store.data.stories[index].relicIDs = [relic.id]
        }
        let firstScene = try XCTUnwrap(store.addScene(storyID: firstStory))
        let secondScene = try XCTUnwrap(store.addScene(storyID: secondStory))
        for index in store.data.scenes.indices {
            store.data.scenes[index].entryIDs = [belief.id]
            store.data.scenes[index].relicIDs = [relic.id]
        }
        store.archiveEntry(id: belief.id)
        store.archiveRelic(id: relic.id)
        store.flush()
        let reopened = AppStore(directory: directory)
        XCTAssertEqual(reopened.data.entries.count, 1, "Connections refer to one shared entry")
        XCTAssertEqual(reopened.data.relics.count, 1)
        XCTAssertEqual(reopened.data.entries.first?.archived, true)
        XCTAssertEqual(reopened.data.relics.first?.archived, true)
        XCTAssertTrue(reopened.data.stories.allSatisfy { $0.entryIDs == [belief.id] && $0.relicIDs == [relic.id] })
        XCTAssertEqual(Set(reopened.data.scenes.map(\.id)), Set([firstScene, secondScene]))
        XCTAssertTrue(reopened.data.scenes.allSatisfy { $0.entryIDs == [belief.id] && $0.relicIDs == [relic.id] })
        XCTAssertEqual(reopened.data.preferences.pinnedStoryID, firstStory, "Beginning another story preserves the existing focus")
        try BackupValidation.validateRecords(reopened.data)
    }

    @MainActor
    func testStaleEditorBindingCannotRecreatePermanentlyDeletedStory() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(directory: directory)
        let id = store.beginStory()
        let story = try XCTUnwrap(store.data.stories.first { $0.id == id })
        let binding = store.recordBinding(\.stories, id: id, fallback: story)
        binding.wrappedValue.title = "A title from the editor"
        store.flush()
        XCTAssertEqual(AppStore(directory: directory).data.stories.first?.title, "A title from the editor")
        store.deleteStory(id: id)
        binding.wrappedValue.title = "A stale view tried to write"
        store.flush()
        XCTAssertTrue(store.data.stories.isEmpty)
        XCTAssertTrue(store.data.chapters.isEmpty)
        XCTAssertTrue(AppStore(directory: directory).data.stories.isEmpty)
    }
}
