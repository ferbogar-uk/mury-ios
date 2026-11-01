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
                HStack(spacing: 6) {
                    ForEach(AppearanceMode.allCases) { mode in
                        let isSelected = appearanceMode == mode
                        Button {
                            appearanceMode = mode
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: mode.symbolName)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(mode.label)
                                    .font(.footnote.weight(.medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .frame(minHeight: 44)
                            .background(
                                isSelected ? theme.accent : Color.clear,
                                in: RoundedRectangle(cornerRadius: 20)
                            )
                            .foregroundStyle(
                                isSelected
                                    ? theme.onAccent
                                    : Color.secondary
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(mode.label)
                        .accessibilityIdentifier("appearance-" + mode.rawValue)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(4)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 20))
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.canvas)
        .navigationTitle("Settings")
    }
}
