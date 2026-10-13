import SwiftUI

private struct InvokePreview: View {
    let themeID: String
    @StateObject private var store: AppStore
    init(themeID: String) {
        self.themeID = themeID
        let store = AppStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("InvokePreview-\(UUID().uuidString)"))
        store.loadExamples()
        store.data.preferences.theme = themeID
        store.data.preferences.onboardingComplete = true
        _store = StateObject(wrappedValue: store)
    }
    var body: some View {
        InvokeRootView().environmentObject(store).environment(\.invokeTheme, InvokeTheme.named(themeID))
            .preferredColorScheme(InvokeTheme.named(themeID).scheme).tint(InvokeTheme.named(themeID).accent)
    }
}

#Preview("Ink & Omen") { InvokePreview(themeID: "ink") }
#Preview("Velvet Observatory") { InvokePreview(themeID: "velvet") }
#Preview("Astral Theatre") { InvokePreview(themeID: "astral") }
#Preview("Larger text") { InvokePreview(themeID: "ink").environment(\.dynamicTypeSize, .accessibility3) }
