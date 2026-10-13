# Invoke verification and acceptance

## Version 1.1.0

[Release run 38349290401](https://github.com/Mostlybonezz/Invoke/actions/runs/38349290401), source commit `ce8428b88c063eccbb20da5812958ab2c4bb423d`, passed **26 tests: 24 unit tests and 2 UI tests, zero failures and zero skips**. The exact toolchain was **Xcode 27.0 (27A266a)** with the **iOS 27.0 SDK**; the simulator was **iPhone 17, iOS 27.0**. Swift and Metal compiled for both simulator and arm64 device Release builds. IPA packaging, strict local ad-hoc signature verification, and source-feed generation passed; [Invoke 1.1.0](https://github.com/Mostlybonezz/Invoke/releases/tag/v1.1.0) was published with five release assets.

Portable checks passed for 24 Swift files, project references, scheme XML, property lists, resource inclusion, and the opaque 1024 × 1024 icon. The workflow requires exact Xcode 27.0 and iOS 27.0 SDK/runtime evidence; it fails instead of silently using an older OS.

New tests cover version 1 preference decoding without losing writing, new appearance round trips, invalid preference rejection, the two-level constellation navigation and scene editing, and selecting all three themes. UI tests launch with an isolated temporary store. CI retained 11 screenshots. Visual inspection covered Astral onboarding, Sanctuary in all three themes, the expanded constellation, scene script, and theme selection; no blocking clipping or contrast issue was found. Screenshots do not verify animation timing or GPU performance. Shader/material controls below the captured Appearance viewport were not visually inspected.

The release assets were downloaded after publication and checked against the IPA SHA-256, compiled Info.plist, build metadata, and source feed. Physical iPhone and LiveContainer operation have not been tested.

## Historical 1.0.0 results

Initial source checks completed on Windows on October 12, 2026. Native CI then ran on macOS using **Xcode 16.4 (16F6)** and an **iOS 18.5 simulator**. [Run 38343056754](https://github.com/Mostlybonezz/Invoke/actions/runs/38343056754) confirms 21 tests passed with zero failures and successful Swift/Metal compilation for both simulator and arm64 iOS Release targets. No physical iPhone or LiveContainer session has been performed.

[Release run 38343919533](https://github.com/Mostlybonezz/Invoke/actions/runs/38343919533), at source commit `db9b62967b89737676cb18a33bc56716b44185e1`, also passed all 21 tests, simulator launch, IPA packaging/signature checks, and source-feed generation. All three workflow jobs succeeded and [Invoke 1.0.0](https://github.com/Mostlybonezz/Invoke/releases/tag/v1.0.0) was published with five release assets. The downloaded 750 × 1334 native screenshot was visually inspected and shows legible initial onboarding in Ink & Omen, with Invoke typography and ornament. The screen scrolls below the captured viewport; this inspection does not cover the complete app or interactive flows.

| Check | Actual result |
| --- | --- |
| Swift grammar parsing | PASS: 21 Swift files, tree-sitter 0.26.0 / tree-sitter-swift 0.7.4, zero syntax-tree errors |
| Project source inclusion, unique/resolved object IDs | PASS via `Tools/check_source.py` |
| XML scheme, Info.plist, privacy manifest, asset metadata | PASS: parsed successfully |
| App icon | PASS: opaque RGB PNG, 1024 × 1024; visually inspected |
| Source/license snapshot integrity | PASS: 11/11 upstream SHA-256 hashes verified |
| Source review | Completed across data, views, and effects; concrete findings corrected |
| Swift type checking / linking | PASS: simulator and arm64 iOS Release builds, Xcode 16.4 |
| Metal compilation | PASS: simulator and arm64 iOS Release builds |
| XCTest | PASS: 21 tests, zero failures; 14 AppStoreTests and 7 StoryFlowTests on iOS 18.5 Simulator |
| Automated simulator launch / screenshot capture | PASS: run 38343919533; one 750 × 1334 initial onboarding screenshot visually inspected |
| IPA packaging / signature / feed | PASS: arm64 IPA, local ad-hoc signature checks, generated source metadata, uploaded artifacts |
| Release publication | PASS: Invoke 1.0.0 published with IPA, source feed, icon, checksum, and build metadata |
| Physical iPhone / LiveContainer / full UI comparison | NOT RUN |
| Shader rendering / interactions | NOT MANUALLY VERIFIED |
| VoiceOver / Dynamic Type / Reduce Motion / contrast | Native support implemented; NOT RUN |
| Performance / scrolling / GPU / battery | NOT MEASURED |

Native compilation and automated tests now supplement the earlier grammar/source checks. They do not establish visual correctness, all user flows, hardware behavior, or LiveContainer compatibility.

## Remaining native checks

Open the shared Invoke scheme with Xcode 27 or later. Build on an iPhone simulator, then actual supported hardware. The Metal file is already in Compile Sources and the MIT notice is already a bundle resource. Start with Settings → Appearance → Try button & card effects. Exercise all three themes and Subtle / Full / Off. Verify the native button fires immediately, the card renders, shader arguments bind correctly, and static alternatives look intentional. Resolve any build/rendering issue before treating the wider effect system as validated.

Run Product → Test. `AppStoreTests.swift` covers defaults, saved/reopened data, debounce, photos, image round trips, restore integrity, invalid imports, schema rejection, corrupt snapshot recovery, archives/deletion, and examples. `StoryFlowTests.swift` covers the actual store helpers used by the story UI. The test target uses isolated temporary directories and synthetic photos.

## Manual acceptance matrix

Every row below is **pending manual validation**. Automated store tests and simulator launch do not complete this matrix. Repeat the main screens, editor flows, search, sheets, settings, and keepsakes in Ink & Omen, Velvet Observatory, and Astral Theatre.

| Flow | Procedure and expected result |
| --- | --- |
| First launch | Delete simulator app, use system Dark Mode, launch. Astral Theatre and Subtle must appear. Choose a new story or explicitly explore labeled examples. |
| Theme persistence | Switch each appearance, relaunch, verify choice retained. Keep unfinished writing and a navigation stack in another tab while switching; return to identical content and position. |
| Authoring | Enter short answers; leave at each of six steps; kill/reopen after Saved; resume. Add/connect manifestation, select all shapes, custom primary mode, max two secondary modes. Free prose remains intact until replacement accepted. |
| Scene loop | Create scene with cue/effort/smaller version; connect belief, ritual, relic; enter; record attempt with an unexpected outcome. Scene becomes Experienced, reflection persists, constellation/list updates. |
| Existing scene revision | Change the guided next-scene answer when a planned scene exists. Choose the scene; confirm action/cue/smaller version update. |
| Cross-tab closure | Leave scene-entry open in Sanctuary; close its chapter from Stories; return. Old scene actions must be unavailable, with a keepsake link. |
| Shared library | Connect one entry to multiple stories; edit once; all links show same data. Archive retains links. Confirm permanent deletion clears links without crashes. |
| Beliefs | Intentionally revise existing wording; earlier wording/fields remain in history. Select Held, Exploring, Rewriting, Released directly. |
| Rituals | Edit reusable steps; record two performances separately; notes/date/reflection persist independently of template. |
| Photos | Import portrait/landscape/HEIC images and large source; check orientation, grid, cover choice, reopen, import failure. No permission request before feature use. |
| Relics | Exercise all lifecycle stages and checklist; record dedication; verify memory entry, finite effect, and native success text. Export/print short and multi-page long cards in all themes. |
| Plot twist | Save free text only; applying must not erase skipped answers. Fill prompts, apply; prior prose/answers retained, next scene added. Review obsolete scenes manually. |
| Chapter closing | Enter reflection/title and choose keepsake scenes/relics; leave/reopen; confirm choices retained. Close; old scene/reflections lock, keepsake opens, new chapter continues. |
| Search/capture | Search all relevant lists, open empty results, revisit unlinked quick captures. All writing remains editable and autosaved. |
| Examples | Add examples twice without duplication. Remove with confirmation; personal descendants are preserved according to dependency rules in Data Reliability. |
| Backup round trip | Export full `.invoke` including photos, change records/theme, import original, review counts, export current first, confirm replace. Confirm photos, relationships and theme restore. Save the automatic recovery copy. |
| Invalid backups | Try wrong schema, bad JSON, missing photo, wrong hash, path traversal filename, duplicate IDs and broken parent links. Existing memory/files must remain unchanged. |
| Interruptions/errors | Background during typing/photo import; reopen; test locked storage and low-disk conditions. Unsaved errors must remain visible; retry/export must preserve current writing. |
| Offline | Airplane Mode: author, edit, reflect, photos already on device, search, keep/restore local backup. No external service dependency. Files/photos stored only in a cloud provider may require that provider to download first. |
| Constellation | Open Sanctuary preview, verify native zoom into map and into a labeled star’s scene script; back navigation reverses each transition. Test all chapters, more than six scenes, readable list, edited scripts, and closed chapters. Reduce Motion uses standard navigation. |
| Liquid Glass | Verify system/tinted/solid controls, legible writing, native tab/navigation bars, Reduce Transparency and Increase Contrast; inspect both light Ink and dark Astral/Velvet. |
| Effects | Check touch origins, finite record/relic/chapter effects, rapid taps, scrolling offscreen, changing tabs/theme, backgrounding, Low Power Mode and Off. No idle recurring rendering. |

## Accessibility and hardware

Test at 320pt logical width (iPhone SE), a regular iPhone, and a large iPhone, in portrait with keyboard open/closed. Use the largest accessibility Dynamic Type sizes, Bold Text, Increase Contrast, Reduce Motion, and VoiceOver. Confirm reading order, labeled 44pt touch targets, form-field names, selected theme announcements, accessible constellation list, clipped decoration, and unobscured bottom controls. Inspect multiline titles, long custom modes, long PDF meaning/dedication, and no-photo/error states.

On the oldest supported hardware available, ideally iPhone XS or XR with iOS 17, use Instruments for CPU/GPU frame times, memory after photo imports and restores, scrolling, and energy. Low Power currently disables animated effects. Measure both Subtle and Full; no FPS, battery, or memory claims have been established. Keep exports well below the 512 MB format limit on low-memory devices; see the documented in-memory implementation boundary.

Record exact Xcode version, iOS version, device model, accessibility settings, result, and any repair for each run. Do not mark this checklist complete based on source inspection.
