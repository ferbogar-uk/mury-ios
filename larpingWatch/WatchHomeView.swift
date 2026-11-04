import SwiftUI

struct WatchHomeView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "figure.run")
                .font(.title2)
            Text("MURY")
                .font(.headline)
            Text("Watch")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    WatchHomeView()
}
