# Invoke 2.0 data API

All APIs below are `@MainActor` AppStore methods unless marked pure. Mutations throw on validation/save failure; callers must show the error. IDs are not regenerated during edits.

```swift
// Pure selectors; safe in a SwiftUI body. Defaults use Date().
func grimoireOccurrences(in range: DateInterval, now: Date = Date(), practiceID: UUID? = nil) -> [PracticeOccurrence]
func occurrenceStatus(_ occurrence: PracticeOccurrence) -> OccurrenceStatus
func sessionCount(for occurrence: PracticeOccurrence) -> Int
func activeActions(for occurrenceID: String) -> [ActionRecord]

func ensureOccurrence(_ occurrence: PracticeOccurrence) throws
func materializeOccurrences(in range: DateInterval, now: Date = Date()) throws
func savePractice(_ practice: PracticeDefinition, effectiveFrom: Date = Date()) throws
func activatePractice(_ practice: PracticeDefinition) throws
func setPracticePaused(_ id: UUID, paused: Bool) throws
func archivePractice(_ id: UUID, archived: Bool = true) throws
func beginSession(occurrenceID: String, newSession: Bool = false, now: Date = Date()) throws -> UUID
@discardableResult
func recordAction(occurrenceID: String, kind: ActionKind, sessionID: UUID,
                  requestID: UUID, steps: [UUID] = [], notes: String = "",
                  measurement: Double? = nil, measurementUnit: String = "",
                  occurredAt: Date = Date(), now: Date = Date()) throws -> ActionRecord
func undoAction(_ id: UUID, now: Date = Date()) throws
func deferOccurrence(_ id: String, to date: Date, now: Date = Date()) throws
func snoozeReminder(_ id: String, until date: Date) throws
func commitGrimoire(_ value: GrimoireData, now: Date = Date()) throws
func saveInvocation(_ value: Invocation) throws
func saveSpell(_ value: Spell) throws
func saveEnchantment(_ value: Enchantment) throws
func saveAsset(_ value: CareAsset) throws
func saveArcana(_ value: ArcanaRecord) throws
func saveEcho(_ value: Echo) throws
func saveEvent(_ value: GrimoireEvent) throws
func recordInspection(assetID: UUID, inspection: AssetInspection,
                      followUp: PracticeDefinition? = nil) throws
func mergeBackup(_ payload: BackupPayload) throws
```

Before opening a runner or completing a generated row, call `ensureOccurrence(row)`. `beginSession` resumes an unfinished session. Pass `newSession: true` only for an explicitly requested additional quota session. Save the returned session ID and a stable request UUID for each command; retries return the original action. Completing a non-quota occurrence cannot add duplicate completion even with a different request ID. Smaller-version records are partial and do not complete the full occurrence. Check-off steps record progress, not separate credited actions. Existing legacy arrays are preserved; links use legacyEntryID/legacySceneID/legacyStoryID without fabricating prior actions.

Pure scheduling/notification helpers:

```swift
ScheduleEngine.occurrences(for: PracticeDefinition, in: DateInterval,
    settings: GrimoireSettings, actions: [ActionRecord] = [], events: [GrimoireEvent] = [],
    currentZone: TimeZone = .current, limit: Int = 20_000) -> [PracticeOccurrence]
ScheduleEngine.activeActions(_ actions: [ActionRecord]) -> [ActionRecord]
ScheduleEngine.summary(_ schedule: ScheduleRule) -> String
ScheduleEngine.zone(for: ScheduleRule, settings: GrimoireSettings,
    currentZone: TimeZone = .current) -> TimeZone
ScheduleEngine.wallTime(day: LocalDay, hour: Int, minute: Int, calendar: Calendar) -> Date?
GrimoireLogic.status(of: PracticeOccurrence, actions: [ActionRecord]) -> OccurrenceStatus
GrimoireLogic.sessionCount(for: PracticeOccurrence, actions: [ActionRecord]) -> Int
```

`saveAsset` retains stored inspection history when an older editor is submitted. Specialty records archive by setting archived=true and saving; there is no destructive delete API. Merge keeps existing records on same-ID conflicts, appends only new IDs and retains current settings, and uses the staged restore/recovery path. The UI must state this policy and allow explicit replacement through existing `restore` when desired.

## SQLite integration contract — implemented, 2026-10-26

The following supersedes direct reads of `store.data.grimoire.actions`, `.occurrences`, and `.revisions`. Those arrays remain in the portable Codable model and can carry explicit additions/updates into `commitGrimoire`; the published runtime core leaves them empty. They are not an incomplete representation of history to display. `exportFullData()` is the deliberate full-read operation for backup, restore, merge, and tests.

Ordinary startup opens `generations/<UUID>/history.sqlite` and reads a single core snapshot. SQLite owns the core snapshot and all three history collections in one transaction. It indexes record IDs, request IDs, practice/occurrence links and dates. Initial conversion of a JSON generation is a staged, validated one-time full read, with the original generation retained and `CURRENT` switched only after successful validation. A failed action transaction changes neither durable core/history nor published state. Legacy collections and specialty records remain intact in the core; new action/occurrence/revision history is fetched on demand.

```swift
struct HistoryCursor: Codable, Equatable { var timestamp: Date; var key: String }
struct HistoryPage {
    var actions: [ActionRecord]
    var revisions: [GrimoireRevision]
    var correctedActionIDs: Set<UUID> // Includes corrections outside this page/date range.
    var nextCursor: HistoryCursor?
}
struct HistoryCounts { var actions: Int; var occurrences: Int; var revisions: Int }

// AppStore, main actor. These are the public UI integration names.
var historyCounts: HistoryCounts { get }
var historyRevision: Int { get } // Published after every durable core/history commit.
func historyConflictCount(actionIDs: [UUID], occurrenceIDs: [String], revisionIDs: [UUID]) throws -> Int
func refreshRecoveryBackups() throws // Explicitly validate and discover unindexed copies.
func action(id: UUID) -> ActionRecord?
func occurrence(id: String) -> PracticeOccurrence?
func revision(id: UUID) -> GrimoireRevision?
func isActionCorrected(_ id: UUID) -> Bool
func completionCount(practiceIDs: [UUID]? = nil, in range: DateInterval? = nil) -> Int
func recentCompletions(practiceIDs: [UUID]? = nil, in range: DateInterval? = nil,
                       limit: Int = 20) -> [ActionRecord]
func revisions(for recordID: UUID, limit: Int = 50) -> [GrimoireRevision]
func historyPage(in range: DateInterval? = nil, practiceID: UUID? = nil,
                 includeActions: Bool = true, includeRevisions: Bool = true,
                 actionKinds: [ActionKind] = [], recordType: String? = nil,
                 search: String = "", limit: Int = 100,
                 cursor: HistoryCursor? = nil) throws -> HistoryPage
func schedulePreview(for practice: PracticeDefinition, in range: DateInterval,
                     limit: Int = 8) -> [PracticeOccurrence]
func reminderProjectionData(in range: DateInterval, now: Date = Date()) throws -> GrimoireData
func exportFullData() throws -> AppData
```

`historyPage` orders action occurrence times and revision change times descending with a stable key as tie-breaker. It uses keyset pagination, bounds each request to 500 records, and returns correction status independently of the page. Search applies to action title/notes/unit and revision title/summary/source JSON. Core/specialty/legacy timeline rows can be merged locally by the Chronicle; their presence does not require reading the action ledger. Single-record and aggregate UI helpers preserve existing convenience semantics; any SQL failure is surfaced as a storage error, and mutation methods always throw rather than record an assumed success. `historyPage` and export/reminder preparation throw directly so their callers can show failure explicitly.

Existing `activeActions(for:)`, `occurrenceStatus`, `sessionCount`, `grimoireProjection`, and `grimoireOccurrences` signatures remain. They use indexed ledger queries and bounded memoization, never a hidden first-use load of the full ledger. `reminderProjectionData` returns the requested candidate occurrences, their effective action rows, and latest actual completion anchors needed by the pure reminder planner; it is intentionally a bounded projection, not a backup. `schedulePreview` supplies the same actual completion anchor to editor previews.

Additional implemented APIs before this storage slice: `storageRecoveryRequired`, `recoveryBackupURLs`, `lastRecoveryBackupURL`, `grimoireProjection(in:now:)` with occurrences/warnings/truncated, and `commitGrimoire(_:now:)`. Occurrences and practice revisions snapshot instructions/context/materials/smallerVersion. Annual schedules consistently use `dayOfMonth`; weekly deadlines use the final day of the window; changing week-start preserves the established current quota period.
