import SwiftUI

struct SettingsView: View {
    @Environment(\.brandTheme) private var theme
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system

    var body: some View {
        List {
            Section {
                Image("LogoHorizontal")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 180)
                    .accessibilityLabel("MURY")
                Text("Move. Explore. Achieve.")
                    .font(MuryTypography.font(.body, size: 17))
            }
            .listRowBackground(theme.surface)

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
        .toolbarBackground(theme.navigation, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
