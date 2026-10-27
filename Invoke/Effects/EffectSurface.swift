import SwiftUI
import Combine
import UIKit

enum InvokeEffectTheme: String, CaseIterable, Identifiable {
    case ink, velvet, astral
    var id: String { rawValue }

    var title: String {
        switch self {
        case .ink: "Ink & Omen"
        case .velvet: "Velvet Observatory"
        case .astral: "Astral Theatre"
        }
    }

    fileprivate var decoration: Color {
        switch self {
        case .ink: Color(red: 0.40, green: 0.10, blue: 0.13)
        case .velvet: Color(red: 0.88, green: 0.82, blue: 0.76)
        case .astral: Color(red: 0.94, green: 0.66, blue: 0.42)
        }
    }
}

enum InvokeEffectLevel: String, CaseIterable, Identifiable {
    case subtle, full, off
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum InvokeShaderStyle: String, CaseIterable, Identifiable {
    case theme, ripple, beam, sparkle
    var id: String { rawValue }
    var title: String {
        switch self {
        case .theme: "Theme signature"
        case .ripple: "Ripples"
        case .beam: "Spotlight"
        case .sparkle: "Constellation"
        }
    }
    var detail: String {
        switch self {
        case .theme: "Pigment, silver, or a theatrical arch, chosen by your theme."
        case .ripple: "Rings spread from your touch, adapted from Ripples."
        case .beam: "A short sweep of light, adapted from Beam."
        case .sparkle: "A few stars briefly illuminate, adapted from Sparkle."
        }
    }
}

enum EffectKind: String, CaseIterable, Identifiable {
    case button, card, record, relic, chapter
    var id: String { rawValue }

    fileprivate var index: Float {
        switch self {
        case .button: 0
        case .card: 1
        case .record: 2
        case .relic: 3
        case .chapter: 4
        }
    }

    fileprivate var duration: TimeInterval {
        switch self {
        case .button: 0.68
        case .card: 0.95
        case .record: 1.15
        case .relic: 1.10
        case .chapter: 0.90
        }
    }
}

/// Transparent decorative surface. Put this below native text or above a background.
/// Increment `trigger` for a meaningful action; no animation ever owns that action's completion.
/// Coordinates in `origin` are normalized, top-left based. VoiceOver activation uses the center.
struct EffectSurface: View {
    let theme: InvokeEffectTheme
    let level: InvokeEffectLevel
    let trigger: Int
    let kind: EffectKind
    var origin: CGPoint = CGPoint(x: 0.5, y: 0.5)

    @EnvironmentObject private var store: AppStore
    @InvokeReducedMotion private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.scenePhase) private var scenePhase
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var startedAt: Date?
    @State private var eventOrigin = CGPoint(x: 0.5, y: 0.5)
    @State private var visible = true

    private var motionAllowed: Bool {
        level != .off && !reduceMotion && !reduceTransparency && !lowPower && scenePhase == .active && visible
    }

    private var intensity: Float {
        let base: Float = level == .full ? 0.42 : 0.22
        let requested = Float(min(1.5, max(0.35, store.data.preferences.effectIntensity)))
        return base * requested * (contrast == .increased ? 0.55 : 1)
    }
    private var duration: TimeInterval { kind.duration / min(1.4, max(0.6, store.data.preferences.effectSpeed)) }
    private var style: InvokeShaderStyle { InvokeShaderStyle(rawValue: store.data.preferences.shaderStyle) ?? .theme }

    private var chosenColor: Color {
        if kind == .button {
            switch theme {
            case .ink: Color(red: 0.13, green: 0.015, blue: 0.025)
            case .velvet: Color(red: 0.34, green: 0.31, blue: 0.39)
            case .astral: Color(red: 1.0, green: 0.69, blue: 0.43)
            }
        } else { theme.decoration }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                staticDecoration(size: geometry.size)
                if let startedAt, motionAllowed {
                    TimelineView(.animation(minimumInterval: level == .full ? 1.0 / 60.0 : 1.0 / 30.0)) { context in
                        let progress = min(1, max(0, context.date.timeIntervalSince(startedAt) / duration))
                        // Shader conforms to ShapeStyle; it only paints this transparent shape.
                        // Native labels and the native Button are never rasterized or distorted.
                        Rectangle().fill(shader(size: geometry.size, progress: Float(progress)))
                    }
                }
            }
            .onChange(of: geometry.frame(in: .global), initial: true) { _, frame in
                let onscreen = frame.width > 0 && frame.height > 0 && frame.intersects(UIScreen.main.bounds)
                if visible != onscreen { visible = onscreen }
                if !onscreen { startedAt = nil }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: kind == .button ? 16 : 22))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: trigger) {
            guard trigger > 0, motionAllowed else { return }
            eventOrigin = origin
            startedAt = Date()
            do {
                try await Task.sleep(for: .seconds(duration))
            } catch {
                return // Cancellation belongs to a new trigger or a disappearing surface.
            }
            startedAt = nil // Removing TimelineView removes its frame schedule entirely.
        }
        .onChange(of: motionAllowed) { _, allowed in
            if !allowed { startedAt = nil }
        }
        .onChange(of: theme) { _, _ in startedAt = nil }
        .onChange(of: level) { _, _ in startedAt = nil }
        .onChange(of: store.data.preferences.shaderStyle) { _, _ in startedAt = nil }
        .onChange(of: store.data.preferences.effectIntensity) { _, _ in startedAt = nil }
        .onChange(of: store.data.preferences.effectSpeed) { _, _ in startedAt = nil }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange).receive(on: RunLoop.main)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .onDisappear { startedAt = nil }
    }

    private func shader(size: CGSize, progress: Float) -> Shader {
        let dimensions = Shader.Argument.float2(Float(max(size.width, 1)), Float(max(size.height, 1)))
        let point = Shader.Argument.float2(Float(min(1, max(0, eventOrigin.x))), Float(min(1, max(0, eventOrigin.y))))
        switch style {
        case .ripple:
            return ShaderLibrary.invokeRippleChoice(dimensions, .float(progress), .float(intensity), point, .color(chosenColor))
        case .beam:
            return ShaderLibrary.invokeBeamChoice(dimensions, .float(progress), .float(intensity), point, .color(chosenColor))
        case .sparkle:
            return ShaderLibrary.invokeSparkleChoice(dimensions, .float(progress), .float(intensity), point, .color(chosenColor))
        case .theme: break
        }
        switch theme {
        case .ink:
            return ShaderLibrary.invokePigment(dimensions, .float(progress), .float(intensity), point, .float(kind.index))
        case .velvet:
            return ShaderLibrary.invokeSilver(dimensions, .float(progress), .float(intensity), point, .float(kind.index))
        case .astral:
            return ShaderLibrary.invokeSpotlight(dimensions, .float(progress), .float(intensity), point, .float(kind.index))
        }
    }

    @ViewBuilder private func staticDecoration(size: CGSize) -> some View {
        // These native vectors remain attractive with effects Off, Reduce Motion, or Low Power.
        // They are stable: no implicit animations and no shader/timer is involved.
        let alpha = contrast == .increased ? 0.25 : 0.14
        RoundedRectangle(cornerRadius: kind == .button ? 16 : 22)
            .strokeBorder(theme.decoration.opacity(alpha), lineWidth: 0.7)
        if kind != .button {
            if theme == .astral {
                Path { path in
                    let rect = CGRect(x: size.width * 0.075, y: 12, width: size.width * 0.85,
                                      height: max(10, size.height - 24))
                    path.addRoundedRect(in: rect, cornerSize: CGSize(width: rect.width / 2, height: 40))
                }
                .stroke(theme.decoration.opacity(0.09), lineWidth: 0.6)
            }
            Image(systemName: theme == .ink ? "sparkle" : "moon.stars")
                .font(.system(size: 14, weight: .ultraLight))
                .foregroundStyle(theme.decoration.opacity(0.3))
                .position(x: max(16, size.width - 21), y: 21)
        }
    }
}

/// An optional native ButtonStyle for callers that want touch-centered shader feedback.
/// The Button's own action stays native and synchronous. A drag observer only records location.
struct InvokeEffectButtonStyle: ButtonStyle {
    let theme: InvokeEffectTheme
    let level: InvokeEffectLevel
    var background: Color
    var foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        EffectButtonBody(configuration: configuration, theme: theme, level: level,
                         background: background, foreground: foreground)
    }

    private struct EffectButtonBody: View {
        let configuration: ButtonStyle.Configuration
        let theme: InvokeEffectTheme
        let level: InvokeEffectLevel
        let background: Color
        let foreground: Color
        @Environment(\.isEnabled) private var isEnabled
        @State private var trigger = 0
        @State private var origin = CGPoint(x: 0.5, y: 0.5)
        @State private var dimensions = CGSize(width: 1, height: 1)

        var body: some View {
            configuration.label
                .font(.system(.body, design: .serif).weight(.semibold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, minHeight: 24)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(background)
                        EffectSurface(theme: theme, level: level, trigger: trigger, kind: .button, origin: origin)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(foreground.opacity(configuration.isPressed ? 0.50 : 0.05), lineWidth: 1)
                }
                .opacity(isEnabled ? 1 : 0.45)
                .background {
                    GeometryReader { geometry in
                        Color.clear.onChange(of: geometry.size, initial: true) { _, size in dimensions = size }
                    }
                }
                .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { value in
                    origin = CGPoint(x: value.location.x / max(dimensions.width, 1),
                                     y: value.location.y / max(dimensions.height, 1))
                })
                .onChange(of: configuration.isPressed) { _, pressed in
                    if pressed && isEnabled {
                        if UIAccessibility.isVoiceOverRunning { origin = CGPoint(x: 0.5, y: 0.5) }
                        trigger += 1
                    }
                }
        }
    }
}
