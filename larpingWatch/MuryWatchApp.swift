import SwiftUI

@main
struct MuryWatchApp: App {
    init() {
        MirrorReceiver.shared.activate()
        HeartRateMonitor.shared.onReading = {
            // The same reading goes to the watch's own recording and, when reachable, the iPhone.
            WatchRecorder.shared.receive($0)
            MirrorReceiver.shared.send($0)
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
        }
    }
}
