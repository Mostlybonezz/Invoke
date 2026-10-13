# Invoke asset inventory

The supplied mockups are the primary direction. Their desktop columns become one scrolling Sanctuary with one prominent next-scene action, a four-item native tab bar, and detail destinations. Old branding appears only inside the untouched reference PNGs, never in app text or metadata.

| Asset | Purpose and theme | State | Source / attribution / replacement |
| --- | --- | --- | --- |
| `AppIcon.appiconset/Invoke.png` | Oxblood wax-disc/celestial mark on ivory; iPhone app icon | Provisional original | Created with vector geometry by `Tools/draw_icon.py`. Opaque 1024px PNG. Replace in asset catalog. |
| Invoke wordmark | Native serif text in Sanctuary, onboarding, PDF card | Provisional original treatment | Apple system serif, no bundled external font or font download. |
| Display/body typography | Serif headings, native legible body/control text, Dynamic Type | First-version selection | System typography via SwiftUI and UIKit; Georgia fallback for PDF output. No font files redistributed. |
| Nine story-shape sigils | Coordinated fine-ring geometric symbols for the nine story shapes | Provisional original | `Design/StorySigil.swift`; editable native Canvas paths. Shape labels provide meaning separately. |
| Navigation/action glyphs | Tabs, settings, search, add, archive, photo, sharing, scene states | Platform assets | SF Symbols through `Image(systemName:)`, used inside an Apple platform app. No SF Symbol artwork redistributed as files. |
| Paper flecks | Extremely faint, deterministic dots on selected Ink cards | Provisional original | `ThemeScenery`, `DesignSystem.swift`. No image or third-party texture. |
| Orbit engraving | Velvet scene/card decoration | Provisional original | Native ellipses and celestial mark in `ThemeScenery` / `CelestialOrnament`. |
| Proscenium and curtain-fold lines | Astral featured scene treatment | Provisional original | Native paths in `ThemeScenery`; stronger treatment reserved for scene cards. |
| Relic placeholders | Cabinet tiles, detail hero, exported card without photo | Provisional symbolic | Native SF Symbols and geometric framing. Do not imply a real photograph exists. |
| Imported relic photos and story covers | Real personal images, all themes; Velvet oval, Astral shadowbox | User content | Native PhotosPicker → local resized JPEG. Kept in protected Application Support, embedded in portable backups. |
| Shader treatments | Presses, record, relic, chapter; all themes | Native prototype, GPU validation pending | `Effects/InvokeEffects.metal`; adapted MIT source, mapping and complete attribution in `Shader-Mapping.md`. |
| Shader static alternatives | Off, Reduce Motion, Low Power, inactive | Native vectors | `Effects/EffectSurface.swift`; original fixed borders/celestial marks. |
| Three source mockups | Composition/material/type guidance only | User-supplied references | `DesignReferences/01-velvet-observatory.png`, `02-ink-and-omen.png`, `03-astral-theatre.png`. Copied unchanged from the user's supplied files. Not included in the app bundle. Rights not otherwise asserted. |

The artwork is intentionally separated from text and controls. None of the reference screenshot labels, navigation, cards, or buttons are rendered as interface images. Native controls remain usable without a shader or decorative asset.

Potential art pass after device validation: original botanical engravings for Ink, tactile low-contrast velvet edge textures for Velvet, and a restrained illustrated arch/curtain set for Astral. These are not included or claimed as completed.
