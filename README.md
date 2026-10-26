# Invoke

A private, native iPhone app for chosen practices, intentions, stories and the changes you actually observe. **Invoke 2.0 — The Living Grimoire** brings the complete Life Maintenance Codex into Today, Quests, Grimoire, Invocations and Chronicle while retaining the original stories, constellation, beliefs, rituals and relics. The source is public; personal writing and photos belong to your local collection.

[2.0 user guide](docs/invoke-v2/USER_GUIDE.md) · [Acceptance evidence](docs/invoke-v2/ACCEPTANCE.md) · [Upgrade and recovery](docs/invoke-v2/MIGRATION.md)

## Download and LiveContainer

[GitHub build status](https://github.com/Mostlybonezz/Invoke/actions/workflows/ipa.yml) · [Releases](https://github.com/Mostlybonezz/Invoke/releases/latest) · [IPA download](https://github.com/Mostlybonezz/Invoke/releases/latest/download/Invoke.ipa)

The GitHub Actions workflow builds and tests on macOS before publishing a release with its IPA, source feed, icon, checksum and build metadata. Check the release version and its verification record before installing. The IPA uses an ad-hoc signature for LiveContainer or another signing tool; it is not App Store or Apple-distribution signed. Downloading it in Safari alone does not install it on your Home Screen.

**LiveContainer source URL:** `https://github.com/Mostlybonezz/Invoke/releases/latest/download/source.json`

See [LiveContainer setup](docs/LIVECONTAINER.md) for adding the source/importing an IPA and the [2.0 upgrade guide](docs/invoke-v2/USER_GUIDE.md#update-through-livecontainer-without-losing-your-collection) for preserving the existing data container. Export a complete backup outside the host before updating. The intended environment is iOS 27 with LiveContainer 3.8.10; the exact physical-device/host checks are recorded separately in [LiveContainer verification](docs/invoke-v2/LIVECONTAINER.md). Invoke requires iOS 17 or later. Native CI does not by itself prove physical-device compatibility or accessibility.

## New in 2.0

- Five connected areas: Today foregrounds chosen actions and consequential deadlines; Quests provides calendar/filter views; Grimoire holds inactive templates and owned practices; Invocations connect direction, actions and observations; Chronicle preserves the history and corrections.
- Complete Codex coverage: **254 original source entries**, normalized into **252 canonical templates/references**, with eight reference-only records. Search plain/fantasy names and full original wording. Activation is explicit and personal copies survive library updates.
- Daily/weekday, weekly/quota, monthly, quarterly, semiannual, annual, actual-completion interval, event and condition schedules. Importance remains separate from frequency; unknown dates stay unknown.
- Durable sessions, steps, partial/smaller versions, explicit skip, deferral, snooze, pause/archive and audited undo. Recorded actions and observed outcomes are distinct.
- Saved methods, Enchantments, asset/supply inspections, optional replacement reserves, Bonds planning, Arcana/belief records and comparative Echoes.
- Additive schema-2 storage keeps every original collection and photograph. Upgrade checkpoints, portable export, previewed merge/replace and recovery preserve a path back to the original data.
- Optional local reminders with private previews, quiet hours and a bounded queue. The app remains usable without notification permission.

The current [acceptance matrix](docs/invoke-v2/ACCEPTANCE.md) maps all 34 brief scenarios to source, tests and actual verification. At its documentation checkpoint, portable checks passed; final native 2.0 CI, screenshot inspection and device results were still pending. Historical results below refer to their named versions only.

## Open and run

1. On a Mac, open **Invoke.xcodeproj** in **Xcode 27 or later**. No package manager or third-party runtime dependency is needed.
2. Select the **Invoke** scheme and an iPhone simulator running iOS 17 or later. Build and Run.
3. For a physical iPhone, select your development team in Signing & Capabilities and replace `app.invoke.personal` with an available bundle identifier. No signing identity is included.
4. Open Settings → Appearance → **Try button & card effects** first to validate the native shader prototype. See [Shader mapping](docs/Shader-Mapping.md).
5. Run Product → Test for the included XCTest target. Complete the device checks in [Testing](docs/TESTING.md) before relying on the app for irreplaceable writing.

The deployment target is **iOS 17.0**, portrait iPhone. Astral Theatre and Subtle effects are explicit first-launch defaults. Existing installations retain their saved theme. The indigo and orange icon matches Astral Theatre. Xcode previews in `Invoke/App/InvokePreviews.swift` cover all three themes and larger text; they have not been rendered here.

Example command on a Mac, substituting an installed simulator's identifier:

```sh
xcodebuild -project Invoke.xcodeproj -scheme Invoke \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UDID' \
  -derivedDataPath build/DerivedData test
```

## Retained from 1.1.0

- Tap Sanctuary’s constellation to zoom into a chapter map. Tap a labeled star to zoom into its scene script, intended action, cue, smaller version, and reflections. Use the chapter selector, page controls, or readable scene list to reach every scene.
- Astral Theatre is the new-install default; saved themes and version 1 writing/backups are preserved.
- Native Liquid Glass controls and system bars on iOS 26 and later, with solid alternatives for older systems and accessibility preferences.
- Settings → Appearance offers system, tinted, or solid surfaces, plus theme-matched/Ripples/Beam/Sparkle effects, intensity, speed, and a live replay preview.
- The release workflow requires Xcode 27.0, the iOS 27.0 device SDK, and an exact iOS 27.0 simulator. The iOS 17 minimum is retained; a minimum deployment version is not an upper OS limit.

[Release run 38349290401](https://github.com/Mostlybonezz/Invoke/actions/runs/38349290401) built version 1.1.0 with **Xcode 27.0 (27A266a)** and the **iOS 27.0 SDK**. All **26 tests passed with zero failures or skipped tests** on an iPhone 17 simulator running iOS 27.0: 24 unit tests and 2 UI flows covering constellation navigation, scene editing, the Astral default, and all three themes. Native screenshots were inspected for onboarding, Sanctuary, the expanded constellation, scene scripts, and theme selection. The arm64 IPA passed packaging and local signature checks. Physical iPhone/LiveContainer operation, animation performance, and the full accessibility matrix still require device testing.

## Implemented in source

- Five native tabs: Today, Quests, Grimoire, Invocations and Chronicle. Original Sanctuary, Stories, Grimoire and Relic Cabinet remain reachable through the new navigation.
- Three immediately switchable semantic themes, persisted appearance and effects settings, themed sheets and writing surfaces, original vector sigils, and an indigo/orange celestial app icon.
- Six-step resumable story authoring, free prose, template preview with explicit acceptance, nine shapes, seven initial modes, custom primary modes, and up to two secondary modes.
- Independent manifestations, beliefs, and rituals; searchable lists; shared connections; belief wording history; reusable ritual templates and separate performance logs.
- Planned scenes, situational cues, smaller alternatives, focused rehearsal/entry, reflections that distinguish attempts from outcomes, and interactive constellations with accessible lists.
- Plot twists, role reflections, retained prior prose/answers, chapter closing, selected keepsake scenes/relics, and a continuing story. Closed chapter scenes and reflections are read-only in the UI.
- A physical relic workshop with lifecycle, editable making checklist, multiple imported photos, dedication, memories, and themed PDF cards shared or printed through native interfaces.
- Optional labeled examples, archives, confirmation before permanent deletion, and shared-link cleanup.
- Local versioned autosaving, protected image storage, previous-snapshot recovery, validated complete portable backups, explicit restore confirmation, and recovery copies.
- Metal adaptations of the required repository's Ripples, Beam, and Sparkle kernels. Native controls and text remain separate from the decoration. Off, Reduce Motion, Low Power Mode, and inactivity use static alternatives.

## Historical 1.0.0 verification

Initial source preparation and checks ran on Windows. [GitHub Actions run 38343056754](https://github.com/Mostlybonezz/Invoke/actions/runs/38343056754) subsequently compiled the Swift and Metal sources for the simulator and arm64 iOS Release target using **Xcode 16.4 (16F6)**. On the **iOS 18.5 simulator, all 21 XCTest cases passed with zero failures**: 14 persistence/library tests and 7 story-flow tests.

[Release run 38343919533](https://github.com/Mostlybonezz/Invoke/actions/runs/38343919533) also passed all 21 tests, the automated simulator launch, IPA packaging/signature checks, and source-feed generation, then published [Invoke 1.0.0](https://github.com/Mostlybonezz/Invoke/releases/tag/v1.0.0). One native onboarding screenshot was visually inspected: the Ink & Omen appearance, Invoke typography, ornament, and visible text rendered correctly. This covers the initial screen only. Physical iPhone and LiveContainer operation, complete UI flows, accessibility, shader behavior, and performance remain unverified.

Performed checks:

- Parsed all **21 Swift files** with tree-sitter-swift 0.7.4: no grammar errors. This does not establish Swift type correctness or Apple API compatibility.
- Checked Xcode object references, source and resource inclusion, shared scheme XML, property lists, asset metadata, and the opaque 1024 × 1024 app icon.
- Independently reviewed data validation, theme literals, scene/chapter boundaries, draft resumption, and framework API usage; corrected the concrete defects found.
- Verified all **11 upstream source/license snapshot hashes** against the pinned shader checkout.
- Executed **21 XCTest cases** covering persistence, image/backup handling, tampering, relationship cleanup, examples, and story-flow integration in native CI; all passed.

Metal compilation passed. The shader rendering and interaction checks remain open; compilation and an automated launch do not establish visual correctness or GPU performance.

## Source organization

| Location | Purpose |
| --- | --- |
| `Invoke/App` | Entry point, tabs, Sanctuary, onboarding, settings, backups, previews |
| `Invoke/Core` | Codable records, validated persistence, images, backups, examples |
| `Invoke/Grimoire` | Living Grimoire models, scheduling, actions, reminders, Codex and new feature screens |
| `Invoke/Resources/Codex.json` | Versioned inactive library with all original source mappings |
| `Invoke/Design` | Semantic themes, typography, controls, vector ornaments and sigils |
| `Invoke/Stories` | Authoring, scenes, reflection, connections, constellations, keepsakes |
| `Invoke/Library` | Grimoire, relic workshop, photo display, PDF/share/print |
| `Invoke/Effects` | Native Metal source, finite rendering wrapper, prototype, MIT notice |
| `InvokeTests` | Persistence, migration, recurrence, action/undo, reminders, Codex, Chronicle and story-flow tests |
| `InvokeUITests` | Native core/relaunch, recovery, layout, constellation, scene and theme checks |
| `ThirdParty` | Pinned original shader source, license, manifest |
| `DesignReferences` (local delivery only) | Original supplied visual references; omitted from the public repository and never used as app UI |
| `Tools` | Repeatable project generation, icon rendering, portable source checks |
| `docs/invoke-v2` | Audit, product/calendar decisions, complete content mapping, migration, user guide and acceptance record |

## Runtime and verification boundaries

Core use is offline. There are no accounts, cloud sync, analytics, subscriptions, runtime AI calls, contact scraping or remote push dependency. Photos use the native photo picker; direct camera capture is not included. Local notifications are optional and permission/host dependent; Invoke schedules a bounded future horizon and refreshes it when used. Custom story modes are free text for the primary mode; secondary selections use the seven supplied modes.

The visual kit is intentionally replaceable. Native paper flecks, orbit linework, arches, placeholders, and geometric marks establish the three directions without extracting flattened UI from the supplied images. High-fidelity botanical engravings, velvet photography, hand-drawn curtains, and final brand artwork remain art-production work. No photograph of The Witness is fabricated as the user's real object.

Runtime storage uses SQLite transactions for the core snapshot and indexed action/occurrence/revision history. Chronicle requests bounded history pages; ordinary startup does not decode the full new action ledger. Original collections and specialty records still load with the core. Portable backups remain complete JSON archives with image checksums and a 512 MB cap; explicit exports, imports and large image operations can pause the UI. Native performance and low-storage behavior still need measured verification. See [Migration and recovery](docs/invoke-v2/MIGRATION.md) and [Data and scheduling](docs/invoke-v2/DATA_AND_SCHEDULING.md).

## Maintenance

After adding source files, run `python3 Tools/generate_project.py` to regenerate the project. Run `python3 Tools/check_source.py` for portable package checks and `python3 Tools/build_codex.py --check` for full content coverage. Installing `tree-sitter` and `tree-sitter-swift` also enables the optional grammar check. `Tools/draw_icon.py` requires Pillow only when regenerating the original app icon; none of these Python packages are app dependencies.

See [Asset inventory](docs/ASSET-INVENTORY.md), [Shader mapping](docs/Shader-Mapping.md), and [Testing checklist](docs/TESTING.md) for completed checks and remaining device validation.
