import Foundation

/// Text for the Profile screen, kept Foundation-only so it is tested on Linux.
enum ProfileSummary {
    /// Up to two capital letters from the name: "Ricardo Bueno" gives "RB", "Ricardo" gives "R", blank gives "M".
    static func initials(from name: String) -> String {
        let words = name.split(whereSeparator: { $0.isWhitespace }).filter { $0.first?.isLetter == true }
        let letters = words.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }
        return letters.isEmpty ? "M" : letters.joined()
    }

    /// "842 km" for large totals, one decimal below 100 km, "0 km" for none.
    static func totalDistance(meters: Double) -> String {
        let km = meters / 1000
        if km >= 100 { return "\(Int(km.rounded())) km" }
        if km <= 0 { return "0 km" }
        return String(format: "%.1f km", km)
    }

    /// "96 h" from 10 hours up, "9.5 h" below, "0 h" for none.
    static func totalTime(seconds: Int) -> String {
        let hours = Double(seconds) / 3600
        if hours >= 10 { return "\(Int(hours.rounded())) h" }
        if hours <= 0 { return "0 h" }
        return String(format: "%.1f h", hours)
    }

    enum BackupState: Equatable {
        case never
        case recent(Date)
        /// Older than `staleAfterDays`: the screen highlights it.
        case stale(Date)
    }

    static let staleAfterDays = 30

    static func backupState(lastBackup: Date?, now: Date, calendar: Calendar) -> BackupState {
        guard let lastBackup else { return .never }
        let days = calendar.dateComponents([.day], from: lastBackup, to: now).day ?? 0
        return days > staleAfterDays ? .stale(lastBackup) : .recent(lastBackup)
    }
}
