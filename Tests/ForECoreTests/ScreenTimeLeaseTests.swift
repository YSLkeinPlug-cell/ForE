import XCTest
@testable import ForECore

final class ScreenTimeLeaseTests: XCTestCase {
    private func lease(ownership: ScreenTimeLease.Ownership = .uncertain,
                       phase: ScreenTimeLease.Phase = .arming) -> ScreenTimeLease {
        ScreenTimeLease(startedAt: 1_000, endsAt: 2_500, ownership: ownership, phase: phase)
    }

    func testUnfinishedActivationRequiresManualReviewAndHasNoReceipt() {
        let journal = lease()
        XCTAssertTrue(journal.needsManualReview)
        XCTAssertFalse(journal.canAutomaticallyRestore)
        XCTAssertNil(journal.receipt())
    }

    func testOnlyAppOwnedActiveOrRestoringLeaseCanAutomaticallyRestore() {
        for ownership in [ScreenTimeLease.Ownership.uncertain, .app, .external] {
            for phase in [ScreenTimeLease.Phase.arming, .active, .restoring, .attention] {
                let journal = lease(ownership: ownership, phase: phase)
                let expected = ownership == .app && (phase == .active || phase == .restoring)
                XCTAssertEqual(journal.canAutomaticallyRestore, expected,
                               "Unexpected restoration permission for \(ownership)/\(phase)")
            }
        }
    }

    func testExistingDowntimeIsNotTreatedAsAppOwned() {
        var journal = lease(ownership: .external, phase: .active)
        XCTAssertFalse(journal.needsManualReview)
        XCTAssertFalse(journal.canAutomaticallyRestore)
        journal.markFinished(at: 2_500, completed: true)
        XCTAssertEqual(journal.phase, .restoring)
        XCTAssertFalse(journal.canAutomaticallyRestore)
    }

    func testAttentionAlwaysRequiresReview() {
        for ownership in [ScreenTimeLease.Ownership.uncertain, .app, .external] {
            XCTAssertTrue(lease(ownership: ownership, phase: .attention).needsManualReview)
        }
        XCTAssertTrue(lease(ownership: .app, phase: .arming).needsManualReview)
    }

    func testFinishSnapshotIsPreservedAcrossRetries() throws {
        var journal = lease(ownership: .app, phase: .active)
        journal.markFinished(at: 1_600, completed: false)
        journal.markFinished(at: 3_000, completed: true)

        XCTAssertEqual(journal.phase, .restoring)
        XCTAssertEqual(journal.finishedAt, 1_600)
        XCTAssertEqual(journal.completed, false)
        let receipt = try XCTUnwrap(journal.receipt())
        XCTAssertEqual(receipt.id, journal.id)
        XCTAssertFalse(receipt.completed)
        XCTAssertEqual(receipt.duration, 600)
        XCTAssertTrue(receipt.domains.isEmpty)
    }

    func testUncertainFinishStillRequiresManualReview() {
        var journal = lease()
        journal.markFinished(at: 1_100, completed: false)
        XCTAssertEqual(journal.phase, .attention)
        XCTAssertTrue(journal.needsManualReview)
        XCTAssertFalse(journal.canAutomaticallyRestore)
        XCTAssertNil(journal.receipt())
    }

    func testUnconfirmedActivationCannotAwardTimeOrTreesAfterRecovery() throws {
        var journal = lease()
        journal.markFinished(at: 2_500, completed: true)
        let encoded = try JSONEncoder().encode(journal)
        var recovered = try JSONDecoder().decode(ScreenTimeLease.self, from: encoded)
        recovered.markFinished(at: 4_000, completed: false)
        XCTAssertNil(recovered.receipt())
        let statistics = FocusStatistics(sessions: recovered.receipt().map { [$0] } ?? [],
                                         now: Date(timeIntervalSince1970: 5_000))
        XCTAssertEqual(statistics.totalSeconds, 0)
        XCTAssertEqual(statistics.xp, 0)
        XCTAssertEqual(statistics.treesCount, 0)
    }

    func testDelayedFinishDoesNotAwardTimeBeyondDeadline() throws {
        var journal = lease(ownership: .app, phase: .active)
        journal.markFinished(at: 5_000, completed: true)
        XCTAssertEqual(try XCTUnwrap(journal.receipt()).duration, 1_500)
    }

    func testIncompleteSnapshotDoesNotProduceReceiptOrOverwriteOriginalField() {
        var journal = ScreenTimeLease(startedAt: 1_000, endsAt: 2_500,
                                     ownership: .app, phase: .restoring,
                                     finishedAt: 1_600, completed: nil)
        journal.markFinished(at: 3_000, completed: true)
        XCTAssertEqual(journal.finishedAt, 1_600)
        XCTAssertNil(journal.completed)
        XCTAssertNil(journal.receipt())
    }

    func testJournalRoundTripsAfterInterruptedRestore() throws {
        var journal = lease(ownership: .app, phase: .active)
        journal.markFinished(at: 1_600, completed: false)
        let encoded = try JSONEncoder().encode(journal)
        let restored = try JSONDecoder().decode(ScreenTimeLease.self, from: encoded)
        XCTAssertEqual(restored, journal)
        XCTAssertEqual(restored.receipt(), journal.receipt())
        XCTAssertTrue(restored.canAutomaticallyRestore)
    }
}
