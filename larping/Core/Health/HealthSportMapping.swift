import HealthKit

/// How MURY's activity types line up with Apple Health workout types, both ways.
/// Indoor running, cycling and rowing are told apart by Health's indoor flag.
extension HKWorkoutActivityType {
    init(sport: SportType) {
        switch sport {
        case .run, .treadmill: self = .running
        case .ride, .indoorCycle: self = .cycling
        case .walk: self = .walking
        case .hike: self = .hiking
        case .swim: self = .swimming
        case .rowing, .indoorRow: self = .rowing
        case .tennis: self = .tennis
        case .football: self = .soccer
        case .strength: self = .traditionalStrengthTraining
        case .stairs: self = .stairClimbing
        case .elliptical: self = .elliptical
        case .hiit: self = .highIntensityIntervalTraining
        case .yoga: self = .yoga
        case .pilates: self = .pilates
        case .core: self = .coreTraining
        case .dance: self = .cardioDance
        case .climbing: self = .climbing
        case .boxing: self = .boxing
        case .other: self = .other
        }
    }
}

extension SportType {
    init(workoutActivityType type: HKWorkoutActivityType, indoor: Bool = false) {
        switch type {
        case .running: self = indoor ? .treadmill : .run
        case .cycling: self = indoor ? .indoorCycle : .ride
        case .walking: self = .walk
        case .hiking: self = .hike
        case .swimming: self = .swim
        case .rowing: self = indoor ? .indoorRow : .rowing
        case .tennis: self = .tennis
        case .soccer: self = .football
        case .traditionalStrengthTraining, .functionalStrengthTraining: self = .strength
        case .stairClimbing, .stairs, .stepTraining: self = .stairs
        case .elliptical: self = .elliptical
        case .highIntensityIntervalTraining, .crossTraining, .mixedCardio: self = .hiit
        case .yoga: self = .yoga
        case .pilates, .barre: self = .pilates
        case .coreTraining: self = .core
        case .cardioDance, .socialDance: self = .dance
        case .climbing: self = .climbing
        case .boxing, .kickboxing, .martialArts: self = .boxing
        default: self = .other
        }
    }

    /// Type for a Health workout, reading its indoor flag.
    init(workout: HKWorkout) {
        let indoor = (workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool) ?? false
        self.init(workoutActivityType: workout.workoutActivityType, indoor: indoor)
    }
}
