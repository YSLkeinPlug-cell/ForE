import Foundation
import XCTest
import ForECore
@testable import ForEScreenTime

@MainActor
private final class MockScreenTimeBridge: ScreenTimeControlling {
    var isTrusted = true
    var state: DowntimeState
    var inspections = 0
    var mutations: [Bool] = []
    var failAfterNextMutation = false

    init(state: DowntimeState = .disabled) { self.state = state }

    func requestPermission() { }
    func openSettings() { }

    func inspect() async throws -> DowntimeState {
        inspections += 1
        return state
    }

    func setDowntime(enabled: Bool) async throws -> DowntimeState {
        mutations.append(enabled)
        state = enabled ? .enabled : .disabled
        if failAfterNextMutation {
            failAfterNextMutation = false
            throw MockFailure.readBackFailed
        }
        return state
    }

    private enum MockFailure: LocalizedError {
        case readBackFailed
        var errorDescription: String? { "The control changed, but read-back failed." }
    }
}

@MainActor
final class AppModelTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ForEAppTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeModel(bridge: MockScreenTimeBridge, directory: URL) -> AppModel {
        let model = AppModel(bridge: bridge,
                             storageURL: directory.appendingPathComponent("journal.json"),
                             startsTimer: false)
        model.setupConfirmed = true
        model.soundEnabled = false
        return model
    }

    private func waitUntilIdle(_ model: AppModel,
                               file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<200 {
            if !model.isBusy { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("AppModel did not finish its asynchronous operation within four seconds.",
                file: file, line: line)
    }

    func testAppOwnedDowntimeIsRestoredAndInterruptedHistoryIsWrittenOnce() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let bridge = MockScreenTimeBridge()
        let model = makeModel(bridge: bridge, directory: directory)

        model.startSession()
        try await waitUntilIdle(model)

        XCTAssertEqual(model.activeSession?.ownership, .app)
        XCTAssertEqual(model.activeSession?.phase, .active)
        XCTAssertEqual(model.downtimeEnabled, true)
        XCTAssertEqual(bridge.state, .enabled)
        XCTAssertEqual(bridge.mutations, [true])

        model.stopSession()
        try await waitUntilIdle(model)

        XCTAssertNil(model.activeSession)
        XCTAssertEqual(bridge.state, .disabled)
        XCTAssertEqual(bridge.mutations, [true, false])
        XCTAssertEqual(model.data.sessions.count, 1)
        XCTAssertFalse(try XCTUnwrap(model.data.sessions.first).completed)
        model.stopSession()
        XCTAssertEqual(model.data.sessions.count, 1)
        XCTAssertEqual(bridge.mutations, [true, false])
    }

    func testExistingDowntimeRemainsOnWithoutAnyMutation() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let bridge = MockScreenTimeBridge(state: .enabled)
        let model = makeModel(bridge: bridge, directory: directory)

        model.startSession()
        try await waitUntilIdle(model)

        XCTAssertEqual(model.activeSession?.ownership, .external)
        XCTAssertTrue(bridge.mutations.isEmpty)
        XCTAssertEqual(bridge.inspections, 1)

        model.stopSession()
        try await waitUntilIdle(model)

        XCTAssertNil(model.activeSession)
        XCTAssertEqual(bridge.state, .enabled)
        XCTAssertTrue(bridge.mutations.isEmpty)
        XCTAssertEqual(bridge.inspections, 1)
        XCTAssertEqual(model.data.sessions.count, 1)
        XCTAssertFalse(try XCTUnwrap(model.data.sessions.first).completed)
    }

    func testIndeterminateActivationRequiresManualReviewAndAwardsNoFocusTime() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let bridge = MockScreenTimeBridge()
        bridge.failAfterNextMutation = true
        let model = makeModel(bridge: bridge, directory: directory)

        model.startSession()
        try await waitUntilIdle(model)

        XCTAssertEqual(bridge.state, .enabled)
        XCTAssertEqual(model.activeSession?.ownership, .uncertain)
        XCTAssertTrue(model.needsRecovery)
        XCTAssertFalse(model.canStart)
        XCTAssertNil(model.downtimeEnabled)

        // The user restores the setting directly in macOS, outside this app.
        bridge.state = .disabled
        model.acknowledgeManualRecovery()

        XCTAssertNil(model.activeSession)
        XCTAssertTrue(model.canStart)
        XCTAssertEqual(bridge.mutations, [true])
        XCTAssertTrue(model.data.sessions.isEmpty)
        XCTAssertEqual(model.statistics.totalSeconds, 0)
        XCTAssertEqual(model.statistics.xp, 0)
        XCTAssertEqual(model.statistics.treesCount, 0)
    }

    func testRestartRequiresManualReviewWithoutRestoringFromStaleOwnership() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let bridge = MockScreenTimeBridge()
        let original = makeModel(bridge: bridge, directory: directory)
        original.startSession()
        try await waitUntilIdle(original)
        let originalID = try XCTUnwrap(original.activeSession).id
        let inspectionsBeforeRestart = bridge.inspections

        let recovered = makeModel(bridge: bridge, directory: directory)

        XCTAssertEqual(recovered.activeSession?.id, originalID)
        XCTAssertEqual(recovered.activeSession?.ownership, .app)
        XCTAssertEqual(recovered.activeSession?.phase, .attention)
        XCTAssertTrue(recovered.needsRecovery)
        XCTAssertFalse(recovered.canStart)
        XCTAssertEqual(bridge.state, .enabled)
        XCTAssertEqual(bridge.mutations, [true])
        XCTAssertEqual(bridge.inspections, inspectionsBeforeRestart)
        XCTAssertTrue(recovered.data.sessions.isEmpty)

        bridge.state = .disabled
        recovered.acknowledgeManualRecovery()
        XCTAssertEqual(bridge.mutations, [true])
        XCTAssertEqual(recovered.data.sessions.count, 1)
        XCTAssertFalse(try XCTUnwrap(recovered.data.sessions.first).completed)
    }

    func testManualSessionNeedsNoAccessibilityCallsAndNeverOwnsDowntime() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let bridge = MockScreenTimeBridge(state: .enabled)
        bridge.isTrusted = false
        let model = makeModel(bridge: bridge, directory: directory)

        model.startManualSession()

        XCTAssertEqual(model.activeSession?.ownership, .external)
        XCTAssertEqual(model.activeSession?.phase, .active)
        XCTAssertNil(model.downtimeEnabled)
        XCTAssertEqual(bridge.inspections, 0)
        XCTAssertTrue(bridge.mutations.isEmpty)

        model.stopSession()
        try await waitUntilIdle(model)

        XCTAssertNil(model.activeSession)
        XCTAssertEqual(bridge.state, .enabled)
        XCTAssertEqual(bridge.inspections, 0)
        XCTAssertTrue(bridge.mutations.isEmpty)
        XCTAssertEqual(model.data.sessions.count, 1)
    }

    func testMalformedOrInvalidJournalDisablesStartAndPreservesOriginalBytes() throws {
        struct InvalidDocument: Encodable {
            let version = 1
            let history = StoredData(domains: [])
            let lease = ScreenTimeLease(startedAt: 1e308, endsAt: 1.1e308,
                                        ownership: .app, phase: .active)
        }
        let corruptDocuments = [Data("{this is not valid JSON".utf8),
                                try JSONEncoder().encode(InvalidDocument())]
        for bytes in corruptDocuments {
            let directory = try temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let journal = directory.appendingPathComponent("journal.json")
            try bytes.write(to: journal)
            let bridge = MockScreenTimeBridge()
            let model = makeModel(bridge: bridge, directory: directory)

            XCTAssertFalse(model.canStart)
            XCTAssertNil(model.activeSession)
            XCTAssertEqual(model.remainingText, "00:00")
            XCTAssertNotNil(model.notice)
            model.startSession()
            model.startManualSession()
            XCTAssertEqual(bridge.inspections, 0)
            XCTAssertTrue(bridge.mutations.isEmpty)
            XCTAssertEqual(try Data(contentsOf: journal), bytes)
        }
    }
}
