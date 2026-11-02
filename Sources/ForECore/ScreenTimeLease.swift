import Foundation

/// A durable journal for a focus session and its observed manual Downtime change.
/// Ownership records what this app observed; it is not proof that every app or
/// website is blocked by the user's Screen Time configuration.
public struct ScreenTimeLease: Codable, Equatable, Identifiable {
    public enum Ownership: String, Codable {
        /// Activation may have happened, but read-back or journal commit failed.
        case uncertain
        /// Downtime was off, and this app observed its own activation succeed.
        case app
        /// Downtime was already on before this session.
        case external
    }

    public enum Phase: String, Codable {
        case arming
        case active
        case restoring
        case attention
    }

    public var id: UUID
    public var startedAt: Double
    public var endsAt: Double
    public var ownership: Ownership
    public var phase: Phase
    public var finishedAt: Double?
    public var completed: Bool?

    public init(id: UUID = UUID(), startedAt: Double, endsAt: Double,
                ownership: Ownership = .uncertain, phase: Phase = .arming,
                finishedAt: Double? = nil, completed: Bool? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.ownership = ownership
        self.phase = phase
        self.finishedAt = finishedAt
        self.completed = completed
    }

    /// Ambiguous transitions require the user's review instead of guessing that
    /// an existing Downtime state belongs to this app.
    public var needsManualReview: Bool {
        ownership == .uncertain || phase == .arming || phase == .attention
    }

    /// An existing or ambiguous Downtime setting must never be disabled on the
    /// basis of this journal. An attention state also stops automatic changes.
    public var canAutomaticallyRestore: Bool {
        ownership == .app && (phase == .active || phase == .restoring)
    }

    /// Keep the first finish snapshot so retries cannot add focus time or turn
    /// an interrupted session into a completed one.
    public mutating func markFinished(at timestamp: Double, completed didComplete: Bool) {
        if finishedAt == nil && completed == nil {
            finishedAt = timestamp
            completed = didComplete
        }
        phase = ownership == .uncertain ? .attention : .restoring
    }

    /// A focus-time receipt does not represent a verified per-app block list.
    public func receipt() -> FocusSession? {
        // An arming attempt never became a confirmed timer session. Recovery
        // must not award focus time merely because the attempt stayed on disk.
        guard ownership != .uncertain, let finishedAt, let completed else { return nil }
        return FocusSession(id: id, domains: [],
                            startedAt: Date(timeIntervalSince1970: startedAt),
                            endedAt: Date(timeIntervalSince1970: finishedAt),
                            plannedEnd: Date(timeIntervalSince1970: endsAt),
                            completed: completed)
    }
}
