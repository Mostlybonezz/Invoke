# Schema 1 → 2 preservation and recovery

## What changes

`AppData.schemaVersion` becomes 2 and adds `grimoire`. Stories, chapters, scenes, library entries, relics, reflections, ritual logs, UUIDs, prose, historical dates, images and appearance preferences remain in their original fields. Existing stories are not automatically relabeled as completed goals; old ritual performances do not create new completion credit. New links can point to the original records after explicit user action.

Schema 1 decoding requires the real legacy fields and initializes an empty Grimoire. Schema 2 requires its Grimoire payload; a missing payload is corruption, not a request to erase it. Newer schema/format versions are rejected. The portable envelope remains format 1 with an explicit nested data schema; version 1 apps consequently reject schema 2 rather than silently dropping new data.

## Atomic upgrade

`AppStore` validates the JSON legacy graph and checks every referenced image before migration. It creates a separate UUID generation, copies the referenced images, and writes:

- A `history.sqlite` database containing the schema 2 core and indexed action, occurrence and revision tables.
- `legacy-schema-1.json`, retaining the exact original snapshot bytes, including unknown fields.
- A complete `recovery/Before-2.0-<UUID>.invoke` portable copy of the known legacy data and images.

The staged database is validated with SQLite integrity and foreign-key checks, the core is read back, and ledger counts are checked against the source. The raw source is compared byte-for-byte. Only then is `CURRENT` atomically replaced. The original generation is retained, including its original images and unknown fields. Pre-SQLite schema 2 JSON also migrates once, retaining `legacy-schema-2.json` and a `Before-paged-history` portable copy. Subsequent launches open the database without repeating migration.

An abandoned, unreferenced stage never becomes active merely because it exists. If staging fails before the pointer switch, the original pointer remains. If current and previous snapshots cannot be read, writes are blocked and the recovery UI reports the failure; no empty data is saved over the damaged collection. The previous-snapshot fallback remains available and retains a damaged original. There is no automatic purge of previous generations.

## Save and action safety

Legacy prose edits retain the existing 300 ms debounce and scene-phase flush. Discrete Grimoire actions use `commitSnapshot`, which validates the core and affected ledger records, then commits both in one SQLite transaction before publishing success. Request IDs are unique, original actions/revisions cannot be rewritten, and foreign keys prevent orphaned practice history. A failed transaction throws and rolls back both core and ledger. Existing unsaved prose remains in memory on a failure so the user can retry or export.

Ordinary launch reads the core and compact metadata rather than all action notes, occurrence snapshots and revision bodies. Chronicle uses bounded keyset pages; indexed summaries answer completion and quota questions. Portable export intentionally reconstructs the complete history. Recovery-copy discovery reads a compact manifest and file attributes at launch; choosing a restore revalidates the complete copy. An explicit recovery check can discover and validate older unindexed copies.

## Portable restore and merge

Exports contain all new definitions, occurrence snapshots, action/correction history, Invocation observations, specialty records, revisions, settings, links and referenced images. They contain sensitive personal writing and are not encrypted. The existing 512 MB encoded backup limit and photograph integrity checks still apply.

Replacement validates and stages a complete new generation, writes a pre-restore recovery backup, and switches `CURRENT` atomically. Schema 1 imports become schema 2 without fabricating new actions. Merge uses the same staged restore path after combining collections by stable ID: current records and settings win same-ID conflicts; only absent IDs are appended. Repeating a merge does not duplicate records. Inconsistent cross-links or same-name photos with different content cause a validation error rather than guessed reconciliation. The UI must show this merge policy and allow a deliberate replacement choice.

## Recovery instructions

Before an installation change, export a complete `.invoke` backup outside the app/container. Do not delete the LiveContainer data container to install an update. If the upgrade fails, keep the preserved container and use Settings recovery/import. The pre-2.0 recovery file can be exported; the original generation remains available for forensic recovery. Installing old code alone does not convert schema 2 back to schema 1. Restoring the pre-upgrade backup to the old version is the intended rollback path.

Do not manually delete generations or edit `CURRENT` while the app is running. Uninstalling an app/container can remove all its local files, including its internal recovery copies; an external export is therefore the portable recovery route.

## Evidence and boundaries

`GrimoireMigrationTests` covers a representative actual schema 1 graph, exact raw source retention, IDs and settings, idempotence, an interrupted/uncommitted stage, corrupt input, old portable imports, strict schema 2 decoding, photograph copying and a full version 2 relationship round trip. `GrimoireStoreTests` covers failed atomic actions, invalid imports, merge idempotence, and retained history. Native execution is recorded in the release acceptance log; test source alone is not execution evidence.

`SQLiteHistoryTests` additionally covers ordinary launch/Today without old history payload decoding, bounded pages, stable tied-date cursors, corrections outside the visible range, chunked aggregate queries, immutable records, schema rejection and JSON-to-SQLite conversion. `GrimoireStoreTests` injects a real SQLite page-cap failure to exercise rollback. These tests were included in [native run 40406587243](https://github.com/Mostlybonezz/Invoke/actions/runs/40406587243), source `0c7b701eb90f1d032e6693c638521fb591250174`: all 130 unit tests passed with zero failures using Xcode 27 on the iPhone 17 / iOS 27.0 (24A434) simulator. UI tests and release validation were still pending when this evidence was recorded.

The debug synthetic fixture with 1,000 practices and 3,000 actions/occurrences measured an in-process reopen at 39.225 ms, Today projection plus 1,000 status queries at 388.991 ms, and the first 50 Chronicle rows at 4.168 ms. These measurements do not represent a full cold launch or establish physical-device latency or FPS. Portable backups are reconstructed in memory rather than streamed; legacy and specialty collections remain in the core. This does not claim power-loss-proof device storage or end-to-end encryption. Locked-device, Files-provider and LiveContainer update behavior still require corresponding device checks.
