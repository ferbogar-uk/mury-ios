import SwiftUI

/// The supplied identity follows the selected appearance after the system launch screen.
struct SplashView: View {
    @Environment(\.brandTheme) private var theme

    var body: some View {
        theme.canvas
            .ignoresSafeArea()
            .overlay {
                Image("LogoHorizontal")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 56)
                    .accessibilityLabel("MURY")
            }
    }
}