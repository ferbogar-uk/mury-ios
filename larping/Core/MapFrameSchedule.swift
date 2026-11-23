import Foundation

/// Which frames of the in-app render copy a real map picture, and when the map has stopped changing.
/// Foundation only, so the rules are tested on Linux.
enum MapFrameSchedule {
    /// Even frames (and always the last one) copy the live map. The frames between are a blend of the two
    /// neighbouring copies, which halves the number of map copies, the slow part of the render.
    static func isKeyframe(index: Int, count: Int) -> Bool {
        index % 2 == 0 || index == count - 1
    }

    /// Average absolute difference between two same-size pixel samples, from 0 (identical) to 1.
    static func meanDifference(_ a: [UInt8], _ b: [UInt8]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 1 }
        var total = 0
        for i in 0..<a.count { total += abs(Int(a[i]) - Int(b[i])) }
        return Double(total) / Double(a.count * 255)
    }

    /// Below this the map is taken as finished loading. About 2.5 of 255 on average; chosen by reasoning, not yet
    /// measured on a phone (build 46).
    static let settledDifference = 0.01

    static func isSettled(difference: Double) -> Bool { difference < settledDifference }
}
