# Native shader source mapping

Invoke uses native Metal adaptations of selected source in [shader-effects-inc/shaders](https://github.com/shader-effects-inc/shaders), pinned to [81fd4ece5d493ca6c424a2af41f0e2c361ec8258](https://github.com/shader-effects-inc/shaders/tree/81fd4ece5d493ca6c424a2af41f0e2c361ec8258). The repository and Apple's shader documentation were inspected on October 12, 2026. The web package itself, its engine, its hosted editor, and commercial presets are not runtime dependencies. No WebView is used.

## Prototype status and integration

`Invoke/Effects/EffectsLabView.swift` is the small, reachable button-and-card feasibility prototype, exposed from Appearance as Open effects studio. It uses a real native `Button`, a decorative Metal fill, and an independent native card. The button action immediately changes the status and triggers the card; the shader does not gate the action. The three additional sample actions exercise scene recording, relic dedication, and chapter opening with the same wrapper. Appearance also includes a replayable preview beside the customization controls.

**Rendering validation remains required:** local work runs on Windows without Xcode, iOS Simulator, a Metal compiler, or a connected iPhone. Source inspection and source-integrity checks do not establish visual correctness. See the release validation report for any subsequent CI build results; even a successful build is not a device/GPU validation. The first device check should be this studio, followed by all event placements.

Minimum iOS version: **17.0**. Apple documents `Shader` as an iOS 17 API. Its fill pattern signature is a stitchable function returning premultiplied color and receiving pixel position followed by bound arguments. Invoke uses this ShapeStyle path rather than applying a filter to text or entire view hierarchies. References: [Shader](https://developer.apple.com/documentation/swiftui/shader), [Apple's Markdown source](https://developer.apple.com/documentation/swiftui/shader.md).

## Source-to-native correspondence

All paths below are relative to the pinned repository. Complete, unmodified copies of these source files are retained under `ThirdParty/shader-effects-inc/shaders/`, with SHA-256 hashes in `SOURCE-MANIFEST.json`.

| Original component | Original implementation | Native implementation | Adaptation |
| --- | --- | --- | --- |
| `Ripples` | `packages/core/src/shaders/Ripples/index.ts`; recipe in `packages/core/src/std/paint/patterns.ts` (`ringWaves`); kernel in `packages/core/src/gpu/kit/patternPaints.ts` (`ripplesMask`) | `InvokeEffects.metal`: `invokeRingWaves`, used by `invokePigment` and `invokeSilver` | Ported radial sine and smoothstep thickness/softness band. Retains aspect correction, removes the web engine's vertical coordinate double-flip, and accepts native touch coordinates. Invoke adds a finite expanding envelope. |
| `Beam` | `packages/core/src/shaders/Beam/index.ts`; recipe in `packages/core/src/std/paint/gradients.ts`; field in `packages/core/src/gpu/kit/gradientPaints.ts`; `pointToSegment` and `taperedSegmentGlow` in `packages/core/src/gpu/kit/lightfields.ts` | `InvokeEffects.metal`: `invokeSegment`, `invokeBeam`, used by `invokeSpotlight` and the pigment relic glint | Ported clamped segment projection, thickness/softness interpolation, zero-length guards, and power-falloff glow. Invoke animates endpoints through one finite sweep. Uses the theme's single fixed light color instead of the web component's configurable color-space interpolation. |
| `Sparkle` | `packages/core/src/shaders/Sparkle/index.ts`; `starGlint` in `packages/core/src/std/paint/light.ts` | `InvokeEffects.metal`: `invokeStar`, used by `invokeSilver` and `invokeSpotlight` | Ported Gaussian core plus crossed exponential rays and Chebyshev reach window. Uses a maximum of five authored constellation positions and one brief sequential exposure. Omits brightness sampling, scattered grids, continuous blinking, and render-to-texture. |

Native `invokeEnvelope`, `invokeArch`, pigment edge irregularity, event timing, palette, and static vector decoration are Invoke-authored additions. They are not claimed as upstream component ports. The luminous arch combines Invoke's distance-based outline with the adapted Beam field.

`InkFlow` and `CursorRipples` were also inspected. They depend on multi-pass compute simulations with persistent fluid/wave buffers. A SwiftUI stitchable fill does not provide that stateful compute pipeline. They were not copied into the app or advertised as implemented. Pigment-styled `Ripples` is the selected simpler source-derived alternative; it is a brief decorative ink bloom, not simulated fluid.

## Theme and event mapping

| Event | Ink & Omen | Velvet Observatory | Astral Theatre |
| --- | --- | --- | --- |
| Primary button | Touch-centered oxblood pigment ripple | Touch-centered silver ring | Small warm spotlight sweep |
| Story card / scene entry | Quiet pigment edge | Silver ripple plus orbital ring | Brief illuminated proscenium |
| Scene recording | Pigment seal-style bloom | Five source-derived glints illuminate sequentially | Arch plus three brief glints |
| Relic dedication / reveal | Tarnished-gold metallic sweep | Silver ring and cameo-like constellation glints | Spotlight and arch reveal |
| Chapter opening / closing | Lower-intensity soft ink reveal | Silver ripple with brief points | Restrained arch and spotlight |

The scene-recording overlay is ceremonial. Actual experienced scene counts and accessible scene buttons are native app state. The shader's small fixed glint set is not the data model and never substitutes for that native constellation.

## Host API

```swift
EffectSurface(theme: .ink, level: .subtle, trigger: eventCounter,
              kind: .record, origin: CGPoint(x: 0.5, y: 0.5))
```

`InvokeEffectTheme`: `ink`, `velvet`, `astral`. `InvokeEffectLevel`: `subtle`, `full`, `off`. `EffectKind`: `button`, `card`, `record`, `relic`, `chapter`. Increment `trigger` after a successful meaningful action, or when opening a destination. A trigger of zero is idle. The optional origin uses normalized top-left coordinates. Caller-owned event counters are deliberately separate from persisted record identity.

Put `EffectSurface` in a background below native text. It is transparent outside its decoration, clipped to a rounded surface, excluded from hit testing, and hidden from accessibility. The host remains responsible for giving any semantic success feedback through visible native text and correct record state. Native navigation and saving happen immediately.

`InvokeEffectButtonStyle` observes a native button's press state and touch position; it never replaces the action closure. It provides the older-iOS and solid-material primary-button fallback. On iOS 26 and later, `InvokePrimaryButton` uses the actual native `glassProminent` button style with the same independent decorative shader layer. The app must not apply shader filters to reading or editing text.

## Version 1.1 appearance controls and Liquid Glass

The default theme for a new collection is Astral Theatre. Existing collections and backups retain their explicit appearance selection. Appearance preferences are additive to the existing versioned data schema.

| Preference | Choices | Rendering behavior |
| --- | --- | --- |
| Material | System glass, Theme-tinted glass, Solid surfaces | Genuine native Liquid Glass for compact controls on iOS 26+. Solid fallback on older systems, with Reduce Transparency, or with increased contrast. |
| Moment effects | Subtle, Full, Off | Existing finite schedules and static Off treatment. |
| Effect style | Theme signature, Ripples, Spotlight, Constellation | Theme signature keeps the theme/event table above. The other choices use `invokeRippleChoice`, `invokeBeamChoice`, and `invokeSparkleChoice`, respectively, reusing the same pinned upstream kernels and the selected theme's palette. |
| Intensity | 35%-150%, default 100% | Multiplies bounded event opacity; text stays separate and the final alpha cap remains 0.38. |
| Speed | 0.6x-1.4x, default 1x | Divides the base event duration. The longest allowed event remains under two seconds. |

All event surfaces read the same saved preferences, so customization reaches primary buttons, scene records, relics, chapter moments, and the studio. Editing a rendering preference cancels an in-flight event; a new interaction uses the updated choice. Reset motion & material restores Subtle, Theme signature, 100% intensity, 1x speed, and System glass without changing the theme or any writing.

`invokeGlassControl(in:interactive:)` is a reusable modifier for compact floating controls and labels. It applies Apple's `glassEffect(.regular...)` on supported systems, with optional theme tint and native interactive response. `InvokeGlassGroup` uses `GlassEffectContainer` to group nearby custom controls. Read-only labels pass `interactive: false`; Reduce Motion also disables that custom interactive response. This implementation does not emulate Liquid Glass with a blur or translucent rectangle.

Standard navigation and tab bars retain their system Liquid Glass appearance on the eligible path: Invoke does not force an opaque toolbar background there. Solid mode and accessibility fallbacks restore the theme's opaque toolbar background. Content cards, long-form text, and editable fields deliberately remain opaque so their contrast does not vary with scenery.

Apple references inspected for the native integration: [Glass](https://developer.apple.com/documentation/swiftui/glass), [applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views), [glassEffect](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)), and [glassProminent](https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glassprominent). These APIs require iOS 26 and a corresponding or newer SDK; the app retains its iOS 17 deployment target with runtime availability gates.

## Motion, accessibility, and rendering budget

- Default Subtle is a 30-frame-per-second maximum scheduling request, with lower alpha. Full requests up to 60 frames per second. SwiftUI controls actual cadence.
- At 1x speed, the schedule exists only for a finite event: button 0.68 s; card 0.95 s; record 1.15 s; relic 1.10 s; chapter 0.90 s. The `TimelineView` is removed afterward. There are no ambient repeating shader animations.
- Off, Reduce Motion, Reduce Transparency, Low Power Mode, and inactive app state remove animated rendering. Stable native vector rules and celestial marks remain. Off does not call any shader.
- Higher accessibility contrast reduces decoration intensity. Text and controls stay separate from the shader and continue to support native Dynamic Type and VoiceOver.
- A geometry check stops a surface when its bounds no longer intersect the screen; disappearance and scene-phase changes stop it as well. This is a conservative screen-bounds heuristic: verify nested scroll clipping and tab transitions on a device. Even if an unusual container retains a partly clipped surface, events still have a hard finite end.
- A theme or effects-level change cancels a running event. It does not alter navigation, drafts, or model state.
- Returned Metal colors are premultiplied. Theme intensity scales coverage before a final opacity cap of 0.38. This is decoration, not an HDR bloom pipeline.

## Required remaining Xcode and iPhone checks

1. Confirm `InvokeEffects.metal` belongs to the app target's Compile Sources and `ShaderLicense.txt` is bundled. The default Metal library must contain all six stitchable functions: three theme signatures and three configurable styles.
2. Build in Xcode using an iOS 17 deployment target. Open Effects studio and verify the native button responds immediately and both button and card actually render in every theme.
3. Check actual low-end supported hardware (an iPhone XS or XR running iOS 17), then a current iPhone. Measure CPU/GPU frame time and idle power with Instruments; the source delivery makes no FPS or battery claim.
4. Repeatedly press, scroll a playing card fully out of view, switch tabs, background the app, and enable Low Power Mode during a running effect. Check frame scheduling stops.
5. Enable Reduce Motion, higher contrast, VoiceOver, and the largest accessibility text sizes. Verify static alternatives, clear focus order, correct button activation, and untruncated wrapping.
6. Test all actual event placements: scene entry, successful scene recording and constellation update, relic reveal/dedication, and chapter open/close. Confirm no overlay intercepts touches or hides writing.
7. Switch theme, material, style, intensity, speed, and effects level mid-event and while drafts are open. Confirm content state and navigation stay intact. Reopen the app and restore a backup to verify preference persistence.
8. On iOS 26+ check actual native glass buttons, compact map controls, standard navigation, sheets, and tab bars. Compare System glass, Theme-tinted glass, and Solid surfaces under all themes; repeat with Reduce Transparency, increased contrast, and Reduce Motion. Repeat on iOS 17 to check solid fallbacks and absence of unavailable-API crashes.

No device, Simulator, GPU rendering, scrolling-performance, or battery results are claimed in this delivery.

## License and attribution

Upstream code is MIT licensed, copyright (c) 2026 Shader Effects Inc. Its complete license is preserved in `ThirdParty/shader-effects-inc/shaders/LICENSE` and `Invoke/Effects/ShaderLicense.txt`. The `.metal` file identifies the adaptation and pinned revision. Keep these notices when redistributing source or compiled app resources. Only MIT repository components were used; no shaders.com commercial preset or hosted-editor content was incorporated.
