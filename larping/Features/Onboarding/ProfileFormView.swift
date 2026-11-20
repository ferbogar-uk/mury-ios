import SwiftUI

/// Which profile fields came from Apple Health in this session, so the form can label them.
struct HealthFilledFields: OptionSet {
    let rawValue: Int
    static let birthDate = HealthFilledFields(rawValue: 1 << 0)
    static let sex = HealthFilledFields(rawValue: 1 << 1)
}

/// Birth date, sex, height and weight as a list of rows. Values from Health carry a "Health" tag; typing
/// a new value turns it into a manual value dated now. Used by the first-launch flow; Settings reuses it later.
struct ProfileFormView: View {
    @Binding var profile: UserProfile
    var healthFilled: HealthFilledFields = []
    @Environment(\.brandTheme) private var theme
    @State private var heightText = ""
    @State private var weightText = ""

    var body: some View {
        VStack(spacing: 10) {
            row("Birth date", fromHealth: healthFilled.contains(.birthDate) && profile.birthDate != nil) {
                if profile.birthDate == nil {
                    Button("Add") {
                        profile.birthDate = Calendar.current.date(byAdding: .year, value: -30, to: Date())
                    }
                    .font(MuryTypography.font(.body, size: 16, weight: .semibold))
                    .tint(theme.accent)
                    .accessibilityIdentifier("profile-add-birthdate")
                } else {
                    DatePicker("Birth date", selection: birthDateBinding, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .accessibilityIdentifier("profile-birthdate")
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Sex").font(MuryTypography.font(.body, size: 16))
                    if healthFilled.contains(.sex) && profile.sex != nil { healthTag }
                    Spacer()
                }
                Picker("Sex", selection: sexBinding) {
                    ForEach(BiologicalSex.allCases, id: \.self) { Text($0.label).tag(BiologicalSex?.some($0)) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("profile-sex")
            }
            .padding(14)
            .background(rowBackground)

            row("Height", fromHealth: profile.heightCm?.source == .health) {
                numberField(text: $heightText, unit: "cm", id: "profile-height")
                    .onChange(of: heightText) { _, text in profile.heightCm = typed(text, replacing: profile.heightCm) }
            }
            row("Weight", fromHealth: profile.weightKg?.source == .health) {
                numberField(text: $weightText, unit: "kg", id: "profile-weight")
                    .onChange(of: weightText) { _, text in profile.weightKg = typed(text, replacing: profile.weightKg) }
            }

            let issues = profile.validationIssues(now: Date())
            if !issues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(issues, id: \.self) { issue in
                        Label(issue, systemImage: "exclamationmark.circle")
                    }
                }
                .font(MuryTypography.font(.footnote, size: 13))
                .foregroundStyle(theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
        }
        .onAppear {
            heightText = profile.heightCm.map { Self.format($0.value) } ?? ""
            weightText = profile.weightKg.map { Self.format($0.value) } ?? ""
        }
    }

    // MARK: Pieces

    private func row<Trailing: View>(_ title: String, fromHealth: Bool, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 8) {
            Text(title).font(MuryTypography.font(.body, size: 16))
            if fromHealth { healthTag }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 56)
        .background(rowBackground)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.border.opacity(0.35), lineWidth: 1))
    }

    private var healthTag: some View {
        Text("Health")
            .font(MuryTypography.font(.caption2, size: 11, weight: .semibold))
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(theme.accent.opacity(0.12), in: Capsule())
            .accessibilityLabel("from Apple Health")
    }

    private func numberField(text: Binding<String>, unit: String, id: String) -> some View {
        HStack(spacing: 4) {
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(MuryTypography.font(.body, size: 17, weight: .semibold))
                .monospacedDigit()
                .frame(width: 72)
                .accessibilityIdentifier(id)
            Text(unit).foregroundStyle(theme.muted)
        }
    }

    private var birthDateBinding: Binding<Date> {
        Binding(get: { profile.birthDate ?? Date() }, set: { profile.birthDate = $0 })
    }

    private var sexBinding: Binding<BiologicalSex?> {
        Binding(get: { profile.sex }, set: { profile.sex = $0 })
    }

    /// A typed number becomes a manual value dated now; empty or unreadable text clears it.
    private func typed(_ text: String, replacing current: ProfileValue<Double>?) -> ProfileValue<Double>? {
        guard let number = Double(text.replacingOccurrences(of: ",", with: ".")) else { return nil }
        if let current, abs(current.value - number) < 0.05 { return current }
        return ProfileValue(value: number, source: .manual, updatedAt: Date())
    }

    private static func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}
