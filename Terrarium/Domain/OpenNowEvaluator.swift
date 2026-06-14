//
//  OpenNowEvaluator.swift
//  Terrarium — Domain
//
//  US-C2: Pure open-now evaluation (FR-10). No network at eval time — hours are
//  loaded ahead of time and handed in as a value type. `nil` hours → `.unknown`
//  which the ranker treats as a soft penalty (RulesRecommender.unknownHoursPenalty).
//
//  Keep this pure (no singletons, no clock reads inside the type) so it is
//  deterministic and unit-testable — the caller injects `date` and `calendar`.
//

import Foundation

// MARK: - Opening hours value type

/// A single contiguous open span on a given weekday. Both times are in minutes
/// since midnight (0–1439) so arithmetic stays integer and timezone-free.
/// Stores as `Int16` to stay small but exposed as `Int` for convenience.
struct TimeRange: Equatable, Codable {
    /// Minutes since midnight (0...1439).
    var openMinute: Int
    /// Minutes since midnight (0...1439). May equal `openMinute` (instantaneous —
    /// avoid in practice) or be *less* when the range spans midnight (e.g. bar
    /// open 22:00 → 02:00 encoded as openMinute 1320, closeMinute 120).
    var closeMinute: Int

    init(openMinute: Int, closeMinute: Int) {
        self.openMinute = openMinute
        self.closeMinute = closeMinute
    }

    /// Convenience: e.g. `TimeRange(open: 8, 0, close: 17, 30)`.
    init(openHour: Int, openMin: Int = 0, closeHour: Int, closeMin: Int = 0) {
        self.openMinute = openHour * 60 + openMin
        self.closeMinute = closeHour * 60 + closeMin
    }

    /// True when the range wraps midnight (closes the next calendar day).
    var spansMidnight: Bool { closeMinute < openMinute }

    /// Returns true if `minute` (minutes since midnight) falls within this range.
    func contains(minute: Int) -> Bool {
        if spansMidnight {
            return minute >= openMinute || minute < closeMinute
        } else {
            return minute >= openMinute && minute < closeMinute
        }
    }
}

/// Weekly opening hours — one array of `TimeRange` per weekday.
/// `weekday` index follows `Calendar.component(.weekday)`: 1 = Sunday … 7 = Saturday.
/// An empty array for a weekday means closed all day. A missing key (day not in
/// the dict) is treated as "unknown for that day" by the evaluator.
struct OpeningHours: Equatable, Codable {
    /// Keyed by weekday index (1 = Sun, 7 = Sat).
    var schedule: [Int: [TimeRange]]

    init(schedule: [Int: [TimeRange]] = [:]) {
        self.schedule = schedule
    }

    // MARK: Convenience builders

    /// Every day of the week has the same hours.
    static func allWeek(_ range: TimeRange) -> OpeningHours {
        let days = [1, 2, 3, 4, 5, 6, 7]
        return OpeningHours(schedule: Dictionary(uniqueKeysWithValues: days.map { ($0, [range]) }))
    }

    /// Weekdays (Mon–Fri) only.
    static func weekdays(_ range: TimeRange) -> OpeningHours {
        let days = [2, 3, 4, 5, 6] // Mon–Fri
        return OpeningHours(schedule: Dictionary(uniqueKeysWithValues: days.map { ($0, [range]) }))
    }
}

// MARK: - Open state

/// The result of evaluating whether a place is open at a given moment.
enum OpenState: Equatable {
    /// The place is definitively open right now.
    case open
    /// The place is definitively closed right now.
    case closed
    /// Hours are not known; the ranker applies a soft penalty rather than
    /// hard-excluding the place (FR-10, decisions: unknownHoursPenalty = 0.6).
    case unknown
}

// MARK: - Evaluator

/// Pure open-now evaluator. All inputs injected; no singletons or clock reads
/// inside the type — deterministic and unit-testable.
struct OpenNowEvaluator {

    /// Evaluate whether a place is open at `date` given its `hours`.
    ///
    /// - Parameters:
    ///   - hours: The place's weekly schedule, or `nil` if unknown.
    ///   - date: The moment to evaluate (usually `RecommendationContext.date`).
    ///   - calendar: Calendar used to extract weekday/hour/minute components.
    ///               Defaults to the user's current calendar (injected for tests).
    /// - Returns: `.open`, `.closed`, or `.unknown`.
    static func evaluate(
        hours: OpeningHours?,
        at date: Date,
        calendar: Calendar = .current
    ) -> OpenState {
        guard let hours else { return .unknown }

        let weekday = calendar.component(.weekday, from: date) // 1 = Sun
        guard let ranges = hours.schedule[weekday] else {
            // Weekday not in schedule → unknown for this day
            return .unknown
        }

        // Empty array for the day = explicitly closed all day
        if ranges.isEmpty { return .closed }

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let minuteOfDay = hour * 60 + minute

        return ranges.contains(where: { $0.contains(minute: minuteOfDay) }) ? .open : .closed
    }
}
