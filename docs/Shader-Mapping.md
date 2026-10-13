# Native shader source mapping

Invoke uses native Metal adaptations of selected source in [shader-effects-inc/shaders](https://github.com/shader-effects-inc/shaders), pinned to [81fd4ece5d493ca6c424a2af41f0e2c361ec8258](https://github.com/shader-effects-inc/shaders/tree/81fd4ece5d493ca6c424a2af41f0e2c361ec8258). The repository and Appleâ€™s shader documentation were inspected on October 12, 2026. The web package itself, its engine, its hosted editor, and commercial presets are not runtime dependencies. No WebView is used.

## Prototype status and integration

`Invoke/Effects/EffectsLabView.swift` is the small, reachable button-and-card feasibility prototype, exposed from Appearance as Try button & card effects. It uses a real native `Button`, a decorative Metal fill, and an independent native card. The button action immediately changes the status and triggers the card; the shader does not gate the action. The three additional sample actions exercise scene recording, relic dedication, and chapter opening with the same wrapper.

**Validation gate remains open:** the build environment is Windows and has no Xcode, iOS Simulator, Metal compiler, or connected iPhone. Source inspection and source-integrity checks are complete. The prototype has not been built or run. Its reusable implementation is connected to the feature code to make the first version reviewable, but expansion must not be mistaken for a validated GPU approach. The first Xcode/device check should be this studio; if shaders fail to render, select Effects Off to continue checking the native app, fix the shader build/integration, and then validate all event placements.

Minimum iOS version: **17.0**. Apple documents `Shader` as an iOS 17 API. Its fill pattern signature is a stitchable function returning premultiplied color and receiving pixel position followed by bound arguments. Invoke uses this ShapeStyle path rather than applying a filter to text or entire view hierarchies. References: [Shader](https://developer.apple.com/documentation/swiftui/shader), [Appleâ€™s Markdown source](https://developer.apple.com/documentation/swiftui/shader.md).

## Source-to-native correspondence

All paths below are relative to the pinned repository. Complete, unmodified copies of these source files are retained under `ThirdParty/shader-effects-inc/shaders/`, with SHA-256 hashes in `SOURCE-MANIFEST.json`.

| Original component | Original implementation | Native implementation | Adaptation |
| --- | --- | --- | --- |
| `Ripples` | `packages/core/src/shaders/Ripples/index.ts`; recipe in `packages/core/src/std/paint/patterns.ts` (`ringWaves`); kernel in `packages/core/src/gpu/kit/patternPaints.ts` (`ripplesMask`) | `InvokeEffects.metal`: `invokeRingWaves`, used by `invokePigment` and `invokeSilver` | Ported radial sine and smoothstep thickness/softness band. Retains aspect correction, removes the web engineâ€™s vertical coordinate double-flip, and accepts native touch coordinates. Invoke adds a finite expanding envelope. |
| `Beam` | `packages/core/src/shaders/Beam/index.ts`; recipe in `packages/core/src/std/paint/gradients.ts`; field in `packages/core/src/gpu/kit/gradientPaints.ts`; `pointToSegment` and `taperedSegmentGlow` in `packages/core/src/gpu/kit/lightfields.ts` | `InvokeEffects.metal`: `invokeSegment`, `invokeBeam`, used by `invokeSpotlight` and the pigment relic glint | Ported clamped segment projection, thickness/softness interpolation, zero-length guards, and power-falloff glow. Invoke animates endpoints through one finite sweep. Uses the themeâ€™s single fixed light color instead of the web componentâ€™s configurable color-space interpolation. |
| `Sparkle` | `packages/core/src/shaders/Sparkle/index.ts`; `starGlint` in `packages/core/src/std/paint/light.ts` | `InvokeEffects.metal`: `invokeStar`, used by `invokeSilver` and `invokeSpotlight` | Ported Gaussian core plus crossed exponential rays and Chebyshev reach window. Uses a maximum of five authored constellation positions and one brief sequential exposure. Omits brightness sampling, scattered grids, continuous blinking, and render-to-texture. |

Native `invokeEnvelope`, `invokeArch`, pigment edge irregularity, event timing, palette, and static vector decoration are Invoke-authored additions. They are not claimed as upstream component ports. The luminous arch combines Invokeâ€™s distance-based outline with the adapted Beam field.

`InkFlow` and `CursorRipples` were also inspected. They depend on multi-pass compute simulations with persistent fluid/wave buffers. A SwiftUI stitchable fill does not provide that stateful compute pipeline. They were not copied into the app or advertised as implemented. Pigment-styled `Ripples` is the selected simpler source-derived alternative; it is a brief decorative ink bloom, not simulated fluid.

## Theme and event mapping

| Event | Ink & Omen | Velvet Observatory | Astral Theatre |
| --- | --- | --- | --- |
| Primary button | Touch-centered oxblood pigment ripple | Touch-centered silver ring | Small warm spotlight sweep |
| Story card / scene entry | Quiet pigment edge | Silver ripple plus orbital ring | Brief illuminated proscenium |
| Scene recording | Pigment seal-style bloom | Five source-derived glints illuminate sequentially | Arch plus three brief glints |
| Relic dedication / reveal | Tarnished-gold metallic sweep | Silver ring and cameo-like constellation glints | Spotlight and arch reveal |
| Chapter opening / closing | Lower-intensity soft ink reveal | Silver ripple with brief points | Restrained arch and spotlight |

The scene-recording overlay is ceremonial. Actual experienced scene counts and accessible scene buttons are native app state. The shaderâ€™s small fixed glint set is not the data model and never substitutes for that native constellation.

## Host API

```swift
EffectSurface(theme: .ink, level: .subtle, trigger: eventCounter,
              kind: .record, origin: CGPoint(x: 0.5, y: 0.5))
```

`InvokeEffectTheme`: `ink`, `velvet`, `astral`. `InvokeEffectLevel`: `subtle`, `full`, `off`. `EffectKind`: `button`, `card`, `record`, `relic`, `chapter`. Increment `trigger` after a successful meaningful action, or when opening a destination. A trigger of zero is idle. The optional origin uses normalized top-left coordinates. Caller-owned event counters are deliberately separate from persisted record identity.

Put `EffectSurface` in a background below native text. It is transparent outside its decoration, clipped to a rounded surface, excluded from hit testing, and hidden from accessibility. The host remains responsible for giving any semantic success feedback through visible native text and correct record state. Native navigation and saving happen immediately.

`InvokeEffectButtonStyle` observes a native buttonâ€™s press state and touch position; it never replaces the action closure. It is provided for a touch-centered press effect. The app may use the surface directly for event effects, and must not apply shader filters to reading or editing text.

## Motion, accessibility, and rendering budget

- Default Subtle is a 30-frame-per-second maximum scheduling request, with lower alpha. Full requests up to 60 frames per second. SwiftUI controls actual cadence.
- The schedule exists only for a finite event: button 0.68 s; card 0.95 s; record 1.15 s; relic 1.10 s; chapter 0.90 s. The `TimelineView` is removed afterward. There are no ambient repeating shader animations.
- Off, Reduce Motion, Low Power Mode, and inactive app state remove animated rendering. Stable native vector rules and celestial marks remain. Off does not call any shader.
- Higher accessibility contrast reduces decoration intensity. Text and controls stay separate from the shader and continue to support native Dynamic Type and VoiceOver.
- A geometry check stops a surface when its bounds no longer intersect the screen; disappearance and scene-phase changes stop it as well. This is a conservative screen-bounds heuristic: verify nested scroll clipping and tab transitions on a device. Even if an unusual container retains a partly clipped surface, events still have a hard finite end.
- A theme or effects-level change cancels a running event. It does not alter navigation, drafts, or model state.
- Returned Metal colors are premultiplied. Theme intensity scales coverage before a final opacity cap of 0.38. This is decoration, not an HDR bloom pipeline.

## Required remaining Xcode and iPhone checks

1. Add `InvokeEffects.metal` to the app targetâ€™s Compile Sources and `ShaderLicense.txt` to bundle resources. Confirm the default Metal library contains all three stitchable functions.
2. Build in Xcode using an iOS 17 deployment target. Open Effects studio and verify the native button responds immediately and both button and card actually render in every theme.
3. Check actual low-end supported hardware (an iPhone XS or XR running iOS 17), then a current iPhone. Measure CPU/GPU frame time and idle power with Instruments; the source delivery makes no FPS or battery claim.
4. Repeatedly press, scroll a playing card fully out of view, switch tabs, background the app, and enable Low Power Mode during a running effect. Check frame scheduling stops.
5. Enable Reduce Motion, higher contrast, VoiceOver, and the largest accessibility text sizes. Verify static alternatives, clear focus order, correct button activation, and untruncated wrapping.
6. Test all actual event placements: scene entry, successful scene recording and constellation update, relic reveal/dedication, and chapter open/close. Confirm no overlay intercepts touches or hides writing.
7. Switch theme and effects level mid-event and while drafts are open. Confirm those content states and navigation positions remain intact.

No device, Simulator, GPU rendering, scrolling-performance, or battery results are claimed in this delivery.

## License and attribution

Upstream code is MIT licensed, copyright (c) 2026 Shader Effects Inc. Its complete license is preserved in `ThirdParty/shader-effects-inc/shaders/LICENSE` and `Invoke/Effects/ShaderLicense.txt`. The `.metal` file identifies the adaptation and pinned revision. Keep these notices when redistributing source or compiled app resources. Only MIT repository components were used; no shaders.com commercial preset or hosted-editor content was incorporated.
