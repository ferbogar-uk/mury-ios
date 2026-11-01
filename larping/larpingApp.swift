import SwiftData
import SwiftUI

@main
struct larpingApp: App {
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system
    @AppStorage(BrandTheme.storageKey) private var themeSelection = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSplash = true

    private var theme: BrandTheme { BrandTheme.resolvePreference(themeSelection) ?? .mury }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if BrandTheme.resolvePreference(themeSelection) != nil {
                    RootTabView()
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
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) { showSplash = false }
            }
        }
        .modelContainer(for: [CDActivity.self, CDTrackPoint.self])
    }
}
