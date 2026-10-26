import Foundation

/// Calendar dates are deliberately separate from UTC timestamps.
struct LocalDay: Codable, Equatable, Hashable, Comparable, CustomStringConvertible {
    var year: Int
    var month: Int
    var day: Int
    init(year: Int, month: Int, day: Int) { self.year = year; self.month = month; self.day = day }
    init(_ date: Date = Date(), timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        let value = calendar.dateComponents([.year, .month, .day], from: date)
        year = value.year!; month = value.month!; day = value.day!
    }
    var description: String { String(format: "%04d-%02d-%02d", year, month, day) }
    static func < (lhs: Self, rhs: Self) -> Bool { (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day) }
}

enum Discipline: String, Codable, CaseIterable, Identifiable {
    case vitality, regalia, hearth, wayfaring, stewardship, artifice, craft, bonds, arcana, renewal
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .vitality: "heart"; case .regalia: "tshirt"; case .hearth: "house"; case .wayfaring: "map"
        case .stewardship: "tray.full"; case .artifice: "desktopcomputer"; case .craft: "hammer"
        case .bonds: "person.2"; case .arcana: "moon.stars"; case .renewal: "leaf"
        }
    }
}
enum PracticePurpose: String, Codable, CaseIterable, Identifiable {
    case preservation, transformation, discovery
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
enum Importance: String, Codable, CaseIterable, Identifiable {
    case critical, core, supporting, optional
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var rank: Int { Self.allCases.firstIndex(of: self)! }
}
enum ScheduleKind: String, Codable, CaseIterable, Identifiable {
    case unscheduled, once, daily, weekdays, weekly, weeklyQuota, monthly, quarterly, semiannual, annual, afterCompletion, event, condition, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .once: "One date"; case .weeklyQuota: "Sessions per week"; case .afterCompletion: "After completion"
        case .event: "After an event"; case .condition: "Condition review"; case .custom: "Custom interval"
        default: rawValue.capitalized
        }
    }
}
enum OverduePolicy: String, Codable, CaseIterable, Identifiable {
    case renew, persist, flexible, conditionReview
    var id: String { rawValue }
    var title: String {
        switch self { case .renew: "Renew without debt"; case .persist: "Keep until resolved"; case .flexible: "Flexible window"; case .conditionReview: "Inspect condition" }
    }
}
enum CalendarUnit: String, Codable, CaseIterable, Identifiable {
    case day, week, month, year
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
struct TimeSlot: Codable, Equatable, Identifiable {
    var id = UUID()
    var name = "Practice"
    var hour = 9
    var minute = 0
}
struct ScheduleRule: Codable, Equatable {
    var kind: ScheduleKind = .unscheduled
    var startDate = LocalDay()
    var endDate: LocalDay? = nil
    var weekdays: [Int] = [2] // Calendar weekday: Sunday = 1.
    var slots: [TimeSlot] = [] // Empty means a date/window, not a timed deadline.
    var dayOfMonth = 1
    var lastDayOfMonth = false
    var weekdayOrdinal: Int? = nil // 1...5 or -1 (last); nil uses dayOfMonth.
    var ordinalWeekday = 2
    var interval = 1
    var intervalUnit: CalendarUnit = .day
    var quota = 2
    var calendarQuarter = false
    var eventName = ""
    var conditionPrompt = "What is its actual condition?"
    var policy: OverduePolicy = .renew
    var homeTimeZoneID: String? = nil // nil follows the global home/travel policy.
    var deadlineHour: Int? = nil
    var deadlineMinute = 0
    var hardDeadline = false
    var reminderHour: Int? = nil
    var reminderMinute = 0
    var lastActualCompletion: Date? = nil // Unknown stays unknown.
}
struct PracticeStep: Identifiable, Codable, Equatable {
    var id = UUID()
    var title = ""
    var instructions = ""
}
struct PracticeRevision: Identifiable, Codable, Equatable {
    var id = UUID()
    var version = 1
    var effectiveFrom = Date()
    var title = ""
    var instructions = ""
    var steps: [PracticeStep] = []
    var schedule = ScheduleRule()
}
struct PracticePause: Identifiable, Codable, Equatable {
    var id = UUID(); var startedAt = Date(); var endedAt: Date? = nil
}
struct PracticeDefinition: Identifiable, Codable, Equatable {
    var id = UUID()
    var title = ""
    var plainTitle = ""
    var instructions = ""
    var discipline: Discipline = .renewal
    var purpose: PracticePurpose = .preservation
    var importance: Importance = .supporting
    var importanceReason = ""
    var templateID: String? = nil
    var templateVersion: Int? = nil
    var sourceIDs: [String] = []
    var tags: [String] = []
    var steps: [PracticeStep] = []
    var schedule = ScheduleRule()
    var version = 1
    var effectiveFrom = Date()
    var revisions: [PracticeRevision] = []
    var invocationID: UUID? = nil
    var spellIDs: [UUID] = []
    var assetID: UUID? = nil
    var legacyEntryID: UUID? = nil
    var legacySceneID: UUID? = nil
    var context = ""
    var materials = ""
    var smallerVersion = ""
    var effortMinutes: Int? = nil
    var responsiblePerson = ""
    var paused = false
    var pauses: [PracticePause] = []
    var archived = false
    var createdAt = Date()
    var updatedAt = Date()
}
struct PracticeOccurrence: Identifiable, Codable, Equatable {
    var id: String
    var practiceID: UUID
    var definitionVersion: Int
    var title: String
    var steps: [PracticeStep]
    var windowStart: LocalDay
    var windowEnd: LocalDay // Exclusive.
    var availableAt: Date
    var dueAt: Date?
    var hardDeadline: Date?
    var timeZoneID: String
    var slotKey: String
    var requiredSessions = 1
    var deferredUntil: Date? = nil
    var reminderSnoozedUntil: Date? = nil
    var superseded = false
    var eventID: UUID? = nil
}
enum ActionKind: String, Codable, CaseIterable, Identifiable {
    case begin, progress, complete, smaller, skip, deferAction, correction, observation
    var id: String { rawValue }
    var title: String {
        switch self { case .begin: "Started"; case .progress: "Partial progress"; case .complete: "Completed"
        case .smaller: "Smaller version"; case .skip: "Skipped"; case .deferAction: "Deferred"
        case .correction: "Correction"; case .observation: "Observation" }
    }
}
struct ActionRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    var requestID = UUID()
    var occurrenceID = ""
    var practiceID: UUID
    var sessionID = UUID()
    var kind: ActionKind = .complete
    var occurredAt = Date()
    var recordedAt = Date()
    var timeZoneID = TimeZone.current.identifier
    var completedStepIDs: [UUID] = []
    var notes = ""
    var measurement: Double? = nil
    var measurementUnit = ""
    var reversesActionID: UUID? = nil
    var targetDate: Date? = nil
    var titleSnapshot = ""
}
enum OccurrenceStatus: String, CaseIterable {
    case unrecorded, inProgress, partial, completed, skipped, deferred
    var title: String {
        switch self { case .unrecorded: "Not recorded"; case .inProgress: "In progress"; case .partial: "Partial"
        case .completed: "Completed"; case .skipped: "Skipped"; case .deferred: "Deferred" }
    }
}
struct InvocationMilestone: Identifiable, Codable, Equatable {
    var id = UUID(); var title = ""; var notes = ""; var completedAt: Date? = nil
}
struct InvocationObservation: Identifiable, Codable, Equatable {
    var id = UUID(); var observedAt = Date(); var text = ""; var measurement: Double? = nil; var unit = ""
}
struct Invocation: Identifiable, Codable, Equatable {
    var id = UUID(); var title = ""; var intention = ""; var outcome = ""; var evidence = ""
    var influence = ""; var obstacles = ""; var counterspells = ""; var notes = ""
    var discipline: Discipline = .renewal
    var status = "Active"
    var milestones: [InvocationMilestone] = []
    var observations: [InvocationObservation] = []
    var reviewDate: Date? = nil
    var legacyStoryID: UUID? = nil
    var legacyEntryID: UUID? = nil
    var archived = false; var createdAt = Date(); var updatedAt = Date()
}
struct Spell: Identifiable, Codable, Equatable {
    var id = UUID(); var title = ""; var plainTitle = ""; var purpose = ""; var method = ""
    var source = ""; var notes = ""; var discipline: Discipline = .arcana
    var archived = false; var createdAt = Date(); var updatedAt = Date()
}
struct Enchantment: Identifiable, Codable, Equatable {
    var id = UUID(); var title = ""; var supports = ""; var establishmentEvidence = ""
    var status = "Planned"; var invocationID: UUID? = nil; var maintenancePracticeID: UUID? = nil
    var reviewDate: Date? = nil; var notes = ""; var archived = false; var createdAt = Date(); var updatedAt = Date()
}
struct AssetInspection: Identifiable, Codable, Equatable {
    var id = UUID(); var date = Date(); var condition = "Serviceable"; var notes = ""
    var actionID: UUID? = nil; var followUpPracticeID: UUID? = nil
}
struct CareAsset: Identifiable, Codable, Equatable {
    var id = UUID(); var name = ""; var category = ""; var discipline: Discipline = .hearth
    var resourceKind = "Durable asset"; var condition = "Unknown"; var careInstructions = ""
    var purchasedAt: Date? = nil; var installedAt: Date? = nil; var expiresAt: Date? = nil
    var quantity: Double? = nil; var quantityUnit = ""; var replenishBelow: Double? = nil
    var replacementCriteria = ""; var estimatedCost: Double? = nil; var reservedAmount: Double? = nil
    var reserveTargetDate: Date? = nil; var responsiblePerson = ""; var notes = ""
    var inspections: [AssetInspection] = []; var archived = false; var createdAt = Date(); var updatedAt = Date()
}
struct ArcanaRecord: Identifiable, Codable, Equatable {
    var id = UUID(); var title = ""; var kind = "Practice"; var origin = ""; var source = ""
    var purpose = ""; var method = ""; var materials = ""; var context = ""
    var expectedResult = ""; var observedResult = ""; var interpretation = ""; var alternatives = ""
    var nextDecision = "Study"; var beliefStatus = "Exploring"; var notes = ""
    var occurredAt: Date? = nil; var legacyEntryID: UUID? = nil
    var archived = false; var createdAt = Date(); var updatedAt = Date()
}
struct Echo: Identifiable, Codable, Equatable {
    var id = UUID(); var title = ""; var sourceA = ""; var sourceB = ""; var similarities = ""
    var differences = ""; var originalContext = ""; var historicalConnections = ""
    var interpretation = ""; var questions = ""; var changesOfView = ""
    var archived = false; var createdAt = Date(); var updatedAt = Date()
}
struct GrimoireEvent: Identifiable, Codable, Equatable {
    var id = UUID(); var name = ""; var occurredAt = Date(); var timeZoneID = TimeZone.current.identifier; var notes = ""
}
struct GrimoireRevision: Identifiable, Codable, Equatable {
    var id = UUID(); var recordID: UUID; var recordType = ""; var title = ""; var summary = ""
    var changedAt = Date(); var before: Data; var after: Data
}
struct GrimoireSettings: Codable, Equatable {
    var fantasyLanguage = true
    var weekStartsOn = 2
    var followsTravelTimeZone = true
    var homeTimeZoneID = TimeZone.current.identifier
    var restorationMode = false
    var essentialPracticeIDs: [UUID] = []
    var focusPracticeID: UUID? = nil
    var remindersEnabled = false
    var quietHoursStart = 22
    var quietHoursEnd = 8
    var privateNotificationPreviews = true
    var digestEnabled = false
    var digestHour = 9
    var soundEnabled = false
    var motionEnabled = true
    var recognitionEnabled = true
    var applicableDisciplines: [Discipline] = []
    var responsibilities: [String] = []
    var desiredDevelopments = ""
}
struct GrimoireData: Codable, Equatable {
    var practices: [PracticeDefinition] = []
    var occurrences: [PracticeOccurrence] = []
    var actions: [ActionRecord] = []
    var invocations: [Invocation] = []
    var spells: [Spell] = []
    var enchantments: [Enchantment] = []
    var assets: [CareAsset] = []
    var arcana: [ArcanaRecord] = []
    var echoes: [Echo] = []
    var events: [GrimoireEvent] = []
    var revisions: [GrimoireRevision] = []
    var settings = GrimoireSettings()
    var setupCompleted = false
    var upgradeIntroductionSeen = false
}
