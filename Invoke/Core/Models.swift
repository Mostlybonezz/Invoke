import Foundation

/// Legacy records remain intact; schema 2 adds the Living Grimoire alongside them.
struct AppData: Codable, Equatable {
    static let currentSchemaVersion = 2
    var schemaVersion = currentSchemaVersion
    var stories: [Story] = []
    var chapters: [Chapter] = []
    var scenes: [Scene] = []
    var entries: [LibraryEntry] = []
    var relics: [Relic] = []
    var reflections: [Reflection] = []
    var ritualLogs: [RitualLog] = []
    var preferences = Preferences()
    var grimoire = GrimoireData()
}

extension AppData {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, stories, chapters, scenes, entries, relics, reflections, ritualLogs, preferences, grimoire
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        guard (1...Self.currentSchemaVersion).contains(schemaVersion) else { throw InvokeDataError.unsupportedVersion(schemaVersion) }
        stories = try values.decode([Story].self, forKey: .stories)
        chapters = try values.decode([Chapter].self, forKey: .chapters)
        scenes = try values.decode([Scene].self, forKey: .scenes)
        entries = try values.decode([LibraryEntry].self, forKey: .entries)
        relics = try values.decode([Relic].self, forKey: .relics)
        reflections = try values.decode([Reflection].self, forKey: .reflections)
        ritualLogs = try values.decode([RitualLog].self, forKey: .ritualLogs)
        preferences = try values.decode(Preferences.self, forKey: .preferences)
        if schemaVersion == 1 { grimoire = GrimoireData() }
        else { grimoire = try values.decode(GrimoireData.self, forKey: .grimoire) }
    }
}

struct Preferences: Codable, Equatable {
    var theme = "astral"
    var effects = "subtle"
    var shaderStyle = "theme"
    var effectIntensity = 1.0
    var effectSpeed = 1.0
    var glassStyle = "system"
    var onboardingComplete = false
    var pinnedStoryID: UUID? = nil
    var lastOpenedAt = Date()
}

extension Preferences {
    private enum CodingKeys: String, CodingKey {
        case theme, effects, shaderStyle, effectIntensity, effectSpeed, glassStyle
        case onboardingComplete, pinnedStoryID, lastOpenedAt
    }

    /// Additive appearance settings preserve version 1 writing and the user's chosen theme.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        theme = try values.decode(String.self, forKey: .theme)
        effects = try values.decode(String.self, forKey: .effects)
        shaderStyle = try values.decodeIfPresent(String.self, forKey: .shaderStyle) ?? "theme"
        effectIntensity = try values.decodeIfPresent(Double.self, forKey: .effectIntensity) ?? 1
        effectSpeed = try values.decodeIfPresent(Double.self, forKey: .effectSpeed) ?? 1
        glassStyle = try values.decodeIfPresent(String.self, forKey: .glassStyle) ?? "system"
        onboardingComplete = try values.decode(Bool.self, forKey: .onboardingComplete)
        pinnedStoryID = try values.decodeIfPresent(UUID.self, forKey: .pinnedStoryID)
        lastOpenedAt = try values.decode(Date.self, forKey: .lastOpenedAt)
    }
}

struct Story: Identifiable, Codable, Equatable {
    var id = UUID()
    var title = "Untitled story"
    var premise = ""
    var shape = "Quest"
    var primaryMode = "Realist"
    var secondaryModes: [String] = []
    var status = "Draft"
    var currentChapterID: UUID? = nil
    var entryIDs: [UUID] = []
    var relicIDs: [UUID] = []
    var answers: [String: String] = [:]
    var prose = ""
    var authoringStep = 0
    var coverFile: String? = nil
    var createdAt = Date()
    var updatedAt = Date()
    var archived = false
    var isExample = false
}

struct Chapter: Identifiable, Codable, Equatable {
    var id = UUID()
    var storyID: UUID
    var title = "Beginnings"
    var closedAt: Date? = nil
    var sceneIDs: [UUID] = []
    var reflectionIDs: [UUID] = []
    var relicIDs: [UUID] = []
    var createdAt = Date()
    var updatedAt = Date()
    var archived = false
    var isExample = false
}

struct Scene: Identifiable, Codable, Equatable {
    var id = UUID()
    var storyID: UUID
    var chapterID: UUID
    var title = "My next believable scene"
    var action = ""
    var why = ""
    var cue = ""
    var effort = ""
    var smallerVersion = ""
    var status = "Planned"
    var entryIDs: [UUID] = []
    var relicIDs: [UUID] = []
    var createdAt = Date()
    var updatedAt = Date()
    var archived = false
    var isExample = false
}

enum EntryKind: String, CaseIterable, Codable, Identifiable {
    case manifestation, belief, ritual
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var plural: String { title + "s" }
    var symbol: String {
        switch self {
        case .manifestation: "sparkles"
        case .belief: "eye"
        case .ritual: "flame"
        }
    }
}

struct Revision: Identifiable, Codable, Equatable {
    var id = UUID()
    var date = Date()
    var title = ""
    var fields: [String: String] = [:]
    var status = ""
}

struct LibraryEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: EntryKind
    var title = ""
    var fields: [String: String] = [:]
    var status = "Active"
    var linkedEntryIDs: [UUID] = []
    var history: [Revision] = []
    var createdAt = Date()
    var updatedAt = Date()
    var archived = false
    var isExample = false

    init(id: UUID = UUID(), kind: EntryKind, title: String = "", fields: [String: String] = [:],
         status: String? = nil, linkedEntryIDs: [UUID] = [], history: [Revision] = [],
         createdAt: Date = Date(), updatedAt: Date = Date(), archived: Bool = false, isExample: Bool = false) {
        self.id = id
        self.kind = kind
        self.title = title
        self.fields = fields
        self.status = status ?? (kind == .belief ? "Held" : "Active")
        self.linkedEntryIDs = linkedEntryIDs
        self.history = history
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archived = archived
        self.isExample = isExample
    }
}

struct ChecklistItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var text = ""
    var isDone = false
}

struct Relic: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = "Unnamed relic"
    var photoFiles: [String] = []
    var objectType = ""
    var origin = ""
    var meaning = ""
    var intention = ""
    var materials = ""
    var checklist: [ChecklistItem] = []
    var dedication = ""
    var location = ""
    var care = ""
    var memories = ""
    var status = "Imagined"
    var entryIDs: [UUID] = []
    var createdAt = Date()
    var updatedAt = Date()
    var archived = false
    var isExample = false
}

struct Reflection: Identifiable, Codable, Equatable {
    var id = UUID()
    var storyID: UUID? = nil
    var chapterID: UUID? = nil
    var sceneID: UUID? = nil
    var kind = "Thought"
    var answers: [String: String] = [:]
    var text = ""
    var createdAt = Date()
    var updatedAt = Date()
    var archived = false
    var isExample = false
}

struct RitualLog: Identifiable, Codable, Equatable {
    var id = UUID()
    var ritualID: UUID
    var date = Date()
    var notes = ""
    var reflection = ""
    var createdAt = Date()
    var updatedAt = Date()
    var isExample = false
}

enum StoryCatalog {
    static let shapes = ["Overcoming the monster", "Quest", "Voyage and return", "Rise", "Fall", "Rebirth", "Love or union", "Separation or loss", "Discovery"]
    static let modes = ["Realist", "Mythic", "Romantic", "Tragic", "Comic", "Satiric", "Epic"]
    static let storyStatuses = ["Draft", "Active", "Resting", "Closed"]
    static let sceneStatuses = ["Planned", "In progress", "Experienced", "Skipped"]
    static let beliefStatuses = ["Held", "Exploring", "Rewriting", "Released"]
    static let relicStatuses = ["Imagined", "In the Making", "In Use", "Resting"]
}
