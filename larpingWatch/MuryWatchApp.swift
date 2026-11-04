import SwiftUI

@main
struct MuryWatchApp: App {
    init() {
        MirrorReceiver.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
        }
    }
}
