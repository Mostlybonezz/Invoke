# Invoke 2.0 data API

All APIs below are `@MainActor` AppStore methods unless marked pure. Mutations throw on validation/save failure; callers must show the error. IDs are not regenerated during edits.

```swift
// Pure selectors; safe in a SwiftUI body. Defaults use Date().
func grimoireOccurrences(in range: DateInterval, now: Date = Date()) -> [PracticeOccurrence]
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
func commitGrimoire(_ value: GrimoireData) throws
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
