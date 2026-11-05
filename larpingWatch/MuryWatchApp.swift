import SwiftUI

@main
struct MuryWatchApp: App {
    init() {
        MirrorReceiver.shared.activate()
        HeartRateMonitor.shared.onReading = { MirrorReceiver.shared.send($0) }
    }

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
        }
    }
}
