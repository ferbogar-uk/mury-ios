import Foundation

/// The automatic title of an activity: sport, part of the day and, when known, the place.
/// "Corrida da manhã em Wembley", or just "Corrida da manhã" without a place.
///
/// Foundation only, so it is tested on Linux. The place comes from `PlaceNamer`, which is the
/// only part that talks to Apple; everything here works offline.
enum ActivityNamer {
    enum DayPart: Equatable {
        case madrugada, manha, almoco, tarde, fimDeTarde, noite

        var phrase: String {
            switch self {
            case .madrugada: "da madrugada"
            case .manha: "da manhã"
            case .almoco: "do almoço"
            case .tarde: "da tarde"
            case .fimDeTarde: "do fim de tarde"
            case .noite: "da noite"
            }
        }
    }

    /// `hour` is 0...23 in the person's own time zone.
    static func dayPart(hour: Int) -> DayPart {
        switch hour {
        case 5..<11: .manha
        case 11..<14: .almoco
        case 14..<17: .tarde
        case 17..<20: .fimDeTarde
        case 20..<24: .noite
        default: .madrugada
        }
    }

    static func noun(for sport: SportType) -> String {
        switch sport {
        case .run: "Corrida"
        case .ride: "Pedalada"
        case .walk: "Caminhada"
        case .hike: "Trilho"
        case .swim: "Natação"
        case .rowing: "Remo"
        case .tennis: "Ténis"
        case .football: "Futebol"
        case .strength: "Musculação"
        case .treadmill: "Passadeira"
        case .indoorCycle: "Bicicleta indoor"
        case .stairs: "Escadas"
        case .elliptical: "Elíptica"
        case .hiit: "HIIT"
        case .yoga: "Yoga"
        case .pilates: "Pilates"
        case .core: "Treino de core"
        case .dance: "Dança"
        case .climbing: "Escalada"
        case .indoorRow: "Remo indoor"
        case .boxing: "Boxe"
        case .other: "Treino"
        }
    }

    static func title(sport: SportType, hour: Int, place: String?) -> String {
        let base = "\(noun(for: sport)) \(dayPart(hour: hour).phrase)"
        let trimmed = place?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? base : "\(base) em \(trimmed)"
    }
}
