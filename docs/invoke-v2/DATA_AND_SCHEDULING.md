# Living Grimoire data and scheduling

## One source of truth

User-owned `PracticeDefinition` records contain instructions, ordered steps, configured schedule, importance, origin and links. The built-in Codex stays separate; content updates do not overwrite activated copies. `PracticeOccurrence` is a stable snapshot of a definition version and an actionable calendar window. `ActionRecord` is the canonical action/correction history used by Today, the runner, Invocations and Chronicle. Checking a step records progress; it is not a separate completed ritual.

Occurrence identity combines practice UUID, definition version, local window/explicit event identity and time-slot UUID. Weekly quotas use one period identity. Event occurrences additionally retain the actual user-recorded event UUID. Persisted occurrence snapshots keep their original zone/title/steps across later settings and definition changes.

Every command carries a stable request UUID. A retry returns its original action, including after restart. A normal occurrence cannot receive two effective full completions even if a caller supplies a different request. Quotas accept distinct session UUIDs, allowing two real sessions while collapsing retries of either session. Beginning/resuming is distinct from completion. Smaller versions and partial steps do not silently complete the full routine.

Undo appends a correction referencing the original action. Effective aggregates exclude corrected actions while Chronicle retains the original and correction. Corrections are idempotent. Completion-anchored future instances are reconciled when their causal completion is undone, so obsolete unacted instances cannot keep reminding the user.

Invocation observations and milestone changes are explicit user records, independent of effort counts. Spell, Enchantment, asset, Arcana, Echo and Invocation edits retain immutable before/after revisions. Asset inspections retain actual condition and optional explicitly requested follow-up work. Unknown purchase/install/completion dates remain nil. Archive/pause retain history.

## Calendar semantics

`ScheduleEngine` is a pure Foundation Calendar service with explicit query bounds, settings, action/event inputs and an injectable current time zone. `LocalDay` stores year/month/day separately from UTC instants. Calendar arithmetic is used for days, weeks, months and years.

| Family | Meaning |
| --- | --- |
| Unscheduled | One stable opportunity with no invented due date |
| One-off | A configured local date, optionally with an explicit timed deadline |
| Daily / weekdays | One date window or distinct configured time slots; selected weekdays use Calendar numbering, Sunday=1 |
| Weekly | One flexible week window using the chosen week start |
| Weekly quota | N genuine sessions in one week, never N daily obligations; time slots do not split the quota |
| Monthly | Chosen day, last day, or ordinal weekday; unavailable numbered days clamp to month end; an absent fifth weekday is skipped |
| Quarterly | Every three months from the anchor, or an explicitly labeled calendar-quarter window |
| Semiannual | Every six calendar months from the anchor |
| Annual | Anchor month/day; February 29 defaults to February 28 in a non-leap year |
| After completion | Configured interval after the latest effective full action; an explicit start supplies the first opportunity when no actual completion is known |
| Event | Only after a matching user-recorded named event; no inferred private-data triggers |
| Condition review | Scheduled inspection; replacement/repair requires an actual recorded condition and explicit follow-up |
| Custom interval | Calendar day/week/month/year increments from the original anchor, preserving month-end intent |

Home-zone mode uses the selected IANA identifier; travel mode uses the current device zone for future projection. A per-practice home zone can override that choice. Historical records retain their original event and recorded instants plus zone. For a DST gap, a wall-time reminder moves to the next valid local instant; a repeated hour uses the first offset once.

Availability, target/due date, hard deadline, reminder and completion are separate. Snooze changes only notification time. Deferral records a deliberate action and leaves a hard deadline unchanged. External legal/financial deadlines are not changed by editing Invoke. Skip is not completion and never advances an after-completion anchor.

## Absence, revisions and bounds

Renewing daily practices project the requested day rather than accumulating missed opportunities on Today. Persist-until-resolved practices reconstruct distinct outstanding windows from their configured anchor even if the app was closed; records already completed/skipped are filtered appropriately. One-off and event obligations remain reachable. An after-completion task remains one eligible unresolved opportunity after its due date.

Future schedule/step edits snapshot earlier opportunities and retain old definition revisions. Existing acted instances keep their original meaning. Future unacted instances become superseded; the new definition generates future available instances under a new version. Pause intervals exclude opportunities that would otherwise be generated during the pause. Changes to presentation/restoration mode do not create, complete or remove actions.

Projection is bounded (20,000 occurrences per definition per query), and imports bound collection sizes. UI requests bounded date horizons and paginates visible lists; it does not generate an infinite future. Extremely large historical obligations can reach this projection bound; this is not a complete unlimited-backlog query. An explicit overflow/pagination path is needed before claiming support beyond the bound. The existing JSON persistence still loads structured history into memory; it is not a database with lazy history loading.

The native performance fixture has 1,000 active definitions and 3,000 saved actions/occurrences across three years. Its one-day query must return 1,000 rows without appending synthetic activity. Actual timings and test outcomes belong in `ACCEPTANCE.md`; no fixed FPS or latency promise is inferred from the fixture.

## Validation

Import/save checks reject duplicate IDs/request identities, duplicate full completion credit, invalid enums/dates/zones, absent relationships, invalid schedule ranges, nonfinite measurements/costs, unsafe image names and broken image manifests. New collections are single-user local data, matching the existing app. There is no cloud account, sync engine, analytics or runtime AI dependency.

See `DATA_API.md` for exact store methods. All discrete mutations throw on failed validation or persistence; callers must display the error and avoid success feedback. Native reminder delivery and LiveContainer-specific limits are documented separately.
