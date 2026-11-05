import SwiftUI

/// Carries the "the watch asked to finish" flag from the app root down to the Record
/// tab, which shows the confirmation. The flag is a binding, so the Record tab can
/// clear it once the person has answered on the iPhone.
private struct FinishRequestedFromWatchKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var finishRequestedFromWatch: Binding<Bool> {
        get { self[FinishRequestedFromWatchKey.self] }
        set { self[FinishRequestedFromWatchKey.self] = newValue }
    }
}