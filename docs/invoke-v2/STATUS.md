# Invoke 2.0 implementation status

Baseline: `718c5f35ff15ca33542de7b5e844f57bc95dce96`. Branch: `invoke-2.0-living-grimoire`.

Implemented: five main areas; complete 254-source Codex; all recurrence families; real sessions, partial scope, correction and undo; specialty/Bonds/Arcana/assets/Invocations; original collection access; settings/setup/recovery; local reminder planning; migration and portable merge/replace. SQLite core/history transactions and paged Chronicle have replaced eager action-history loading in the local working source.

In progress: SQLite regression tests and integration review, final native compilation, UI/layout verification, measured larger-fixture performance, and release packaging. Owner reported LiveContainer 3.8.10 on iOS 27. Runtime compatibility on that physical host remains untested.

Evidence: portable grammar/package checks and seven Python release-gate tests pass. Native runs 6–7 stopped before compilation because GitHub's web editor preserved CRLF in the shell script; the ZIP importer fixed raw line endings. Run 8 used Xcode/iOS SDK 27 and compiled far enough to find a backup-document/payload type error; fixed in development commit `b941f42b7a4c53e754d898065d0e89042b5a86e4`. Run 9 tests that pre-SQLite source. No successful 2.0 native test result, IPA, or release is claimed yet.

Next executable step: finish and package the coordinated SQLite source/tests, based on the latest public development SHA; use the reviewed hash manifest and preserve LF bytes in shell files. Run GitHub verification without publication, fix native failures, inspect retained simulator screenshots, then merge the tested source and publish a new v2.0.0 IPA only after the release gates pass. Update this file and ACCEPTANCE.md with observed results.
