import XCTest
@testable import ForECore

final class FocusStatisticsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    private func session(_ start: String, _ end: String, plannedEnd: String? = nil,
                         completed: Bool = true) -> FocusSession {
        FocusSession(domains: ["youtube.com"], startedAt: date(start), endedAt: date(end),
                     plannedEnd: date(plannedEnd ?? end), completed: completed)
    }

    func testEmptyHistoryHasNoInventedProgress() {
        let stats = FocusStatistics(sessions: [], now: date("2026-10-30T12:00:00Z"), calendar: calendar)
        XCTAssertEqual(stats.totalSeconds, 0)
        XCTAssertEqual(stats.todaySeconds, 0)
        XCTAssertEqual(stats.weekSeconds, 0)
        XCTAssertEqual(stats.currentStreak, 0)
        XCTAssertEqual(stats.treesCount, 0)
        XCTAssertEqual(stats.xp, 0)
        XCTAssertEqual(stats.level, 1)
        XCTAssertEqual(stats.lastSevenDays.count, 7)
        XCTAssertEqual(stats.currentWeekDays.count, 7)
        XCTAssertEqual(stats.recentWeeks.count, 8)
    }

    func testMidnightSessionSplitsIntoRealDailyDurations() {
        let item = session("2026-10-29T22:45:00Z", "2026-10-29T23:15:00Z")
        let stats = FocusStatistics(sessions: [item], now: date("2026-10-30T12:00:00Z"), calendar: calendar)
        XCTAssertEqual(stats.totalSeconds, 1_800)
        XCTAssertEqual(stats.todaySeconds, 900)
        XCTAssertEqual(stats.seconds(on: date("2026-10-29T12:00:00Z")), 900)
        XCTAssertEqual(stats.currentStreak, 2)
    }

    func testWeekStartsMondayEvenWhenInputCalendarStartsSunday() {
        var usCalendar = calendar
        usCalendar.firstWeekday = 1
        let sunday = session("2026-10-25T12:00:00Z", "2026-10-25T12:30:00Z")
        let monday = session("2026-10-26T12:00:00Z", "2026-10-26T12:45:00Z")
        let stats = FocusStatistics(sessions: [sunday, monday], now: date("2026-10-30T12:00:00Z"), calendar: usCalendar)
        XCTAssertEqual(stats.totalSeconds, 4_500)
        XCTAssertEqual(stats.weekSeconds, 2_700)
        XCTAssertEqual(stats.calendar.component(.weekday, from: stats.currentWeekDays[0].date), 2)
        XCTAssertEqual(stats.currentWeekDays[0].seconds, 2_700)
        XCTAssertEqual(stats.recentWeeks[6].seconds, 1_800)
    }

    func testDaylightSavingUsesElapsedTimeOnLongAndShortDays() {
        let spring = session("2026-03-28T23:00:00Z", "2026-03-29T22:00:00Z")
        let fall = session("2026-10-24T22:00:00Z", "2026-10-25T23:00:00Z")
        let stats = FocusStatistics(sessions: [spring, fall], now: date("2026-10-30T12:00:00Z"), calendar: calendar)
        XCTAssertEqual(stats.seconds(on: date("2026-03-29T12:00:00Z")), 23 * 3_600)
        XCTAssertEqual(stats.seconds(on: date("2026-10-25T12:00:00Z")), 25 * 3_600)
        XCTAssertEqual(stats.totalSeconds, 48 * 3_600)
    }

    func testInterruptedTimeCountsButDoesNotGrowTree() {
        let interrupted = session("2026-10-30T09:00:00Z", "2026-10-30T09:10:00Z",
                                  plannedEnd: "2026-10-30T09:25:00Z", completed: false)
        let completed = session("2026-10-30T10:00:00Z", "2026-10-30T10:25:00Z")
        let stats = FocusStatistics(sessions: [interrupted, completed], now: date("2026-10-30T12:00:00Z"), calendar: calendar)
        XCTAssertEqual(stats.totalSeconds, 35 * 60)
        XCTAssertEqual(stats.xp, 35)
        XCTAssertEqual(stats.treesCount, 1)
    }

    func testDelayedReceiptDoesNotAwardTimeBeyondDeadline() {
        let delayed = session("2026-10-30T09:00:00Z", "2026-10-30T10:00:00Z", plannedEnd: "2026-10-30T09:25:00Z")
        XCTAssertEqual(delayed.duration, 25 * 60)
        let stats = FocusStatistics(sessions: [delayed], now: date("2026-10-30T12:00:00Z"), calendar: calendar)
        XCTAssertEqual(stats.totalSeconds, 25 * 60)
    }

    func testStreakPersistsUntilTodayEndsThenBreaks() {
        let thursday = session("2026-10-29T09:00:00Z", "2026-10-29T09:25:00Z")
        let wednesday = session("2026-10-28T09:00:00Z", "2026-10-28T09:25:00Z")
        let friday = FocusStatistics(sessions: [thursday, wednesday], now: date("2026-10-30T12:00:00Z"), calendar: calendar)
        let saturday = FocusStatistics(sessions: [thursday, wednesday], now: date("2026-10-31T12:00:00Z"), calendar: calendar)
        XCTAssertEqual(friday.currentStreak, 2)
        XCTAssertEqual(saturday.currentStreak, 0)
    }

    func testLevelUsesActualWholeMinutes() {
        let item = session("2026-10-30T09:00:00Z", "2026-10-30T11:05:59Z")
        let stats = FocusStatistics(sessions: [item], now: date("2026-10-30T12:00:00Z"), calendar: calendar)
        XCTAssertEqual(stats.xp, 125)
        XCTAssertEqual(stats.level, 2)
        XCTAssertEqual(stats.levelProgress, 5.0 / 120, accuracy: 0.0001)
    }

    func testMalformedAndFutureIntervalsCannotAwardExtraTime() {
        let reverse = session("2026-10-30T10:00:00Z", "2026-10-30T09:00:00Z")
        let future = session("2026-10-31T10:00:00Z", "2026-10-31T10:30:00Z")
        let stats = FocusStatistics(sessions: [reverse, future], now: date("2026-10-30T12:00:00Z"), calendar: calendar)
        XCTAssertEqual(reverse.duration, 0)
        XCTAssertEqual(stats.totalSeconds, 0)
        XCTAssertEqual(stats.treesCount, 0)
    }

    func testPersistenceRoundTripsAndPreservesCanceledState() throws {
        let receipt = session("2026-10-30T09:00:00Z", "2026-10-30T09:10:00Z", completed: false)
        let stored = StoredData(sessions: [receipt], preferredMinutes: 45, dailyGoalMinutes: 90)
        let data = try JSONEncoder().encode(stored)
        XCTAssertEqual(try JSONDecoder().decode(StoredData.self, from: data), stored)
        let old = try JSONDecoder().decode(StoredData.self, from: Data("{}".utf8))
        XCTAssertEqual(old.domains, StoredData.defaultDomains)
        XCTAssertEqual(old.preferredMinutes, 25)
        XCTAssertThrowsError(try JSONDecoder().decode(StoredData.self, from: Data("{\"schemaVersion\":999}".utf8)))
    }
}
