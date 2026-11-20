import Foundation

/// Heart rate for activities without a route (gym, treadmill…), stored on the activity
/// itself because there are no GPS points to carry it. Compact JSON: [[seconds since 1970, bpm], …].
nonisolated enum HeartRateSeriesCodec {
    static func encode(_ samples: [HeartRateSample]) -> Data? {
        let valid = samples.filter { $0.bpm > 0 }.sorted { $0.timestamp < $1.timestamp }
        guard !valid.isEmpty else { return nil }
        let rows = valid.map { [($0.timestamp.timeIntervalSince1970 * 1000).rounded() / 1000, Double($0.bpm)] }
        return try? JSONEncoder().encode(rows)
    }

    /// Unreadable or empty data gives no samples, never a crash.
    static func decode(_ data: Data?) -> [HeartRateSample] {
        guard let data, let rows = try? JSONDecoder().decode([[Double]].self, from: data) else { return [] }
        return rows.compactMap { row in
            guard row.count == 2, row[1] > 0 else { return nil }
            return HeartRateSample(timestamp: Date(timeIntervalSince1970: row[0]), bpm: Int(row[1]))
        }
    }
}
