import SwiftUI

/// A small, reachable native feasibility prototype. It exercises actual Metal shader fills,
/// but the Windows source-delivery environment cannot compile it or validate GPU behavior.
struct EffectsLabView: View {
    let theme: InvokeEffectTheme
    let level: InvokeEffectLevel
    @EnvironmentObject private var store: AppStore
    @State private var event = 0
    @State private var eventKind = EffectKind.card
    @State private var status = "Try the button and the story card."

    private var paper: Color {
        switch theme {
        case .ink: Color(red: 0.96, green: 0.94, blue: 0.89)
        case .velvet: Color(red: 0.08, green: 0.045, blue: 0.075)
        case .astral: Color(red: 0.035, green: 0.055, blue: 0.12)
        }
    }
    private var text: Color { theme == .ink ? Color(red: 0.11, green: 0.10, blue: 0.09) : Color(red: 0.96, green: 0.91, blue: 0.85) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("A little ceremony")
                    .font(.system(.largeTitle, design: .serif))
                Text("\(theme.title) · \(level.title) effects")
                    .font(.subheadline)
                Text("\((InvokeShaderStyle(rawValue: store.data.preferences.shaderStyle) ?? .theme).title) · \(store.data.preferences.effectIntensity, format: .percent.precision(.fractionLength(0))) intensity · \(store.data.preferences.effectSpeed, format: .number.precision(.fractionLength(1)))× speed")
                    .font(.footnote)
                Text("A native button and card for checking Invoke’s effects. These samples don’t change your stories.")
                    .font(.body)

                InvokePrimaryButton(title: "Enter the scene") {
                    status = "Scene entered immediately."
                    eventKind = .card
                    event += 1
                }

                Button {
                    eventKind = .card
                    event += 1
                    status = "Story card opened immediately."
                } label: {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("CURRENT STORY").font(.caption).tracking(2)
                        Text("The artist who lets herself be seen")
                            .font(.system(.title2, design: .serif))
                        Text("A small act still changes the page.").font(.body)
                        Label("Open story", systemImage: "arrow.up.right").font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .foregroundStyle(text)
                    .background {
                        RoundedRectangle(cornerRadius: 22).fill(text.opacity(0.035))
                        EffectSurface(theme: theme, level: level, trigger: event, kind: eventKind)
                    }
                }
                .buttonStyle(.plain)

                Text(status).font(.subheadline).accessibilityAddTraits(.updatesFrequently)

                InvokeGlassGroup(spacing: 12) {
                    VStack(spacing: 14) {
                        eventButton("Record a scene", symbol: "star", kind: .record)
                        eventButton("Dedicate a relic", symbol: "sparkles", kind: .relic)
                        eventButton("Open a chapter", symbol: "book", kind: .chapter)
                    }
                }
                Text("Effects stop after each moment. Reduce Motion, Reduce Transparency, Low Power Mode, and Off use a static frame. Scroll the card out of view or leave the app to check that rendering stops. Adjust style, intensity, speed, and material in Appearance.")
                    .font(.footnote)
            }
            .padding(22)
        }
        .foregroundStyle(text)
        .background(paper.ignoresSafeArea())
        .navigationTitle("Effects studio")
        .navigationBarTitleDisplayMode(.inline)
        .invokeScreen()
    }

    private func eventButton(_ title: String, symbol: String, kind: EffectKind) -> some View {
        Button {
            eventKind = kind
            event += 1
            status = "\(title) sample played."
        } label: {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .invokeGlassControl(in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack { EffectsLabView(theme: .astral, level: .subtle) }
        .environmentObject(AppStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("InvokeEffectsPreview", isDirectory: true)))
        .environment(\.invokeTheme, .astral)
}
