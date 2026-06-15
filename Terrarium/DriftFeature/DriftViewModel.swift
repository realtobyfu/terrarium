//
//  DriftViewModel.swift
//  Terrarium — DriftFeature
//
//  US-E1 (ramble lifecycle) + US-E2 (cell discovery + fog-of-war).
//  Expanded from the Wave-0 skeleton (Stream H) to the full implementation.
//
//  Responsibilities
//  ────────────────
//  • startRamble() / endRamble() — session lifecycle + background-location
//    capability handshake.
//  • Consumes breadcrumbStream() → maps each fix to a geohash cell at
//    precision 7, records Discovery events in DiscoveryStore.
//  • Exposes live stats (elapsed time, distance) for the map overlay.
//  • Exposes the cells explored this session and all previously explored
//    cells for the fog-of-war map.
//  • generateRoute() — calls RouteGenerator with the current recommender
//    seeds, exposed for DriftView's route overlay.
//
//  Concurrency
//  ───────────
//  @Observable @MainActor — all state mutations happen on main. The breadcrumb
//  Task is created from main context and each breadcrumb is processed there.
//  The test suite marks tests @MainActor and injects a mock stream.
//

import Foundation
import Observation

// MARK: - RambleSummary

/// The result handed to the UI after `endRamble()`.
struct RambleSummary: Equatable {
    var newCellsCount: Int
    var totalCellsCount: Int
    var distanceMeters: Double
    var durationSeconds: TimeInterval
}

// MARK: - DriftViewModel

@Observable
@MainActor
final class DriftViewModel {

    // -------------------------------------------------------------------------
    // MARK: Published state
    // -------------------------------------------------------------------------

    /// The in-flight ramble, if one is running.
    private(set) var session: RambleSession?

    /// All cells lit this session (for new-this-session highlight colour).
    private(set) var newCells: Set<String> = []

    /// All cells ever explored (the union of all past + current sessions).
    private(set) var allExploredCells: Set<String> = []

    /// Live elapsed seconds (only increments while a session is active).
    private(set) var elapsedSeconds: TimeInterval = 0

    /// Live distance in metres accumulated from successive breadcrumbs.
    private(set) var distanceMeters: Double = 0

    /// Summary produced by `endRamble()`. Displayed on the post-session card.
    private(set) var summary: RambleSummary?

    /// Suggested route waypoints (US-E3). Nil until `generateRoute` is called.
    private(set) var routeWaypoints: [Coordinate]?

    /// The randomness setting for route generation (0 = seeds, 1 = random).
    var routeRandomness: Double = 0.3

    /// Target walk duration in minutes for route generation.
    var targetMinutes: Double = 30

    /// Scattered bonus spots for this session — walk into one to collect points.
    /// Computed near the walk's start; `collected` flips when its cell lights.
    private(set) var pointSpots: [PointSpot] = []

    /// Points earned during the current session (cells + collected spots).
    private(set) var pointsThisSession: Int = 0

    /// Garden tiers gained this session (drives the summary's "garden grew" beat).
    private(set) var tiersGainedThisSession: Int = 0

    /// Points per brand-new cell, and the jackpot for collecting a bonus spot.
    static let cellPoints = 2
    static let spotPoints = 25

    // -------------------------------------------------------------------------
    // MARK: Injected dependencies
    // -------------------------------------------------------------------------

    let location: LocationSessionProviding
    let recommender: PlaceRecommending
    let discoveries: DiscoveryStore
    let preferences: UserPreferences

    /// Persistent world store for future specimen growth (wired in Wave 3 / Stream F).
    var worldStore: WorldStore?

    // -------------------------------------------------------------------------
    // MARK: Private
    // -------------------------------------------------------------------------

    /// The async Task consuming the breadcrumb stream.
    private var breadcrumbTask: Task<Void, Never>?

    /// Timer task that ticks elapsed time every second.
    private var timerTask: Task<Void, Never>?

    /// Last breadcrumb position, used for incremental distance calculation.
    private var lastBreadcrumb: Coordinate?

    /// Context used to record cell discoveries (snapshot at session start).
    private var sessionContext: DiscoveryContext = DiscoveryContext(weather: .clear, timeOfDay: .morning)

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    init(
        location: LocationSessionProviding,
        recommender: PlaceRecommending,
        discoveries: DiscoveryStore,
        preferences: UserPreferences = .default
    ) {
        self.location = location
        self.recommender = recommender
        self.discoveries = discoveries
        self.preferences = preferences

        // Populate fog-of-war from the store so returning users see their
        // previously explored cells immediately.
        self.allExploredCells = discoveries.exploredCells()
    }

    // -------------------------------------------------------------------------
    // MARK: Session lifecycle (US-E1)
    // -------------------------------------------------------------------------

    /// Begin a ramble. Requests / uses `When In Use` location permission,
    /// starts the session, and begins consuming breadcrumbs.
    ///
    /// Calling `startRamble()` while a session is already active is a no-op.
    func startRamble() {
        guard session == nil || session?.isActive == false else { return }

        // Reset per-session state.
        newCells       = []
        elapsedSeconds = 0
        distanceMeters = 0
        lastBreadcrumb = nil
        summary        = nil
        routeWaypoints = nil
        pointSpots     = []
        pointsThisSession = 0
        tiersGainedThisSession = 0

        // Scatter bonus spots near where the walk begins (falls back to SF if
        // location is unavailable). Computed once per session, stable thereafter.
        Task { [weak self] in
            guard let self else { return }
            let center = await self.location.currentCoordinate()
                ?? Coordinate(latitude: 37.7596, longitude: -122.4269)
            if self.pointSpots.isEmpty {
                self.pointSpots = PointSpotField.spots(near: center)
            }
        }

        // Snapshot context at session start (weather/time — ideally injected
        // from a ContextAssembler in the container; default to clear/morning
        // until Stream F wires the live context).
        sessionContext = DiscoveryContext(weather: .clear, timeOfDay: currentDayPart())

        // Start the location layer.
        location.start()

        // Create the session value.
        session = RambleSession(startedAt: .now)

        // Consume breadcrumbs.
        breadcrumbTask = Task { [weak self] in
            guard let self else { return }
            for await coord in self.location.breadcrumbStream() {
                self.handleBreadcrumb(coord)
            }
        }

        // Live elapsed time counter.
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if !(Task.isCancelled) {
                    self?.elapsedSeconds += 1
                }
            }
        }
    }

    /// End the ramble, stop tracking, and produce a summary.
    ///
    /// Safe to call when no session is active (no-op).
    func endRamble() {
        guard var activeSession = session, activeSession.isActive else { return }

        // Stop the location layer first.
        location.stop()

        // Cancel the background tasks.
        breadcrumbTask?.cancel()
        breadcrumbTask = nil
        timerTask?.cancel()
        timerTask = nil

        // Finalise the session.
        activeSession.endedAt = .now
        activeSession.litCells = newCells.map {
            DiscoveryCell(id: $0, state: .newThisSession)
        }
        session = activeSession

        // Build summary.
        summary = RambleSummary(
            newCellsCount:   newCells.count,
            totalCellsCount: allExploredCells.count,
            distanceMeters:  distanceMeters,
            durationSeconds: elapsedSeconds
        )
    }

    // -------------------------------------------------------------------------
    // MARK: Route generation (US-E3)
    // -------------------------------------------------------------------------

    /// Generates a suggested loop walk from the current (or last known)
    /// position and stores it in `routeWaypoints`.
    ///
    /// - Parameters:
    ///   - context: The recommendation context used to fetch seeds. If nil,
    ///              a default context is assembled from stored preferences.
    func generateRoute(context: RecommendationContext? = nil) {
        let ctx = context ?? RecommendationContext(
            weather: .clear,
            date: Date(),
            timeOfDay: currentDayPart(),
            coordinate: session?.breadcrumbs.last,
            preferences: preferences
        )

        let seeds  = recommender.driftSeeds(ctx)
        let origin = ctx.coordinate ?? Coordinate(latitude: 37.7749, longitude: -122.4194)
        var rng    = SystemRandomNumberGenerator()

        routeWaypoints = RouteGenerator.generateLoop(
            from:          origin,
            targetMinutes: targetMinutes,
            randomness:    routeRandomness,
            seeds:         seeds,
            currentHour:   Calendar.current.component(.hour, from: Date()),
            rng:           &rng
        )
    }

    // -------------------------------------------------------------------------
    // MARK: Breadcrumb processing (US-E2)
    // -------------------------------------------------------------------------

    /// Called for each location fix while a session is active.
    private func handleBreadcrumb(_ coord: Coordinate) {
        guard var activeSession = session, activeSession.isActive else { return }

        // Accumulate distance.
        if let last = lastBreadcrumb {
            distanceMeters += RouteGenerator.haversine(last, coord)
        }
        lastBreadcrumb = coord

        // Append to session breadcrumbs.
        activeSession.breadcrumbs.append(coord)
        session = activeSession

        // Map to a geohash cell.
        let cellID = GeohashCell.encode(coord, precision: 7)

        // Determine cell state and record discovery if new to this session.
        let alreadyExplored = allExploredCells.contains(cellID)
        let isNewThisSession = !newCells.contains(cellID)

        if isNewThisSession {
            newCells.insert(cellID)
            allExploredCells.insert(cellID)

            let discovery = Discovery(
                target:    .cell(id: cellID),
                timestamp: .now,
                context:   sessionContext
            )
            discoveries.record(discovery)

            // Award points: a trickle for a brand-new cell, a jackpot for walking
            // into a bonus spot. Points drive globe growth (the per-cell "grow a
            // tree" specimen is gone — see PointSpot / WorldStore.awardPoints).
            var earned = alreadyExplored ? 0 : Self.cellPoints
            if let idx = pointSpots.firstIndex(where: { !$0.collected && $0.cellID == cellID }) {
                pointSpots[idx].collected = true
                earned += Self.spotPoints
            }
            if earned > 0 {
                pointsThisSession += earned
                if let award = worldStore?.awardPoints(earned) {
                    tiersGainedThisSession += award.tiersGained
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Helpers
    // -------------------------------------------------------------------------

    private func currentDayPart() -> DayPart {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default:      return .night
        }
    }
}
