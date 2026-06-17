<!-- refreshed: 2026-06-17 -->
# Architecture

**Analysis Date:** 2026-06-17

## System Overview

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                    Feature Views (UI Layer)                              │
├──────────────────┬─────────────────────┬──────────────────┬──────────────┤
│   HomeView       │   DriftView         │   AnchorView     │ OnboardingView│
│  `HomeFeature/`  │  `DriftFeature/`    │ `AnchorFeature/` │`OnboardingF/` │
└────────┬─────────┴────────┬────────────┴────────┬─────────┴──────────────┘
         │                  │                     │
         │                  └──────────┬──────────┘
         ▼                             ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                    View Models (State & Logic Layer)                      │
│  `HomeViewModel`, `DriftViewModel`, `AnchorViewModel`                     │
│  @Observable @MainActor; compose Domain layer providers                  │
└──────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                    Domain Layer (Pure Logic)                              │
│  `Domain/` — Models, protocols, pure algorithms                          │
├────────────────────────────────────────────────────────────────────────┤
│  Providers (ExploreProviders.swift, Providers.swift):                  │
│  • POICatalogProviding  → BundledPOICatalog, StubPOICatalog            │
│  • WeatherProviding     → WeatherKitProvider, StubWeatherProvider      │
│  • LocationSessionProviding → LocationSessionManager, StubLocationSession
│  • PlaceRecommending    → RulesRecommender, StubRecommender            │
│  • DiscoveryStore       → InMemoryDiscoveryStore                        │
│  • SkyStateProviding    → SolarSkyStateProvider, StubSkyStateProvider   │
│  • WorldStateProviding  → WorldStore, StubWorldStateProvider            │
├────────────────────────────────────────────────────────────────────────┤
│  Models (ExploreModels.swift, Models.swift, PersistenceModels.swift):  │
│  • POI, Coordinate, Weather, SkyState, WorldState, Quest, Discovery     │
│  • POICategory, DayPart, Vibe, GoodFor, PriceTier, IndoorOutdoor        │
├────────────────────────────────────────────────────────────────────────┤
│  Algorithms:                                                             │
│  • RulesRecommender — deterministic scoring (location, weather, taste)  │
│  • RouteGenerator   — breadth-first walk path from seeds                │
│  • GeohashCell      — spatial indexing at precision 7                   │
│  • RulesRecommender — points/tier calculation, vitality system          │
└──────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                    Persistence Layer                                      │
│  WorldStore (SwiftData) — Records: WorldStateRecord, WorldPropRecord,   │
│  CompletedQuest, JournalEntry. PreferencesStore (UserDefaults).         │
└──────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│                    Rendering Layer (RealityKit + SwiftUI)                 │
│  WorldView → GlobeEntityFactory → 3D prop meshes, lighting, animation   │
│  SkyLayer → SkyPalette → dynamic sky gradient                            │
│  LiquidGlassKit → glass chrome, buttons, pill badges                    │
└──────────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| **TerrariumApp** | App entry point; builds `AppContainer` once; injects into environment | `TerrariumApp.swift` |
| **AppContainer** | DI container; composes providers; owns SwiftData model container; vends view models | `App/AppContainer.swift` |
| **RootView** | Conditional router: onboarding vs. ExploreShellView; reads `PreferencesStore.hasCompletedOnboarding` | `App/RootView.swift` |
| **ExploreShellView** | 3-tab shell (Home, Drift, Anchor); manages active tab; creates VMs once | `ExploreFeature/ExploreShellView.swift` |
| **HomeView/HomeViewModel** | Globe display; sky state; world state; growth progress; specimen journal | `HomeFeature/` |
| **DriftView/DriftViewModel** | Ramble (location tracking); breadcrumb stream; geohash cells; fog-of-war; route gen | `DriftFeature/` |
| **AnchorView/AnchorViewModel** | Concierge: ranked pick, re-roll, "I'm here" geofence verification; award ceremony | `AnchorFeature/` |
| **RulesRecommender** | Pure scoring: category match, open-now, weather fit, distance, novelty, persona bias | `Domain/RulesRecommender.swift` |
| **WorldStore** | SwiftData persistence; quest completion → growth + vitality; journal entries | `Domain/WorldStore.swift` |
| **LocationSessionManager** | CoreLocation integration; breadcrumb stream; one-shot coordinate fix | `Domain/LocationSessionManager.swift` |
| **BundledPOICatalog** | Bundled SF-POI catalog (JSON); allows-list for quest grounding | `Domain/BundledPOICatalog.swift` |
| **ContextAssembler** | Assembles `RecommendationContext` from weather, time, location, preferences | `Domain/ContextAssembler.swift` |
| **WorldView** | RealityKit globe render; prop placement; tappable specimens; drag orbit | `WorldRendering/WorldView.swift` |
| **SkyLayer** | Gradient sky background; driven by `SkyState` (elevation + weather) | `HomeFeature/SkyLayer.swift` |
| **LiquidGlassKit** | Reusable glass chrome: buttons, pills, nav bar, washi tape stickers | `DesignSystem/LiquidGlassKit.swift` |

## Pattern Overview

**Overall:** Layered MVVM with dependency injection + provider pattern.

**Key Characteristics:**
- **Pure domain**: All business logic (scoring, routes, cells) is pure value-type code with no dependencies on CoreLocation, WeatherKit, SwiftData.
- **Provider protocols**: Every external integration (weather, location, catalog, persistence) is behind a protocol so stubs are available for offline testing/previews.
- **Composition root**: `AppContainer` wires everything once at app launch; `live()` method selects real implementations; tests/previews use stubs.
- **@Observable @MainActor**: All view models are Observation-based, main-actor-confined, with immutable (private) state + mutation methods.
- **Frozen contracts**: `ExploreProviders.swift` and `ExploreModels.swift` are the Wave-0 integration contract; any signature change must be coordinated across streams.

## Layers

**UI Layer:**
- Purpose: SwiftUI view hierarchy; renders state, captures user input.
- Location: `HomeFeature/`, `DriftFeature/`, `AnchorFeature/`, `JournalFeature/`, `OnboardingFeature/`, `ExploreFeature/`
- Contains: Views, `@ViewBuilder` compositions, gesture handlers.
- Depends on: View models, environment (container).
- Used by: User interactions, system events.

**View Model Layer:**
- Purpose: State management; bridges UI to domain; manages async work (location, weather, scoring).
- Location: `*ViewModel.swift` in each feature + `App/AppContainer.swift`
- Contains: `@Observable` classes; mutation methods; async task orchestration.
- Depends on: Domain providers (POI catalog, weather, location, recommender, persistence).
- Used by: Views (via @Environment or constructor injection).

**Domain Layer:**
- Purpose: Pure algorithms, model definitions, provider protocols.
- Location: `Domain/`
- Contains: Value types (POI, Coordinate, WorldState, etc.); provider protocols; pure algorithms (RulesRecommender, RouteGenerator, GeohashCell).
- Depends on: Foundation, simd (for 3D coords).
- Used by: View models, persistence layer.

**Persistence Layer:**
- Purpose: Durable state — world growth, quest completion, journal entries, user preferences.
- Location: `Domain/WorldStore.swift` (SwiftData), `Domain/PreferencesStore.swift` (UserDefaults), `Domain/PersistenceModels.swift`.
- Contains: SwiftData models (WorldStateRecord, WorldPropRecord, CompletedQuest, JournalEntry); UserDefaults bridge.
- Depends on: SwiftData, Foundation.
- Used by: View models (inject into VMs, read on demand).

**Rendering Layer:**
- Purpose: Visual presentation — globe, sky, glass UI components.
- Location: `WorldRendering/`, `DesignSystem/`, `HomeFeature/SkyLayer.swift`
- Contains: RealityKit entity factories (GlobeEntityFactory, SpecimenFactory); SwiftUI view wrappers; glass design system.
- Depends on: RealityKit, SwiftUI, domain models.
- Used by: Feature views (HomeView, DriftView, etc.).

## Data Flow

### Primary Request Path: "I'm Here" Arrival (AnchorView)

1. **User taps "I'm here"** → `AnchorViewModel.arrive()` (`AnchorViewModel.swift:150`)
2. **Request one-shot location fix** → `location.requestOneShotCoordinate()` (`LocationSessionManager` or stub)
3. **Verify arrival** → `arrivalVerifier.verify(quest)` (LocationVerifier or HonorVerifier) (`Domain/QuestVerifier.swift`)
4. **On success, award specimen** → `worldStore?.complete(quest:with:)` → SwiftData insert (`WorldStore.swift:47`)
5. **Record discovery** → `discoveries.record(Discovery)` → `InMemoryDiscoveryStore` (`ExploreProviders.swift:156`)
6. **Update view state** → `arrivalResult` set; view shows award ceremony (`AnchorView.swift`)

### Drift Ramble Flow (DriftView)

1. **User taps "Start walk"** → `DriftViewModel.startRamble()` (`DriftViewModel.swift`)
2. **Request location permission + start session** → `location.start()` → `LocationSessionManager` subscribes to CLLocationManager
3. **Breadcrumb stream begins** → `location.breadcrumbStream()` emits `Coordinate` on each fix
4. **Map coordinate to geohash cell** → `GeohashCell.fromCoordinate()` → cell ID
5. **Record discovery** → `discoveries.record(Discovery(target: .cell(id)))`
6. **Update UI state** → `newCells`, `allExploredCells`, `elapsedSeconds`, `distanceMeters`
7. **Point spots collected** → Check if cell intersects a `PointSpot`, award points
8. **User taps "End walk"** → `DriftViewModel.endRamble()` → summary card shown

### Anchor Re-roll Pool (AnchorView)

1. **`refresh()` called** (appear or pull-to-refresh)
2. **Fetch weather** → `weather.current()` → `WeatherKitProvider` or stub
3. **Request coordinate** → `location.requestOneShotCoordinate()` → current position (or nil in honor mode)
4. **Assemble context** → `ContextAssembler.assemble(weather, now, coordinate, preferences)` → `RecommendationContext`
5. **Score catalog** → `recommender.driftSeeds(context)` → ranked [POI]
6. **Build pool** → Deduplicate and order; `poolIndex = 0`; show `pool[0]`
7. **User taps "Another"** → `rollAnother()` → advance `poolIndex` (wraps)
8. **Show next POI** → `pick = pool[poolIndex]`

### World Growth (HomeView)

1. **Tab appears** → `HomeViewModel.refresh()`
2. **Read world** → `worldProvider.current()` → `WorldStore.current()` reads SwiftData
3. **Read points** → `worldStore?.totalPoints()` → sum of all `PointsAward`
4. **Calculate tier** → `tier = points / pointsPerTier`; `tierProgress` is the remainder
5. **View observes** changes via `@Observable` property updates
6. **Tap specimen** → `HomeViewModel.openSpecimen(propID)` → `activeSheet = .specimenJournal(id)`
7. **Journal reads** → `worldStore?.journalEntry(forPropID:)` → SwiftData fetch

**State Management:**
- **Transient state** (current pick, active sheet, loading flag) lives in view models (`@Observable` @MainActor).
- **Durable state** (world props, discoveries, journal, preferences) lives in SwiftData + UserDefaults, loaded on demand or on app boot.
- **Sky state** is computed fresh each time `SkyStateProviding.current()` is called (solar position + weather).
- **Discoveries** are recorded immediately to `DiscoveryStore` and fed back to `RulesRecommender` on next rank.

## Key Abstractions

**Provider Pattern:**
- Purpose: Decouple integration code (CoreLocation, WeatherKit, SwiftData) from business logic.
- Examples: `POICatalogProviding`, `WeatherProviding`, `LocationSessionProviding`, `PlaceRecommending`, `DiscoveryStore`, `WorldStateProviding`
- Pattern: Protocol + stub conformance + real implementation swapped at `AppContainer.live()`

**Recommendation Context:**
- Purpose: Immutable snapshot of scoring inputs (weather, time of day, user location, preferences).
- Examples: `RecommendationContext` assembled once per refresh, passed to `PlaceRecommending.anchor()` and `.driftSeeds()`
- Pattern: Pure value type; computed fresh from providers

**Discovery & Novelty:**
- Purpose: Track explored places/cells; feed back to recommender for demotion.
- Examples: `Discovery` (POI or cell), `DiscoveryStore.exploredRefs()`, `DiscoveryStore.exploredCells()`
- Pattern: Record on arrival/cell light-up; read on rank

**Quest Verification:**
- Purpose: Plug in different arrival verification strategies (geofence vs. honor mode).
- Examples: `QuestVerifier` protocol; `LocationVerifier` (real geofence), `HonorVerifier` (always passes)
- Pattern: Strategy pattern; injected into `AnchorViewModel.arrivalVerifier`

**Persona Bias:**
- Purpose: Apply taste-based scoring adjustments.
- Examples: `UserPreferences` (interests list, persona); `RulesRecommender` applies persona-specific bonuses
- Pattern: Loaded on app boot from `PreferencesStore`; passed into `RecommendationContext`

## Entry Points

**TerrariumApp.main:**
- Location: `TerrariumApp.swift:11`
- Triggers: App launch
- Responsibilities: Build `AppContainer.live()`, inject into environment, show `RootView()`

**RootView.body:**
- Location: `App/RootView.swift:25`
- Triggers: Every render; reads `PreferencesStore.hasCompletedOnboarding` on appear
- Responsibilities: Route to onboarding or `ExploreShellView`

**ExploreShellView.body:**
- Location: `ExploreFeature/ExploreShellView.swift:78`
- Triggers: Returning user
- Responsibilities: 3-tab shell; create and preserve VMs; dispatch to active tab

**AnchorView.body:**
- Location: `AnchorFeature/AnchorView.swift`
- Triggers: User selects Anchor tab
- Responsibilities: Show ranked pick; re-roll buttons; arrival action

**DriftView.body:**
- Location: `DriftFeature/DriftView.swift`
- Triggers: User selects Drift tab
- Responsibilities: Show map; fog-of-war; ramble lifecycle; route preview

**HomeView.body:**
- Location: `HomeFeature/HomeView.swift`
- Triggers: User selects Home tab (or app first launch)
- Responsibilities: Render globe; show sky; display growth progress; journal access

## Architectural Constraints

- **Threading:** All state mutations on `@MainActor`. Location breadcrumbs received on main. WeatherKit and SwiftData calls are async but land on main via `@MainActor func`.
- **Global state:** `AppContainer` built once and passed via environment. SwiftData `ModelContainer` built once in `AppContainer.init`. No class-level singletons outside the container.
- **Circular imports:** None by design — features import Domain; Domain imports nothing but Foundation + simd. DesignSystem imports Foundation + SwiftUI.
- **Offline-first**: Stubs exist for all providers; app compiles and runs fully offline. Real implementations wired only when `AppContainer.live()` is used (production) vs. test defaults.
- **Frozen contracts:** `ExploreModels.swift` and `ExploreProviders.swift` are never edited unilaterally; any signature change is coordinated across the team.

## Anti-Patterns

### Mutable Global State in View Models

**What happens:** Early sketches kept exploration points as a global counter in a view model singleton.
**Why it's wrong:** Breaks Observation reactivity; state doesn't sync across features; tests can't isolate.
**Do this instead:** Store points in SwiftData (WorldStore); read on demand in HomeViewModel via `worldStore?.totalPoints()` (`Domain/WorldStore.swift:92`)

### Direct CoreLocation in Features

**What happens:** DriftView directly calls `CLLocationManager`.
**Why it's wrong:** Untestable; blocks offline work; violates pure-domain discipline.
**Do this instead:** Use `LocationSessionProviding` protocol; inject `LocationSessionManager` (real) or `StubLocationSession` (test/preview) via `AppContainer` (`Domain/ExploreProviders.swift:43`)

### Hardcoded Scoring Multipliers

**What happens:** Earlier recommender mixed constants with logic.
**Why it's wrong:** Multipliers are policy; hard to tweak or understand scoring decisions.
**Do this instead:** Define all multipliers as static named constants in `RulesRecommender` with comments (`Domain/RulesRecommender.swift:45–102`)

### SwiftData Queries in View Models

**What happens:** `DriftViewModel` directly calls `@Query` to load discoveries.
**Why it's wrong:** Breaks unit testing; ties view model to persistence.
**Do this instead:** Inject `DiscoveryStore` protocol; `WorldStore` holds the persistence details (`Domain/ExploreProviders.swift:79`)

## Error Handling

**Strategy:** Silent fallback + graceful degradation.

**Patterns:**
- **Location unavailable:** No fix → honor mode (always pass arrival check) (`AnchorViewModel.swift:104`)
- **Weather unavailable:** Return `.fog` to match offline default sky (`StubWeatherProvider` / `ExploreProviders.swift:122`)
- **Catalog unavailable:** Never happens in prod; tests use `StubPOICatalog` with fixtures
- **SwiftData failure:** `WorldStore.init` catches and uses `StubWorldStateProvider` as fallback (`AppContainer.swift:65–68`)
- **Hours unknown:** Soft penalty (0.6×) in scoring, not hard exclusion (`RulesRecommender.swift:52`)

## Cross-Cutting Concerns

**Logging:** Console only; no logging framework. Debug prints in ViewModel methods for diagnostics (remove before ship).

**Validation:** 
- POI refs validated against `catalog.allowedRefs()` for quest grounding (`ExploreProviders.swift:26`)
- Coordinates validated in range checks within domain logic (`Coordinate` is just (lat, lon) tuple with no validation; callers must bounds-check)

**Authentication:** None for this prototype. Future: location permission prompt on first Drift/Anchor use (seam in `RootView.makeOnboardingVM()` for Stream B integration).

---

*Architecture analysis: 2026-06-17*
