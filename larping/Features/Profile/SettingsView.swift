import SwiftUI

struct SettingsView: View {
    @Environment(\.brandTheme) private var theme
    @AppStorage(BrandTheme.storageKey) private var themeSelection = ""
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system

    var body: some View {
        List {
            Section("Theme") {
                Picker("Colour theme", selection: $themeSelection) {
                    ForEach(BrandTheme.allCases) { option in
                        Text(option.label).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: 44)
                .accessibilityIdentifier("profile-theme")
            }
    
            Section("Appearance") {
                Picker("Appearance", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: 44)
                .accessibilityIdentifier("profile-appearance")
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.canvas)
        .navigationTitle("Settings")
    }
}
