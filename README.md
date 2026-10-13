# Invoke

A private, native iPhone app for authoring a story, living its next believable scene, and keeping what the experience teaches. The source is public; your personal writing and photos stay on your iPhone.

## Download and LiveContainer

[GitHub build status](https://github.com/Mostlybonezz/Invoke/actions/workflows/ipa.yml) · [Releases](https://github.com/Mostlybonezz/Invoke/releases/latest) · [IPA download](https://github.com/Mostlybonezz/Invoke/releases/latest/download/Invoke.ipa)

The GitHub Actions workflow builds and tests on macOS before publishing a release. [Invoke 1.1.0](https://github.com/Mostlybonezz/Invoke/releases/tag/v1.1.0) is published with the IPA, source feed, icon, checksum, and build metadata. The IPA uses an ad-hoc signature for LiveContainer or another signing tool; it is not App Store or Apple-distribution signed. Downloading it in Safari alone does not install it on your Home Screen.

**LiveContainer source URL:** `https://github.com/Mostlybonezz/Invoke/releases/latest/download/source.json`

See [LiveContainer setup](docs/LIVECONTAINER.md) for adding the source or importing the downloaded IPA from Files. Invoke requires iOS 17 or later. Actual physical-iPhone compatibility and accessibility testing are still pending; CI results do not establish those.

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

## New in 1.1.0

- Tap Sanctuary’s constellation to zoom into a chapter map. Tap a labeled star to zoom into its scene script, intended action, cue, smaller version, and reflections. Use the chapter selector, page controls, or readable scene list to reach every scene.
- Astral Theatre is the new-install default; saved themes and version 1 writing/backups are preserved.
- Native Liquid Glass controls and system bars on iOS 26 and later, with solid alternatives for older systems and accessibility preferences.
- Settings → Appearance offers system, tinted, or solid surfaces, plus theme-matched/Ripples/Beam/Sparkle effects, intensity, speed, and a live replay preview.
- The release workflow requires Xcode 27.0, the iOS 27.0 device SDK, and an exact iOS 27.0 simulator. The iOS 17 minimum is retained; a minimum deployment version is not an upper OS limit.

[Release run 38349290401](https://github.com/Mostlybonezz/Invoke/actions/runs/38349290401) built version 1.1.0 with **Xcode 27.0 (27A266a)** and the **iOS 27.0 SDK**. All **26 tests passed with zero failures or skipped tests** on an iPhone 17 simulator running iOS 27.0: 24 unit tests and 2 UI flows covering constellation navigation, scene editing, the Astral default, and all three themes. Native screenshots were inspected for onboarding, Sanctuary, the expanded constellation, scene scripts, and theme selection. The arm64 IPA passed packaging and local signature checks. Physical iPhone/LiveContainer operation, animation performance, and the full accessibility matrix still require device testing.

## Implemented in source

- Four native tabs: Sanctuary, Stories, Grimoire, and Relic Cabinet.
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
| `Invoke/Design` | Semantic themes, typography, controls, vector ornaments and sigils |
| `Invoke/Stories` | Authoring, scenes, reflection, connections, constellations, keepsakes |
| `Invoke/Library` | Grimoire, relic workshop, photo display, PDF/share/print |
| `Invoke/Effects` | Native Metal source, finite rendering wrapper, prototype, MIT notice |
| `InvokeTests` | Persistence, migration, and story-flow tests |
| `InvokeUITests` | Native constellation navigation, scene editing, and theme checks |
| `ThirdParty` | Pinned original shader source, license, manifest |
| `DesignReferences` (local delivery only) | Original supplied visual references; omitted from the public repository and never used as app UI |
| `Tools` | Repeatable project generation, icon rendering, portable source checks |

## Deliberate first-version boundaries

Core use is offline. There are no accounts, cloud sync, analytics, social features, subscriptions, AI calls, or notification permission requests. Photos use the native photo picker; direct camera capture and reminders are not included. Custom modes are free text for the primary mode; secondary selections use the seven supplied modes.

The visual kit is intentionally replaceable. Native paper flecks, orbit linework, arches, placeholders, and geometric marks establish the three directions without extracting flattened UI from the supplied images. High-fidelity botanical engravings, velvet photography, hand-drawn curtains, and final brand artwork remain art-production work. No photograph of The Witness is fabricated as the user's real object.

Storage and backups use bounded, in-memory JSON rather than a database/streamed archive. Backups include image checksums and are capped at 512 MB; large image operations and writes can pause the UI. Device performance and low-storage behavior must be checked. See [Data reliability](docs/DATA-RELIABILITY.md) for interruption windows, recovery files, image sizing, and privacy limits.

## Maintenance

After adding source files, run `python3 Tools/generate_project.py` to regenerate the project. Run `python3 Tools/check_source.py` for portable package checks. Installing `tree-sitter` and `tree-sitter-swift` also enables the optional grammar check. `Tools/draw_icon.py` requires Pillow only when regenerating the original app icon; none of these Python packages are app dependencies.

See [Asset inventory](docs/ASSET-INVENTORY.md), [Shader mapping](docs/Shader-Mapping.md), and [Testing checklist](docs/TESTING.md) for completed checks and remaining device validation.
