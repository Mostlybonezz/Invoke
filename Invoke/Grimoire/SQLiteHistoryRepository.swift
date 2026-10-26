import Foundation
import SQLite3

struct HistoryCursor: Codable, Equatable { var timestamp: Date; var key: String }
struct HistoryPage {
    var actions: [ActionRecord] = []
    var revisions: [GrimoireRevision] = []
    var correctedActionIDs: Set<UUID> = []
    var nextCursor: HistoryCursor? = nil
}
struct HistoryCounts { var actions: Int; var occurrences: Int; var revisions: Int }

/// The core and the ledger share one SQLite transaction. Portable backups retain
/// complete Codable arrays; the ordinary published core does not load the ledger.
@MainActor
final class SQLiteHistoryRepository {
    enum Value { case text(String), real(Double), integer(Int), blob(Data), null }
    let url: URL
    private var db: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private(set) var decodedHistoryRecords = 0

    init(url: URL, create: Bool = false) throws {
        self.url = url
        var keepConnection = false
        defer { if !keepConnection { if let db { sqlite3_close(db) }; db = nil } }
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX | (create ? SQLITE_OPEN_CREATE : 0)
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK else { throw failure() }
        sqlite3_extended_result_codes(db, 1)
        sqlite3_busy_timeout(db, 5_000)
        try execute("PRAGMA foreign_keys=ON")
        try execute("PRAGMA journal_mode=DELETE")
        try execute("PRAGMA synchronous=FULL")
        if create {
            try execute("CREATE TABLE core (id INTEGER PRIMARY KEY CHECK(id=1), payload BLOB NOT NULL)")
            try execute("CREATE TABLE practice_keys (id TEXT PRIMARY KEY, version INTEGER NOT NULL)")
            try execute("""
                CREATE TABLE occurrences (
                    id TEXT PRIMARY KEY, practice_id TEXT NOT NULL REFERENCES practice_keys(id) DEFERRABLE INITIALLY DEFERRED, version INTEGER NOT NULL,
                    available REAL NOT NULL, window_end REAL NOT NULL, due REAL, deferred REAL, reminder_snoozed REAL,
                    required_sessions INTEGER NOT NULL, superseded INTEGER NOT NULL,
                    status TEXT NOT NULL, sessions INTEGER NOT NULL, payload BLOB NOT NULL)
                """)
            try execute("""
                CREATE TABLE actions (
                    id TEXT PRIMARY KEY, request_id TEXT UNIQUE NOT NULL,
                    occurrence_id TEXT NOT NULL REFERENCES occurrences(id) DEFERRABLE INITIALLY DEFERRED,
                    practice_id TEXT NOT NULL, session_id TEXT NOT NULL, kind TEXT NOT NULL,
                    occurred REAL NOT NULL, recorded REAL NOT NULL,
                    reverses_id TEXT UNIQUE REFERENCES actions(id) DEFERRABLE INITIALLY DEFERRED,
                    payload BLOB NOT NULL, search TEXT NOT NULL)
                """)
            try execute("CREATE INDEX actions_by_occurrence ON actions(occurrence_id,recorded,id)")
            try execute("CREATE INDEX actions_by_practice ON actions(practice_id,kind,occurred DESC)")
            try execute("CREATE INDEX actions_by_time ON actions(occurred DESC,id)")
            try execute("CREATE INDEX occurrences_by_practice ON occurrences(practice_id,available,window_end)")
            try execute("CREATE INDEX occurrences_by_window ON occurrences(available,window_end,status)")
            try execute("""
                CREATE TRIGGER prevent_practice_version_rewind BEFORE UPDATE OF version ON practice_keys
                WHEN NEW.version < (SELECT MAX(version) FROM occurrences WHERE practice_id=NEW.id)
                BEGIN SELECT RAISE(ABORT,'Recorded practice versions cannot be removed'); END
                """)
            try execute("CREATE TABLE revisions (id TEXT PRIMARY KEY, record_id TEXT NOT NULL, record_type TEXT NOT NULL, changed REAL NOT NULL, payload BLOB NOT NULL, search TEXT NOT NULL)")
            try execute("CREATE INDEX revisions_by_record ON revisions(record_id,changed DESC)")
            try execute("CREATE INDEX revisions_by_time ON revisions(changed DESC,id)")
            try execute("PRAGMA user_version=1")
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        } else {
            guard try scalar("PRAGMA user_version") == 1 else { throw InvokeDataError.storageUnavailable("This local history format needs a newer version of Invoke.") }
            // Ordinary launch reads metadata and the core only. A full integrity
            // scan belongs to staging/import, not an implicit scan of all history.
            guard try scalar("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN ('core','practice_keys','occurrences','actions','revisions')") == 5 else {
                throw InvokeDataError.storageUnavailable("Local history is incomplete. Its original files were preserved.")
            }
        }
        keepConnection = true
    }
    deinit { if let db { sqlite3_close(db) } }

    private func failure() -> InvokeDataError {
        let detail = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open the local history file."
        return .storageUnavailable("Local history could not be read or saved: \(detail)")
    }
    private func statement(_ sql: String, _ values: [Value]) throws -> OpaquePointer {
        var result: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &result, nil) == SQLITE_OK, let result else { throw failure() }
        do {
            for (offset, value) in values.enumerated() {
                let index = Int32(offset + 1), code: Int32
                switch value {
                case .text(let text): code = sqlite3_bind_text(result, index, text, -1, transient)
                case .real(let number): code = sqlite3_bind_double(result, index, number)
                case .integer(let number): code = sqlite3_bind_int64(result, index, Int64(number))
                case .blob(let bytes): code = bytes.withUnsafeBytes { sqlite3_bind_blob(result, index, $0.baseAddress, Int32(bytes.count), transient) }
                case .null: code = sqlite3_bind_null(result, index)
                }
                guard code == SQLITE_OK else { throw failure() }
            }
            return result
        } catch { sqlite3_finalize(result); throw error }
    }
    private func execute(_ sql: String, _ values: [Value] = []) throws {
        let statement = try statement(sql, values); defer { sqlite3_finalize(statement) }
        let code = sqlite3_step(statement)
        guard code == SQLITE_DONE || code == SQLITE_ROW else { throw failure() }
    }
    private func query<T>(_ sql: String, _ values: [Value] = [], decode: (OpaquePointer) throws -> T) throws -> [T] {
        let statement = try statement(sql, values); defer { sqlite3_finalize(statement) }
        var values: [T] = []
        while true {
            let code = sqlite3_step(statement)
            if code == SQLITE_DONE { break }
            guard code == SQLITE_ROW else { throw failure() }
            values.append(try decode(statement))
        }
        return values
    }
    private func scalar(_ sql: String, _ values: [Value] = []) throws -> Int {
        try query(sql, values) { Int(sqlite3_column_int64($0, 0)) }.first ?? 0
    }
    private static func string(_ row: OpaquePointer, _ column: Int32) -> String {
        sqlite3_column_text(row, column).map { String(cString: $0) } ?? ""
    }
    private static func bytes(_ row: OpaquePointer, _ column: Int32) -> Data {
        guard let pointer = sqlite3_column_blob(row, column) else { return Data() }
        return Data(bytes: pointer, count: Int(sqlite3_column_bytes(row, column)))
    }
    private func records<T: Decodable>(_ type: T.Type, _ sql: String, _ values: [Value] = []) throws -> [T] {
        try query(sql, values) { row in
            decodedHistoryRecords += 1
            return try PersistenceCoding.decoder().decode(type, from: Self.bytes(row, 0))
        }
    }
    private func transaction<T>(_ body: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE")
        do { let result = try body(); try execute("COMMIT"); return result }
        catch { try? execute("ROLLBACK"); throw error }
    }
    static func coreOnly(_ source: AppData) -> AppData {
        var value = source
        value.grimoire.actions = []; value.grimoire.occurrences = []; value.grimoire.revisions = []
        return value
    }
    func loadCore() throws -> AppData {
        guard let bytes = try query("SELECT payload FROM core WHERE id=1", decode: { Self.bytes($0, 0) }).first else {
            throw InvokeDataError.storageUnavailable("The local core snapshot is missing. Existing history was preserved.")
        }
        return try PersistenceCoding.decoder().decode(AppData.self, from: bytes)
    }
    private func saveCore(_ value: AppData) throws {
        try execute("INSERT INTO core(id,payload) VALUES(1,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload",
                    [.blob(try PersistenceCoding.encoder().encode(Self.coreOnly(value)))])
    }
    private func savePracticeKeys(_ value: AppData) throws {
        let retained = Set(value.grimoire.practices.map { $0.id.uuidString })
        let existing: [String] = try query("SELECT id FROM practice_keys") { Self.string($0, 0) }
        for id in existing where !retained.contains(id) { try execute("DELETE FROM practice_keys WHERE id=?", [.text(id)]) }
        for practice in value.grimoire.practices {
            try execute("INSERT INTO practice_keys(id,version) VALUES(?,?) ON CONFLICT(id) DO UPDATE SET version=excluded.version WHERE version<>excluded.version",
                        [.text(practice.id.uuidString), .integer(practice.version)])
        }
    }
    func counts() throws -> HistoryCounts {
        HistoryCounts(actions: try scalar("SELECT COUNT(*) FROM actions"), occurrences: try scalar("SELECT COUNT(*) FROM occurrences"), revisions: try scalar("SELECT COUNT(*) FROM revisions"))
    }
    func conflictCount(actionIDs: [UUID], occurrenceIDs: [String], revisionIDs: [UUID]) throws -> Int {
        var total = 0
        for (table, all) in [("actions", actionIDs.map(\.uuidString)), ("occurrences", occurrenceIDs), ("revisions", revisionIDs.map(\.uuidString))] {
            let ids = Array(Set(all))
            for start in stride(from: 0, to: ids.count, by: 400) {
                let chunk = Array(ids[start..<min(start + 400, ids.count)])
                let placeholders = Array(repeating: "?", count: chunk.count).joined(separator: ",")
                total += try scalar("SELECT COUNT(*) FROM \(table) WHERE id IN (\(placeholders))", chunk.map(Value.text))
            }
        }
        return total
    }
    func action(id: UUID) throws -> ActionRecord? { try records(ActionRecord.self, "SELECT payload FROM actions WHERE id=?", [.text(id.uuidString)]).first }
    func action(requestID: UUID) throws -> ActionRecord? { try records(ActionRecord.self, "SELECT payload FROM actions WHERE request_id=?", [.text(requestID.uuidString)]).first }
    func occurrence(id: String) throws -> PracticeOccurrence? { try records(PracticeOccurrence.self, "SELECT payload FROM occurrences WHERE id=?", [.text(id)]).first }
    func revision(id: UUID) throws -> GrimoireRevision? { try records(GrimoireRevision.self, "SELECT payload FROM revisions WHERE id=?", [.text(id.uuidString)]).first }
    func isCorrected(_ id: UUID) throws -> Bool { try scalar("SELECT EXISTS(SELECT 1 FROM actions WHERE reverses_id=?)", [.text(id.uuidString)]) != 0 }
    func activeActions(for occurrenceID: String) throws -> [ActionRecord] {
        try records(ActionRecord.self, "SELECT a.payload FROM actions a WHERE a.occurrence_id=? AND a.kind<>'correction' AND NOT EXISTS(SELECT 1 FROM actions c WHERE c.reverses_id=a.id) ORDER BY a.recorded,a.id", [.text(occurrenceID)])
    }
    func allActions(for occurrenceID: String) throws -> [ActionRecord] {
        try records(ActionRecord.self, "SELECT payload FROM actions WHERE occurrence_id=? ORDER BY recorded,id", [.text(occurrenceID)])
    }
    func latestCompletion(for practiceID: UUID) throws -> ActionRecord? {
        try records(ActionRecord.self, "SELECT a.payload FROM actions a WHERE a.practice_id=? AND a.kind='complete' AND NOT EXISTS(SELECT 1 FROM actions c WHERE c.reverses_id=a.id) ORDER BY a.occurred DESC,a.recorded DESC,a.id DESC LIMIT 1", [.text(practiceID.uuidString)]).first
    }
    func summary(for occurrence: PracticeOccurrence) throws -> (OccurrenceStatus, Int) {
        let row: [(String, Int)] = try query("SELECT status,sessions FROM occurrences WHERE id=?", [.text(occurrence.id)]) { (Self.string($0, 0), Int(sqlite3_column_int64($0, 1))) }
        if let value = row.first { return (OccurrenceStatus(rawValue: value.0) ?? .unrecorded, value.1) }
        return (occurrence.deferredUntil == nil ? .unrecorded : .deferred, 0)
    }
    private func saveOccurrence(_ row: PracticeOccurrence) throws {
        let zone = TimeZone(identifier: row.timeZoneID) ?? .current
        let end = ScheduleEngine.date(row.windowEnd, in: ScheduleEngine.calendar(zone: zone)) ?? row.availableAt
        try execute("""
            INSERT INTO occurrences(id,practice_id,version,available,window_end,due,deferred,reminder_snoozed,required_sessions,superseded,status,sessions,payload)
            VALUES(?,?,?,?,?,?,?,?,?,?,?,0,?) ON CONFLICT(id) DO UPDATE SET practice_id=excluded.practice_id,version=excluded.version,
            available=excluded.available,window_end=excluded.window_end,due=excluded.due,deferred=excluded.deferred,
            reminder_snoozed=excluded.reminder_snoozed,required_sessions=excluded.required_sessions,
            superseded=excluded.superseded,payload=excluded.payload
            """, [.text(row.id), .text(row.practiceID.uuidString), .integer(row.definitionVersion), .real(row.availableAt.timeIntervalSince1970), .real(end.timeIntervalSince1970),
                    row.dueAt.map { .real($0.timeIntervalSince1970) } ?? .null, row.deferredUntil.map { .real($0.timeIntervalSince1970) } ?? .null,
                    row.reminderSnoozedUntil.map { .real($0.timeIntervalSince1970) } ?? .null,
                    .integer(row.requiredSessions), .integer(row.superseded ? 1 : 0),
                    .text(row.deferredUntil == nil ? "unrecorded" : "deferred"), .blob(try PersistenceCoding.encoder().encode(row))])
    }
    private func insertAction(_ row: ActionRecord) throws {
        if let old = try action(id: row.id) {
            guard old == row else { throw InvokeDataError.invalidBackup("An existing action cannot be rewritten. Add a correction instead.") }
            return
        }
        try execute("INSERT INTO actions(id,request_id,occurrence_id,practice_id,session_id,kind,occurred,recorded,reverses_id,payload,search) VALUES(?,?,?,?,?,?,?,?,?,?,?)",
            [.text(row.id.uuidString), .text(row.requestID.uuidString), .text(row.occurrenceID), .text(row.practiceID.uuidString), .text(row.sessionID.uuidString),
             .text(row.kind.rawValue), .real(row.occurredAt.timeIntervalSince1970), .real(row.recordedAt.timeIntervalSince1970),
             row.reversesActionID.map { .text($0.uuidString) } ?? .null, .blob(try PersistenceCoding.encoder().encode(row)),
             .text([row.titleSnapshot, row.notes, row.measurementUnit, row.kind.title].joined(separator: "\n").lowercased())])
    }
    private func insertRevision(_ row: GrimoireRevision) throws {
        if let old = try revision(id: row.id) {
            guard old == row else { throw InvokeDataError.invalidBackup("An existing revision cannot be rewritten.") }
            return
        }
        try execute("INSERT INTO revisions(id,record_id,record_type,changed,payload,search) VALUES(?,?,?,?,?,?)",
            [.text(row.id.uuidString), .text(row.recordID.uuidString), .text(row.recordType), .real(row.changedAt.timeIntervalSince1970),
             .blob(try PersistenceCoding.encoder().encode(row)), .text([row.title, row.summary, String(data: row.before, encoding: .utf8) ?? "", String(data: row.after, encoding: .utf8) ?? ""].joined(separator: "\n").lowercased())])
    }
    private func refreshStatus(_ occurrence: PracticeOccurrence) throws {
        let rows: [(Int, Int, Int, Int)] = try query("""
            SELECT COUNT(DISTINCT CASE WHEN a.kind='complete' THEN a.session_id END),
                MAX(CASE WHEN a.kind='skip' THEN 1 ELSE 0 END),
                MAX(CASE WHEN a.kind IN ('complete','progress','smaller') THEN 1 ELSE 0 END),
                MAX(CASE WHEN a.kind='begin' THEN 1 ELSE 0 END)
            FROM actions a WHERE a.occurrence_id=? AND a.kind<>'correction'
                AND NOT EXISTS(SELECT 1 FROM actions c WHERE c.reverses_id=a.id)
            """, [.text(occurrence.id)]) { (Int(sqlite3_column_int64($0, 0)), Int(sqlite3_column_int64($0, 1)), Int(sqlite3_column_int64($0, 2)), Int(sqlite3_column_int64($0, 3))) }
        let stats = rows.first ?? (0, 0, 0, 0)
        let status: OccurrenceStatus = stats.0 >= occurrence.requiredSessions ? .completed : stats.1 > 0 ? .skipped : stats.2 > 0 ? .partial : stats.3 > 0 ? .inProgress : occurrence.deferredUntil != nil ? .deferred : .unrecorded
        try execute("UPDATE occurrences SET status=?,sessions=? WHERE id=?", [.text(status.rawValue), .integer(stats.0), .text(occurrence.id)])
    }

    func seed(_ source: AppData) throws {
        // Reject unsupported source versions before normalizing a supported legacy import.
        try BackupValidation.validateRecords(source)
        var source = source; source.schemaVersion = AppData.currentSchemaVersion
        try BackupValidation.validateRecords(source)
        try transaction {
            guard try scalar("SELECT COUNT(*) FROM core") == 0 else { throw InvokeDataError.storageUnavailable("This history generation already contains data.") }
            try savePracticeKeys(source)
            for row in source.grimoire.occurrences { try saveOccurrence(row) }
            for row in source.grimoire.actions { try insertAction(row) }
            for row in source.grimoire.revisions { try insertRevision(row) }
            for row in source.grimoire.occurrences { try refreshStatus(row) }
            try saveCore(source)
        }
        try verifyIntegrity()
    }
    func verifyIntegrity() throws {
        let check: [String] = try query("PRAGMA quick_check(1)") { Self.string($0, 0) }
        let foreignKeyFailures: [String] = try query("PRAGMA foreign_key_check") { Self.string($0, 0) }
        guard check == ["ok"], foreignKeyFailures.isEmpty else { throw InvokeDataError.storageUnavailable("Local history needs recovery. Its original files were preserved.") }
    }
    func validateCore(_ core: AppData) throws {
        guard core.schemaVersion == AppData.currentSchemaVersion else {
            throw InvokeDataError.unsupportedVersion(core.schemaVersion)
        }
        guard core.grimoire.actions.isEmpty, core.grimoire.occurrences.isEmpty, core.grimoire.revisions.isEmpty else {
            throw InvokeDataError.storageUnavailable("The local core and history ledger need recovery.")
        }
        let keys: [(String, Int)] = try query("SELECT id,version FROM practice_keys") { (Self.string($0, 0), Int(sqlite3_column_int64($0, 1))) }
        let expected = Dictionary(core.grimoire.practices.map { ($0.id.uuidString, $0.version) }, uniquingKeysWith: { first, _ in first })
        let actual = Dictionary(keys, uniquingKeysWith: { first, _ in first })
        guard expected.count == core.grimoire.practices.count, actual.count == keys.count, actual == expected else {
            throw InvokeDataError.storageUnavailable("The core practice index does not match saved history. Existing files were preserved.")
        }
        var candidate = core
        // These are external ledger references, checked through the primary-key index.
        for i in candidate.grimoire.assets.indices {
            for j in candidate.grimoire.assets[i].inspections.indices {
                if let id = candidate.grimoire.assets[i].inspections[j].actionID {
                    guard try scalar("SELECT EXISTS(SELECT 1 FROM actions WHERE id=?)", [.text(id.uuidString)]) != 0 else {
                        throw InvokeDataError.invalidBackup("An inspection's original action is missing.")
                    }
                    candidate.grimoire.assets[i].inspections[j].actionID = nil
                }
            }
        }
        try BackupValidation.validateRecords(candidate)
    }
    func commit(_ candidate: AppData, now: Date = Date()) throws -> AppData {
        guard candidate.schemaVersion == AppData.currentSchemaVersion else {
            throw InvokeDataError.unsupportedVersion(candidate.schemaVersion)
        }
        return try transaction {
            var validation = candidate
            var ids = Set(candidate.grimoire.actions.map(\.occurrenceID) + candidate.grimoire.occurrences.map(\.id))
            for inspection in candidate.grimoire.assets.flatMap(\.inspections) {
                if let id = inspection.actionID, let row = try action(id: id) { ids.insert(row.occurrenceID) }
            }
            for row in candidate.grimoire.actions {
                if let id = row.reversesActionID, let original = try action(id: id) { ids.insert(original.occurrenceID) }
            }
            var existingOccurrences: [String: PracticeOccurrence] = [:]
            var existingActions: [UUID: ActionRecord] = [:]
            for id in ids {
                if let row = try occurrence(id: id) { existingOccurrences[id] = row }
                for row in try allActions(for: id) { existingActions[row.id] = row }
            }
            for row in candidate.grimoire.occurrences { existingOccurrences[row.id] = row }
            for row in candidate.grimoire.actions {
                if let old = existingActions[row.id], old != row { throw InvokeDataError.invalidBackup("Recorded actions are immutable; use a correction.") }
                existingActions[row.id] = row
            }
            validation.grimoire.occurrences = Array(existingOccurrences.values)
            validation.grimoire.actions = Array(existingActions.values)
            try BackupValidation.validateRecords(validation)
            try savePracticeKeys(candidate)
            for row in candidate.grimoire.occurrences { try saveOccurrence(row) }
            for row in candidate.grimoire.actions { try insertAction(row) }
            for row in candidate.grimoire.revisions { try insertRevision(row) }
            let totals = try counts()
            guard totals.actions <= 500_000, totals.occurrences <= 250_000, totals.revisions <= 100_000 else {
                throw InvokeDataError.invalidBackup("The history collection exceeds its supported record count. Existing data is unchanged.")
            }
            for row in existingOccurrences.values { try refreshStatus(row) }
            let affected = Set(candidate.grimoire.actions.map(\.practiceID))
            for practice in candidate.grimoire.practices where affected.contains(practice.id) && practice.schedule.kind == .afterCompletion {
                try reconcileCompletionInterval(practice, settings: candidate.grimoire.settings, now: now)
            }
            try saveCore(candidate)
            return Self.coreOnly(candidate)
        }
    }
    private func reconcileCompletionInterval(_ practice: PracticeDefinition, settings: GrimoireSettings, now: Date) throws {
        let latest = try latestCompletion(for: practice.id)
        let expected = Set(ScheduleEngine.occurrences(for: practice, in: DateInterval(start: practice.createdAt, end: now.addingTimeInterval(366 * 86_400 * 10)),
            settings: settings, actions: latest.map { [$0] } ?? []).map(\.id))
        let candidates = try records(PracticeOccurrence.self, """
            SELECT o.payload FROM occurrences o WHERE o.practice_id=? AND NOT EXISTS(
                SELECT 1 FROM actions a WHERE a.occurrence_id=o.id AND a.kind IN ('complete','progress','smaller','observation')
                    AND NOT EXISTS(SELECT 1 FROM actions c WHERE c.reverses_id=a.id))
            """, [.text(practice.id.uuidString)])
        for var row in candidates {
            let superseded = !expected.contains(row.id)
            if row.superseded != superseded { row.superseded = superseded; try saveOccurrence(row) }
        }
    }
    func fullData(core: AppData? = nil) throws -> AppData {
        var value = try core ?? loadCore()
        value.grimoire.occurrences = try records(PracticeOccurrence.self, "SELECT payload FROM occurrences ORDER BY id")
        value.grimoire.actions = try records(ActionRecord.self, "SELECT payload FROM actions ORDER BY recorded,id")
        value.grimoire.revisions = try records(GrimoireRevision.self, "SELECT payload FROM revisions ORDER BY changed,id")
        return value
    }
    func occurrences(ids: [String]) throws -> [PracticeOccurrence] {
        var result: [PracticeOccurrence] = []
        for start in stride(from: 0, to: ids.count, by: 400) {
            let chunk = Array(ids[start..<min(start + 400, ids.count)])
            let placeholders = Array(repeating: "?", count: chunk.count).joined(separator: ",")
            result += try records(PracticeOccurrence.self, "SELECT payload FROM occurrences WHERE id IN (\(placeholders))", chunk.map(Value.text))
        }
        return result
    }
    /// Headers only: past resolved records can be excluded without decoding their
    /// historical scripts, step snapshots, or any action-note payloads.
    func ignoredOccurrenceIDs(_ ids: [String], before date: Date) throws -> Set<String> {
        var result = Set<String>()
        for start in stride(from: 0, to: ids.count, by: 400) {
            let chunk = Array(ids[start..<min(start + 400, ids.count)])
            let placeholders = Array(repeating: "?", count: chunk.count).joined(separator: ",")
            let rows: [String] = try query("SELECT id FROM occurrences WHERE id IN (\(placeholders)) AND (superseded=1 OR (status IN ('completed','skipped') AND COALESCE(deferred,due,window_end)<?))",
                chunk.map(Value.text) + [.real(date.timeIntervalSince1970)]) { Self.string($0, 0) }
            result.formUnion(rows)
        }
        return result
    }
    func occurrences(for practiceID: UUID, in range: DateInterval, includeOverdue: Bool, limit: Int = 20_001) throws -> [PracticeOccurrence] {
        try records(PracticeOccurrence.self, """
            SELECT payload FROM occurrences WHERE practice_id=? AND superseded=0 AND available<?
                AND (COALESCE(deferred,due,window_end)>=? OR reminder_snoozed>=? OR (?=1 AND status NOT IN ('completed','skipped')))
            ORDER BY available,id LIMIT ?
            """, [.text(practiceID.uuidString), .real(range.end.timeIntervalSince1970), .real(range.start.timeIntervalSince1970), .real(range.start.timeIntervalSince1970), .integer(includeOverdue ? 1 : 0), .integer(limit)])
    }
    func snoozedPracticeIDs(in range: DateInterval) throws -> Set<UUID> {
        let ids: [String] = try query("SELECT DISTINCT practice_id FROM occurrences WHERE superseded=0 AND reminder_snoozed>=? AND reminder_snoozed<?",
            [.real(range.start.timeIntervalSince1970), .real(range.end.timeIntervalSince1970)]) { Self.string($0, 0) }
        return Set(ids.compactMap(UUID.init(uuidString:)))
    }
    func occurrences(for practiceID: UUID, availableFrom date: Date) throws -> [PracticeOccurrence] {
        try records(PracticeOccurrence.self, "SELECT payload FROM occurrences WHERE practice_id=? AND available>=? ORDER BY available,id", [.text(practiceID.uuidString), .real(date.timeIntervalSince1970)])
    }
    func overlappingPeriods(for practiceID: UUID, version: Int, from start: Date, to end: Date) throws -> [PracticeOccurrence] {
        try records(PracticeOccurrence.self, "SELECT payload FROM occurrences WHERE practice_id=? AND version=? AND superseded=0 AND available<? AND window_end>? ORDER BY available,id LIMIT 20001",
            [.text(practiceID.uuidString), .integer(version), .real(end.timeIntervalSince1970), .real(start.timeIntervalSince1970)])
    }
    func hasActions(for occurrenceID: String) throws -> Bool {
        try scalar("SELECT EXISTS(SELECT 1 FROM actions WHERE occurrence_id=?)", [.text(occurrenceID)]) != 0
    }
    private func completionPredicate(practiceIDs: [UUID]?, range: DateInterval?) -> (String, [Value]) {
        var sql = "a.kind='complete' AND NOT EXISTS(SELECT 1 FROM actions c WHERE c.reverses_id=a.id)", binds: [Value] = []
        if let ids = practiceIDs {
            if ids.isEmpty { sql += " AND 0" }
            else { sql += " AND a.practice_id IN (" + Array(repeating: "?", count: ids.count).joined(separator: ",") + ")"; binds += ids.map { .text($0.uuidString) } }
        }
        if let range { sql += " AND a.occurred>=? AND a.occurred<?"; binds += [.real(range.start.timeIntervalSince1970), .real(range.end.timeIntervalSince1970)] }
        return (sql, binds)
    }
    private func completionBatches(practiceIDs: [UUID]?) -> [[UUID]?] {
        guard let practiceIDs else { return [nil] }
        var seen = Set<UUID>()
        let unique = practiceIDs.filter { seen.insert($0).inserted }
        // Reserve parameters for date bounds and LIMIT even on conservative SQLite builds.
        return stride(from: 0, to: unique.count, by: 400).map { start in
            Optional(Array(unique[start..<min(start + 400, unique.count)]))
        }
    }
    func completionCount(practiceIDs: [UUID]? = nil, range: DateInterval? = nil) throws -> Int {
        var count = 0
        for ids in completionBatches(practiceIDs: practiceIDs) {
            let (predicate, values) = completionPredicate(practiceIDs: ids, range: range)
            count += try scalar("SELECT COUNT(*) FROM actions a WHERE \(predicate)", values)
        }
        return count
    }
    func recentCompletions(practiceIDs: [UUID]? = nil, range: DateInterval? = nil, limit: Int = 20) throws -> [ActionRecord] {
        let count = min(500, max(1, limit))
        var recent: [(record: ActionRecord, timestamp: Double, key: String)] = []
        for ids in completionBatches(practiceIDs: practiceIDs) {
            let (predicate, values) = completionPredicate(practiceIDs: ids, range: range)
            let rows = try query("SELECT a.payload,a.occurred,a.id FROM actions a WHERE \(predicate) ORDER BY a.occurred DESC,a.id DESC LIMIT ?", values + [.integer(count)]) { row in
                decodedHistoryRecords += 1
                return (record: try PersistenceCoding.decoder().decode(ActionRecord.self, from: Self.bytes(row, 0)),
                        timestamp: sqlite3_column_double(row, 1), key: Self.string(row, 2))
            }
            // Preserve SQLite's exact ordering keys, not a decoded-date approximation.
            // Keep only the global top N after each batch so memory stays bounded.
            recent = Array((recent + rows).sorted {
                $0.timestamp == $1.timestamp ? $0.key > $1.key : $0.timestamp > $1.timestamp
            }.prefix(count))
        }
        return recent.map { $0.record }
    }
    func revisions(for recordID: UUID, limit: Int = 50) throws -> [GrimoireRevision] {
        try records(GrimoireRevision.self, "SELECT payload FROM revisions WHERE record_id=? ORDER BY changed DESC,id DESC LIMIT ?", [.text(recordID.uuidString), .integer(min(500, max(1, limit)))])
    }
    func historyPage(in range: DateInterval? = nil, practiceID: UUID? = nil, includeActions: Bool = true,
                     includeRevisions: Bool = true, actionKinds: [ActionKind] = [], recordType: String? = nil,
                     search: String = "", limit: Int = 100, cursor: HistoryCursor? = nil) throws -> HistoryPage {
        var actionWhere = includeActions ? "1" : "0", revisionWhere = includeRevisions ? "1" : "0"
        var actionValues: [Value] = [], revisionValues: [Value] = []
        if let range {
            actionWhere += " AND a.occurred>=? AND a.occurred<?"; revisionWhere += " AND r.changed>=? AND r.changed<?"
            let values: [Value] = [.real(range.start.timeIntervalSince1970), .real(range.end.timeIntervalSince1970)]
            actionValues += values; revisionValues += values
        }
        if let practiceID { actionWhere += " AND a.practice_id=?"; actionValues.append(.text(practiceID.uuidString)); revisionWhere += " AND r.record_id=?"; revisionValues.append(.text(practiceID.uuidString)) }
        if !actionKinds.isEmpty {
            actionWhere += " AND a.kind IN (" + Array(repeating: "?", count: actionKinds.count).joined(separator: ",") + ")"
            actionValues += actionKinds.map { .text($0.rawValue) }
        }
        if let recordType { revisionWhere += " AND r.record_type=?"; revisionValues.append(.text(recordType)) }
        if !search.isEmpty {
            let escaped = search.lowercased().replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_")
            actionWhere += " AND a.search LIKE ? ESCAPE '\\'"; revisionWhere += " AND r.search LIKE ? ESCAPE '\\'"
            actionValues.append(.text("%" + escaped + "%")); revisionValues.append(.text("%" + escaped + "%"))
        }
        var outer = "1", values = actionValues + revisionValues
        if let cursor {
            outer = "event_time<? OR (event_time=? AND event_key<?)"
            values += [.real(cursor.timestamp.timeIntervalSince1970), .real(cursor.timestamp.timeIntervalSince1970), .text(cursor.key)]
        }
        let count = min(500, max(1, limit)); values.append(.integer(count + 1))
        let sql = """
            SELECT event_key,event_time,record_kind,payload,corrected FROM (
                SELECT 'a:'||a.id AS event_key,a.occurred AS event_time,'action' AS record_kind,a.payload,
                    EXISTS(SELECT 1 FROM actions c WHERE c.reverses_id=a.id) AS corrected FROM actions a WHERE \(actionWhere)
                UNION ALL
                SELECT 'r:'||r.id,r.changed,'revision',r.payload,0 FROM revisions r WHERE \(revisionWhere)
            ) WHERE \(outer) ORDER BY event_time DESC,event_key DESC LIMIT ?
            """
        let statement = try statement(sql, values); defer { sqlite3_finalize(statement) }
        var page = HistoryPage(), used = 0, totalBytes = 0, last: HistoryCursor?
        while true {
            let code = sqlite3_step(statement)
            if code == SQLITE_DONE { break }
            guard code == SQLITE_ROW else { throw failure() }
            let size = Int(sqlite3_column_bytes(statement, 3))
            if used >= count || (used > 0 && totalBytes + size > 8 * 1_024 * 1_024) { page.nextCursor = last; break }
            let bytes = Self.bytes(statement, 3)
            if Self.string(statement, 2) == "action" {
                let action = try PersistenceCoding.decoder().decode(ActionRecord.self, from: bytes)
                page.actions.append(action)
                if sqlite3_column_int(statement, 4) != 0 { page.correctedActionIDs.insert(action.id) }
            } else { page.revisions.append(try PersistenceCoding.decoder().decode(GrimoireRevision.self, from: bytes)) }
            decodedHistoryRecords += 1; used += 1; totalBytes += size
            last = HistoryCursor(timestamp: Date(timeIntervalSince1970: sqlite3_column_double(statement, 1)), key: Self.string(statement, 0))
        }
        return page
    }

    #if DEBUG
    /// A real SQLITE_FULL fault, used to verify transaction rollback on write failure.
    func constrainStorageToCurrentSizeForTesting() throws {
        let pages = try scalar("PRAGMA page_count")
        try execute("PRAGMA max_page_count=\(pages)")
    }
    #endif
}
