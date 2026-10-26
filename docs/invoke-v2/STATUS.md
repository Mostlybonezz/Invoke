# Invoke 2.0 implementation status

## Current release checkpoint — 26 October 2026

Invoke 2.0 Preview is published at https://github.com/Mostlybonezz/Invoke/releases/tag/v2.0.0 and is the latest release for the existing LiveContainer source. It was built from `0c7b701eb90f1d032e6693c638521fb591250174` with Xcode 27 and the iOS 27 SDK. Native run https://github.com/Mostlybonezz/Invoke/actions/runs/40406587243 passed 130 unit tests and seven UI tests; two UI tests failed (saved-method editing and corrupt-storage backup review). The generated source contains the real IPA version and preserves `app.invoke.personal`.

The follow-up source at `97b8b6965246c8b7334cf9a30e8beb7258ae36d9` gives editable fields unique identifiers, presents the recovery review from a validated backup item, and includes date/history presentation refinements. It is being verified in https://github.com/Mostlybonezz/Invoke/actions/runs/40416355839 for a possible v2.0.1 release. Do not claim the follow-up passed until that run has completed successfully.

The owner reports that the v2.0.0 preview installed and opened in their iOS 27 / LiveContainer 3.8.10 environment and that their existing data appeared. Exact device model and detailed record counts were not supplied; file-provider, reminder, recovery and broader host checks remain unverified. Full manual accessibility, screen-layout, visual and device-performance review also remains open. Export a backup outside the host and preserve the existing Invoke data container before updating.

## Earlier development checkpoint

Baseline: `718c5f35ff15ca33542de7b5e844f57bc95dce96`. Branch: `invoke-2.0-living-grimoire`.

Implemented: five main areas; complete 254-source Codex; all recurrence families; real sessions, partial scope, correction and undo; specialty/Bonds/Arcana/assets/Invocations; original collection access; settings/setup/recovery; local reminder planning; migration and portable merge/replace. SQLite core/history transactions and paged Chronicle have replaced eager action-history loading in the local working source.

In progress: SQLite regression tests and integration review, final native compilation, UI/layout verification, measured larger-fixture performance, and release packaging. Owner reported LiveContainer 3.8.10 on iOS 27. Runtime compatibility on that physical host remains untested.

Evidence: portable grammar/package checks and seven Python release-gate tests pass. Native runs 6–7 stopped before compilation because GitHub's web editor preserved CRLF in the shell script; the ZIP importer fixed raw line endings. Run 8 used Xcode/iOS SDK 27 and compiled far enough to find a backup-document/payload type error; fixed in development commit `b941f42b7a4c53e754d898065d0e89042b5a86e4`. Run 9 tests that pre-SQLite source. No successful 2.0 native test result, IPA, or release is claimed yet.

Next executable step: finish and package the coordinated SQLite source/tests, based on the latest public development SHA; use the reviewed hash manifest and preserve LF bytes in shell files. Run GitHub verification without publication, fix native failures, inspect retained simulator screenshots, then merge the tested source and publish a new v2.0.0 IPA only after the release gates pass. Update this file and ACCEPTANCE.md with observed results.
