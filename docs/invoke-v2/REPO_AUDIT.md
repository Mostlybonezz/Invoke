# Invoke 2.0 repository baseline

Inspected 2026-10-26. Repository: https://github.com/Mostlybonezz/Invoke.
Baseline `main`: `718c5f35ff15ca33542de7b5e844f57bc95dce96`; clean fresh clone.
Development branch: `invoke-2.0-living-grimoire`. No repository AGENTS.md was found.
The user explicitly authorized implementation and publication of the 2.0 IPA.

## Observed architecture

- Native SwiftUI iPhone app, portrait, iOS 17 minimum; Swift 5 language mode. No package-manager dependencies or runtime AI/network/account service.
- Entry: `Invoke/App/InvokeApp.swift`. Existing tabs: Sanctuary, Stories, Grimoire, Relic Cabinet. All remain accessible in 2.0.
- Models: `Invoke/Core/Models.swift`, schema 1, seven record arrays and appearance preferences. Story/chapter/scene relationships use UUIDs. There is no existing recurrence engine.
- Persistence: main-actor `AppStore` in `Invoke/Core/AppStore.swift`; Application Support/Invoke; `CURRENT` points to UUID-named generation with data.json, previous.json and images. Debounced saves, atomic writes, retained recovery data. No sync or multi-user boundaries.
- Portability: `Invoke/Core/Backup.swift`; versioned JSON `.invoke` package including hashed/downsampled images, 512 MB limit, strict identifiers and relationships. Existing restore stages a generation, backs up the old state and switches the pointer.
- Existing journeys include guided/free story authoring, scene rehearsal/reflection, two-level constellation navigation, manifestations/beliefs/rituals with history, relic photos/workshop/PDF sharing, examples/archive, theme/effects settings and complete backups.
- Visual tokens: `Invoke/Design/DesignSystem.swift`; Astral indigo #101422 / surface #202237 / peach #F7E5DE / orange #B63D24; Ink light paper and Velvet dark plum alternatives. Serif headings, system body text, 20pt margins, 16pt cards, minimum 44pt controls. `Invoke/Effects` contains finite Metal effects and accessibility alternatives. Native Liquid Glass gates at iOS 26. Existing zoom gates at iOS 18. App icon is indigo/orange celestial geometry.
- Build generation: `Tools/generate_project.py`; source/package check: `Tools/check_source.py`; native tests `Tools/test_ios.sh`; device archive `Tools/build_ipa.sh`; feed `Tools/generate_feed.py`; `.github/workflows/ipa.yml` builds on official xcode-27 runner, exact Xcode/iOS SDK/runtime 27.0. No signing identity/provisioning profile is stored; IPA has local ad-hoc signing for a compatible host/signing tool.

## Baseline evidence and limits

Portable package and optional Swift grammar checks passed: 24 Swift files, one Metal source, 26 authored tests. Windows has no Xcode or iOS runtime. The existing 1.1.0 release evidence records 26 passing tests on iOS 27; this is historical evidence, not a new 2.0 test result. Retained 1.1.0 simulator screenshots provide the baseline visual reference. New native checks and screenshots must be produced by GitHub CI. Physical iPhone/LiveContainer operation cannot be inferred from simulator results.

## Preservation matrix

| Existing data/feature | Verified source | 2.0 destination | Strategy | Regression evidence required |
|---|---|---|---|---|
| Stories, chapters, prose, drafts, plot twists | Core/Models; Stories/StoryAuthorView, StoryViews, ReflectionViews | Invocations → Stories; Today → Sanctuary | Keep original UUIDs, arrays and dates; no invented goal completion | Legacy story-flow suite; migration fixture equality |
| Scenes, reflections, constellation | Stories/SceneViews, ConstellationExplorer | Original story/constellation flows | Retain original action/history semantics; new practice activation explicit | Existing constellation UI flow and scene editing |
| Beliefs, manifestations, rituals, logs | Library/LibraryViews; Core/Models | Grimoire → Original collection | Preserve fields/status/revisions; do not reinterpret old logs as scheduled completions | Existing library tests; migration fixture |
| Relics, checklist, photos, PDF | Library/RelicViews, Sharing | Grimoire → Relic Cabinet | Retain UUIDs/image names and relationships | Backup image round trip, existing tests |
| Preferences and shaders | App/SettingsView; Design; Effects | Settings → Appearance | Existing choices unchanged, Astral default retained | Three-theme UI checks, preference tests |
| Complete export/restore | Core/Backup, AppStore | Settings → Data and recovery | Schema-2 additions, schema-1 import, retained pre-upgrade generation | Migration/recovery/merge/replace tests |

Paths in the table are relative to `Invoke/` unless stated otherwise.
