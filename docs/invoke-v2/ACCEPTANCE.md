# Invoke 2.0 acceptance record

Checkpoint: 26 October 2026, before final native release verification. This maps all 34 cases in the approved master brief to implemented source and authored tests. A test listed below is evidence of coverage intent, not evidence that it passed. The release owner must append the actual tested commit, CI run, results and inspected screenshots before publication.

## Checks actually performed at this checkpoint

| Command/check | Observed result | Scope |
| --- | --- | --- |
| python Tools/check_source.py, with the optional Swift grammar parser available, before the SQLite integration slice | PASS: 49 Swift files; one Metal source; 117 authored XCTest methods; no Swift grammar errors; package references and resources consistent | Earlier portable source/package checkpoint; no Swift type checking or Apple runtime execution. Re-run against final sources. |
| python Tools/build_codex.py --check | PASS: 254 source entries, 252 canonical templates/references, eight reference-only entries | Deterministic source coverage and generated-file consistency |
| Independent source review | Identified and coordinated corrections to recovery access, calendar transitions, archive state, inspection follow-up and history-query cost | Read-only review plus targeted source fixes; native regression execution remains pending |
| SQLite follow-up review | Extracted schema, tied-time cursor boundaries, correction flags outside the selected range, escaped search, deferred foreign-key rollback and deferred date predicate passed an in-memory SQLite exercise; edited Swift files passed grammar parsing | SQL/grammar checks only. Final AppStore integration, migrations and authored native page tests still require execution. |
| Xcode/iOS 27 build and XCTest | NOT RUN in the Windows workspace; final native CI result pending | Required release evidence |
| Physical iPhone, LiveContainer 3.8.10, VoiceOver, keyboard and measured device performance | NOT RUN | Manual/device acceptance remains open |

Historical 1.1.0 CI results in the root README establish a baseline only. They do not prove 2.0 passes.

## Evidence key

Paths below are relative to the repository root. The suites are:

- [ScheduleEngineTests](../../InvokeTests/ScheduleEngineTests.swift): pure calendar boundaries and identities.
- [GrimoireStoreTests](../../InvokeTests/GrimoireStoreTests.swift): durable actions, quotas, undo, specialty records and larger synthetic history.
- [GrimoireMigrationTests](../../InvokeTests/GrimoireMigrationTests.swift): real schema-1 shape, preserved legacy graph/images, staged upgrade and portability.
- [ReminderCoordinatorTests](../../InvokeTests/ReminderCoordinatorTests.swift): reminder planning, authorization/failure handling and host isolation.
- [CodexLibraryTests](../../InvokeTests/CodexLibraryTests.swift) and [ChronicleTimelineTests](../../InvokeTests/ChronicleTimelineTests.swift): content coverage, independent template copies and read-only history projection.
- [SQLiteHistoryTests](../../InvokeTests/SQLiteHistoryTests.swift): transactional storage, lazy history reads and repository limits. ChronicleTimelineTests also authors a 126-record mixed-page/tied-time/out-of-range-correction integration fixture.
- [LivingGrimoireUITests](../../InvokeUITests/LivingGrimoireUITests.swift), [LivingLayoutUITests](../../InvokeUITests/LivingLayoutUITests.swift), [StorageRecoveryUITests](../../InvokeUITests/StorageRecoveryUITests.swift): authored native interaction, relaunch, layout and recovery flows.
- [AppStoreTests](../../InvokeTests/AppStoreTests.swift), [StoryFlowTests](../../InvokeTests/StoryFlowTests.swift), [PreferencesCompatibilityTests](../../InvokeTests/PreferencesCompatibilityTests.swift), [ConstellationUITests](../../InvokeUITests/ConstellationUITests.swift): retained regression coverage.

“Native pending” means the implemented case has authored automated coverage whose 2.0 execution has not been recorded here. “Manual pending” means the listed inspection still needs a person/device; passing automation alone does not close it.

## All 34 acceptance cases

| # | Required scenario | Actual implementation and authored evidence | Verification at this checkpoint |
| --- | --- | --- | --- |
| 1 | Fresh user can skip setup, selectively activate and use the app without runtime AI | LivingSetupView supports skipping and a chosen starting set. LivingGrimoireView previews an inactive template before PracticeEditor saves a copy. LivingGrimoireUITests exercises skip/activation; GrimoireStoreTests exercises offline persistence. | Native pending. No runtime AI/account/network dependency added. |
| 2 | Daily actions visible; consequential annual work remains visible | TodayQuestsView has attention, daily progress and action rows. GrimoireStoreTests.testAnnualConsequentialDeadlineRemainsVisibleBesideDailyWork; LivingLayoutUITests includes six important obligations. | Native pending; first actionable item above the fold needs actual screenshot inspection. |
| 3 | All schedule families produce expected windows | ScheduleEngine implements unscheduled/once, daily/selected weekdays, weekly/quota, monthly/quarterly/semiannual/annual, actual-completion intervals, events, condition reviews and custom calendar intervals. ScheduleEngineTests covers each family. | Native pending. |
| 4 | Two weekly sessions count; retries collapse; no seven-day quota debt | One period identity with requiredSessions and distinct session IDs. GrimoireStoreTests.testQuotaCountsTwoDistinctSessionsButNotRetry; ScheduleEngineTests.testWeeklyQuotaIsOneWindowNotSevenDailyObligations. | Native pending. |
| 5 | Double tap, retry and reopen give one completion | Stable request IDs plus occurrence/session duplicate guards. GrimoireStoreTests.testRetryDoubleTapAndReopenCannotDuplicateOneCompletion; native completion/relaunch flow. | Native pending. Sync retries are not applicable: this app has no sync service. |
| 6 | One action updates all connected views without duplicate credit | Today, occurrence detail, Invocation, recognition and Chronicle derive from canonical actions. GrimoireStoreTests.testInvocationPracticeCompletionChronicleUndoAndRestartUseOneRecord; LivingGrimoireUITests.testInvocationLinkedPracticeUpdatesActualActionHistory. | Native pending; recognition wording also requires source/visual review. |
| 7 | Partial/smaller work and timer remain honest | OccurrenceDetailView records begin/progress/smaller/full separately and persists interrupted drafts. Beginning/resuming and partial-step store tests; reminder smaller-version test. | Native pending; timer/background/resume interaction needs manual check. |
| 8 | Undo reconciles counts, availability and reminders | Undo appends a dated correction; active aggregates exclude its target. Store undo/interval tests, reminder completion/skip/undo test, Chronicle projection and relaunch UI test. | Native pending. |
| 9 | Optional absence renews; unresolved obligations persist individually | Renew and persist policies are separate; stored/generated obligations keep identities. GrimoireStoreTests.testMissingOptionalDaysDoNotAccumulateButDistinctBillsRemain. | Native pending; return-after-absence walkthrough still needs visual review. |
| 10 | Pause/resume and future edits preserve history without duplicates | Definition revisions, occurrence snapshots, pause intervals and supersession in GrimoireStore/ScheduleEngine. Future-revision and pause/archive tests. | Native pending; verify same-day edits and partially completed quota transitions explicitly. |
| 11 | Month ends, leap years, boundaries, ordinal weekdays and week starts | Calendar arithmetic with clamp/February-28/absent-fifth policies; ScheduleEngineTests contains January 31, last/ordinal weekday, leap, quarter, custom-anchor and Sunday-week fixtures. | Native pending; switching an existing quota’s week-start policy requires transition regression, not only independent settings fixtures. |
| 12 | DST, home/travel, midnight and retrospective entries retain truthful identity | ScheduleEngine wall-time policy uses next valid time/first repeated offset. Saved occurrences/actions keep their zone. DST/non-DST and retrospective store tests; Today refreshes at activation/minute tick. | Native pending. Actual device travel/midnight reopening is manual pending. |
| 13 | Snooze affects notification time, not the deadline | Separate reminderSnoozedUntil, deferredUntil and hardDeadline. Store snooze/deferral test and ReminderCoordinatorTests.testSnoozeUsesStoredOccurrenceAndKeepsItsDeadline. | Native pending; actual delivery/cancellation on host remains manual pending. |
| 14 | Unknown completion/install dates remain unknown | Optional known-date fields, configured Codex schedules stay unspecified, first interval uses an explicit anchor. CodexLibraryTests and serviceable-asset/unknown-completion tests. | Native pending; no universal age/expiry is seeded. |
| 15 | Every Appendix A source is reachable, with documented consolidation | Bundled Codex.json, full original source disclosure/search, stable IDs, related references and CONTENT_COVERAGE.md. CodexLibraryTests checks all sources and consolidation. | Portable coverage PASS: all 254 IDs. Native browsing/decoding pending. |
| 16 | Selective activation without assumed ownership/caregiving | Applicability/responsibility text, inactive library, explicit save and optional setup responsibility choices. Codex activation UI test; template copy tests. | Native pending; applicability wording was source-reviewed. |
| 17 | Personal names/instructions/schedules survive library changes and imports | Owned copies retain template ID/version; bundled content never mutates them. Template personalization and idempotent merge tests. Existing IDs win merge conflicts. | Native pending. Inconsistent cross-links reject a merge rather than guessing; documented in MIGRATION.md. |
| 18 | Serviceable/repair/replacement states depend on observations | CareAssetDetail/AssetInspectionEditor and atomic recordInspection; serviceable and warranted-follow-up store tests. Dates, quantity and condition are distinct. | Native pending; replenishment follow-up must be included in final regression run. |
| 19 | Invocation supports exploratory intention and separates outcome from effort | Invocation editor has optional evidence; observations and milestone status are explicit. Store outcome-independence test and Chronicle action/outcome test. | Native pending. |
| 20 | Saved Spell and Enchantment with upkeep can be found after restart | Grimoire shelves/editors; arrangement evidence, linked maintenance practice and review date. GrimoireStoreTests.testSpecialtyRecordsAndSettingsPersistWithoutNetwork; method/Echo UI relaunch flow. | Native pending. Manually verify arrangement review visibility and reminder behavior actually offered by the final UI. |
| 21 | Tend/Widen the Circle use chosen schedules and action-only records | BondsPlanningView presents Maintenance/Moderate/Active growth proposals; each opens the practice editor without activating. Sources C14 retain personal-preference guidance. | Source reviewed; dedicated Bonds UI/manual walkthrough pending. No loyalty/affection score implemented. |
| 22 | Arcana and Echo retain sources, observations, interpretations and differences | Full specialty editors and audit snapshots. GrimoireStoreTests.testArcanaBeliefRevisionAndEchoSourcesSurvivePortableRoundTrip; Echo source relaunch UI test. | Native pending; full source/interpretation editing walkthrough pending. |
| 23 | Check-offs never claim measured health, mental state, supernatural power or relationship quality | Recognition describes recorded sessions only. Invocation observations and Arcana interpretations are separate from actions. Relevant source and library wording reviewed. | Source review performed; full rendered-copy inspection pending. |
| 24 | Realistic legacy graph upgrades intact; second migration does nothing | Schema-1 decoder retains all seven original collections/preferences. Shadow generation, image copies, original raw bytes and recovery file. GrimoireMigrationTests checks IDs, values, links, photos and idempotence. | Native pending. |
| 25 | Interrupted/corrupt/full-storage cases recover without reset | Atomic generation pointer, retained original data, blocked writes and dedicated storage recovery route. Interrupted-stage/corrupt-input/failed-write tests; StorageRecoveryUITests. | Native pending. Real full-device, locked-device and interrupted-install tests are manual pending. |
| 26 | Portable data round trip, idempotent merge and deliberate recoverable replacement | Versioned .invoke file includes new records/history/images; validation preview, explicit merge/replace and retained recovery copy. Migration/store round-trip, merge and invalid-import tests. | Native pending. Files-provider interaction and recovery after host upgrade are manual pending. |
| 27 | Existing supported features/platform boundaries remain accessible | Five new tabs link original Sanctuary/constellation, Stories, original Grimoire and Relic Cabinet. Existing theme, story, image/PDF and persistence code retained. Preservation matrix and legacy regression suites. | Native pending. No original account/authentication or cloud integration exists to migrate. |
| 28 | Denied/failed permissions, storage and provider errors remain usable | Notification gateway reports denial/failure; app works without notifications; save failures retain state/error; import/export reports failure; storage recovery bypasses setup. Mock failure tests and recovery UI test. | Native pending. Real Files-provider/network/host interruptions are manual pending. |
| 29 | Owner isolation where applicable; no private production data in evidence | Single-user local app; no account or cloud owner boundary. Tests use generated/synthetic records and isolated temporary directories. Evidence should be reviewed before upload. | Multi-user isolation not applicable. Source/fixture review performed; final artifacts still require a privacy inspection. |
| 30 | Keyboard/VoiceOver/contrast/reduced motion/large text/sizes checked | Semantic native controls, theme contrast/Reduce Motion/Reduce Transparency handling and 44pt primary controls. LivingLayoutUITests authors small/accessibility text and all-theme checks; constellation regression covers readable scene alternatives. | Native automated execution pending. Manual VoiceOver, external keyboard, contrast measurement and small/large device layouts NOT RUN. No conformance claim. |
| 31 | Empty/long/high-count/completed/paused/archive/error states work | Source includes empty states, filters, saved/partial/correction states, archive/restore, loading and storage errors. Native layout/completion/recovery tests plus store pause/archive tests. | Native pending; complete visual state matrix remains manual pending. |
| 32 | Representative scale without infinite projection or invented performance | Synthetic store fixture: 1,000 definitions and 3,000 actions/occurrences across three years. SQLite indexes the new ledger, ordinary startup reads the core only, and Chronicle requests bounded keyset pages with a stable merge frontier. | Native timing/rendering measurements pending. Original/specialty collections still load in the core; full portable export is explicit. No FPS or device-latency guarantee is claimed. |
| 33 | Real build/type/lint/applicable tests run, with exact results | Tools/test_ios.sh, Tools/build_ipa.sh and GitHub workflow gate simulator tests and arm64 packaging. Portable check commands passed above. No separate SwiftLint configuration is present. | Native Swift/Metal compile, XCTest results, toolchain/version metadata and package checks pending. Record introduced versus baseline failures when results arrive. |
| 34 | Baseline/new screenshots retain identity and show actionable home | Original Astral/Ink/Velvet tokens, icon and shaders remain; authored UI attachments cover original constellation and new Today/Chronicle/Invocation/library flows. | New runtime screenshots have not been inspected at this checkpoint. Baseline 1.1 screenshots/results are historical only. |

## Manual release walkthroughs still open

Use only synthetic or sanitized fixtures; do not publish the owner’s writing, photos, beliefs, financial details or credentials.

1. Normal day: select Astral, small/default text and a representative portrait phone. Confirm a daily action is visible without scrolling, the full attention list expands, and first-use empty state is useful.
2. Annual obligation: mix daily, monthly and annual priorities; inspect the deadline, snooze and defer it, and confirm the external deadline remains unchanged.
3. Return after absence: include optional daily work, a weekly quota and separate unresolved obligations. Confirm absence is “not recorded,” not an invented skip or achievement.
4. Transformation ritual: link a nonnumeric Invocation, begin, check some steps, leave/relaunch, record smaller scope, finish a real full session, undo and inspect the correction.
5. Asset care: keep a serviceable item, then record a warranted repair/replacement/replenishment separately. Verify unknown dates and reserve arithmetic.
6. Arcana/Bonds: edit source and interpretation separately, change belief position, compare differences in an Echo, and activate only chosen social practices.
7. Upgrade: export schema-1 data outside the host, update the same LiveContainer data container, inspect every legacy collection/photo/theme, review the retained recovery copy and export schema 2.
8. Accessibility/device: VoiceOver order/labels, keyboard dismissal/focus, long titles, contrast, Reduce Motion/Transparency, denied notifications and Files-provider failures. Record actual iPhone model, iOS version and exact LiveContainer build.

## Final native result to append

The release owner must replace “pending” with observed evidence, not with a forecast:

- Tested Git commit and workflow/run URL.
- Xcode version/build, device and simulator SDKs, exact simulator runtime/model.
- Actual command exit codes and XCTest totals, failures and skips.
- Retained xcresult/log/metadata and screenshot paths; visual reviewer and inspected screens.
- arm64 IPA/signature/resource/feed/checksum results.
- Published release URL and asset list, only after publication succeeds.
- Open manual/device limitations, including iOS 27 + LiveContainer 3.8.10, and any remaining acceptance failures.

See [repository audit](REPO_AUDIT.md), [migration/recovery](MIGRATION.md), [calendar semantics](DATA_AND_SCHEDULING.md), [content coverage](CONTENT_COVERAGE.md), [LiveContainer verification](LIVECONTAINER.md) and [user guide](USER_GUIDE.md).
