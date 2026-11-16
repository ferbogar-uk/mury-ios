import Foundation

/// A note the flyover render leaves on the phone while it works, so an app that is closed by the system
/// (out of memory, crash) can say what it was doing when it was cut off. Nothing leaves the device: the
/// report is shown on the next launch and the person chooses whether to share it.
///
/// The note is removed when the render ends in any normal way (finished, cancelled, failed). A note that is
/// still there at the next launch therefore means the app was killed in the middle of a render.
nonisolated struct RenderBreadcrumb: Codable, Equatable {
    struct Sample: Codable, Equatable {
        var frame: Int
        var megabytes: Int
    }

    var startedAt: Date
    var lastUpdate: Date
    var frame: Int
    var total: Int
    var phase: String
    var megabytes: Int
    var samples: [Sample]
    var appVersion: String
    var systemVersion: String
    var device: String
}

nonisolated struct RenderCrashLog {
    let directory: URL
    /// How many memory samples are kept (one every `sampleEvery` frames), newest last.
    static let maxSamples = 16
    static let sampleEvery = 10
    /// The note is rewritten this often, to keep the cost per frame negligible.
    static let saveEvery = 5

    init(directory: URL) { self.directory = directory }

    static var shared: RenderCrashLog {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        return RenderCrashLog(directory: base)
    }

    var breadcrumbURL: URL { directory.appendingPathComponent("render-breadcrumb.json") }
    var diagnosticsURL: URL { directory.appendingPathComponent("metrickit-diagnostics.json") }

    func begin(total: Int, appVersion: String, systemVersion: String, device: String, now: Date = Date()) {
        write(RenderBreadcrumb(startedAt: now, lastUpdate: now, frame: 0, total: total, phase: "starting",
                               megabytes: 0, samples: [], appVersion: appVersion,
                               systemVersion: systemVersion, device: device))
    }

    /// Records progress. Only every `saveEvery`-th frame is written to disk.
    func update(frame: Int, phase: String, megabytes: Int, now: Date = Date()) {
        guard frame % Self.saveEvery == 0, var crumb = read() else { return }
        crumb.frame = frame
        crumb.phase = phase
        crumb.megabytes = megabytes
        crumb.lastUpdate = now
        if frame % Self.sampleEvery == 0 {
            crumb.samples.append(.init(frame: frame, megabytes: megabytes))
            if crumb.samples.count > Self.maxSamples { crumb.samples.removeFirst(crumb.samples.count - Self.maxSamples) }
        }
        write(crumb)
    }

    /// Called when the render ends normally. Leaves nothing behind.
    func clear() {
        try? FileManager.default.removeItem(at: breadcrumbURL)
    }

    /// The note of a render that never ended normally, if there is one.
    func interrupted() -> RenderBreadcrumb? { read() }

    /// Text the person can share: what was happening, memory over time, and any system diagnostics.
    static func reportText(_ crumb: RenderBreadcrumb, diagnostics: String?) -> String {
        var lines = [
            "MURY flyover render was interrupted",
            "Frame \(crumb.frame) of \(crumb.total), phase: \(crumb.phase)",
            "Memory at last save: \(crumb.megabytes) MB",
            "Ran for \(Int(crumb.lastUpdate.timeIntervalSince(crumb.startedAt))) s",
            "App \(crumb.appVersion), iOS \(crumb.systemVersion), \(crumb.device)",
        ]
        if !crumb.samples.isEmpty {
            lines.append("Memory by frame: " + crumb.samples.map { "\($0.frame)=\($0.megabytes)MB" }.joined(separator: ", "))
        }
        if let diagnostics, !diagnostics.isEmpty {
            lines.append("System diagnostics:")
            lines.append(String(diagnostics.prefix(8000)))
        }
        return lines.joined(separator: "\n")
    }

    func diagnosticsText() -> String? {
        guard let data = try? Data(contentsOf: diagnosticsURL) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Removes the note and the stored diagnostics once the person has seen the report.
    func dismiss() {
        clear()
        try? FileManager.default.removeItem(at: diagnosticsURL)
    }

    private func read() -> RenderBreadcrumb? {
        guard let data = try? Data(contentsOf: breadcrumbURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(RenderBreadcrumb.self, from: data)
    }

    private func write(_ crumb: RenderBreadcrumb) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(crumb) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: breadcrumbURL, options: .atomic)
    }
}
