# Invoke 2.0 implementation status

## Current release checkpoint — 26 October 2026

Invoke 2.0.1 is published at https://github.com/Mostlybonezz/Invoke/releases/tag/v2.0.1 and is the latest release for the LiveContainer source. It was built from `c1865cb7e520e11f073c7d02aed77a137191722a`. [Release run 40421558460](https://github.com/Mostlybonezz/Invoke/actions/runs/40421558460) passed all 139 authored tests (130 unit and 9 UI), with no failures or skips, using Xcode 27.0 and an iPhone 17 iOS 27.0 simulator. The IPA was built for arm64 with the iOS 27 SDK, retains `app.invoke.personal`, and its downloaded checksum matches the published checksum. The source feed advertises 2.0.1.

The editor and corrupt-storage recovery failures in the preview were fixed and pass in both focused and full runs. Progress records with equal timestamps now preserve insertion order across reopening and backup restoration. The simulator reported two runtime warnings: an invalid frame dimension and publishing changes during a view update. These warnings remain to be investigated; passing tests do not establish that they are harmless.

The owner reports that the v2.0.0 preview installed and opened on iOS 27 in LiveContainer 3.8.10 with existing data visible. The final 2.0.1 IPA has not yet been exercised on that physical phone. Detailed collection checks, file-provider and notification behavior, VoiceOver, performance and broader physical-host validation remain open. Export a backup outside the host and preserve the existing Invoke data container before updating.

## Earlier development checkpoint

Baseline: `718c5f35ff15ca33542de7b5e844f57bc95dce96`. Branch: `invoke-2.0-living-grimoire`.

Implemented: five main areas; complete 254-source Codex; all recurrence families; real sessions, partial scope, correction and undo; specialty/Bonds/Arcana/assets/Invocations; original collection access; settings/setup/recovery; local reminder planning; migration and portable merge/replace. SQLite core/history transactions and paged Chronicle have replaced eager action-history loading in the local working source.

In progress: SQLite regression tests and integration review, final native compilation, UI/layout verification, measured larger-fixture performance, and release packaging. Owner reported LiveContainer 3.8.10 on iOS 27. Runtime compatibility on that physical host remains untested.

Evidence: portable grammar/package checks and seven Python release-gate tests pass. Native runs 6–7 stopped before compilation because GitHub's web editor preserved CRLF in the shell script; the ZIP importer fixed raw line endings. Run 8 used Xcode/iOS SDK 27 and compiled far enough to find a backup-document/payload type error; fixed in development commit `b941f42b7a4c53e754d898065d0e89042b5a86e4`. Run 9 tests that pre-SQLite source. No successful 2.0 native test result, IPA, or release is claimed yet.

Next executable step: finish and package the coordinated SQLite source/tests, based on the latest public development SHA; use the reviewed hash manifest and preserve LF bytes in shell files. Run GitHub verification without publication, fix native failures, inspect retained simulator screenshots, then merge the tested source and publish a new v2.0.0 IPA only after the release gates pass. Update this file and ACCEPTANCE.md with observed results.
