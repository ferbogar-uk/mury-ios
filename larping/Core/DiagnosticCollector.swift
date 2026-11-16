import Foundation
import MetricKit

/// Receives the crash and memory reports iOS itself collects about this app (MetricKit, on the device only)
/// and keeps the newest on the phone, so the render report can include them. Nothing is sent anywhere.
nonisolated final class DiagnosticCollector: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = DiagnosticCollector()

    func start() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let json = payloads.map { String(decoding: $0.jsonRepresentation(), as: UTF8.self) }.joined(separator: "\n")
        guard !json.isEmpty else { return }
        try? Data(json.utf8).write(to: RenderCrashLog.shared.diagnosticsURL, options: .atomic)
    }
}
