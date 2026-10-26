import Foundation

/// Built-in definitions are immutable suggestions. Activating makes an owned copy.
struct CodexTemplate: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let contentVersion: Int
    let sourceIDs: [String]
    let sourceTexts: [String]
    let plainTitle: String
    let fantasyTitle: String
    let instructions: [String]
    let disciplines: [String]
    let purpose: String
    let tags: [String]
    let applicability: String
    let responsibleParty: String
    let suggestedSchedule: String
    let cadenceDescription: String
    let requiresScheduleConfiguration: Bool
    let suggestedImportance: String
    let completionCriteria: String
    let followOnTrigger: String
    let provenance: String
    let reviewStatus: String
    let sourceLinks: [String]
    let referenceOnly: Bool
    let relatedTemplateIDs: [String]

    var searchableText: String {
        ([plainTitle, fantasyTitle, applicability, responsibleParty, cadenceDescription, provenance]
         + instructions + sourceIDs + sourceTexts + disciplines + tags).joined(separator: " ")
    }
    func matches(_ query: String) -> Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || searchableText.localizedCaseInsensitiveContains(query)
    }
    func displayTitle(fantasy: Bool) -> String { fantasy ? fantasyTitle : plainTitle }

    /// No persistence or activation side effect; the editor must present the draft.
    func practiceDraft(fantasy: Bool = true, now: Date = Date(), timeZone: TimeZone = .current) -> PracticeDefinition {
        var value = PracticeDefinition()
        value.title = displayTitle(fantasy: fantasy)
        value.plainTitle = plainTitle
        value.instructions = instructions.joined(separator: "\n\n")
        value.discipline = disciplines.compactMap(Discipline.init(rawValue:)).first ?? .renewal
        value.purpose = PracticePurpose(rawValue: purpose) ?? .preservation
        value.importance = Importance(rawValue: suggestedImportance) ?? .supporting
        value.templateID = id; value.templateVersion = contentVersion; value.sourceIDs = sourceIDs
        value.tags = tags; value.context = applicability
        value.steps = instructions.enumerated().map { index, instruction in
            PracticeStep(title: instructions.count == 1 ? plainTitle : "Part \(index + 1)", instructions: instruction)
        }
        value.schedule.startDate = LocalDay(now, timeZone: timeZone)
        value.schedule.dayOfMonth = value.schedule.startDate.day
        // Required real-world dates and condition triggers stay unspecified.
        switch suggestedSchedule {
        case "daily": value.schedule.kind = .daily
        case "weekly": value.schedule.kind = .weekly; value.schedule.policy = .flexible
        case "monthly": value.schedule.kind = .monthly
        case "quarterly": value.schedule.kind = .quarterly
        case "semiannual": value.schedule.kind = .semiannual
        case "annual": value.schedule.kind = .annual
        case "event": value.schedule.kind = .event
        default: value.schedule.kind = .unscheduled
        }
        value.createdAt = now; value.updatedAt = now; value.effectiveFrom = now
        return value
    }
}

enum CodexLibraryError: LocalizedError {
    case missingResource
    case invalidContent(String)
    var errorDescription: String? {
        switch self {
        case .missingResource: "The bundled Codex could not be found. Your own practices and records remain available."
        case .invalidContent(let detail): "The bundled Codex could not be read: \(detail). Your own records remain available."
        }
    }
}

enum CodexLibrary {
    private struct Envelope: Decodable {
        let formatVersion: Int
        let contentVersion: Int
        let sourceEntryCount: Int
        let templates: [CodexTemplate]
    }
    static let sourceCounts = [16, 11, 18, 11, 11, 14, 12, 12, 12, 12, 10, 13, 10, 13, 7, 22, 8, 10, 10, 10, 12]
    static var expectedSourceIDs: Set<String> {
        Set(sourceCounts.enumerated().flatMap { group, count in
            (1...count).map { String(format: "C%02d.%02d", group + 1, $0) }
        })
    }
    private static let cached: Result<[CodexTemplate], Error> = Result { try load(bundle: .main) }
    static var templates: [CodexTemplate] { get throws { try cached.get() } }

    static func load(bundle: Bundle) throws -> [CodexTemplate] {
        guard let url = bundle.url(forResource: "Codex", withExtension: "json") else {
            throw CodexLibraryError.missingResource
        }
        return try decode(Data(contentsOf: url))
    }

    static func decode(_ data: Data) throws -> [CodexTemplate] {
        guard data.count < 2_000_000 else { throw CodexLibraryError.invalidContent("the file exceeds its size limit") }
        let envelope: Envelope
        do { envelope = try JSONDecoder().decode(Envelope.self, from: data) }
        catch { throw CodexLibraryError.invalidContent("the file does not match its declared format") }
        guard envelope.formatVersion == 1, envelope.contentVersion > 0, envelope.sourceEntryCount == 254 else {
            throw CodexLibraryError.invalidContent("unsupported library version or source count")
        }
        let records = envelope.templates
        let ids = records.map(\.id)
        let sourceIDs = records.flatMap(\.sourceIDs)
        guard !records.isEmpty, Set(ids).count == ids.count,
              sourceIDs.count == 254, Set(sourceIDs) == expectedSourceIDs else {
            throw CodexLibraryError.invalidContent("source coverage is missing or duplicated")
        }
        let disciplines = Set(Discipline.allCases.map(\.rawValue))
        let purposes = Set(PracticePurpose.allCases.map(\.rawValue))
        let importance = Set(Importance.allCases.map(\.rawValue))
        let schedules: Set<String> = ["daily", "weekly", "monthly", "quarterly", "semiannual", "annual", "event", "condition", "configured", "oneOff", "reference"]
        for item in records {
            guard item.id.hasPrefix("codex."), item.contentVersion > 0,
                  !item.plainTitle.isEmpty, !item.fantasyTitle.isEmpty,
                  !item.instructions.isEmpty, !item.sourceIDs.isEmpty,
                  item.sourceTexts.count == item.sourceIDs.count,
                  !item.disciplines.isEmpty, Set(item.disciplines).isSubset(of: disciplines),
                  purposes.contains(item.purpose), importance.contains(item.suggestedImportance),
                  schedules.contains(item.suggestedSchedule),
                  Set(item.relatedTemplateIDs).isSubset(of: Set(ids)),
                  !item.applicability.isEmpty, !item.provenance.isEmpty, !item.reviewStatus.isEmpty,
                  item.referenceOnly || item.requiresScheduleConfiguration else {
                throw CodexLibraryError.invalidContent("a template has invalid fields")
            }
        }
        return records
    }
}
