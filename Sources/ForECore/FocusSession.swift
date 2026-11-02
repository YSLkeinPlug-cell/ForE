import Foundation

/// A receipt for elapsed focus time, capped at the planned session end.
/// It records the timer session, not verified Screen Time enforcement.
public struct FocusSession: Codable, Identifiable, Equatable {
    public var id: UUID
    public var domains: [String]
    public var startedAt: Date
    public var endedAt: Date
    public var plannedEnd: Date
    public var completed: Bool

    public init(id: UUID = UUID(), domains: [String], startedAt: Date,
                endedAt: Date, plannedEnd: Date, completed: Bool) {
        self.id = id
        self.domains = domains
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedEnd = plannedEnd
        self.completed = completed
    }

    public var duration: TimeInterval {
        let value = min(endedAt, plannedEnd).timeIntervalSince(startedAt)
        return value.isFinite ? max(0, value) : 0
    }
}

/// The app's local, versioned JSON document. Missing settings from older documents
/// receive defaults; invalid JSON remains an error for the UI to surface.
public struct StoredData: Codable, Equatable {
    // Retained for the original data format; ScreenTime rules live in macOS.
    public static let defaultDomains: [String] = []
    public var schemaVersion: Int
    public var sessions: [FocusSession]
    public var domains: [String]
    public var preferredMinutes: Int
    public var dailyGoalMinutes: Int

    public init(sessions: [FocusSession] = [], domains: [String] = Self.defaultDomains,
                preferredMinutes: Int = 25, dailyGoalMinutes: Int = 120) {
        schemaVersion = 1
        self.sessions = sessions
        self.domains = domains
        self.preferredMinutes = preferredMinutes
        self.dailyGoalMinutes = dailyGoalMinutes
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, sessions, domains, preferredMinutes, dailyGoalMinutes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        guard schemaVersion == 1 else {
            throw DecodingError.dataCorruptedError(forKey: .schemaVersion, in: container,
                                                  debugDescription: "Unsupported data version")
        }
        sessions = try container.decodeIfPresent([FocusSession].self, forKey: .sessions) ?? []
        domains = try container.decodeIfPresent([String].self, forKey: .domains) ?? Self.defaultDomains
        preferredMinutes = try container.decodeIfPresent(Int.self, forKey: .preferredMinutes) ?? 25
        dailyGoalMinutes = try container.decodeIfPresent(Int.self, forKey: .dailyGoalMinutes) ?? 120
    }
}
