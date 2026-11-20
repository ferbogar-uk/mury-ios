import SwiftData
import SwiftUI

@main
struct larpingApp: App {
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system
    @AppStorage(BrandTheme.storageKey) private var themeSelection = ""
    @AppStorage("onboardingDone") private var onboardingDone = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSplash = true

    init() {
        DiagnosticCollector.shared.start()
        #if DEBUG
        // Seed once per test launch so Continue can update persistent preferences normally.
        if let seed = ProcessInfo.processInfo.environment["MURY_UI_TEST_BRAND_THEME"] {
            UserDefaults.standard.set(seed, forKey: BrandTheme.storageKey)
        }
        _themeSelection = AppStorage(wrappedValue: "", BrandTheme.storageKey)
        // UI tests that seed a theme skip the first-launch flow unless they ask to see it.
        if ProcessInfo.processInfo.environment["MURY_UI_TEST_BRAND_THEME"] != nil {
            let showOnboarding = ProcessInfo.processInfo.environment["MURY_UI_TEST_SHOW_ONBOARDING"] != nil
            UserDefaults.standard.set(!showOnboarding, forKey: "onboardingDone")
        }
        if ProcessInfo.processInfo.environment["MURY_UI_TEST_SKIP_ONBOARDING"] != nil {
            UserDefaults.standard.set(true, forKey: "onboardingDone")
        }
        #endif
    }

    private var theme: BrandTheme { BrandTheme.resolvePreference(themeSelection) ?? .mury }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if BrandTheme.resolvePreference(themeSelection) != nil {
                    if onboardingDone {
                        RootTabView()
                    } else {
                        OnboardingView { onboardingDone = true }
                    }
                } else {
                    ThemeSelectionView(selection: $themeSelection)
                }
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .environment(\.brandTheme, theme)
            .tint(theme.tint)
            .foregroundStyle(theme.ink)
            .preferredColorScheme(appearanceMode.colorScheme)
            .task {
                WatchMirror.shared.activate()
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) { showSplash = false }
            }
        }
        .modelContainer(for: [CDActivity.self, CDTrackPoint.self])
    }
}
