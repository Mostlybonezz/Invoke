import SwiftUI

/// Presentation helpers use the same calendar policy as the domain, never a second scheduler.
enum GrimoirePresentation {
    static func calendar(_ settings: GrimoireSettings) -> Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = settings.followsTravelTimeZone ? .current : TimeZone(identifier: settings.homeTimeZoneID) ?? .current
        value.firstWeekday = settings.weekStartsOn
        value.minimumDaysInFirstWeek = 4
        return value
    }
    static func title(_ practice: PracticeDefinition, settings: GrimoireSettings) -> String {
        settings.fantasyLanguage || practice.plainTitle.isEmpty ? practice.title : practice.plainTitle
    }
    static func date(_ day: LocalDay, settings: GrimoireSettings) -> Date {
        calendar(settings).date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? Date()
    }
}

extension AppStore {
    func presentGrimoireError(_ action: () throws -> Void) {
        do { try action() } catch { errorMessage = error.localizedDescription }
    }
}

struct GrimoireTextField: View {
    let label: String
    @Binding var text: String
    var lines = 3
    var identifier = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline.weight(.medium))
            TextField(label, text: $text, axis: .vertical).lineLimit(lines...max(lines, 8))
                .accessibilityLabel(label).accessibilityIdentifier(identifier.isEmpty ? label : identifier)
        }.padding(.vertical, 3)
    }
}

struct OptionalDateField: View {
    let title: String
    @Binding var date: Date?
    var components: DatePickerComponents = .date
    var body: some View {
        Toggle(title, isOn: Binding(get: { date != nil }, set: { date = $0 ? Date() : nil }))
        if date != nil {
            DatePicker(title, selection: Binding(get: { date ?? Date() }, set: { date = $0 }), displayedComponents: components)
        }
    }
}

struct OptionalNumberField: View {
    let title: String
    @Binding var number: Double?
    var body: some View {
        TextField(title, value: $number, format: .number).keyboardType(.decimalPad).accessibilityLabel(title)
    }
}

struct DisciplinePicker: View {
    @Binding var value: Discipline
    var body: some View {
        Picker("Discipline", selection: $value) {
            ForEach(Discipline.allCases) { item in Label(item.title, systemImage: item.symbol).tag(item) }
        }
    }
}

struct GrimoireDetailText: View {
    let title: String
    let text: String
    @Environment(\.invokeTheme) private var theme
    var body: some View {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionEyebrow(text: title)
                Text(text).textSelection(.enabled).foregroundStyle(theme.text)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SavedFeedback: View {
    let message: String
    @Environment(\.invokeTheme) private var theme
    var body: some View {
        if !message.isEmpty {
            Label(message, systemImage: "checkmark.seal").font(.subheadline).foregroundStyle(theme.accent)
                .accessibilityAddTraits(.updatesFrequently)
        }
    }
}
