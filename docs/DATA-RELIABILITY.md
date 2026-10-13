# Invoke data reliability

Minimum target: iOS 17. Core data uses Foundation Codable rather than an account, server, or external AI service. Photos use ImageIO and native file handling. The app does not make network requests.

## Local layout and saving

The app stores its collection in Application Support/Invoke. A small `CURRENT` file identifies a UUID-named generation. That generation contains `data.json`, `previous.json`, and `images/`. The structured snapshot and backup each declare a version. Version 1 is the first released schema; unknown schema or format versions are rejected rather than guessed. There is no migration from an earlier public release.

`AppStore` is a main-actor ObservableObject. Nested edits to its published `AppData` trigger a 300 ms coalesced save; the app also calls `flush()` on scene-phase changes. Each save validates references, updates modification timestamps, retains the previous complete snapshot, and atomically writes the new snapshot. Protection is Complete Until First User Authentication. The UI reports saving, saved, and failure states. A failed write leaves the draft in memory for retry or export. A forced termination within the 300 ms debounce can lose the last uncommitted keystrokes; operating-system termination and device failure cannot be prevented by this app.

On opening, Invoke validates the snapshot. A damaged latest snapshot can recover the previous complete version; the damaged file is retained and the user receives a message. If neither version opens, Invoke preserves all files and blocks autosaving over them. The user can restore a known backup. Do not treat an empty recovery UI as evidence that the preserved disk files are empty.

## Relationships and deletion

Records use UUIDs and shared entries remain single records. Archiving retains relationships. Permanent entry/relic deletion removes their connections; ritual deletion also removes that ritual's performance logs. Story deletion removes its chapters, scenes, and related reflections while preserving shared library entries and relics. Scene deletion preserves its reflections and clears their scene link. Call the store deletion helpers after the UI confirmation; do not directly remove records that other records reference.

Examples are opt-in and marked individually. Removal keeps personal records. If a personal record depends on an example, the required example and its dependencies become personal records, preventing accidental deletion of the user's writing. Example photographs are intentionally absent; museum-style placeholders do not pretend to be the user's real objects.

## Images

Image import accepts supported photo formats up to 40 MB and 100 megapixels. ImageIO downsamples to a maximum 2,048-pixel side and applies orientation before JPEG encoding at quality 0.86. Re-encoding omits source EXIF/GPS metadata. Images have UUID filenames and stay in the active generation. A backup contains only referenced photos and story covers. Files no longer referenced are removed after a successful save once neither the current nor previous snapshot needs them. Imports awaiting attachment stay protected for the process lifetime.

## Portable backup and restore

An `.invoke` backup is UTF-8 JSON containing the full structured collection, every referenced JPEG as base64, an export time, and a SHA-256 checksum for each image. It is a portable user-owned format, not encrypted. Treat exported backups as personal files. The 512 MB encoded import/export cap keeps this first version's in-memory file handling bounded; image decoding and encoding are synchronous, so large collections can pause the UI. A streamed archive format is a future improvement, not a claim of this version.

Validation checks the format and schema, settings, unique IDs, required parent relationships, existing links, safe image filenames, an exact image manifest, image checksums, dimensions, and successful image decoding. Missing or invalid imports do not modify the current state. SHA-256 detects damaged images; it does not authenticate the source of a backup. The UI must validate first, describe replacement, offer a current export, and obtain explicit confirmation before calling `restore`.

Restoration revalidates, writes all incoming data and images into a new generation, writes an automatic pre-restore backup of current in-memory content in `recovery/`, then atomically replaces `CURRENT`. If validation or a staged write fails, the old generation remains active. Previous generations are retained as a recovery safety net and are not automatically purged. `lastRecoveryBackupURL` allows sharing the automatic backup after restore. If local storage was already damaged, the old generation is retained even though it cannot be serialized as a verified portable backup. The user-requested export before restore is the best portable recovery copy.

On-device files may participate in the user's operating-system device backup according to their iOS settings. Invoke itself implements no cloud sync. Uninstalling the app removes its local sandbox; exported backups must be kept outside it.

## Verification status

`InvokeTests/AppStoreTests.swift` contains XCTest coverage for defaults, restart persistence, debounced nested edits, image sizing and complete portable round trips, automatic recovery backups, invalid/tampered imports leaving memory and disk unchanged, future schemas and traversal names, archive/deletion relationship behavior, example removal with personal descendants, latest-snapshot recovery, and sample graph integrity.

`InvokeTests/StoryFlowTests.swift` adds integration coverage for the actual story-screen helpers: first story/chapter/scene relationships surviving reopening, rejection of scenes in closed chapters, reflections remaining with a scene's original chapter, separate resumable chapter drafts, template proposals preserving authored prose, shared archived connections, and stale editor bindings after permanent deletion. The prose test exercises proposal generation; it does not claim to automate the UI confirmation sheet.

These tests were authored but **not executed** in the Windows development environment. Run the XCTest target with Xcode on macOS. Device verification remains required for file-provider import/export, protected storage during lock/unlock, suspension/termination timing, low-storage failures, and large photo collections.
