import Foundation

public struct FocusDay: Identifiable, Equatable {
    public let date: Date
    public let seconds: TimeInterval
    public var id: Date { date }

    public init(date: Date, seconds: TimeInterval) {
        self.date = date
        self.seconds = seconds
    }
}

public struct FocusWeek: Identifiable, Equatable {
    public let start: Date
    public let seconds: TimeInterval
    public var id: Date { start }

    public init(start: Date, seconds: TimeInterval) {
        self.start = start
        self.seconds = seconds
    }
}

/// Calendar-aware totals; sessions crossing midnight are split by their actual
/// overlap, including 23-/25-hour days around daylight-saving changes.
public struct FocusStatistics {
    public let calendar: Calendar
    public let now: Date
    public let totalSeconds: TimeInterval
    public let todaySeconds: TimeInterval
    public let weekSeconds: TimeInterval
    public let currentStreak: Int
    public let completedSessions: Int
    public var treesCount: Int { completedSessions }
    public var xp: Int { Int(totalSeconds / 60) }
    public var level: Int { xp / 120 + 1 }
    public var levelProgress: Double { Double(xp % 120) / 120 }
    public let lastSevenDays: [FocusDay]
    public let currentWeekDays: [FocusDay]
    public let recentWeeks: [FocusWeek]
    private let intervals: [DateInterval]

    public init(sessions: [FocusSession], now: Date = Date(), calendar: Calendar = .current) {
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        mondayCalendar.minimumDaysInFirstWeek = 4
        self.calendar = mondayCalendar
        self.now = now
        let intervals = sessions.compactMap { session -> DateInterval? in
            let end = min(session.endedAt, session.plannedEnd, now)
            guard end > session.startedAt,
                  end.timeIntervalSinceReferenceDate.isFinite,
                  session.startedAt.timeIntervalSinceReferenceDate.isFinite else { return nil }
            return DateInterval(start: session.startedAt, end: end)
        }
        self.intervals = intervals

        func overlap(_ range: DateInterval) -> TimeInterval {
            intervals.reduce(0) { total, interval in
                total + max(0, min(interval.end, range.end).timeIntervalSince(max(interval.start, range.start)))
            }
        }
        func day(_ date: Date) -> FocusDay {
            let start = mondayCalendar.startOfDay(for: date)
            let end = mondayCalendar.date(byAdding: .day, value: 1, to: start)!
            return FocusDay(date: start, seconds: overlap(DateInterval(start: start, end: end)))
        }
        let today = mondayCalendar.startOfDay(for: now)
        let week = mondayCalendar.dateInterval(of: .weekOfYear, for: now)!
        totalSeconds = intervals.reduce(0) { $0 + $1.duration }
        todaySeconds = day(today).seconds
        weekSeconds = overlap(week)
        completedSessions = sessions.filter { $0.completed && $0.duration > 0 && $0.endedAt <= now }.count
        lastSevenDays = (-6...0).map { day(mondayCalendar.date(byAdding: .day, value: $0, to: today)!) }
        currentWeekDays = (0..<7).map { day(mondayCalendar.date(byAdding: .day, value: $0, to: week.start)!) }
        recentWeeks = (-7...0).map { offset in
            let start = mondayCalendar.date(byAdding: .weekOfYear, value: offset, to: week.start)!
            let end = mondayCalendar.date(byAdding: .weekOfYear, value: 1, to: start)!
            return FocusWeek(start: start, seconds: overlap(DateInterval(start: start, end: end)))
        }
        // A streak remains alive until the end of today, even before today's first session.
        var cursor = today
        if day(cursor).seconds == 0 {
            cursor = mondayCalendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        var streak = 0
        while day(cursor).seconds > 0 {
            streak += 1
            cursor = mondayCalendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        currentStreak = streak
    }

    public func seconds(on date: Date) -> TimeInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return seconds(in: DateInterval(start: start, end: end))
    }

    public func seconds(in range: DateInterval) -> TimeInterval {
        intervals.reduce(0) { total, interval in
            total + max(0, min(interval.end, range.end).timeIntervalSince(max(interval.start, range.start)))
        }
    }
}
