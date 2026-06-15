//
//  ContextAssemblerTests.swift
//  TerrariumTests
//
//  US-B3: Tests for `ContextAssembler` and the free `dayPart(forHour:)` function.
//
//  All four `DayPart` buckets are tested, including boundary hours. Every
//  `Weather` value is tested. Coordinate-present and coordinate-absent paths
//  are both covered. The calendar is fixed to UTC to eliminate time-zone
//  flakiness.
//

import Testing
import Foundation
@testable import Terrarium

// MARK: - Helpers

private extension ContextAssemblerTests {
    /// Build a `Date` at the given UTC hour on an arbitrary fixed day.
    static func utcDate(hour: Int, minute: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: 2026, month: 6, day: 14,
                                             hour: hour, minute: minute))!
    }

    /// A UTC-fixed assembler so tests are timezone-independent.
    static var utcAssembler: ContextAssembler {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return ContextAssembler(calendar: cal)
    }
}

// MARK: - DayPart derivation

@Suite("dayPart(forHour:)")
struct DayPartHourTests {

    @Test("Hour 0 → night", arguments: [0, 1, 2, 3, 4])
    func earlyMorningIsNight(hour: Int) {
        #expect(dayPart(forHour: hour) == .night)
    }

    @Test("Hour 5 starts morning", arguments: [5, 6, 7, 8, 9, 10, 11])
    func morningHours(hour: Int) {
        #expect(dayPart(forHour: hour) == .morning)
    }

    @Test("Hour 12 starts afternoon", arguments: [12, 13, 14, 15, 16])
    func afternoonHours(hour: Int) {
        #expect(dayPart(forHour: hour) == .afternoon)
    }

    @Test("Hour 17 starts evening", arguments: [17, 18, 19, 20])
    func eveningHours(hour: Int) {
        #expect(dayPart(forHour: hour) == .evening)
    }

    @Test("Hours 21–23 are night", arguments: [21, 22, 23])
    func lateNightHours(hour: Int) {
        #expect(dayPart(forHour: hour) == .night)
    }

    @Test("Boundary: hour 4 is night, hour 5 is morning")
    func morningBoundary() {
        #expect(dayPart(forHour: 4) == .night)
        #expect(dayPart(forHour: 5) == .morning)
    }

    @Test("Boundary: hour 11 is morning, hour 12 is afternoon")
    func afternoonBoundary() {
        #expect(dayPart(forHour: 11) == .morning)
        #expect(dayPart(forHour: 12) == .afternoon)
    }

    @Test("Boundary: hour 16 is afternoon, hour 17 is evening")
    func eveningBoundary() {
        #expect(dayPart(forHour: 16) == .afternoon)
        #expect(dayPart(forHour: 17) == .evening)
    }

    @Test("Boundary: hour 20 is evening, hour 21 is night")
    func nightBoundary() {
        #expect(dayPart(forHour: 20) == .evening)
        #expect(dayPart(forHour: 21) == .night)
    }
}

// MARK: - Assembler

@Suite("ContextAssembler")
struct ContextAssemblerTests {

    private var assembler: ContextAssembler { Self.utcAssembler }

    // MARK: DayPart from now

    @Test("morning: 08:00 UTC → .morning")
    func assemblesMorning() {
        let ctx = assembler.assemble(weather: .clear, now: Self.utcDate(hour: 8))
        #expect(ctx.timeOfDay == .morning)
    }

    @Test("afternoon: 14:30 UTC → .afternoon")
    func assemblesAfternoon() {
        let ctx = assembler.assemble(weather: .clear, now: Self.utcDate(hour: 14, minute: 30))
        #expect(ctx.timeOfDay == .afternoon)
    }

    @Test("evening: 19:00 UTC → .evening")
    func assemblesEvening() {
        let ctx = assembler.assemble(weather: .clear, now: Self.utcDate(hour: 19))
        #expect(ctx.timeOfDay == .evening)
    }

    @Test("night: 23:00 UTC → .night")
    func assemblesNightLate() {
        let ctx = assembler.assemble(weather: .clear, now: Self.utcDate(hour: 23))
        #expect(ctx.timeOfDay == .night)
    }

    @Test("night: 02:00 UTC → .night")
    func assemblesNightEarly() {
        let ctx = assembler.assemble(weather: .clear, now: Self.utcDate(hour: 2))
        #expect(ctx.timeOfDay == .night)
    }

    // MARK: Weather pass-through

    @Test("Weather is passed through unchanged", arguments: Weather.allCases)
    func weatherPassthrough(weather: Weather) {
        let ctx = assembler.assemble(weather: weather, now: Self.utcDate(hour: 10))
        #expect(ctx.weather == weather)
    }

    // MARK: With / without coordinate

    @Test("Coordinate is nil when not supplied")
    func coordinateAbsent() {
        let ctx = assembler.assemble(weather: .fog, now: Self.utcDate(hour: 8))
        #expect(ctx.coordinate == nil)
    }

    @Test("Coordinate is preserved when supplied")
    func coordinatePresent() {
        let sf = Coordinate(latitude: 37.7749, longitude: -122.4194)
        let ctx = assembler.assemble(weather: .fog, now: Self.utcDate(hour: 8),
                                     coordinate: sf)
        #expect(ctx.coordinate == sf)
    }

    // MARK: UserPreferences

    @Test("Default preferences are applied when not supplied")
    func defaultPreferences() {
        let ctx = assembler.assemble(weather: .clear, now: Self.utcDate(hour: 10))
        #expect(ctx.preferences == .default)
    }

    @Test("Custom preferences are forwarded unchanged")
    func customPreferences() {
        let prefs = UserPreferences(persona: .newcomer,
                                    interestCategories: [.museum, .park],
                                    preferredVibes: [.scenic],
                                    travelRadiusMeters: 800)
        let ctx = assembler.assemble(weather: .clear, now: Self.utcDate(hour: 10),
                                     preferences: prefs)
        #expect(ctx.preferences == prefs)
        #expect(ctx.preferences.persona == .newcomer)
        #expect(ctx.preferences.travelRadiusMeters == 800)
    }

    // MARK: Date stored

    @Test("The supplied date is stored verbatim in the context")
    func dateIsStoredVerbatim() {
        let now = Self.utcDate(hour: 15, minute: 42)
        let ctx = assembler.assemble(weather: .cloudy, now: now)
        #expect(ctx.date == now)
    }

    // MARK: Determinism

    @Test("Same inputs always produce equal contexts (deterministic)")
    func deterministic() {
        let now = Self.utcDate(hour: 9)
        let sf = Coordinate(latitude: 37.7749, longitude: -122.4194)
        let prefs = UserPreferences.default
        let ctx1 = assembler.assemble(weather: .fog, now: now, coordinate: sf, preferences: prefs)
        let ctx2 = assembler.assemble(weather: .fog, now: now, coordinate: sf, preferences: prefs)
        #expect(ctx1 == ctx2)
    }

    // MARK: Each weather × each daypart matrix (spot-check)

    @Test("rain + morning + coordinate")
    func rainMorningWithCoord() {
        let coord = Coordinate(latitude: 37.78, longitude: -122.41)
        let ctx = assembler.assemble(weather: .rain, now: Self.utcDate(hour: 7), coordinate: coord)
        #expect(ctx.weather == .rain)
        #expect(ctx.timeOfDay == .morning)
        #expect(ctx.coordinate == coord)
    }

    @Test("snow + night + no coordinate")
    func snowNightNoCoord() {
        let ctx = assembler.assemble(weather: .snow, now: Self.utcDate(hour: 22))
        #expect(ctx.weather == .snow)
        #expect(ctx.timeOfDay == .night)
        #expect(ctx.coordinate == nil)
    }

    @Test("fog + evening + coordinate")
    func fogEveningWithCoord() {
        let coord = Coordinate(latitude: 37.76, longitude: -122.44)
        let ctx = assembler.assemble(weather: .fog, now: Self.utcDate(hour: 18), coordinate: coord)
        #expect(ctx.weather == .fog)
        #expect(ctx.timeOfDay == .evening)
    }

    @Test("cloudy + afternoon + no coordinate")
    func cloudyAfternoonNoCoord() {
        let ctx = assembler.assemble(weather: .cloudy, now: Self.utcDate(hour: 13))
        #expect(ctx.weather == .cloudy)
        #expect(ctx.timeOfDay == .afternoon)
        #expect(ctx.coordinate == nil)
    }
}
