import SwiftUI

/// The selected Flow palette is applied after the neutral system launch screen.
struct SplashView: View {
    @Environment(\.brandTheme) private var theme

    var body: some View {
        theme.canvas
            .ignoresSafeArea()
            .overlay {
                Image("LogoHorizontal")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 56)
                    .foregroundStyle(theme.tint)
                    .accessibilityLabel("MURY")
            }
    }
}