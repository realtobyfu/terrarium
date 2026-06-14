//
//  ExploreModels.swift
//  Terrarium — Domain
//
//  Pure value types for the Explore feature (Drift & Anchor). These are the
//  frozen contract (Stream H / Wave 0) every other Explore stream builds
//  against — see tasks/prd-explore-drift-anchor.md. Like the rest of Domain,
//  everything here is a plain value type: Equatable for deterministic tests,
//  Codable where it crosses the bundled-JSON catalog or the on-device store.
//
//  Nothing here imports CoreLocation / WeatherKit / SwiftData — the pure-domain
//  discipline keeps the ranker, cell math and assembler unit-testable with no
//  device. Real-world coordinates live in `Coordinate` (degrees), distinct from
//  the existing `SIMD2<Float>` sphere coordinates (radians) used for placement.
//

import Foundation

// MARK: - POI tag schema (FR-1)

/// What kind of place this is. Drives the ranker's category match and the
/// `category → specimenKind` mapping (FR-21).
enum POICategory: String, Equatable, Codable, CaseIterable {
    case park, coffee, bookstore, restaurant, viewpoint, market, museum, bar, other
}

/// Whether a place is sheltered — drives `weatherFit` (rainy → indoor).
enum IndoorOutdoor: String, Equatable, Codable, CaseIterable {
    case indoor, outdoor, mixed
}

/// Coarse time-of-day bucket. Both a POI tag (`bestTime`) and a context signal
/// (assembled from the clock in Stream B).
enum DayPart: String, Equatable, Codable, CaseIterable {
    case morning, afternoon, evening, night
}

/// Who a place suits.
enum GoodFor: String, Equatable, Codable, CaseIterable {
    case solo, date, group
}

/// Controlled vibe tags. Free-ish but enumerated so the ranker and onboarding
/// share one vocabulary.
enum Vibe: String, Equatable, Codable, CaseIterable {
    case quiet, lively, cozy, scenic, quirky
}

/// Price band. Raw values match the catalog JSON (`"free"`, `"$"`, `"$$"`, `"$$$"`).
enum PriceTier: String, Equatable, Codable, CaseIterable {
    case free
    case low = "$"
    case medium = "$$"
    case high = "$$$"
}

/// Provenance for QA (FR-3). `curated` = hand-authored; the rest = API seed.
enum POISource: String, Equatable, Codable, CaseIterable {
    case curated, foursquare, google, osm
}

/// A real-world coordinate in degrees. Deliberately not `CLLocationCoordinate2D`
/// so Domain stays free of CoreLocation; Stream B converts at the boundary.
struct Coordinate: Equatable, Codable, Hashable {
    var latitude: Double
    var longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// A curated point of interest carrying the full tag schema (FR-1). The catalog
/// is the moat; the ranker is only as good as these tags. `poiRef` is the stable,
/// immutable identity that feeds `POIPlacement` and `QuestGrounding`.
struct POI: Equatable, Codable, Identifiable {
    /// Stable id, e.g. `poi.sightglass-coffee.sf`. Immutable.
    var poiRef: String
    var name: String
    var category: POICategory
    /// e.g. "SoMa". Used for Drift seeding + novelty rollups.
    var neighborhood: String
    var coordinate: Coordinate
    var indoorOutdoor: IndoorOutdoor
    var bestTime: [DayPart]
    /// Subset of `Weather` where this place shines.
    var weatherFit: [Weather]
    var goodFor: [GoodFor]
    var vibe: [Vibe]
    var price: PriceTier
    /// Hours source key (API-backed) for open-now checks; nil = unknown.
    var hoursRef: String?
    /// Which terrarium specimen this grows (pilot maps to tree/building/flowers).
    var specimenKind: WorldProp.Kind
    var source: POISource

    var id: String { poiRef }

    init(poiRef: String,
         name: String,
         category: POICategory,
         neighborhood: String,
         coordinate: Coordinate,
         indoorOutdoor: IndoorOutdoor,
         bestTime: [DayPart],
         weatherFit: [Weather],
         goodFor: [GoodFor],
         vibe: [Vibe],
         price: PriceTier,
         hoursRef: String? = nil,
         specimenKind: WorldProp.Kind,
         source: POISource) {
        self.poiRef = poiRef
        self.name = name
        self.category = category
        self.neighborhood = neighborhood
        self.coordinate = coordinate
        self.indoorOutdoor = indoorOutdoor
        self.bestTime = bestTime
        self.weatherFit = weatherFit
        self.goodFor = goodFor
        self.vibe = vibe
        self.price = price
        self.hoursRef = hoursRef
        self.specimenKind = specimenKind
        self.source = source
    }
}

// MARK: - Persona / preferences (US-G1, FR-19)

/// The three pilot personas. Biases the ranker; does not branch the UI.
enum PersonaKind: String, Equatable, Codable, CaseIterable {
    case restlessLocal, newcomer, weekendDrifter
}

/// Captured in onboarding (a few taps), persisted, and fed into every
/// `RecommendationContext`. Defaults to the Restless Local (SF primary persona).
struct UserPreferences: Equatable, Codable {
    var persona: PersonaKind
    var interestCategories: [POICategory]
    var preferredVibes: [Vibe]
    /// Soft travel budget in meters; the ranker penalises beyond it.
    var travelRadiusMeters: Double

    init(persona: PersonaKind = .restlessLocal,
         interestCategories: [POICategory] = [],
         preferredVibes: [Vibe] = [],
         travelRadiusMeters: Double = 1500) {
        self.persona = persona
        self.interestCategories = interestCategories
        self.preferredVibes = preferredVibes
        self.travelRadiusMeters = travelRadiusMeters
    }

    /// Skip-onboarding default (US-G1): the Restless Local with sensible radius.
    static let `default` = UserPreferences()
}

// MARK: - Recommendation context (US-B3, FR-9)

/// Everything the ranker reads, assembled once from weather + clock + location +
/// persona (Stream B). Pure input — the ranker holds no clock/RNG/location of its
/// own, so ranking is deterministic given this value.
struct RecommendationContext: Equatable {
    var weather: Weather
    /// The moment this context was assembled (drives open-now + recency).
    var date: Date
    var timeOfDay: DayPart
    /// The user's current location, if a session is active; nil otherwise.
    var coordinate: Coordinate?
    var preferences: UserPreferences

    init(weather: Weather,
         date: Date,
         timeOfDay: DayPart,
         coordinate: Coordinate? = nil,
         preferences: UserPreferences = .default) {
        self.weather = weather
        self.date = date
        self.timeOfDay = timeOfDay
        self.coordinate = coordinate
        self.preferences = preferences
    }
}

// MARK: - Drift session + fog-of-war cells (US-E1, US-E2)

/// A discrete map cell (hex via H3 port, or geohash — see Open Question #1).
/// `id` is a stable string so it round-trips through the on-device store and
/// stays constant across launches (cell math is pure — Stream E).
struct DiscoveryCell: Equatable, Hashable, Codable, Identifiable {
    enum State: String, Equatable, Codable {
        /// Explored on an earlier session.
        case explored
        /// Lit during the current session — rendered visually distinct.
        case newThisSession
    }

    var id: String
    var state: State

    init(id: String, state: State) {
        self.id = id
        self.state = state
    }
}

/// An in-flight ramble. Records its breadcrumb trail and the cells it lit, only
/// while active. `endedAt == nil` means the session is running.
struct RambleSession: Equatable, Identifiable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var breadcrumbs: [Coordinate]
    var litCells: [DiscoveryCell]

    var isActive: Bool { endedAt == nil }

    init(id: UUID = UUID(),
         startedAt: Date = .now,
         endedAt: Date? = nil,
         breadcrumbs: [Coordinate] = [],
         litCells: [DiscoveryCell] = []) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.breadcrumbs = breadcrumbs
        self.litCells = litCells
    }
}

// MARK: - Discovery event (US-H1, US-F2)

/// What a discovery is anchored to: a curated POI (Anchor / grounded quest) or a
/// freshly-lit map cell (Drift).
enum DiscoveryTarget: Equatable, Codable, Hashable {
    case poi(poiRef: String)
    case cell(id: String)
}

/// The slice of context captured at discovery time so the specimen's appearance
/// can key off the moment (foggy vs clear) like the sky already does (FR-17).
struct DiscoveryContext: Equatable, Codable {
    var weather: Weather
    var timeOfDay: DayPart

    init(weather: Weather, timeOfDay: DayPart) {
        self.weather = weather
        self.timeOfDay = timeOfDay
    }
}

/// A recorded discovery — the unit that feeds the terrarium (specimen + journal)
/// and the fog-of-war / novelty bookkeeping. Persisted on-device only (FR-8).
struct Discovery: Equatable, Codable, Identifiable {
    var id: UUID
    var target: DiscoveryTarget
    var timestamp: Date
    var context: DiscoveryContext

    init(id: UUID = UUID(),
         target: DiscoveryTarget,
         timestamp: Date = .now,
         context: DiscoveryContext) {
        self.id = id
        self.target = target
        self.timestamp = timestamp
        self.context = context
    }
}
