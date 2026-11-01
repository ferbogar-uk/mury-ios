import SwiftUI

struct ThemeSelectionView: View {
    @Binding var selection: String
    @Environment(\.brandTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image("LogoHorizontal")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300)
                    .accessibilityLabel("MURY")
                Text("Move. Explore. Achieve.")
                    .font(MuryTypography.font(.title3, size: 20, weight: .semibold))
                    .foregroundStyle(theme.muted)
                VStack(spacing: 12) {
                    Text("Welcome to MURY")
                        .font(MuryTypography.font(.largeTitle, size: 34, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Record your walks, runs and rides, explore your routes, and share your movement.")
                        .font(MuryTypography.font(.body, size: 17))
                        .foregroundStyle(theme.muted)
                }
                .multilineTextAlignment(.center)

                Button {
                    selection = BrandTheme.mury.rawValue
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(theme.onAccent)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .controlSize(.large)
                .accessibilityIdentifier("theme-continue")
                Text("Your activities stay on this device.")
                    .font(MuryTypography.font(.footnote, size: 13))
                    .foregroundStyle(theme.muted)
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(theme.ink)
        .background(theme.canvas)
    }
}
