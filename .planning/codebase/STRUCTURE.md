# Codebase Structure

**Analysis Date:** 2026-06-17

## Directory Layout

```
Terrarium/
├── Terrarium/                      # Main app source
│   ├── App/                        # Composition root & routing
│   │   ├── TerrariumApp.swift      # @main entry point
│   │   ├── AppContainer.swift      # DI container
│   │   └── RootView.swift          # Onboarding router
│   │
│   ├── Domain/                     # Pure logic, protocols, models
│   │   ├── Models.swift            # Core types: Weather, SkyState, WorldState, Quest
│   │   ├── ExploreModels.swift     # POI schema, Coordinate, Discovery
│   │   ├── PersistenceModels.swift # SwiftData record types
│   │   ├── Providers.swift         # SkyStateProviding, WorldStateProviding (+ stubs)
│   │   ├── ExploreProviders.swift  # Frozen Wave-0 integration contract
│   │   │
│   │   ├── BundledPOICatalog.swift # Bundled SF-POI catalog loader
│   │   ├── RulesRecommender.swift  # Deterministic scoring engine
│   │   ├── RouteGenerator.swift    # BFS walk path generator
│   │   ├── RulesRecommender.swift  # Points tier system, vitality logic
│   │   │
│   │   ├── GeohashCell.swift       # Spatial indexing (precision 7)
│   │   ├── GeofenceTests.swift     # Geofence circle math
│   │   ├── PointSpot.swift         # Bonus collectible spawn points
│   │   ├── QuestGrounding.swift    # POI-ref validation
│   │   ├── QuestVerifier.swift     # LocationVerifier, HonorVerifier strategies
│   │   │
│   │   ├── LocationSessionManager.swift # CoreLocation wrapper
│   │   ├── WeatherKitProvider.swift     # WeatherKit wrapper
│   │   ├── SolarSkyStateProvider.swift  # Solar position + time
│   │   │
│   │   ├── WorldStore.swift        # SwiftData persistence engine
│   │   ├── PreferencesStore.swift   # UserDefaults bridge (persona + onboarding flag)
│   │   ├── ContextAssembler.swift   # RecommendationContext builder
│   │   ├── SpecimenMapping.swift    # POI category → WorldProp.Kind
│   │   └── OpenNowEvaluator.swift   # Hours-based availability check
│   │
│   ├── ExploreFeature/             # Shell & routing
│   │   └── ExploreShellView.swift   # 3-tab shell (Home · Drift · Anchor)
│   │
│   ├── HomeFeature/                # Globe & progress
│   │   ├── HomeView.swift
│   │   ├── HomeViewModel.swift
│   │   ├── SkyLayer.swift           # Dynamic gradient sky background
│   │   └── GardenProgressCard.swift # Tier display
│   │
│   ├── DriftFeature/               # Ramble & map
│   │   ├── DriftView.swift
│   │   ├── DriftViewModel.swift
│   │   ├── DriftControls.swift      # Start/stop, randomness slider
│   │   └── FogMapView.swift         # Geohash grid + fog-of-war
│   │
│   ├── AnchorFeature/              # Concierge & pick
│   │   ├── AnchorView.swift         # Main concierge screen
│   │   ├── AnchorViewModel.swift    # Ranking, re-roll, arrival
│   │   ├── DiscoveryHeroCard.swift  # Hero card component
│   │   ├── DestinationCardVariants.swift # Card design explorations
│   │   ├── PaletteWorkshop.swift    # Design system sandbox
│   │   └── ExperienceFlowDemo.swift # Demo/preview file
│   │
│   ├── JournalFeature/             # Reflection & growth log
│   │   ├── GrowthLogView.swift      # All specimens
│   │   ├── JournalListView.swift    # Specimen list UI
│   │   ├── SpecimenJournalView.swift # Single reflection
│   │   └── RewardOverlay.swift      # Achievement & tier-up animations
│   │
│   ├── OnboardingFeature/          # First-launch flow
│   │   ├── OnboardingFlowView.swift # Sequence driver
│   │   ├── OnboardingViewModel.swift # State & step navigation
│   │   └── OnboardingComponents.swift # Persona + interests UI
│   │
│   ├── DesignSystem/               # Reusable UI components
│   │   ├── LiquidGlassKit.swift     # Glass buttons, pills, top bar, nav
│   │   ├── ScenicArtBand.swift      # Decorative header band
│   │   ├── SkyPalette.swift         # Sky gradient colors by condition
│   │   ├── Components.swift         # Generic SwiftUI helpers
│   │   ├── Tokens.swift             # Typography, spacing constants
│   │   └── GardenTokens.swift       # Garden theme colors
│   │
│   ├── WorldRendering/             # RealityKit 3D
│   │   ├── WorldView.swift          # RealityKit wrapper + interaction
│   │   ├── GlobeEntityFactory.swift  # Sphere mesh + prop placement
│   │   ├── SpecimenFactory.swift    # Tree/building/flowers geometry
│   │   ├── GlobeTextureFactory.swift # Texture baking
│   │   ├── WorldLighting.swift      # Sun-driven directional lights
│   │   └── SpherePlacement.swift    # (Lat, Lon) → sphere coords
│   │
│   ├── Resources/                  # Data + assets
│   │   └── sf-pois.json             # Bundled POI catalog
│   │
│   └── Assets.xcassets/            # Image assets & app icon
│       ├── AppIcon.appiconset/
│       └── AccentColor.colorset/
│
├── TerrariumTests/                 # Unit tests
│   ├── AnchorViewModelTests.swift
│   ├── DriftViewModelTests.swift
│   ├── HomeViewModelTests.swift
│   ├── RulesRecommenderTests.swift
│   ├── RouteGeneratorTests.swift
│   ├── GeohashCellTests.swift
│   ├── PointSpotTests.swift
│   ├── WorldStoreTests.swift
│   ├── LocationSessionManagerTests.swift
│   ├── PreferencesStoreTests.swift
│   ├── BundledPOICatalogTests.swift
│   ├── OpenNowEvaluatorTests.swift
│   ├── SolarPositionTests.swift
│   ├── SolarSkyStateProviderTests.swift
│   ├── SkyPaletteTests.swift
│   ├── SpecimenMappingTests.swift
│   ├── QuestGroundingTests.swift
│   ├── GlobePlacementTests.swift
│   └── TerrariumTests.swift         # Smoke test
│
├── TerrariumUITests/               # UI automation tests (minimal)
│
├── Terrarium.xcodeproj/            # Xcode project
│
├── design/                         # Brand assets
│   └── logo/
│       └── previews/
│
└── tasks/                          # Project notes & PRD
    └── prd-explore-drift-anchor.md # Wave-0 specification
```

## Directory Purposes

**`App/`:**
- Purpose: Application root, dependency injection, routing.
- Contains: `TerrariumApp` (@main), `AppContainer` (composition root), `RootView` (onboarding decision).
- Key files: `AppContainer.swift` defines `live()` method that wires real providers.

**`Domain/`:**
- Purpose: Pure business logic, protocol definitions, value model types.
- Contains: Scoring algorithms, persistence models, provider protocol definitions, stubs.
- Key files: `ExploreProviders.swift` (frozen Wave-0 contracts), `RulesRecommender.swift` (scoring), `WorldStore.swift` (SwiftData bridge).
- Policy: No imports of CoreLocation, WeatherKit, RealityKit, or SwiftUI. Pure value types for unit-test isolation.

**`ExploreFeature/`:**
- Purpose: Tab shell for Explore experience.
- Contains: `ExploreShellView` (3-tab dispatcher).

**`HomeFeature/`:**
- Purpose: Globe & garden progress display.
- Contains: `HomeView`, `HomeViewModel`, `SkyLayer` (gradient background), progress card.

**`DriftFeature/`:**
- Purpose: Ramble (location tracking walk) with map overlay.
- Contains: `DriftView`, `DriftViewModel`, `FogMapView` (geohash grid), controls.

**`AnchorFeature/`:**
- Purpose: Concierge — ranked POI pick, re-roll, arrival verification, award ceremony.
- Contains: `AnchorView`, `AnchorViewModel`, `DiscoveryHeroCard`, design explorations (demo-only).

**`JournalFeature/`:**
- Purpose: Growth log, specimen reflections, reward animations.
- Contains: `JournalListView`, `SpecimenJournalView`, `RewardOverlay`.

**`OnboardingFeature/`:**
- Purpose: First-launch persona selection & interest tagging.
- Contains: `OnboardingFlowView`, `OnboardingViewModel`, persona/interests UI.

**`DesignSystem/`:**
- Purpose: Reusable, frozen UI components (glass kit, tokens, sky palette).
- Contains: `LiquidGlassKit` (Liquid Glass chrome on iOS 26), typography tokens, color palettes.
- Policy: Frozen — no edits by downstream; new designs stay in feature files (preview-only).

**`WorldRendering/`:**
- Purpose: RealityKit 3D globe and specimen rendering.
- Contains: `WorldView` (RealityKit wrapper), entity factories (globe, props, textures), lighting math.

**`Resources/`:**
- Purpose: Bundled data and assets.
- Contains: `sf-pois.json` (curated POI catalog).

**`TerrariumTests/`:**
- Purpose: Unit tests for Domain layer, view models, persistence.
- Contains: One `.swift` file per unit under test; mirror Domain + feature structure.
- No UI tests here — `TerrariumUITests/` for that (currently minimal).

## Key File Locations

**Entry Points:**
- `Terrarium/App/TerrariumApp.swift` - @main, builds AppContainer.live()
- `Terrarium/App/RootView.swift` - Routes to onboarding or ExploreShellView
- `Terrarium/ExploreFeature/ExploreShellView.swift` - 3-tab shell

**Configuration:**
- `Terrarium/App/AppContainer.swift` - DI composition; provider wiring (stubs vs. live)
- `Terrarium/Domain/ExploreProviders.swift` - Frozen Wave-0 protocol contracts

**Core Logic:**
- `Terrarium/Domain/RulesRecommender.swift` - Scoring algorithm
- `Terrarium/Domain/RouteGenerator.swift` - Walk path generation
- `Terrarium/Domain/WorldStore.swift` - SwiftData persistence engine
- `Terrarium/Domain/LocationSessionManager.swift` - CoreLocation bridge
- `Terrarium/Domain/GeohashCell.swift` - Spatial cell math

**Feature State:**
- `Terrarium/AnchorFeature/AnchorViewModel.swift` - Ranked pick + re-roll pool
- `Terrarium/DriftFeature/DriftViewModel.swift` - Ramble session + breadcrumb stream
- `Terrarium/HomeFeature/HomeViewModel.swift` - Sky + world state + progress

**Persistence:**
- `Terrarium/Domain/WorldStore.swift` - SwiftData records
- `Terrarium/Domain/PersistenceModels.swift` - @Model types (WorldStateRecord, WorldPropRecord, CompletedQuest, JournalEntry)
- `Terrarium/Domain/PreferencesStore.swift` - UserDefaults wrapper

**UI Rendering:**
- `Terrarium/WorldRendering/WorldView.swift` - RealityKit globe
- `Terrarium/HomeFeature/SkyLayer.swift` - Sky gradient
- `Terrarium/DesignSystem/LiquidGlassKit.swift` - Glass chrome components

**Testing:**
- `TerrariumTests/` - All unit tests co-located with test name matching source file

## Naming Conventions

**Files:**
- View files: `*View.swift` (e.g., `HomeView.swift`)
- View models: `*ViewModel.swift` (e.g., `HomeViewModel.swift`)
- Domain logic: Noun-based (e.g., `RulesRecommender.swift`, `LocationSessionManager.swift`)
- Test files: `*Tests.swift` matching the unit under test (e.g., `RulesRecommenderTests.swift`)
- Provider implementations: `[Name]Provider.swift` or `[Name]Recommender.swift` (e.g., `WeatherKitProvider.swift`, `RulesRecommender.swift`)
- Stubs: `Stub[Name].swift` pattern within provider protocol file (e.g., `StubPOICatalog` in `ExploreProviders.swift`)

**Directories:**
- Features: `[FeatureName]Feature/` (e.g., `HomeFeature/`, `AnchorFeature/`)
- Domain logic: `Domain/` (all non-UI, non-rendering business code)
- Rendering: `WorldRendering/` (RealityKit), `DesignSystem/` (SwiftUI components)
- Data: `Resources/` (bundled JSON, assets)

**Type Names:**
- View models: PascalCase + `ViewModel` suffix (e.g., `HomeViewModel`)
- Protocol names: PascalCase + `ing` or `Provider` suffix (e.g., `POICatalogProviding`, `WeatherProviding`)
- Models: PascalCase (e.g., `POI`, `Coordinate`, `WorldState`)
- Enums: PascalCase (e.g., `POICategory`, `Weather`, `Vibe`)
- Functions: camelCase (e.g., `requestOneShotCoordinate()`, `driftSeeds()`)

**Constants:**
- Static multipliers in algorithms: `camelCase` with leading noun (e.g., `categoryMatchBoost`, `distancePenaltyFactor`)
- Configuration: UPPER_CASE (e.g., `cellPoints = 2`, `spotPoints = 25`)

## Where to Add New Code

**New Feature (e.g., Photo Journal):**
- Implementation: `Terrarium/PhotoFeature/` (new directory)
  - `PhotoView.swift` — UI
  - `PhotoViewModel.swift` — State + logic
  - `PhotoCaptureManager.swift` — If it wraps an external API
- Tests: `TerrariumTests/PhotoViewModelTests.swift`
- Models: If photo-specific domain types needed, add to `Terrarium/Domain/Models.swift` or create `Terrarium/Domain/PhotoModels.swift`
- Provider: If photo persistence is async, define protocol in `Terrarium/Domain/ExploreProviders.swift` (if shared) or in the feature

**New POI Attribute (e.g., "pet-friendly"):**
- Model: Add field to `POI` struct in `Terrarium/Domain/ExploreModels.swift`
- Catalog: Update `Terrarium/Resources/sf-pois.json` + `Terrarium/Domain/BundledPOICatalog.swift`
- Scoring: Add static constant multiplier to `RulesRecommender` (e.g., `petFriendlyBonus`), apply in score formula
- Tests: Add test case to `TerrariumTests/RulesRecommenderTests.swift`

**New Design Component (e.g., "Status Badge"):**
- Implementation: `Terrarium/DesignSystem/LiquidGlassKit.swift` if part of Liquid Glass kit (glass-based)
  - OR `Terrarium/DesignSystem/Components.swift` for generic helpers
  - OR add to feature view file if single-use (e.g., `AnchorView.swift`)
- Policy: Frozen kit (LiquidGlassKit) is read-only; new explorations go to feature-specific files as demo/preview-only

**New Geospatial Algorithm (e.g., "Polygon containment"):**
- Implementation: `Terrarium/Domain/[Algorithm].swift` (e.g., `PolygonContainment.swift`)
- Models: Use `Coordinate` (degrees) not SIMD2 (radians reserved for sphere placement)
- Tests: `TerrariumTests/[Algorithm]Tests.swift`
- No external geospatial libraries (e.g., no H3, Uber Geohash) without design review

**Persistent Data (e.g., "User skill level"):**
- Model: Add to `UserPreferences` struct in `Terrarium/Domain/PreferencesStore.swift` (simple), OR create new SwiftData @Model in `Terrarium/Domain/PersistenceModels.swift` (complex)
- Storage: `PreferencesStore` uses UserDefaults for simple Codable types; `WorldStore` uses SwiftData for objects needing relationships
- Access: Inject `PreferencesStore` or `WorldStore` into view model via `AppContainer`

**New Provider Integration (e.g., "Spotify for walk playlists"):**
- Protocol: Define in `Terrarium/Domain/ExploreProviders.swift` (if shared contract) or create new file (if feature-specific)
  - Follow existing pattern: async, fallback-friendly, stubs available
- Implementation: `Terrarium/Domain/SpotifyProvider.swift` (real) + stub in the protocol file
- Wiring: Add to `AppContainer.__init__` + `.live()` method
- Tests: Inject stub in test setup; mock `async` calls with `MockSpotifyProvider`

## Special Directories

**`Terrarium/Assets.xcassets/`:**
- Purpose: Image, color, app icon assets.
- Generated: No (hand-edited icon sets, color definitions).
- Committed: Yes.

**`design/`:**
- Purpose: Brand guidelines, logo variations, design reference (not source-of-truth for code).
- Generated: No.
- Committed: Yes.

**`tasks/`:**
- Purpose: Project documentation (PRD, stream briefs, design specs).
- Generated: No (hand-written markdown).
- Committed: Yes.

**`Terrarium.xcodeproj/`:**
- Purpose: Xcode project configuration.
- Generated: Yes (Xcode generates on save).
- Committed: Yes (project.pbxproj).

**`TerrariumTests/`, `TerrariumUITests/`:**
- Purpose: Test targets.
- Generated: No (hand-written test code).
- Committed: Yes.

---

*Structure analysis: 2026-06-17*
