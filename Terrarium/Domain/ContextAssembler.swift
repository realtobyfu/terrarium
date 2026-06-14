//
//  ContextAssembler.swift
//  Terrarium — Domain
//
//  US-B3 (FR-7, FR-9): Pure, deterministic assembler that builds a
//  `RecommendationContext` from the four raw inputs: weather reading, a moment
//  in time (wall-clock `Date`), an optional on-device `Coordinate`, and the
//  user's stored `UserPreferences`. It holds no clock, RNG, or location reader
//  of its own — callers supply `now` — so it is trivially unit-testable.
//
//  DayPart cutoffs (local calendar hour):
//    morning   05 – 11   ( 5:00 –  11:59 )
//    afternoon 12 – 16   (12:00 –  16:59 )
//    evening   17 – 20   (17:00 –  20:59 )
//    night     21 –  4   (21:00 – next 04:59 )
//
//  These mirror common urban-exploration patterns and are consistent with the
//  `bestTime` tags on POIs. Stream C's ranker reads the assembled `DayPart`,
//  so the cutoffs are the source of truth for the whole system.
//

import Foundation

// MARK: - DayPart derivation (pure, exported for tests)

/// Derive a `DayPart` from a calendar hour (0–23) in the local time zone.
///
/// Separated into a free function so it can be called without instantiating
/// a `ContextAssembler` and tested exhaustively.
///
/// - Parameter hour: Local calendar hour in `0...23`.
/// - Returns: The `DayPart` bucket for that hour.
func dayPart(forHour hour: Int) -> DayPart {
    switch hour {
    case 5...11:  return .morning
    case 12...16: return .afternoon
    case 17...20: return .evening
    default:      return .night   // 0–4 and 21–23
    }
}

// MARK: - Assembler

/// Builds `RecommendationContext` from injected inputs. All parameters must be
/// supplied by the caller; the assembler itself is side-effect free.
struct ContextAssembler {

    // MARK: Calendar injection (allows tests to fix the time zone)

    /// The calendar used to extract the hour from `now`. Defaults to the
    /// current (device) calendar so the real app sees local time. Tests
    /// inject a fixed-timezone calendar to avoid flakiness.
    let calendar: Calendar

    // MARK: Init

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    // MARK: Assembly

    /// Assemble a `RecommendationContext` from the four raw signals.
    ///
    /// - Parameters:
    ///   - weather:     The current weather reading (from `WeatherProviding`).
    ///   - now:         The exact moment the context is assembled (drives `DayPart`
    ///                  and is stored as `date` for open-now evaluation).
    ///   - coordinate:  The user's current position, if a session is active.
    ///                  Pass `nil` when no session is running.
    ///   - preferences: The user's stored preferences (persona, interests, radius).
    /// - Returns: A `RecommendationContext` ready to pass to the ranker.
    func assemble(
        weather: Weather,
        now: Date,
        coordinate: Coordinate? = nil,
        preferences: UserPreferences = .default
    ) -> RecommendationContext {
        let hour = calendar.component(.hour, from: now)
        let part = dayPart(forHour: hour)
        return RecommendationContext(
            weather: weather,
            date: now,
            timeOfDay: part,
            coordinate: coordinate,
            preferences: preferences
        )
    }
}
