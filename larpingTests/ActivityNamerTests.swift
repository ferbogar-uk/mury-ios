import XCTest
@testable import larping

final class ActivityNamerTests: XCTestCase {
    func testDayPartsCoverTheWholeDay() {
        let expected: [(Int, ActivityNamer.DayPart)] = [
            (0, .madrugada), (4, .madrugada), (5, .manha), (10, .manha), (11, .almoco),
            (13, .almoco), (14, .tarde), (16, .tarde), (17, .fimDeTarde), (19, .fimDeTarde),
            (20, .noite), (23, .noite),
        ]
        for (hour, part) in expected {
            XCTAssertEqual(ActivityNamer.dayPart(hour: hour), part, "hour \(hour)")
        }
    }

    func testTitleWithAndWithoutPlace() {
        XCTAssertEqual(ActivityNamer.title(sport: .run, hour: 8, place: "Wembley"), "Corrida da manhã em Wembley")
        XCTAssertEqual(ActivityNamer.title(sport: .run, hour: 8, place: nil), "Corrida da manhã")
        XCTAssertEqual(ActivityNamer.title(sport: .run, hour: 8, place: "  "), "Corrida da manhã")
        XCTAssertEqual(ActivityNamer.title(sport: .ride, hour: 18, place: nil), "Pedalada do fim de tarde")
        XCTAssertEqual(ActivityNamer.title(sport: .walk, hour: 22, place: nil), "Caminhada da noite")
    }

    func testRepeatedTitlesGetANumber() {
        let base = ActivityNamer.title(sport: .run, hour: 8, place: "Wembley")
        XCTAssertEqual(EventNamer.nextName(base: base, existing: [base]), "\(base) 1")
    }
}
