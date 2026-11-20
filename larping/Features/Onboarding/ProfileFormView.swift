import SwiftUI

/// Birth date, sex, height and weight. Used by the first-launch flow; Settings reuses it in a later phase.
/// Health pre-fills these when it can; whatever is typed here is stored as a manual value dated now.
struct ProfileFormView: View {
    @Binding var profile: UserProfile
    @Environment(\.brandTheme) private var theme
    @State private var heightText = ""
    @State private var weightText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Birth date").font(MuryTypography.font(.subheadline, size: 15, weight: .semibold))
                if profile.birthDate == nil {
                    Button("Add birth date") {
                        profile.birthDate = Calendar.current.date(byAdding: .year, value: -30, to: Date())
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("profile-add-birthdate")
                } else {
                    DatePicker("Birth date", selection: birthDateBinding, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .accessibilityIdentifier("profile-birthdate")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Sex").font(MuryTypography.font(.subheadline, size: 15, weight: .semibold))
                Picker("Sex", selection: sexBinding) {
                    Text("Not set").tag(BiologicalSex?.none)
                    ForEach(BiologicalSex.allCases, id: \.self) { Text($0.label).tag(BiologicalSex?.some($0)) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("profile-sex")
            }

            HStack(spacing: 14) {
                numberField("Height (cm)", text: $heightText, id: "profile-height")
                    .onChange(of: heightText) { _, text in profile.heightCm = typed(text, replacing: profile.heightCm) }
                numberField("Weight (kg)", text: $weightText, id: "profile-weight")
                    .onChange(of: weightText) { _, text in profile.weightKg = typed(text, replacing: profile.weightKg) }
            }

            ForEach(profile.validationIssues(now: Date()), id: \.self) { issue in
                Label(issue, systemImage: "exclamationmark.circle")
                    .font(MuryTypography.font(.footnote, size: 13))
                    .foregroundStyle(theme.muted)
            }
        }
        .onAppear {
            heightText = profile.heightCm.map { Self.format($0.value) } ?? ""
            weightText = profile.weightKg.map { Self.format($0.value) } ?? ""
        }
    }

    private var birthDateBinding: Binding<Date> {
        Binding(get: { profile.birthDate ?? Date() }, set: { profile.birthDate = $0 })
    }

    private var sexBinding: Binding<BiologicalSex?> {
        Binding(get: { profile.sex }, set: { profile.sex = $0 })
    }

    private func numberField(_ title: String, text: Binding<String>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(MuryTypography.font(.subheadline, size: 15, weight: .semibold))
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier(id)
        }
    }

    /// A typed number becomes a manual value dated now; empty or unreadable text clears it.
    private func typed(_ text: String, replacing current: ProfileValue<Double>?) -> ProfileValue<Double>? {
        guard let number = Double(text.replacingOccurrences(of: ",", with: ".")) else { return nil }
        if let current, current.value == number { return current }
        return ProfileValue(value: number, source: .manual, updatedAt: Date())
    }

    private static func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}
