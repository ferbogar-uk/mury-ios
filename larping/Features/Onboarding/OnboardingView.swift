import SwiftData
import SwiftUI

/// First launch after the theme choice: connect Apple Health (optional), confirm the profile, pick interests.
/// Everything is stored on the device. Health is never required: without it the profile is typed by hand.
struct OnboardingView: View {
    let onFinished: () -> Void

    @Environment(\.brandTheme) private var theme
    @Environment(\.modelContext) private var modelContext

    private enum Step { case health, profile, interests }
    @State private var step = Step.health
    @State private var profile = ProfileStorage.load()
    @State private var isWorking = false
    @State private var healthMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch step {
                case .health: healthStep
                case .profile: profileStep
                case .interests: interestsStep
                }
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(theme.ink)
        .background(theme.canvas)
    }

    // MARK: Steps

    private var healthStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            header("Bring your history", "MURY can read your workouts, routes and heart rate from Apple Health, plus your birth date, sex, height and weight. The last 90 days of workouts come in right away, and new ones follow. It all stays on this phone.")
            if HealthKitService.isAvailable {
                if let healthMessage {
                    Label(healthMessage, systemImage: "checkmark.circle")
                    primaryButton("Continue", id: "onboarding-continue") { step = .profile }
                } else {
                    primaryButton(isWorking ? "Importing…" : "Connect Apple Health", id: "onboarding-connect-health") {
                        Task { await connectHealth() }
                    }
                    .disabled(isWorking)
                    if isWorking { ProgressView() }
                    Button("Not now") { step = .profile }
                        .disabled(isWorking)
                        .accessibilityIdentifier("onboarding-skip-health")
                }
            } else {
                Text("Apple Health isn't available on this device, so you'll enter your details by hand.")
                    .foregroundStyle(theme.muted)
                primaryButton("Continue", id: "onboarding-continue") { step = .profile }
            }
        }
    }

    private var profileStep: some View {
        let ready = profile.validationIssues(now: Date()).isEmpty
        return VStack(alignment: .leading, spacing: 20) {
            header("About you", "These give MURY accurate calories and heart-rate zones. Check what came from Health and fix anything that's off.")
            ProfileFormView(profile: $profile)
            primaryButton("Continue", id: "onboarding-continue") {
                ProfileStorage.save(profile)
                step = .interests
            }
            .disabled(!ready)
        }
    }

    private var interestsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            header("What do you want from MURY?", "Pick what fits. You can change this later.")
            Text("Sports you do").font(MuryTypography.font(.subheadline, size: 15, weight: .semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                ForEach(SportType.allCases) { sport in
                    let on = profile.sports.contains(sport)
                    Button {
                        if on { profile.sports.removeAll { $0 == sport } } else { profile.sports.append(sport) }
                    } label: {
                        Label(sport.label, systemImage: sport.symbolName)
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.bordered)
                    .tint(on ? theme.accent : theme.muted)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            Text("Your goal").font(MuryTypography.font(.subheadline, size: 15, weight: .semibold))
            Picker("Your goal", selection: Binding(get: { profile.goal }, set: { profile.goal = $0 })) {
                Text("Not set").tag(UsageGoal?.none)
                ForEach(UsageGoal.allCases, id: \.self) { Text($0.label).tag(UsageGoal?.some($0)) }
            }
            .pickerStyle(.menu)
            Text("Your level").font(MuryTypography.font(.subheadline, size: 15, weight: .semibold))
            Picker("Your level", selection: Binding(get: { profile.level }, set: { profile.level = $0 })) {
                Text("Not set").tag(FitnessLevel?.none)
                ForEach(FitnessLevel.allCases, id: \.self) { Text($0.label).tag(FitnessLevel?.some($0)) }
            }
            .pickerStyle(.segmented)
            primaryButton("Start", id: "onboarding-finish") {
                ProfileStorage.save(profile)
                onFinished()
            }
        }
    }

    // MARK: Pieces

    private func header(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(MuryTypography.font(.largeTitle, size: 30, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Text(text)
                .font(MuryTypography.font(.body, size: 16))
                .foregroundStyle(theme.muted)
        }
    }

    private func primaryButton(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(theme.onAccent)
        }
        .buttonStyle(.borderedProminent)
        .tint(theme.accent)
        .controlSize(.large)
        .accessibilityIdentifier(id)
    }

    // MARK: Health

    private func connectHealth() async {
        isWorking = true
        defer { isWorking = false }
        await HealthKitService.requestAuthorization()
        profile = profile.merging(health: await HealthKitService.readProfileSnapshot())
        let store = ActivitiesStore(modelContext: modelContext)
        store.refresh()
        let result = await HealthSync.run(store: store)
        healthMessage = result.imported == 0
            ? "Connected. No workouts to import from the last 90 days."
            : "Imported \(result.imported) workouts from the last 90 days."
    }
}
