import SwiftUI

struct InvokeTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let background: Color
    let surface: Color
    let text: Color
    let secondary: Color
    let accent: Color
    let border: Color
    let button: Color
    let buttonText: Color
    var scheme: ColorScheme { id == "ink" ? .light : .dark }
    static let ink = InvokeTheme(id: "ink", name: "Ink & Omen", subtitle: "A little ink. A little rebellion.", background: Color(hex: 0xF6F1E6), surface: Color(hex: 0xFFFCF5), text: Color(hex: 0x241E1B), secondary: Color(hex: 0x685F56), accent: Color(hex: 0x792E38), border: Color(hex: 0xC8BBAB), button: Color(hex: 0x6D202B), buttonText: Color(hex: 0xFFF7EA))
    static let velvet = InvokeTheme(id: "velvet", name: "Velvet Observatory", subtitle: "Same sky. Different possibilities.", background: Color(hex: 0x170F18), surface: Color(hex: 0x281D2C), text: Color(hex: 0xF4E8DC), secondary: Color(hex: 0xC6B5C7), accent: Color(hex: 0xE0BEC5), border: Color(hex: 0x776277), button: Color(hex: 0xE9D8C4), buttonText: Color(hex: 0x291C2A))
    static let astral = InvokeTheme(id: "astral", name: "Astral Theatre", subtitle: "The stage is yours. Begin quietly.", background: Color(hex: 0x101422), surface: Color(hex: 0x202237), text: Color(hex: 0xF7E5DE), secondary: Color(hex: 0xC3BDD4), accent: Color(hex: 0xF5AC91), border: Color(hex: 0x7C7188), button: Color(hex: 0xB63D24), buttonText: Color(hex: 0xFFF7EC))
    static let all: [InvokeTheme] = [.ink, .velvet, .astral]
    static func named(_ id: String) -> InvokeTheme { all.first { $0.id == id } ?? .astral }
}

extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1) }
}
private struct ThemeKey: EnvironmentKey { static let defaultValue = InvokeTheme.astral }
extension EnvironmentValues {
    var invokeTheme: InvokeTheme { get { self[ThemeKey.self] } set { self[ThemeKey.self] = newValue } }
}

enum InvokeLayout {
    static let margin: CGFloat = 20
    static let gap: CGFloat = 18
    static let corner: CGFloat = 16
    static let minimumTouch: CGFloat = 44
}

struct ScreenBackground: View {
    @Environment(\.invokeTheme) private var theme
    var body: some View { theme.background.ignoresSafeArea() }
}

struct InvokeCard<Content: View>: View {
    @Environment(\.invokeTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: InvokeLayout.corner))
            .overlay(RoundedRectangle(cornerRadius: InvokeLayout.corner).stroke(theme.border.opacity(contrast == .increased ? 1 : 0.65), lineWidth: contrast == .increased ? 1.5 : 0.7))
    }
}

struct SectionEyebrow: View {
    let text: String
    @Environment(\.invokeTheme) private var theme
    var body: some View { Text(text.uppercased()).font(.caption.weight(.medium)).tracking(2).foregroundStyle(theme.secondary).fixedSize(horizontal: false, vertical: true) }
}

struct StatusPill: View {
    let text: String
    @Environment(\.invokeTheme) private var theme
    var body: some View { Text(text).font(.caption).padding(.horizontal, 10).padding(.vertical, 5).foregroundStyle(theme.text).background(theme.accent.opacity(0.12), in: Capsule()) }
}

struct InvokePrimaryButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.invokeTheme) private var theme
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var trigger = 0
    @State private var origin = CGPoint(x: 0.5, y: 0.5)
    @State private var size = CGSize(width: 1, height: 1)
    @State private var touching = false
    var body: some View {
        if #available(iOS 26.0, *), store.data.preferences.glassStyle != "solid", !reduceTransparency, contrast != .increased {
            Button {
                if !touching { trigger += 1 }
                action()
            } label: {
                label.padding(.vertical, 8)
                    .background {
                        EffectSurface(theme: effectTheme, level: effectLevel, trigger: trigger, kind: .button, origin: origin)
                    }
                    .background {
                        GeometryReader { geometry in
                            Color.clear.onChange(of: geometry.size, initial: true) { _, value in size = value }
                        }
                    }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(theme.button)
            .foregroundStyle(theme.buttonText)
            .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { value in
                if !touching {
                    origin = CGPoint(x: value.location.x / max(size.width, 1), y: value.location.y / max(size.height, 1))
                    touching = true
                    trigger += 1
                }
            }.onEnded { _ in touching = false })
        } else {
            Button(action: action) { label }
                .buttonStyle(InvokeEffectButtonStyle(theme: effectTheme, level: effectLevel, background: theme.button, foreground: theme.buttonText))
        }
    }
    private var label: some View { HStack(spacing: 12) { Text(title).font(.headline); Spacer(minLength: 0); Image(systemName: "arrow.right") } }
    private var effectTheme: InvokeEffectTheme { InvokeEffectTheme(rawValue: theme.id) ?? .astral }
    private var effectLevel: InvokeEffectLevel { InvokeEffectLevel(rawValue: store.data.preferences.effects) ?? .subtle }
}

struct InvokePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
    }
}

struct ProseField: View {
    let title: String
    @Binding var text: String
    var prompt: String = ""
    var accessibilityID: String = ""
    @Environment(\.invokeTheme) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if !prompt.isEmpty { Text(prompt).font(.subheadline).foregroundStyle(theme.secondary) }
            TextField("Write in your own words…", text: $text, axis: .vertical)
                .lineLimit(3...14).padding(12).background(theme.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 0.7))
                .accessibilityLabel(title)
                .accessibilityIdentifier(accessibilityID.isEmpty ? title : accessibilityID)
        }.foregroundStyle(theme.text)
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String
    @Environment(\.invokeTheme) private var theme
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(theme.accent).accessibilityHidden(true)
            Text(title).font(.title2.weight(.regular)).fontDesign(.serif)
            Text(message).font(.body).foregroundStyle(theme.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 36).padding(.horizontal, 16)
    }
}


// Original vector ornament. It is decoration, never a control or a text replacement.
struct CelestialOrnament: View {
    @Environment(\.invokeTheme) private var theme
    var body: some View {
        Canvas { context, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) * 0.35
            for n in 0..<3 {
                var p = Path()
                p.addEllipse(in: CGRect(x: c.x - r - CGFloat(n * 8), y: c.y - r * 0.65, width: 2 * r + CGFloat(n * 16), height: r * 1.3))
                context.stroke(p, with: .color(theme.border.opacity(0.6)), lineWidth: 0.6)
            }
            var star = Path()
            star.move(to: CGPoint(x:c.x, y:c.y-r)); star.addLine(to: CGPoint(x:c.x+3,y:c.y-3)); star.addLine(to: CGPoint(x:c.x+r*0.5,y:c.y)); star.addLine(to: CGPoint(x:c.x+3,y:c.y+3)); star.addLine(to: CGPoint(x:c.x,y:c.y+r)); star.addLine(to: CGPoint(x:c.x-3,y:c.y+3)); star.addLine(to: CGPoint(x:c.x-r*0.5,y:c.y)); star.addLine(to: CGPoint(x:c.x-3,y:c.y-3)); star.closeSubpath()
            context.fill(star, with: .color(theme.accent))
        }.frame(height: 66).accessibilityHidden(true)
    }
}

struct ThemeScenery: View {
    @Environment(\.invokeTheme) private var theme
    var body: some View {
        Canvas { context, size in
            if theme.id == "astral" {
                var arch = Path()
                arch.move(to: CGPoint(x: 9, y:size.height)); arch.addLine(to:CGPoint(x:9,y:size.width*0.5))
                arch.addQuadCurve(to:CGPoint(x:size.width-9,y:size.width*0.5),control:CGPoint(x:size.width/2,y:-size.width*0.32))
                arch.addLine(to: CGPoint(x:size.width-9,y:size.height))
                context.stroke(arch,with:.color(theme.accent.opacity(0.35)),lineWidth:1)
                for side in [false,true] { for n in 0..<4 {
                    let x = side ? size.width-CGFloat(n*6) : CGFloat(n*6)
                    var fold = Path(); fold.move(to:CGPoint(x:x,y:0)); fold.addQuadCurve(to:CGPoint(x:x,y:80), control:CGPoint(x:side ? x-30 : x+30,y:40))
                    context.stroke(fold,with:.color(theme.border.opacity(0.25)),lineWidth:2)
                }}
            } else if theme.id == "velvet" {
                for n in 0..<4 { var p = Path(); p.addEllipse(in:CGRect(x:size.width*0.43-CGFloat(n*18),y:-60,width:140+CGFloat(n*36),height:220)); context.stroke(p,with:.color(theme.border.opacity(0.22)),lineWidth:0.6) }
            } else {
                // Deterministic, extremely faint paper flecks at the margins.
                for n in 0..<170 {
                    let x = CGFloat((n*47)%997)/997*size.width, y = CGFloat((n*139)%991)/991*size.height
                    context.fill(Path(ellipseIn:CGRect(x:x,y:y,width:1,height:1)),with:.color(theme.secondary.opacity(0.09)))
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

enum StoryLibrary {
    static let shapes = ["Overcoming the monster", "Quest", "Voyage and return", "Rise", "Fall", "Rebirth", "Love or union", "Separation or loss", "Discovery"]
    static let modes = ["Realist", "Mythic", "Romantic", "Tragic", "Comic", "Satiric", "Epic"]
    static let sigils = ["shield.lefthalf.filled", "sparkle", "moonphase.waning.crescent", "sunrise", "sunset", "arrow.triangle.2.circlepath", "link", "leaf", "eye"]
    static func symbol(_ shape: String) -> String { sigils[shapes.firstIndex(of: shape) ?? 1] }
}

extension View {
    func invokeScreen() -> some View { modifier(InvokeScreenModifier()) }

    /// Use for compact floating controls, never for a long reading or writing surface.
    func invokeGlassControl<S: Shape>(in shape: S, interactive: Bool = true) -> some View {
        modifier(InvokeGlassControlModifier(shape: shape, interactive: interactive))
    }
}

enum InvokeGlassStyle: String, CaseIterable, Identifiable {
    case system, tinted, solid
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "System glass"
        case .tinted: "Theme-tinted glass"
        case .solid: "Solid surfaces"
        }
    }
}

private struct InvokeGlassControlModifier<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool
    @EnvironmentObject private var store: AppStore
    @Environment(\.invokeTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *), store.data.preferences.glassStyle != "solid", !reduceTransparency, contrast != .increased {
            if store.data.preferences.glassStyle == "tinted" {
                content.glassEffect(.regular.tint(theme.accent.opacity(0.22)).interactive(interactive && !reduceMotion), in: shape)
            } else {
                content.glassEffect(.regular.interactive(interactive && !reduceMotion), in: shape)
            }
        } else {
            content.background(theme.surface, in: shape)
                .overlay(shape.stroke(theme.border.opacity(contrast == .increased ? 1 : 0.7), lineWidth: contrast == .increased ? 1.5 : 0.7).allowsHitTesting(false))
        }
    }
}

/// Group nearby custom glass controls so the system can render them together.
struct InvokeGlassGroup<Content: View>: View {
    let spacing: CGFloat
    private let content: () -> Content
    init(spacing: CGFloat = 12, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }
    var body: some View {
        if #available(iOS 26.0, *) { GlassEffectContainer(spacing: spacing) { content() } }
        else { content() }
    }
}

private struct InvokeScreenModifier: ViewModifier {
    @Environment(\.invokeTheme) private var theme
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *), store.data.preferences.glassStyle != "solid", !reduceTransparency, contrast != .increased {
            // Keep the system's real Liquid Glass navigation/tab bars unobscured.
            base(content).toolbarColorScheme(theme.scheme, for: .navigationBar, .tabBar)
        } else {
            base(content).toolbarBackground(theme.background, for: .navigationBar, .tabBar)
                .toolbarBackground(.visible, for: .navigationBar, .tabBar)
                .toolbarColorScheme(theme.scheme, for: .navigationBar, .tabBar)
        }
    }
    private func base(_ content: Content) -> some View {
        content.foregroundStyle(theme.text).tint(theme.accent).scrollContentBackground(.hidden).background(ScreenBackground())
    }
}
