import Foundation

// The backup file format, in one place, with nothing from Apple's frameworks in it.
//
// This is the contract between the apps: whatever writes a backup (this app today, an
// Android app one day) and whatever reads one must agree on exactly this shape.
//
// FORMAT, version 1
// - A JSON object: { "app": "Larping", "version": 1, "exportedAt": <date>, "activities": [...] }.
// - "app" must be exactly "Larping", otherwise the file is not ours and is refused.
// - Dates are ISO 8601 text in UTC with whole seconds, for example "2026-11-05T20:12:09Z".
//   There are NO fractional seconds: a date written by this app loses anything below one
//   second, and a reader must accept the form without fractions.
// - Every activity and every track point has a UUID "id". The id is what keeps an import
//   from adding the same activity twice.
// - Optional values with no value are left out of the file (BackupFormatTests checks this).
//   A reader should treat a missing key and a null the same way.
// - Track points are written oldest first.

enum BackupError: LocalizedError, Equatable {
    case invalidFile
    case notLarpingFile

    var errorDescription: String? {
        switch self {
        case .invalidFile: return "That file isn't a valid Larping backup."
        case .notLarpingFile: return "That file isn't a Larping backup."
        }
    }
}

struct BackupContainer: Codable {
    let app: String
    let version: Int
    let exportedAt: Date
    let activities: [BackupActivity]
}

struct BackupActivity: Codable {
    let id: UUID
    let sportTypeRaw: String
    let startedAt: Date
    let endedAt: Date?
    let durationSeconds: Int?
    let distanceMeters: Int?
    let elevationGainMeters: Int?
    let averageSpeedMps: Double?
    let maxSpeedMps: Double?
    let source: String
    let eventName: String?
    let createdAt: Date
    let trackPoints: [BackupTrackPoint]
}

struct BackupTrackPoint: Codable {
    let id: UUID
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let altitudeMeters: Double?
    let speedMps: Double?
    let heartRateBpm: Int?
    let cadenceRpm: Int?
}

extension JSONEncoder {
    static let pretty: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    /// Mirrors `JSONEncoder.pretty`'s date strategy, so exports round-trip.
    static let backup: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

/// What to do with the activities of a backup file, decided without touching any database.
///
/// Only adds: an activity whose id already exists is skipped, so importing the same file
/// twice, or an older file over newer data, never duplicates or destroys anything. The
/// same rule holds inside one file: a malformed file that lists an id twice imports it once.
enum BackupImportPlan {
    struct Result: Equatable {
        /// The activities to add, in file order.
        let toImport: [BackupActivity]
        /// How many were left out because their id already existed or repeated in the file.
        let skipped: Int
    }

    /// Reads and checks a backup file. Throws `invalidFile` when it cannot be read as a
    /// backup at all, and `notLarpingFile` when it is a valid JSON backup of another app.
    static func container(from data: Data) throws -> BackupContainer {
        let container: BackupContainer
        do {
            container = try JSONDecoder.backup.decode(BackupContainer.self, from: data)
        } catch {
            throw BackupError.invalidFile
        }
        guard container.app == "Larping" else { throw BackupError.notLarpingFile }
        return container
    }

    static func plan(for container: BackupContainer, existingIDs: Set<UUID>) -> Result {
        var toImport: [BackupActivity] = []
        var skipped = 0
        var seen: Set<UUID> = []
        for backup in container.activities {
            guard !existingIDs.contains(backup.id), !seen.contains(backup.id) else {
                skipped += 1
                continue
            }
            seen.insert(backup.id)
            toImport.append(backup)
        }
        return Result(toImport: toImport, skipped: skipped)
    }
}