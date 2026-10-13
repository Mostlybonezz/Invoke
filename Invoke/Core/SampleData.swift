import Foundation

/// Opt-in examples are marked individually and can be removed without touching
/// personal writing. All connections below use the same shared record identifiers.
enum SampleData {
    static func collection() -> AppData {
        var result = AppData()
        var desire = LibraryEntry(kind: .manifestation, title: "Build a creative life I trust", fields: [
            "desire": "Make and share work with a little more freedom.",
            "why": "My ideas deserve a place in ordinary life.",
            "feeling": "Curious, steady, and more present.",
            "everyday": "A sketchbook within reach, one small practice each week.",
            "influence": "When I make, what I share, and how kindly I return after a pause.",
            "progress": "Three short drawing sessions. One honest conversation about my work.",
            "constraints": "Energy changes. Other people's responses are theirs to choose.",
            "moments": "An old friend mentioned a tiny exhibition. I took it as an invitation to notice possibility."
        ], isExample: true)
        let belief = LibraryEntry(kind: .belief, title: "I can be seen before I feel finished", fields: [
            "belief": "My work must be polished before anyone can see it.",
            "origin": "Years of being praised for getting things right.",
            "why": "I want to feel safe while making something uncertain.",
            "choices": "I keep sketches hidden and wait for confidence.",
            "experiences": "A friend connected most with a rough, lively drawing.",
            "alternative": "An unfinished thing can make a real connection.",
            "action": "Share one small sketch with someone I trust."
        ], status: "Exploring", isExample: true)
        let ritual = LibraryEntry(kind: .ritual, title: "Before the first mark", fields: [
            "intention": "Make room for an imperfect beginning.",
            "materials": "A notebook, a pencil, and an optional familiar object.",
            "duration": "5 minutes",
            "steps": "1. Put the phone aside.\n2. Notice three things in the room.\n3. Hold the pencil and make one deliberate mark.\n4. Begin wherever the page lets you.",
            "opening": "I do not need permission to begin.",
            "closing": "A small act still changes the page."
        ], isExample: true)
        desire.linkedEntryIDs = [belief.id, ritual.id]
        let witness = Relic(name: "The Witness", objectType: "Handmade pendant", origin: "A silver setting made around a deep-red stone.",
            meaning: "An object that remembers my willingness to show up.", intention: "Let my work meet the world before it feels perfect.",
            materials: "Silver wire, a deep-red stone, velvet cord", checklist: [
                ChecklistItem(text: "Choose the stone", isDone: true),
                ChecklistItem(text: "Shape the silver setting", isDone: true),
                ChecklistItem(text: "Tie the cord", isDone: true)
            ], dedication: "May I witness what is here, and let it be enough to begin.",
            location: "Beside the sketchbook; worn when sharing work.", care: "Keep dry and polish gently with a soft cloth.",
            memories: "The first imperfect sketch felt less lonely with this on the desk.", status: "In Use", entryIDs: [desire.id, ritual.id], isExample: true)

        var artist = Story(title: "The artist who lets herself be seen", premise: "A quieter creative life becomes a little more visible.",
            shape: "Quest", primaryMode: "Romantic", secondaryModes: ["Realist"], status: "Active", entryIDs: [desire.id, belief.id, ritual.id], relicIDs: [witness.id],
            answers: ["now": "I make things quietly and rarely let anyone see them.", "toward": "A creative life I trust.", "becoming": "A brave beginner who shares unfinished work.", "tension": "I fear being judged; I have one trusted friend and a little time on Sundays.", "next": "Share one imperfect sketch."],
            prose: "I am in a chapter where I make things quietly. I want to move toward a creative life I trust. I am practicing being someone who shares unfinished work. The tension I am working with is the fear of being judged. My next believable act is to share one imperfect sketch.", authoringStep: 5, isExample: true)
        var beginnings = Chapter(storyID: artist.id, title: "Beginnings", relicIDs: [witness.id], isExample: true)
        let titles = ["Clear a small corner for making", "Choose a page without a plan", "Draw for ten ordinary minutes", "Share one imperfect sketch.", "Ask what felt alive"]
        let actions = ["Make a little space on the desk.", "Open the notebook and make the first mark.", "Spend ten minutes drawing something nearby.", "Send one sketch to a trusted friend with a simple note.", "Write down what I noticed, without grading it."]
        let scenes = titles.enumerated().map { index, title in
            Scene(storyID: artist.id, chapterID: beginnings.id, title: title, action: actions[index],
                why: "Practice choosing participation over perfection.", cue: index == 3 ? "The next quiet evening, when I have a little energy." : "After the first cup of tea.",
                effort: index == 3 ? "2 minutes" : "10 minutes", smallerVersion: "Choose the sketch and draft the note; sending can be another scene.",
                status: index < 3 ? "Experienced" : "Planned", entryIDs: [belief.id, ritual.id], relicIDs: [witness.id], isExample: true)
        }
        let attempt = Reflection(storyID: artist.id, chapterID: beginnings.id, sceneID: scenes[2].id, kind: "Scene reflection", answers: [
            "happened": "I drew for seven minutes before the doorbell rang.",
            "tried": "I began without planning the whole page.",
            "learned": "A shortened attempt still counts as participation.",
            "change": "Leave the notebook open so it is easier to return."
        ], text: "The page is uneven. It is also here.", isExample: true)
        beginnings.sceneIDs = scenes.map(\.id)
        beginnings.reflectionIDs = [attempt.id]
        artist.currentChapterID = beginnings.id

        let homeBelief = LibraryEntry(kind: .belief, title: "A home can support me without being perfect", fields: [
            "belief": "I must fix the whole room before I can enjoy it.", "alternative": "One cared-for corner is a beginning.",
            "action": "Clear the chair by the window.", "experiences": "Fresh water in a small vase changed how I felt in the room."
        ], status: "Rewriting", isExample: true)
        let bowl = Relic(name: "The Threshold Bowl", objectType: "Found ceramic bowl", origin: "A secondhand shop on a rainy afternoon.",
            meaning: "A place to put down what I do not need to carry through the door.", intention: "Make arriving home a small return to myself.",
            dedication: "Here, I can set things down.", location: "Beside the front door.", care: "Wipe with a damp cloth.", status: "In Use", entryIDs: [homeBelief.id], isExample: true)
        var home = Story(title: "A home that welcomes me back", premise: "Renewing my relationship with the place I live.",
            shape: "Rebirth", primaryMode: "Realist", secondaryModes: ["Mythic"], status: "Active", entryIDs: [homeBelief.id], relicIDs: [bowl.id], isExample: true)
        var homeChapter = Chapter(storyID: home.id, title: "A softer threshold", relicIDs: [bowl.id], isExample: true)
        let homeScene = Scene(storyID: home.id, chapterID: homeChapter.id, title: "Make one welcoming corner", action: "Clear the chair by the window and put a book there.",
            why: "The room can be lived in before it is finished.", cue: "When I get home on a day with a little spare energy.", effort: "5 minutes", smallerVersion: "Move just one thing from the chair.", entryIDs: [homeBelief.id], relicIDs: [bowl.id], isExample: true)
        homeChapter.sceneIDs = [homeScene.id]
        home.currentChapterID = homeChapter.id

        let noticing = LibraryEntry(kind: .ritual, title: "Three things worth noticing", fields: [
            "intention": "Learn what matters by paying attention to ordinary days.", "duration": "3 minutes", "materials": "A place to write.",
            "steps": "Name one moment that gave you energy.\nName one moment that asked too much.\nName one thing you would like to try again.",
            "closing": "I can let what I notice change the question."
        ], isExample: true)
        var discovery = Story(title: "Learning what matters", premise: "A discovery that begins with paying better attention.", shape: "Discovery", primaryMode: "Realist", secondaryModes: ["Comic"], status: "Resting", entryIDs: [noticing.id], isExample: true)
        var discoveryChapter = Chapter(storyID: discovery.id, title: "Useful questions", isExample: true)
        let discoveryScene = Scene(storyID: discovery.id, chapterID: discoveryChapter.id, title: "Notice a moment that gives me energy", action: "Write one sentence about a moment I would like to experience again.", why: "My attention can teach me something my plans missed.", cue: "The next time an ordinary moment surprises me.", effort: "1 minute", smallerVersion: "Remember one word.", entryIDs: [noticing.id], isExample: true)
        discoveryChapter.sceneIDs = [discoveryScene.id]
        discovery.currentChapterID = discoveryChapter.id

        result.stories = [artist, home, discovery]
        result.chapters = [beginnings, homeChapter, discoveryChapter]
        result.scenes = scenes + [homeScene, discoveryScene]
        result.entries = [desire, belief, ritual, homeBelief, noticing]
        result.relics = [witness, bowl]
        result.reflections = [attempt]
        result.ritualLogs = [RitualLog(ritualID: ritual.id, notes: "I let the first mark be crooked.", reflection: "Beginning was the useful part.", isExample: true)]
        result.preferences.pinnedStoryID = artist.id
        return result
    }
}

extension AppStore {
    func loadExamples() {
        guard !data.stories.contains(where: \.isExample) else { return }
        let examples = SampleData.collection()
        data.stories += examples.stories
        data.chapters += examples.chapters
        data.scenes += examples.scenes
        data.entries += examples.entries
        data.relics += examples.relics
        data.reflections += examples.reflections
        data.ritualLogs += examples.ritualLogs
        if data.preferences.pinnedStoryID == nil { data.preferences.pinnedStoryID = examples.preferences.pinnedStoryID }
        data.preferences.onboardingComplete = true
        flush()
    }

    /// If personal writing depends on an example, preserve that record and its
    /// dependencies as personal content. Removing examples never deletes a personal scene.
    func removeExamples() {
        var stories = Set(data.stories.filter { !$0.isExample }.map(\.id))
        var chapters = Set(data.chapters.filter { !$0.isExample }.map(\.id))
        var scenes = Set(data.scenes.filter { !$0.isExample }.map(\.id))
        var entries = Set(data.entries.filter { !$0.isExample }.map(\.id))
        var relics = Set(data.relics.filter { !$0.isExample }.map(\.id))
        var reflections = Set(data.reflections.filter { !$0.isExample }.map(\.id))
        for log in data.ritualLogs where !log.isExample { entries.insert(log.ritualID) }
        var changed = true
        while changed {
            let before = stories.count + chapters.count + scenes.count + entries.count + relics.count + reflections.count
            for story in data.stories where stories.contains(story.id) {
                if let id = story.currentChapterID { chapters.insert(id) }
                entries.formUnion(story.entryIDs); relics.formUnion(story.relicIDs)
            }
            for chapter in data.chapters where chapters.contains(chapter.id) {
                stories.insert(chapter.storyID); scenes.formUnion(chapter.sceneIDs)
                reflections.formUnion(chapter.reflectionIDs); relics.formUnion(chapter.relicIDs)
            }
            for scene in data.scenes where scenes.contains(scene.id) {
                stories.insert(scene.storyID); chapters.insert(scene.chapterID)
                entries.formUnion(scene.entryIDs); relics.formUnion(scene.relicIDs)
            }
            for entry in data.entries where entries.contains(entry.id) { entries.formUnion(entry.linkedEntryIDs) }
            for relic in data.relics where relics.contains(relic.id) { entries.formUnion(relic.entryIDs) }
            for reflection in data.reflections where reflections.contains(reflection.id) {
                if let id = reflection.storyID { stories.insert(id) }
                if let id = reflection.chapterID { chapters.insert(id) }
                if let id = reflection.sceneID { scenes.insert(id) }
            }
            changed = before != stories.count + chapters.count + scenes.count + entries.count + relics.count + reflections.count
        }
        data.stories.removeAll { !stories.contains($0.id) }
        data.chapters.removeAll { !chapters.contains($0.id) }
        data.scenes.removeAll { !scenes.contains($0.id) }
        data.entries.removeAll { !entries.contains($0.id) }
        data.relics.removeAll { !relics.contains($0.id) }
        data.reflections.removeAll { !reflections.contains($0.id) }
        data.ritualLogs.removeAll { $0.isExample }
        for i in data.stories.indices { data.stories[i].isExample = false }
        for i in data.chapters.indices { data.chapters[i].isExample = false }
        for i in data.scenes.indices { data.scenes[i].isExample = false }
        for i in data.entries.indices { data.entries[i].isExample = false }
        for i in data.relics.indices { data.relics[i].isExample = false }
        for i in data.reflections.indices { data.reflections[i].isExample = false }
        cleanLinks()
        flush()
    }
}
