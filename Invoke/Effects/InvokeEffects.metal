/*
 Invoke native Metal adaptations of shader-effects-inc/shaders.
 Source revision: 81fd4ece5d493ca6c424a2af41f0e2c361ec8258
 Copyright (c) 2026 Shader Effects Inc. MIT License.
 The full notice and original source are in ThirdParty/shader-effects-inc/shaders.
 See docs/Shader-Mapping.md for the exact component-to-kernel mapping.
 This is a native adaptation, not the JavaScript/WebGPU package.
 */
#include <metal_stdlib>
using namespace metal;

// Ripples: packages/core/src/gpu/kit/patternPaints.ts::ripplesMask.
// The web coordinate flip is removed: both SwiftUI position and touch origin use top-left.
static float invokeRingWaves(float distance, float frequency, float phase,
                             float thickness, float softness) {
    float wave = sin(distance * frequency - phase);
    float threshold = thickness * 2.0 - 1.0;
    float soft = max(softness, 0.0001);
    return 1.0 - smoothstep(threshold - soft, threshold + soft, wave);
}

// Beam: packages/core/src/gpu/kit/lightfields.ts::pointToSegment.
static float2 invokeSegment(float2 p, float2 a, float2 b) {
    float2 line = b - a;
    float t = clamp(dot(p - a, line) / max(dot(line, line), 0.0001), 0.0, 1.0);
    return float2(t, length(p - (a + line * t)));
}

// Beam: packages/core/src/gpu/kit/lightfields.ts::taperedSegmentGlow.
static float invokeBeam(float2 p, float2 a, float2 b,
                        float startThickness, float endThickness,
                        float startSoftness, float endSoftness) {
    float2 segment = invokeSegment(p, a, b);
    float thickness = mix(startThickness, endThickness, segment.x);
    float softness = max(mix(startSoftness, endSoftness, segment.x), 0.0001);
    float normalizedDistance = segment.y / max(thickness, 0.0001);
    float alphaBase = 1.0 - smoothstep(1.0, 1.0 + softness, normalizedDistance);
    return pow(alphaBase, 1.0 + softness * 1.5);
}

// Sparkle: packages/core/src/std/paint/light.ts::starGlint.
// A fixed small set of points replaces brightness sampling and scattered grids.
static float invokeStar(float2 offset, float reach) {
    float2 a = abs(offset);
    float core = exp(-dot(offset, offset) * 0.9);
    float streaks = exp(-a.x * 1.6 - a.y * 0.16)
                  + exp(-a.y * 1.6 - a.x * 0.16);
    float window = 1.0 - smoothstep(reach * 0.6, reach, max(a.x, a.y));
    return (core + 0.25 * streaks) * window;
}

// Invoke-authored finite envelope and perimeter: no source textures or text are sampled.
static float invokeEnvelope(float t) {
    return smoothstep(0.0, 0.10, t) * (1.0 - smoothstep(0.55, 1.0, t));
}

static float invokeArch(float2 uv, float2 size) {
    // A semicircular proscenium, two straight pillars, and an inner fine rule.
    float2 p = (uv - float2(0.5, 0.42)) * size;
    float radius = max(12.0, min(size.x * 0.44, size.y * 0.34));
    float upper = abs(length(p) - radius);
    float pillars = abs(abs(p.x) - radius);
    float distance = p.y < 0.0 ? upper : pillars;
    float bottomFade = 1.0 - smoothstep(0.89, 0.99, uv.y);
    return exp(-distance * distance / 4.0) * bottomFade;
}

static half4 invokePremultiplied(float3 rgb, float coverage) {
    half alpha = half(clamp(coverage, 0.0, 0.38));
    return half4(half3(rgb) * alpha, alpha);
}

// All fill functions share this signature: point, size, normalized progress, intensity,
// normalized top-left touch origin, and event kind (button 0/card 1/record 2/relic 3/chapter 4).
[[ stitchable ]] half4 invokePigment(float2 position, float2 size, float progress,
                                    float intensity, float2 origin, float kind) {
    size = max(size, float2(1.0));
    float2 uv = position / size;
    float aspect = size.x / size.y;
    float2 relative = (uv - origin) * float2(aspect, 1.0);
    float angle = atan2(relative.y, relative.x);
    // Authored irregular edge makes the source ring math read as pigment on paper.
    float irregularity = sin(angle * 7.0 + 0.6) * 0.009 + sin(angle * 13.0) * 0.005;
    float distance = max(0.0, length(relative) + irregularity);
    float extent = max(1.0, aspect) * 0.9;
    float radius = progress * extent;
    float wave = invokeRingWaves(distance, 30.0, progress * 12.0, 0.31, 0.38);
    float movingEdge = exp(-pow((distance - radius) / 0.13, 2.0));
    float bloom = (1.0 - smoothstep(radius * 0.45, radius + 0.04, distance)) * 0.22;
    float coverage = (wave * movingEdge * 0.6 + bloom) * invokeEnvelope(progress);
    float3 color = kind < 0.5 ? float3(0.12, 0.008, 0.018) : float3(0.36, 0.055, 0.09);
    if (kind > 2.5 && kind < 3.5) {
        // Metallic sigil/relic glint uses Beam's actual tapered segment math.
        float sweep = mix(-0.30, 1.30, progress);
        float glint = invokeBeam(uv, float2(sweep - 0.18, -0.2),
                                float2(sweep + 0.18, 1.2), 0.016, 0.032, 2.8, 2.8);
        coverage = max(coverage * 0.38, glint * invokeEnvelope(progress));
        color = float3(0.69, 0.54, 0.32);
    }
    if (kind > 3.5) coverage *= 0.72; // Quiet chapter ink reveal.
    return invokePremultiplied(color, coverage * intensity);
}

[[ stitchable ]] half4 invokeSilver(float2 position, float2 size, float progress,
                                   float intensity, float2 origin, float kind) {
    size = max(size, float2(1.0));
    float2 uv = position / size;
    float aspect = size.x / size.y;
    float distance = length((uv - origin) * float2(aspect, 1.0));
    float radius = progress * max(1.0, aspect) * 0.95;
    float wave = invokeRingWaves(distance, 33.0, progress * 13.0, 0.15, 0.17);
    float coverage = wave * exp(-pow((distance - radius) / 0.18, 2.0)) * 0.85;
    if (kind > 0.5) {
        // Cards briefly illuminate orbital rings, instead of maintaining a continuous glow.
        float2 orbital = (uv - float2(0.5, 0.48)) * float2(aspect, 1.0);
        float orbit = abs(length(orbital) - 0.39);
        coverage += exp(-orbit * orbit / 0.000045) * 0.25;
    }
    if (kind > 1.5) {
        // Source starGlint kernel, fixed constellation points with sequential finite exposure.
        const float2 points[5] = {float2(0.12, 0.62), float2(0.30, 0.29),
            float2(0.49, 0.53), float2(0.71, 0.67), float2(0.87, 0.31)};
        for (int i = 0; i < 5; ++i) {
            float localProgress = clamp((progress - float(i) * 0.07) * 1.7, 0.0, 1.0);
            coverage += invokeStar((uv - points[i]) * size / 1.8, 13.0)
                        * invokeEnvelope(localProgress);
        }
    }
    coverage *= invokeEnvelope(progress);
    // The primary button is pale parchment; tarnished silver remains visible on that fill.
    // Cards are dark plum, so their light is warm silver instead.
    float3 silver = kind < 0.5 ? float3(0.34, 0.31, 0.39) : float3(0.91, 0.85, 0.78);
    return invokePremultiplied(silver, coverage * intensity);
}

[[ stitchable ]] half4 invokeSpotlight(float2 position, float2 size, float progress,
                                      float intensity, float2 origin, float kind) {
    size = max(size, float2(1.0));
    float2 uv = position / size;
    float aspect = size.x / size.y;
    // Touch location nudges the authored spotlight path, preserving a calm sweep.
    float sweep = mix(-0.25, 1.25, progress) + (origin.x - 0.5) * 0.15;
    float2 p = uv * float2(aspect, 1.0);
    float coverage = invokeBeam(p, float2((sweep - 0.17) * aspect, -0.1),
                               float2((sweep + 0.17) * aspect, 1.1),
                               0.025, 0.12, 3.5, 2.5);
    if (kind > 0.5) coverage = coverage * 0.40 + invokeArch(uv, size) * 0.80;
    if (kind > 1.5 && kind < 2.5) {
        const float2 points[3] = {float2(0.23, 0.65), float2(0.50, 0.26), float2(0.76, 0.63)};
        for (int i = 0; i < 3; ++i) {
            coverage += invokeStar((uv - points[i]) * size / 1.5, 12.0) * 0.70;
        }
    }
    return invokePremultiplied(float3(1.0, 0.69, 0.43),
                               coverage * invokeEnvelope(progress) * intensity);
}
