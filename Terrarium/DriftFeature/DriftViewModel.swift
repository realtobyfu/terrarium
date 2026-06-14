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

            let state: DiscoveryCell.State = alreadyExplored ? .explored : .newThisSession
            let discovery = Discovery(
                target:    .cell(id: cellID),
                timestamp: .now,
                context:   sessionContext
            )
            discoveries.record(discovery)

            // US-F2 / US-F3: grow a specimen for each brand-new cell
            // (never seen before on any session). Re-explored cells don't grow
            // a second specimen.
            if !alreadyExplored, let store = worldStore {
                growSpecimen(forCell: cellID, context: sessionContext, store: store)
            }

            // Used by DriftView for rendering distinction.
            _ = state
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Specimen growth (US-F2, US-F3)
    // -------------------------------------------------------------------------

    /// Grow a specimen for a brand-new Drift cell discovery.
    ///
    /// Cell discoveries don't have a POI reference, so we:
    /// 1. Use `.other` category → `.flowers` kind (the "wandering" specimen).
    /// 2. Derive the variant from the session context weather.
    /// 3. Use the cell id as the `poiRef` so `POIPlacement` places it
    ///    deterministically — the same cell always grows in the same globe spot.
    /// 4. Write a journal entry (US-F3) with the cell id as the place name so
    ///    the tap-a-specimen interaction surfaces some discovery text.
    ///
    /// The award uses `HonorVerifier` — there's no second location check for
    /// Drift cells; the breadcrumb itself IS the verification.
    private func growSpecimen(forCell cellID: String,
                              context: DiscoveryContext,
                              store: WorldStore) {
        let variant = SpecimenMapping.variant(for: context.weather)
        let kind    = SpecimenMapping.kind(for: .other)  // .flowers

        // Reuse poiRef slot for the cell id so placement is deterministic.
        let quest = Quest(
            title:         "Explored \(cellID)",
            prompt:        "You wandered through a new area.",
            placeName:     "Cell \(cellID)",
            poiRef:        cellID,
            suggestedKind: kind
        )

        let prop = store.award(quest: quest, verifierKind: .honor, variant: variant)
        if let prop = prop {
            // US-F3: seed a discovery journal entry for this cell.
            store.addJournal(
                to:        prop,
                questId:   quest.id,
                text:      "Wandered into a new area.",
                placeName: "Drift discovery"
            )
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
