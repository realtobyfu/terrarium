//
//  OpenNowEvaluatorTests.swift
//  TerrariumTests
//
//  US-C2: Unit tests for OpenNowEvaluator.
//  Covers open, closed, and unknown-hours cases; also midnight-spanning ranges.
//

import Testing
import Foundation
@testable import Terrarium

@Suite("OpenNowEvaluator")
struct OpenNowEvaluatorTests {

    // -------------------------------------------------------------------------
    // MARK: Helpers
    // -------------------------------------------------------------------------

    /// Build a Calendar fixed to the local time zone so tests are timezone-stable.
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// Create a `Date` at a specific weekday (1=Sun…7=Sat), hour, and minute in UTC.
    /// We use 2026-01-04 (Sun) as anchor, so `weekday 1` = that Sunday.
    private func date(weekday: Int, hour: Int, minute: Int = 0) -> Date {
        // 2026-01-04 is a Sunday (weekday = 1 in Gregorian).
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 1
        // day 4 = Sun, 5 = Mon, 6 = Tue, 7 = Wed, 8 = Thu, 9 = Fri, 10 = Sat
        comps.day = 3 + weekday
        comps.hour = hour
        comps.minute = minute
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    // -------------------------------------------------------------------------
    // MARK: nil hours → .unknown
    // -------------------------------------------------------------------------

    @Test("nil hours returns .unknown")
    func nilHoursReturnsUnknown() {
        let result = OpenNowEvaluator.evaluate(hours: nil, at: date(weekday: 2, hour: 10), calendar: utcCalendar)
        #expect(result == .unknown)
    }

    // -------------------------------------------------------------------------
    // MARK: Simple open / closed cases
    // -------------------------------------------------------------------------

    @Test("Place is open during its posted hours")
    func openDuringHours() {
        // Mon–Fri 08:00–18:00
        let hours = OpeningHours.weekdays(TimeRange(openHour: 8, closeHour: 18))
        // Monday at 10:00
        let result = OpenNowEvaluator.evaluate(hours: hours, at: date(weekday: 2, hour: 10), calendar: utcCalendar)
        #expect(result == .open)
    }

    @Test("Place is closed before opening time")
    func closedBeforeOpening() {
        let hours = OpeningHours.weekdays(TimeRange(openHour: 8, closeHour: 18))
        // Monday at 07:59
        let result = OpenNowEvaluator.evaluate(hours: hours, at: date(weekday: 2, hour: 7, minute: 59), calendar: utcCalendar)
        #expect(result == .closed)
    }

    @Test("Place is closed after closing time")
    func closedAfterHours() {
        let hours = OpeningHours.weekdays(TimeRange(openHour: 8, closeHour: 18))
        // Monday at 18:01
        let result = OpenNowEvaluator.evaluate(hours: hours, at: date(weekday: 2, hour: 18, minute: 1), calendar: utcCalendar)
        #expect(result == .closed)
    }

    @Test("Place closed all day when schedule entry is empty array")
    func closedAllDayExplicitly() {
        let hours = OpeningHours(schedule: [2: []]) // Monday: closed all day
        let result = OpenNowEvaluator.evaluate(hours: hours, at: date(weekday: 2, hour: 12), calendar: utcCalendar)
        #expect(result == .closed)
    }

    // -------------------------------------------------------------------------
    // MARK: Missing weekday → .unknown
    // -------------------------------------------------------------------------

    @Test("Weekday missing from schedule returns .unknown")
    func missingWeekdayReturnsUnknown() {
        // Only Monday in schedule; check Tuesday
        let hours = OpeningHours(schedule: [2: [TimeRange(openHour: 9, closeHour: 17)]])
        let result = OpenNowEvaluator.evaluate(hours: hours, at: date(weekday: 3, hour: 12), calendar: utcCalendar)
        #expect(result == .unknown)
    }

    // -------------------------------------------------------------------------
    // MARK: Midnight-spanning ranges
    // -------------------------------------------------------------------------

    @Test("Midnight-spanning range: open late on Saturday night")
    func midnightSpanningRange() {
        // Saturday (weekday=7) open 22:00 → 02:00 (next day). closeMinute < openMinute.
        let range = TimeRange(openHour: 22, closeHour: 2)
        #expect(range.spansMidnight)

        let hours = OpeningHours(schedule: [7: [range]])
        // Saturday at 23:30 → open
        let late = OpenNowEvaluator.evaluate(hours: hours, at: date(weekday: 7, hour: 23, minute: 30), calendar: utcCalendar)
        #expect(late == .open)
    }

    @Test("Midnight-spanning range: closed mid-afternoon")
    func midnightSpanningRangeAfternoonClosed() {
        let range = TimeRange(openHour: 22, closeHour: 2)
        let hours = OpeningHours(schedule: [7: [range]])
        // Saturday at 14:00 → closed
        let afternoon = OpenNowEvaluator.evaluate(hours: hours, at: date(weekday: 7, hour: 14), calendar: utcCalendar)
        #expect(afternoon == .closed)
    }

    // -------------------------------------------------------------------------
    // MARK: AllWeek convenience
    // -------------------------------------------------------------------------

    @Test("allWeek builder: open on any day at matching time")
    func allWeekBuilder() {
        let hours = OpeningHours.allWeek(TimeRange(openHour: 6, closeHour: 22))
        for weekday in 1...7 {
            let result = OpenNowEvaluator.evaluate(hours: hours, at: date(weekday: weekday, hour: 9), calendar: utcCalendar)
            #expect(result == .open, "Expected open on weekday \(weekday)")
        }
    }

    @Test("allWeek builder: closed on any day before opening")
    func allWeekBuilderClosed() {
        let hours = OpeningHours.allWeek(TimeRange(openHour: 9, closeHour: 21))
        for weekday in 1...7 {
            let result = OpenNowEvaluator.evaluate(hours: hours, at: date(weekday: weekday, hour: 5), calendar: utcCalendar)
            #expect(result == .closed, "Expected closed on weekday \(weekday)")
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Exactly at close boundary
    // -------------------------------------------------------------------------

    @Test("Exactly at close minute is considered closed (exclusive upper bound)")
    func exactlyAtClose() {
        let hours = OpeningHours.weekdays(TimeRange(openHour: 8, closeHour: 18))
        // closeMinute = 18*60 = 1080; contains(minute: 1080) → false (exclusive)
        let result = OpenNowEvaluator.evaluate(hours: hours, at: date(weekday: 2, hour: 18, minute: 0), calendar: utcCalendar)
        #expect(result == .closed)
    }

    @Test("Exactly at open minute is considered open (inclusive lower bound)")
    func exactlyAtOpen() {
        let hours = OpeningHours.weekdays(TimeRange(openHour: 8, closeHour: 18))
        let result = OpenNowEvaluator.evaluate(hours: hours, at: date(weekday: 2, hour: 8, minute: 0), calendar: utcCalendar)
        #expect(result == .open)
    }
}
