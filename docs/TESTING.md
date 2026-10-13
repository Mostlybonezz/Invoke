# Invoke verification and acceptance

## Results from this delivery

Environment: Windows, no Swift compiler, Xcode, Apple SDK, Simulator, or connected iPhone. Source checks completed October 12, 2026. **There are no native build/device results.**

| Check | Actual result |
| --- | --- |
| Swift grammar parsing | PASS: 21 Swift files, tree-sitter 0.26.0 / tree-sitter-swift 0.7.4, zero syntax-tree errors |
| Project source inclusion, unique/resolved object IDs | PASS via `Tools/check_source.py` |
| XML scheme, Info.plist, privacy manifest, asset metadata | PASS: parsed successfully |
| App icon | PASS: opaque RGB PNG, 1024 × 1024; visually inspected |
| Source/license snapshot integrity | PASS: 11/11 upstream SHA-256 hashes verified |
| Source review | Completed across data, views, and effects; concrete findings corrected |
| Swift type checking / linking | NOT RUN |
| Metal compilation / shader rendering | NOT RUN |
| XCTest | 21 methods authored; NOT RUN |
| Simulator / device / screenshot comparison | NOT RUN |
| VoiceOver / Dynamic Type / Reduce Motion / contrast | Native support implemented; NOT RUN |
| Performance / scrolling / GPU / battery | NOT MEASURED |

Grammar parsing cannot catch incorrect Apple API signatures, Swift type-inference failures, missing Metal linkage, runtime issues, or layout problems. Source checking is not a successful build.

## First Mac check: feasibility gate

Open the shared Invoke scheme with Xcode 16 or later. Build on an iPhone simulator, then actual supported hardware. The Metal file is already in Compile Sources and the MIT notice is already a bundle resource. Start with Settings → Appearance → Try button & card effects. Exercise all three themes and Subtle / Full / Off. Verify the native button fires immediately, the card renders, shader arguments bind correctly, and static alternatives look intentional. Resolve any build/rendering issue before treating the wider effect system as validated.

Run Product → Test. `AppStoreTests.swift` covers defaults, saved/reopened data, debounce, photos, image round trips, restore integrity, invalid imports, schema rejection, corrupt snapshot recovery, archives/deletion, and examples. `StoryFlowTests.swift` covers the actual store helpers used by the story UI. The test target uses isolated temporary directories and synthetic photos.

## Manual acceptance matrix

Every row below is **pending native execution**. Repeat the main screens, editor flows, search, sheets, settings, and keepsakes in Ink & Omen, Velvet Observatory, and Astral Theatre.

| Flow | Procedure and expected result |
| --- | --- |
| First launch | Delete simulator app, use system Dark Mode, launch. Ink & Omen and Subtle must appear. Choose a new story or explicitly explore labeled examples. |
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
| Effects | Check touch origins, finite record/relic/chapter effects, rapid taps, scrolling offscreen, changing tabs/theme, backgrounding, Low Power Mode and Off. No idle recurring rendering. |

## Accessibility and hardware

Test at 320pt logical width (iPhone SE), a regular iPhone, and a large iPhone, in portrait with keyboard open/closed. Use the largest accessibility Dynamic Type sizes, Bold Text, Increase Contrast, Reduce Motion, and VoiceOver. Confirm reading order, labeled 44pt touch targets, form-field names, selected theme announcements, accessible constellation list, clipped decoration, and unobscured bottom controls. Inspect multiline titles, long custom modes, long PDF meaning/dedication, and no-photo/error states.

On the oldest supported hardware available, ideally iPhone XS or XR with iOS 17, use Instruments for CPU/GPU frame times, memory after photo imports and restores, scrolling, and energy. Low Power currently disables animated effects. Measure both Subtle and Full; no FPS, battery, or memory claims have been established. Keep exports well below the 512 MB format limit on low-memory devices; see the documented in-memory implementation boundary.

Record exact Xcode version, iOS version, device model, accessibility settings, result, and any repair for each run. Do not mark this checklist complete based on source inspection.
