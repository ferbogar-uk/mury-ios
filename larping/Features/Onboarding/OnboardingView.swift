import SwiftData
import SwiftUI

/// First launch after the theme choice, one question per screen:
/// connect Health → confirm your details → sports → goal → a welcome that shows what was imported.
/// Health is never required: without it the details are typed by hand. Everything stays on the device.
struct OnboardingView: View {
    let onFinished: () -> Void

    @Environment(\.brandTheme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("displayName") private var displayName = "MURY User"

    enum Step: Int, CaseIterable { case health, profile, sports, goal, done }
    @State private var step = Step.health
    @State private var movingForward = true
    @State private var profile = ProfileStorage.load()
    @State private var healthFilled: HealthFilledFields = []
    @State private var isImporting = false
    @State private var importedCount: Int?
    @State private var latest: CDActivity?
    @State private var tapCount = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                content
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .id(step)
                    .transition(stepTransition)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) { footer }
        .foregroundStyle(theme.ink)
        .background(theme.canvas.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: tapCount)
    }

    // MARK: Frame

    private var header: some View {
        HStack(spacing: 14) {
            if step != .health && step != .done {
                Button { go(back: true) } label: {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Back")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.border.opacity(0.25))
                    Capsule().fill(theme.accent)
                        .frame(width: geo.size.width * CGFloat(step.rawValue + 1) / CGFloat(Step.allCases.count))
                }
            }
            .frame(height: 4)
            .accessibilityElement()
            .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
            Text("\(step.rawValue + 1) of \(Step.allCases.count)")
                .font(MuryTypography.font(.caption, size: 13))
                .monospacedDigit()
                .foregroundStyle(theme.muted)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85), value: step)
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .health: healthStep
        case .profile: profileStep
        case .sports: sportsStep
        case .goal: goalStep
        case .done: doneStep
        }
    }

    @ViewBuilder private var footer: some View {
        VStack(spacing: 6) {
            switch step {
            case .health:
                if HealthKitService.isAvailable {
                    primary(isImporting ? "Importing…" : "Connect Apple Health", id: "onboarding-connect-health", busy: isImporting) {
                        Task { await connectHealth() }
                    }
                    .disabled(isImporting)
                    secondary("Not now", id: "onboarding-skip-health") { go() }
                        .disabled(isImporting)
                } else {
                    primary("Continue", id: "onboarding-continue") { go() }
                }
            case .profile:
                primary("Continue", id: "onboarding-continue") {
                    ProfileStorage.save(profile)
                    go()
                }
                .disabled(!profile.validationIssues(now: Date()).isEmpty)
            case .sports:
                primary(profile.sports.isEmpty ? "Skip" : "Continue · \(profile.sports.count) chosen", id: "onboarding-sports-continue") {
                    ProfileStorage.save(profile)
                    go()
                }
            case .goal:
                primary(profile.goal == nil ? "Skip" : "Continue", id: "onboarding-goal-continue") {
                    ProfileStorage.save(profile)
                    Task { await loadLatest() }
                    go()
                }
            case .done:
                primary("See my activities", id: "onboarding-finish") {
                    ProfileStorage.save(profile)
                    onFinished()
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(theme.canvas.opacity(0.96).ignoresSafeArea(edges: .bottom))
    }

    // MARK: Steps

    private var healthStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            title("Your workouts, already here", "MURY reads Apple Health. Nothing leaves your iPhone.")
            VStack(alignment: .leading, spacing: 18) {
                benefit("map", "90 days of workouts with maps", "Including walks recorded on your Apple Watch")
                benefit("arrow.triangle.2.circlepath", "New workouts arrive on their own", "Recorded in another app? It shows up here")
                benefit("person.text.rectangle", "Your details, filled in", "Height, weight and age for accurate calories")
            }
            if !HealthKitService.isAvailable {
                Text("Apple Health isn't available on this device, so you'll enter your details by hand.")
                    .font(MuryTypography.font(.footnote, size: 14))
                    .foregroundStyle(theme.muted)
            }
        }
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            title("Check your details", healthFilled.isEmpty && profile.heightCm?.source != .health
                  ? "They give you accurate calories and heart-rate zones."
                  : "We filled these in from Apple Health. Tap any value to change it.")
            ProfileFormView(profile: $profile, healthFilled: healthFilled)
        }
    }

    private var sportsStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            title("What do you do?", "Pick as many as you like. Your Home adapts to them.")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(InterestSport.selectable, id: \.self) { sport in
                    SelectCard(title: sport.label, symbol: sport.symbolName, isOn: profile.sports.contains(sport)) {
                        if let index = profile.sports.firstIndex(of: sport) { profile.sports.remove(at: index) } else { profile.sports.append(sport) }
                        tapCount += 1
                    }
                }
            }
        }
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            title("What brings you to MURY?", "It shapes your Home and your goals.")
            VStack(spacing: 10) {
                ForEach(UsageGoal.allCases, id: \.self) { goal in
                    OptionRow(title: goal.label, detail: goal.detail, symbol: goal.symbolName, isOn: profile.goal == goal) {
                        profile.goal = goal
                        tapCount += 1
                    }
                }
            }
        }
    }

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            let first = displayName.split(separator: " ").first.map(String.init) ?? ""
            title(first.isEmpty || first == "MURY" ? "Welcome to MURY" : "Welcome, \(first)",
                  importedCount.map { $0 == 0 ? "No workouts in Health from the last 90 days. Your first recording starts here." : "We brought in \($0) workouts from the last 90 days." }
                  ?? "You're all set. Your first recording starts here.")
            if let latest {
                ActivityRouteCard(activity: latest, mapHeight: 160)
            }
        }
    }

    // MARK: Pieces

    private func title(_ text: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(MuryTypography.font(.largeTitle, size: 32, weight: .bold))
                .tracking(-0.6)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(MuryTypography.font(.body, size: 17))
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }

    private func benefit(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 42, height: 42)
                .background(theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(MuryTypography.font(.body, size: 16, weight: .semibold))
                Text(detail).font(MuryTypography.font(.subheadline, size: 14)).foregroundStyle(theme.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func primary(_ title: String, id: String, busy: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if busy { ProgressView().tint(theme.onAccent) }
                Text(title)
            }
            .font(MuryTypography.font(.headline, size: 17, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(theme.onAccent)
            .background(theme.accent, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier(id)
    }

    private func secondary(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(MuryTypography.font(.body, size: 16, weight: .semibold))
            .foregroundStyle(theme.ink)
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityIdentifier(id)
    }

    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let edge: Edge = movingForward ? .trailing : .leading
        return .asymmetric(insertion: .move(edge: edge).combined(with: .opacity),
                           removal: .move(edge: edge == .trailing ? .leading : .trailing).combined(with: .opacity))
    }

    private func go(back: Bool = false) {
        let next = Step(rawValue: step.rawValue + (back ? -1 : 1)) ?? step
        movingForward = !back
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.88)) { step = next }
    }

    // MARK: Health

    private func connectHealth() async {
        isImporting = true
        defer { isImporting = false }
        await HealthKitService.requestAuthorization()
        let snapshot = await HealthKitService.readProfileSnapshot()
        var filled: HealthFilledFields = []
        if profile.birthDate == nil, snapshot.birthDate != nil { filled.insert(.birthDate) }
        if profile.sex == nil, snapshot.sex != nil { filled.insert(.sex) }
        healthFilled = filled
        profile = profile.merging(health: snapshot)
        let store = ActivitiesStore(modelContext: modelContext)
        store.refresh()
        let result = await HealthSync.run(store: store)
        importedCount = result.imported
        go()
    }

    private func loadLatest() async {
        let store = ActivitiesStore(modelContext: modelContext)
        store.refresh()
        latest = store.activities.first
    }
}

// MARK: - Components

/// A large tappable card for multi-select, with a clear checked state (not just a colour change).
private struct SelectCard: View {
    let title: String
    let symbol: String
    let isOn: Bool
    let action: () -> Void
    @Environment(\.brandTheme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    SportSymbol(symbol, size: 24)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(isOn ? theme.accent : theme.ink)
                        .frame(height: 28)
                    Spacer()
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isOn ? theme.accent : theme.border.opacity(0.6))
                        .contentTransition(.symbolEffect(.replace))
                }
                Text(title)
                    .font(MuryTypography.font(.body, size: 16, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(minHeight: 96)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isOn ? theme.accent.opacity(0.08) : theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isOn ? theme.accent : theme.border.opacity(0.35), lineWidth: isOn ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(theme.ink)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A single-choice row with an icon, a title, a one-line explanation and a radio mark.
private struct OptionRow: View {
    let title: String
    let detail: String
    let symbol: String
    let isOn: Bool
    let action: () -> Void
    @Environment(\.brandTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isOn ? theme.accent : theme.ink)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(MuryTypography.font(.body, size: 16, weight: .semibold))
                    Text(detail).font(MuryTypography.font(.subheadline, size: 14)).foregroundStyle(theme.muted)
                }
                Spacer(minLength: 8)
                ZStack {
                    Circle().stroke(isOn ? theme.accent : theme.border.opacity(0.6), lineWidth: isOn ? 6 : 1.5)
                        .frame(width: 22, height: 22)
                }
                .animation(.snappy(duration: 0.2), value: isOn)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 68)
            .background(RoundedRectangle(cornerRadius: 16).fill(isOn ? theme.accent.opacity(0.08) : theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isOn ? theme.accent : theme.border.opacity(0.35), lineWidth: isOn ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(theme.ink)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Slight press-in for tappable cards and buttons; respects Reduce Motion.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}
