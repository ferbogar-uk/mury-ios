import XCTest
@testable import larping

final class WatchControlsTests: XCTestCase {
    typealias S = MirrorSnapshot.State

    func testCommandRoundTrip() {
        for c in WatchCommand.allCases {
            XCTAssertEqual(WatchCommand(dictionary: c.dictionary), c)
        }
    }

    func testUnknownOrMalformedCommandIsRejected() {
        XCTAssertNil(WatchCommand(dictionary: [:]))
        XCTAssertNil(WatchCommand(dictionary: ["command": "start"]))
        XCTAssertNil(WatchCommand(dictionary: ["command": "PAUSE"]))
        XCTAssertNil(WatchCommand(dictionary: ["command": 1]))
        XCTAssertNil(WatchCommand(dictionary: ["other": "pause"]))
    }

    func testEveryStateAndCommandCombination() {
        let expected: [(S, WatchCommand, CommandDecision)] = [
            (.idle, .pause, .ignore), (.idle, .resume, .ignore), (.idle, .finish, .ignore),
            (.recording, .pause, .pause), (.recording, .resume, .ignore), (.recording, .finish, .finish),
            (.paused, .pause, .ignore), (.paused, .resume, .resume), (.paused, .finish, .finish),
        ]
        XCTAssertEqual(expected.count, 3 * WatchCommand.allCases.count)
        for (state, command, decision) in expected {
            XCTAssertEqual(WatchControls.decide(command, in: state), decision, "\(command) while \(state)")
        }
    }

    func testRepeatedPauseIsIgnored() {
        // The iPhone is already paused when the second "pause" arrives.
        XCTAssertEqual(WatchControls.decide(.pause, in: .paused), .ignore)
    }

    func testButtonsMatchWhatTheStateAccepts() {
        for state in [S.idle, .recording, .paused] {
            for command in WatchControls.availableCommands(in: state) {
                XCTAssertNotEqual(WatchControls.decide(command, in: state), .ignore, "\(command) shown while \(state)")
            }
            // And every accepted command is offered as a button.
            for command in WatchCommand.allCases where WatchControls.decide(command, in: state) != .ignore {
                XCTAssertTrue(WatchControls.availableCommands(in: state).contains(command))
            }
        }
    }

    func testButtonOrder() {
        XCTAssertEqual(WatchControls.availableCommands(in: .idle), [])
        XCTAssertEqual(WatchControls.availableCommands(in: .recording), [.pause, .finish])
        XCTAssertEqual(WatchControls.availableCommands(in: .paused), [.resume, .finish])
    }

    // MARK: finish confirmation

    func testFinishNeedsTwoTaps() {
        var f = FinishConfirmation()
        XCTAssertFalse(f.isAwaiting)
        XCTAssertTrue(f.requestFinish(in: .recording))
        XCTAssertTrue(f.isAwaiting)
        XCTAssertEqual(f.confirm(in: .recording), .finish)
        XCTAssertFalse(f.isAwaiting)
    }

    func testConfirmWithoutAFirstTapSendsNothing() {
        var f = FinishConfirmation()
        XCTAssertNil(f.confirm(in: .recording))
    }

    func testConfirmationIsOneShot() {
        var f = FinishConfirmation()
        _ = f.requestFinish(in: .paused)
        XCTAssertEqual(f.confirm(in: .paused), .finish)
        XCTAssertNil(f.confirm(in: .paused))
    }

    func testCancelClearsTheConfirmation() {
        var f = FinishConfirmation()
        _ = f.requestFinish(in: .recording)
        f.cancel()
        XCTAssertNil(f.confirm(in: .recording))
    }

    func testNothingToFinishWhenIdle() {
        var f = FinishConfirmation()
        XCTAssertFalse(f.requestFinish(in: .idle))
        XCTAssertFalse(f.isAwaiting)
    }

    func testRecordingEndingByItselfDropsAStaleConfirmation() {
        var f = FinishConfirmation()
        _ = f.requestFinish(in: .recording)
        f.stateChanged(to: .idle)
        XCTAssertFalse(f.isAwaiting)
        XCTAssertNil(f.confirm(in: .idle))
    }

    func testPausingWhileAwaitingKeepsTheConfirmation() {
        var f = FinishConfirmation()
        _ = f.requestFinish(in: .recording)
        f.stateChanged(to: .paused)
        XCTAssertTrue(f.isAwaiting)
        XCTAssertEqual(f.confirm(in: .paused), .finish)
    }
}
