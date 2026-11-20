import Foundation

nonisolated enum BiologicalSex: String, Codable, CaseIterable, Sendable {
    case female, male, other
    var label: String {
        switch self {
        case .female: return "Female"
        case .male: return "Male"
        case .other: return "Other"
        }
    }
}

nonisolated enum ProfileSource: String, Codable, Sendable { case health, manual }

nonisolated enum FitnessLevel: String, Codable, CaseIterable, Sendable {
    case beginner, intermediate, advanced, pro
    var label: String { rawValue.capitalized }
}

nonisolated enum UsageGoal: String, Codable, CaseIterable, Sendable {
    case buildHabit, trainForEvent, stayHealthy, loseWeight, buildMuscle
    var label: String {
        switch self {
        case .buildHabit: return "Build a habit"
        case .trainForEvent: return "Train for an event"
        case .stayHealthy: return "Stay healthy"
        case .loseWeight: return "Lose weight"
        case .buildMuscle: return "Build muscle"
        }
    }
}

/// A profile number plus where it came from and when, so the newest source can win.
nonisolated struct ProfileValue<T: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    var value: T
    var source: ProfileSource
    var updatedAt: Date
}

/// What Apple Health knows about the person. Characteristics (birth date, sex) carry no sample date.
nonisolated struct HealthProfileSnapshot: Equatable, Sendable {
    var birthDate: Date?
    var sex: BiologicalSex?
    var heightCm: Double?
    var heightDate: Date?
    var weightKg: Double?
    var weightDate: Date?
}

nonisolated struct UserProfile: Codable, Equatable, Sendable {
    var birthDate: Date?
    var sex: BiologicalSex?
    var heightCm: ProfileValue<Double>?
    var weightKg: ProfileValue<Double>?
    var sports: [SportType] = []
    var goal: UsageGoal?
    var level: FitnessLevel?

    /// Health fills what is missing (birth date, sex) and replaces height or weight only when its sample is newer.
    func merging(health: HealthProfileSnapshot) -> UserProfile {
        var result = self
        if result.birthDate == nil { result.birthDate = health.birthDate }
        if result.sex == nil { result.sex = health.sex }
        if let cm = health.heightCm, let date = health.heightDate,
           result.heightCm == nil || date > result.heightCm!.updatedAt {
            result.heightCm = ProfileValue(value: cm, source: .health, updatedAt: date)
        }
        if let kg = health.weightKg, let date = health.weightDate,
           result.weightKg == nil || date > result.weightKg!.updatedAt {
            result.weightKg = ProfileValue(value: kg, source: .health, updatedAt: date)
        }
        return result
    }

    static let heightRangeCm = 50.0...300.0
    static let weightRangeKg = 20.0...400.0

    /// Messages to show next to the form; empty means the profile is complete and sensible.
    func validationIssues(now: Date, calendar: Calendar = UserProfile.utcCalendar) -> [String] {
        var issues: [String] = []
        if let birthDate {
            if birthDate > now { issues.append("Birth date can't be in the future.") }
            else if let age = age(now: now, calendar: calendar), age > 150 { issues.append("Check your birth date.") }
        } else { issues.append("Add your birth date.") }
        if sex == nil { issues.append("Choose an option for sex.") }
        if let heightCm {
            if !Self.heightRangeCm.contains(heightCm.value) { issues.append("Height should be between 50 and 300 cm.") }
        } else { issues.append("Add your height.") }
        if let weightKg {
            if !Self.weightRangeKg.contains(weightKg.value) { issues.append("Weight should be between 20 and 400 kg.") }
        } else { issues.append("Add your weight.") }
        return issues
    }

    func age(now: Date, calendar: Calendar = UserProfile.utcCalendar) -> Int? {
        guard let birthDate, birthDate <= now else { return nil }
        return calendar.dateComponents([.year], from: birthDate, to: now).year
    }

    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }
}

nonisolated enum ProfileStorage {
    static let key = "userProfile"

    static func load(_ defaults: UserDefaults = .standard) -> UserProfile {
        guard let data = defaults.data(forKey: key),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else { return UserProfile() }
        return profile
    }

    static func save(_ profile: UserProfile, to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key)
    }
}
