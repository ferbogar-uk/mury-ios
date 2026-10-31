import SwiftUI

struct ThemeSelectionView: View {
    @Binding var selection: String
    @State private var preview: BrandTheme?

    private var theme: BrandTheme { preview ?? .tiffany }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image("LogoHorizontal")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300)
                    .foregroundStyle(theme.tint)
                    .accessibilityLabel("MURY")
                Text("MOVE  EXPLORE  SHARE")
                    .font(.caption.weight(.medium))
                    .tracking(3)
                    .foregroundStyle(theme.muted)
                VStack(spacing: 8) {
                    Text("Welcome to MURY")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("Record your walks, runs and rides, explore your routes, and share your movement.")
                        .foregroundStyle(theme.muted)
                }
                .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    Text("Choose your Flow")
                        .font(.title2.bold())
                    Text("Preview both colours. Change your theme and appearance anytime in Settings.")
                        .foregroundStyle(theme.muted)
                }
                .multilineTextAlignment(.center)

                ForEach(BrandTheme.allCases) { option in
                    Button {
                        preview = option
                    } label: {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(option.label).font(.headline)
                                Spacer()
                                Image(systemName: preview == option ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(option.tint)
                                    .accessibilityHidden(true)
                            }
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Theme preview")
                                    .font(.caption)
                                    .foregroundStyle(option.muted)
                                Label("Your next route", systemImage: "figure.run")
                                    .font(.title3.bold())
                                Image(systemName: "map")
                                    .font(.system(size: 42))
                                    .foregroundStyle(option.tint)
                                    .frame(maxWidth: .infinity, minHeight: 64)
                                    .accessibilityHidden(true)
                                Text("Start recording")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(option.onAccent)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(option.accent, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(16)
                            .background(option.canvas, in: RoundedRectangle(cornerRadius: 18))
                        }
                        .padding(16)
                        .foregroundStyle(option.ink)
                        .background(option.surface, in: RoundedRectangle(cornerRadius: 24))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(preview == option ? option.tint : option.border, lineWidth: preview == option ? 2 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.label + ", theme preview")
                    .accessibilityIdentifier("theme-" + option.rawValue)
                    .accessibilityAddTraits(preview == option ? .isSelected : [])
                }

                Button {
                    if let preview { selection = preview.rawValue }
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(theme.onAccent)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .controlSize(.large)
                .disabled(preview == nil)
                .accessibilityIdentifier("theme-continue")
                Text("Your activities stay on this device.")
                    .font(.footnote)
                    .foregroundStyle(theme.muted)
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(theme.ink)
        .background(theme.canvas)
    }
}
