import SwiftUI

#if DEBUG
@MainActor
extension AppStore {
    static func prepareLivingGrimoireUITestStorage(at directory: URL) throws {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--ui-testing"), arguments.contains("--ui-testing-fixture=corrupt-storage"),
              directory.lastPathComponent.hasPrefix("InvokeUITests-"),
              UUID(uuidString: String(directory.lastPathComponent.dropFirst("InvokeUITests-".count))) != nil else { return }
        let pointer = directory.appendingPathComponent("CURRENT")
        guard !FileManager.default.fileExists(atPath: pointer.path) else { return }
        var recovered = AppData()
        recovered.preferences.onboardingComplete = true
        recovered.grimoire.setupCompleted = true
        recovered.grimoire.upgradeIntroductionSeen = true
        var practice = PracticeDefinition()
        practice.title = "Test recovered practice"
        recovered.grimoire.practices = [practice]
        let payload = BackupPayload(data: recovered, images: [:])
        try BackupValidation.validate(payload)
        let recovery = directory.appendingPathComponent("recovery")
        try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true)
        try PersistenceCoding.encoder().encode(payload).write(to: recovery.appendingPathComponent("ui-fixture-recovery.invoke"), options: .atomic)
        let name = UUID().uuidString
        let generation = directory.appendingPathComponent("generations").appendingPathComponent(name)
        try FileManager.default.createDirectory(at: generation.appendingPathComponent("images"), withIntermediateDirectories: true)
        try Data("invoke-ui-recovery-sentinel".utf8).write(to: generation.appendingPathComponent("data.json"), options: .atomic)
        try Data(name.utf8).write(to: pointer, options: .atomic)
    }

    /// Synthetic records used only in an explicitly isolated UI-test session.
    func installLivingGrimoireUITestFixtureIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--ui-testing"), arguments.contains("--ui-testing-fixture=layout"),
              data.grimoire.practices.isEmpty, !data.preferences.onboardingComplete else { return }
        var value = data.grimoire
        let now = Date()
        for index in 0..<30 {
            var practice = PracticeDefinition()
            practice.title = index < 6
                ? "Arrange the documents and practical support needed for an important appointment — item \(index + 1)"
                : "A deliberately long practice name to verify wrapping, scrolling and comfortable reading — item \(index + 1)"
            practice.instructions = "This is a synthetic layout fixture. Review the practical details, choose the next useful action, and record only what was actually done."
            practice.importance = index < 6 ? .critical : .supporting
            practice.importanceReason = index < 6 ? "An explicitly chosen consequential appointment" : ""
            practice.schedule.startDate = LocalDay(now)
            practice.schedule.kind = .once
            if index < 6 { practice.schedule.hardDeadline = true; practice.schedule.deadlineHour = 18 }
            practice.effectiveFrom = now
            value.practices.append(practice)
        }
        data.grimoire = value
        flush()
    }
}

private struct UITestingDynamicTypeModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var original
    private var requested: DynamicTypeSize? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--ui-testing") else { return nil }
        if arguments.contains("--ui-testing-dynamic-type=accessibility3") { return .accessibility3 }
        if arguments.contains("--ui-testing-dynamic-type=small") { return .small }
        return nil
    }
    func body(content: Content) -> some View { content.environment(\.dynamicTypeSize, requested ?? original) }
}
#endif

extension View {
    @ViewBuilder func uiTestingDynamicType() -> some View {
        #if DEBUG
        modifier(UITestingDynamicTypeModifier())
        #else
        self
        #endif
    }
}
