import SwiftUI

/// Shown on launch when the last flyover render was cut off (the app was closed by the system mid-render).
/// The text stays on the phone until the person shares or dismisses it.
struct RenderReport: Identifiable {
    let id = UUID()
    let text: String

    static func pending() -> RenderReport? {
        let log = RenderCrashLog.shared
        guard let crumb = log.interrupted() else { return nil }
        return RenderReport(text: RenderCrashLog.reportText(crumb, diagnostics: log.diagnosticsText()))
    }
}

struct RenderReportView: View {
    let report: RenderReport
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("The last flyover render closed the app")
                        .font(.title3.weight(.semibold))
                    Text("This report stays on your phone. Share it only if you want to send it to whoever is fixing the app.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(report.text)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    ShareLink(item: report.text, subject: Text("MURY render report")) {
                        Label("Share report", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("render-report-share")
                }
                .padding(16)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDone)
                        .accessibilityIdentifier("render-report-done")
                }
            }
        }
        .interactiveDismissDisabled()
    }
}
