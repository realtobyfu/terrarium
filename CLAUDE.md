<!-- GSD:project-start source:PROJECT.md -->

## Project

**Terrarium**

Terrarium is a native iOS app (iOS 26+, SwiftUI + RealityKit) that turns real-world exploration into a living terrarium you grow. It has three tabs: **Home** (a 3D globe/terrarium that grows and gains vitality as you explore), **Drift** (a location-tracked walking "ramble" with a breadcrumb stream and geohash fog-of-war map), and **Anchor** (a concierge that recommends a nearby place to go, lets you re-roll, and verifies arrival to award a specimen). It is built for someone who wants going outside to feel rewarding.

**Core Value:** The recommend → arrive → grow loop must feel rewarding: going somewhere real and watching the terrarium respond is the one thing that has to work. Everything else serves that loop.

### Constraints

- **Tech stack**: Swift 5, SwiftUI + RealityKit + SwiftData + CoreLocation + WeatherKit; iOS 26.0+; no external SPM/CocoaPods dependencies — system frameworks only.
- **Concurrency**: MainActor default isolation, strict concurrency (`SWIFT_APPROACHABLE_CONCURRENCY=YES`); all view models are `@Observable @MainActor`.
- **Frozen contracts**: `ExploreModels.swift` and `ExploreProviders.swift` signatures must not change unilaterally — coordinate any bump.
- **Architecture**: features import Domain; Domain imports only Foundation + simd. Keep card UI in `AnchorFeature/`; keep logic in `AnchorViewModel`.
- **Offline-first**: must compile and run fully against stub providers (previews/tests).

<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->

## Technology Stack

## Languages

- Swift 5.0 - All application code, UI, domain logic, and testing

## Runtime

- iOS 26.0+ (deployment target)
- Xcode 26.0.1 (minimum toolchain)
- Native iOS app using SwiftUI + Swift 5 concurrency (async/await)
- MainActor isolation enforced throughout for UI safety

## Frameworks

- SwiftUI - Declarative UI framework for all screens and views
- Combine - Reactive stream support for view model bindings and location updates
- RealityKit - 3D globe rendering, scene composition, entity management
- SwiftData - On-device database for world state, props, quests, journal entries
- CoreLocation - Device location tracking (When In Use authorization)
- WeatherKit - Real-time weather conditions via Apple's weather service
- MapKit - Map rendering and display
- SIMD (Swift SIMD) - Vector math for 3D positioning and sphere coordinates
- Observation framework - SwiftUI @Observable decorator for view models
- Swift Testing framework - New Apple testing framework
- UIKit - UIColor, UIImage, and Core Graphics integration points
- CoreGraphics - Texture drawing and image composition

## Configuration

- `IPHONEOS_DEPLOYMENT_TARGET`: 26.0
- `SWIFT_VERSION`: 5.0
- `SWIFT_APPROACHABLE_CONCURRENCY`: YES (strict concurrency checking enabled)
- `SWIFT_DEFAULT_ACTOR_ISOLATION`: MainActor (default isolation)
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`: YES (future language feature)
- `CODE_SIGN_STYLE`: Automatic
- `DEVELOPMENT_TEAM`: 679K683SQ5 (Tobias Fu personal team)
- Location services (When In Use)
- Background location updates (for Drift sessions)
- WeatherKit capability (when entitlement is enabled)
- `NSLocationWhenInUseUsageDescription`: "Terrarium draws your map and grows your terrarium while you explore. Location is only used during an active session."
- Background modes: location
- Uses Xcode's file system synchronization (PBXFileSystemSynchronizedRootGroup)
- No external package dependencies (SPM or CocoaPods) - all functionality via system frameworks

## Key Dependencies

- SwiftData (persistence) - Mandatory for world state durability
- CoreLocation (location) - Required for Explore feature (Drift/Anchor)
- WeatherKit (weather) - When entitled; graceful fallback to `.clear` if missing
- `Terrarium/Domain/` - Pure business logic, providers, algorithms
- `Terrarium/App/` - Dependency injection container (composition root)
- `Terrarium/WorldRendering/` - 3D globe and visualization
- `Terrarium/AnchorFeature/` - POI discovery and quest system
- `Terrarium/DriftFeature/` - Map-based exploration with breadcrumb tracking
- `Terrarium/HomeFeature/` - Home screen and globe view
- `Terrarium/DesignSystem/` - Design tokens and reusable components

## Optional Dependencies

- WeatherKit - Falls back to stub provider (`.clear` condition) if entitlement absent
- CoreLocation - Full accuracy requests optional; `.fitness` activity type for efficiency
- CLGeocoder - Location reverse-geocoding (future wiring)

## Platform Requirements

- macOS with Xcode 26.0.1+
- Swift 5.0 toolchain
- iOS 26.0 or later on device/simulator
- iOS 26.0+ devices
- Apple Developer Program account (required for location/WeatherKit entitlements)
- iCloud sync optional (SwiftData CloudKit integration available but not wired)
- Location services (NSLocationWhenInUseUsageDescription)
- (Optional) Camera/microphone if future journal video recording is added

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

## Naming Patterns

- Feature-organized: `[Feature]/[ComponentName].swift` (e.g., `AnchorFeature/AnchorView.swift`)
- Test files mirror production structure: `[ComponentName]Tests.swift` (e.g., `AnchorViewModelTests.swift`)
- View models suffix with `ViewModel` (e.g., `HomeViewModel.swift`, `DriftViewModel.swift`)
- Protocols named with `Providing` or `Managing` suffix for clarity (e.g., `POICatalogProviding`, `LocationSessionManager`)
- Enum-heavy for state: `HomeSheet`, `DiscoveryNavItem`, `RambleSummary`
- camelCase throughout
- Verb-first for action methods: `refresh()`, `startRamble()`, `rollAnother()`, `arrive()`
- Getter-like computed properties: `current()`, `all()`, `allowedRefs()`
- Single responsibility principle: `activateSession()`, `requestFullAccuracyIfNeeded()`
- Async methods use `await`: `refresh() async`, `arrive() async`
- camelCase for all variables
- Prefix with underscores for private computed properties (rare, used strategically)
- Published state in view models uses `private(set)` (e.g., `private(set) var pick: POI?`)
- Boolean properties use `is` prefix when interrogative: `isActive`, `isLoading`, `arrivalBlocked`
- Immutable computed properties return values directly: `var globeSignature: String { ... }`
- PascalCase for all types (classes, structs, enums)
- Protocols: descriptive gerunds with `Providing` or `Managing` (e.g., `SkyStateProviding`, `LocationManaging`)
- Enum cases: camelCase (e.g., `.growthLog`, `.specimenJournal(UUID)`)
- Associated values in enums are supported and type-checked strictly

## Code Style

- 4-space indentation (Swift standard)
- Line width respected but not strictly enforced
- Trailing comma patterns used in multi-line arrays/dicts for clean diffs
- Comments separated from code with blank lines where appropriate
- No explicit linter configuration detected (Swift Lint/SwiftFormat not present)
- Style is enforced by team convention and code review
- Consistent with Xcode defaults and SwiftUI best practices

## Import Organization

- No custom path aliases detected
- Fully qualified imports used throughout

## Error Handling

- Most async functions do NOT throw; instead they return optional results or `.clear` defaults
- `WeatherProviding.current()` returns `Weather` (never throws); implementations fall back rather than error
- Core Data operations use `try?` with silent failure for non-critical operations (`try? ctx.delete(model:)`)
- Location permission denied/restricted paths degrade gracefully to "honor mode" (nil coordinates)
- No custom error types detected; instead enums and optionals carry error information
- `@MainActor` guards ensure thread-safe mutations without explicit error handling

## Logging

- Strategic comments explain non-obvious behavior (see `LocationSessionManager.currentCoordinate()`)
- Debug cycler (`DebugSkyCycler`) used for manual testing, not logging
- Comments describe *why*, not *what*: "Yield so the Task fires" vs "Yield"
- Inline comments use ASCII dashes for visual separation: `// ────────`

## Comments

- Explain complex business logic (e.g., "pool is ranked; we cycle through it to avoid flickering")
- Document concurrency considerations: "@MainActor guards main-thread mutations"
- Mark architectural decisions: "Honor-friendly: only set when we have a fix"
- Use comment blocks for section headers: `// MARK: - Section Name`
- No formal documentation style detected
- Inline comments are Markdown-ish, using quotes for code samples
- Block comments use /// style occasionally for visibility; not systematic

## Function Design

- Prefer small, focused functions (typically 10–30 lines)
- Example: `activateSession()` is 8 lines; `requestFullAccuracyIfNeeded()` is ~5 lines
- Longer functions signal refactoring opportunity (see `refresh()` at 45 lines with extensive comments explaining pooling)
- Dependency injection standard: `init(catalog: POICatalogProviding, weather: WeatherProviding, ...)`
- Named parameters required; positional argument chaining avoided
- Async methods accept trailing closures: `.task { await vm.refresh() }`
- Default parameters used sparingly, only for optional configuration: `func init(..., preferences: UserPreferences = .default)`
- Optionals for "may not exist": `func anchor(_ context: RecommendationContext) -> POI?`
- Arrays for collections: `func all() -> [POI]`, `func driftSeeds(...) -> [POI]`
- Computed properties for derived state: `var tierProgress: Double { ... }`
- Never use empty collections to signal failure; use `nil` instead

## Module Design

- Public `class` for main types (e.g., `final class AnchorViewModel`)
- Public `struct` for value types and protocols (e.g., `struct POI: Codable`)
- Private helpers marked `private` or `fileprivate` (never internal)
- Test fixtures marked `private struct` within test suites
- No explicit barrel/re-export files detected
- Each feature module is self-contained: `AnchorFeature/` exports what it needs internally
- No top-level `__all__.swift` or similar aggregation

## Architecture Patterns

- View models use `@Observable @MainActor` from Swift 5.9+
- No `ObservableObject` / `@Published` (Combine-based); pure Observation instead
- Views access state directly from view model: `viewModel.pick`, `viewModel.isLoading`
- Constructor-based injection is standard; no service locator or global singletons (except `AppContainer`)
- Protocols define contracts; stubs implement them for offline/test use
- Stream-based architecture (Streams A–H) means dependencies are frozen at compile time
- Protocols like `POICatalogProviding`, `WeatherProviding` encapsulate external concerns
- Stubs (`StubPOICatalog`, `StubWeatherProvider`) are minimal offline implementations
- Real implementations are stream-specific (e.g., `LocationSessionManager` from Stream B)

<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

## System Overview

```text

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

- **Pure domain**: All business logic (scoring, routes, cells) is pure value-type code with no dependencies on CoreLocation, WeatherKit, SwiftData.
- **Provider protocols**: Every external integration (weather, location, catalog, persistence) is behind a protocol so stubs are available for offline testing/previews.
- **Composition root**: `AppContainer` wires everything once at app launch; `live()` method selects real implementations; tests/previews use stubs.
- **@Observable @MainActor**: All view models are Observation-based, main-actor-confined, with immutable (private) state + mutation methods.
- **Frozen contracts**: `ExploreProviders.swift` and `ExploreModels.swift` are the Wave-0 integration contract; any signature change must be coordinated across streams.

## Layers

- Purpose: SwiftUI view hierarchy; renders state, captures user input.
- Location: `HomeFeature/`, `DriftFeature/`, `AnchorFeature/`, `JournalFeature/`, `OnboardingFeature/`, `ExploreFeature/`
- Contains: Views, `@ViewBuilder` compositions, gesture handlers.
- Depends on: View models, environment (container).
- Used by: User interactions, system events.
- Purpose: State management; bridges UI to domain; manages async work (location, weather, scoring).
- Location: `*ViewModel.swift` in each feature + `App/AppContainer.swift`
- Contains: `@Observable` classes; mutation methods; async task orchestration.
- Depends on: Domain providers (POI catalog, weather, location, recommender, persistence).
- Used by: Views (via @Environment or constructor injection).
- Purpose: Pure algorithms, model definitions, provider protocols.
- Location: `Domain/`
- Contains: Value types (POI, Coordinate, WorldState, etc.); provider protocols; pure algorithms (RulesRecommender, RouteGenerator, GeohashCell).
- Depends on: Foundation, simd (for 3D coords).
- Used by: View models, persistence layer.
- Purpose: Durable state — world growth, quest completion, journal entries, user preferences.
- Location: `Domain/WorldStore.swift` (SwiftData), `Domain/PreferencesStore.swift` (UserDefaults), `Domain/PersistenceModels.swift`.
- Contains: SwiftData models (WorldStateRecord, WorldPropRecord, CompletedQuest, JournalEntry); UserDefaults bridge.
- Depends on: SwiftData, Foundation.
- Used by: View models (inject into VMs, read on demand).
- Purpose: Visual presentation — globe, sky, glass UI components.
- Location: `WorldRendering/`, `DesignSystem/`, `HomeFeature/SkyLayer.swift`
- Contains: RealityKit entity factories (GlobeEntityFactory, SpecimenFactory); SwiftUI view wrappers; glass design system.
- Depends on: RealityKit, SwiftUI, domain models.
- Used by: Feature views (HomeView, DriftView, etc.).

## Data Flow

### Primary Request Path: "I'm Here" Arrival (AnchorView)

### Drift Ramble Flow (DriftView)

### Anchor Re-roll Pool (AnchorView)

### World Growth (HomeView)

- **Transient state** (current pick, active sheet, loading flag) lives in view models (`@Observable` @MainActor).
- **Durable state** (world props, discoveries, journal, preferences) lives in SwiftData + UserDefaults, loaded on demand or on app boot.
- **Sky state** is computed fresh each time `SkyStateProviding.current()` is called (solar position + weather).
- **Discoveries** are recorded immediately to `DiscoveryStore` and fed back to `RulesRecommender` on next rank.

## Key Abstractions

- Purpose: Decouple integration code (CoreLocation, WeatherKit, SwiftData) from business logic.
- Examples: `POICatalogProviding`, `WeatherProviding`, `LocationSessionProviding`, `PlaceRecommending`, `DiscoveryStore`, `WorldStateProviding`
- Pattern: Protocol + stub conformance + real implementation swapped at `AppContainer.live()`
- Purpose: Immutable snapshot of scoring inputs (weather, time of day, user location, preferences).
- Examples: `RecommendationContext` assembled once per refresh, passed to `PlaceRecommending.anchor()` and `.driftSeeds()`
- Pattern: Pure value type; computed fresh from providers
- Purpose: Track explored places/cells; feed back to recommender for demotion.
- Examples: `Discovery` (POI or cell), `DiscoveryStore.exploredRefs()`, `DiscoveryStore.exploredCells()`
- Pattern: Record on arrival/cell light-up; read on rank
- Purpose: Plug in different arrival verification strategies (geofence vs. honor mode).
- Examples: `QuestVerifier` protocol; `LocationVerifier` (real geofence), `HonorVerifier` (always passes)
- Pattern: Strategy pattern; injected into `AnchorViewModel.arrivalVerifier`
- Purpose: Apply taste-based scoring adjustments.
- Examples: `UserPreferences` (interests list, persona); `RulesRecommender` applies persona-specific bonuses
- Pattern: Loaded on app boot from `PreferencesStore`; passed into `RecommendationContext`

## Entry Points

- Location: `TerrariumApp.swift:11`
- Triggers: App launch
- Responsibilities: Build `AppContainer.live()`, inject into environment, show `RootView()`
- Location: `App/RootView.swift:25`
- Triggers: Every render; reads `PreferencesStore.hasCompletedOnboarding` on appear
- Responsibilities: Route to onboarding or `ExploreShellView`
- Location: `ExploreFeature/ExploreShellView.swift:78`
- Triggers: Returning user
- Responsibilities: 3-tab shell; create and preserve VMs; dispatch to active tab
- Location: `AnchorFeature/AnchorView.swift`
- Triggers: User selects Anchor tab
- Responsibilities: Show ranked pick; re-roll buttons; arrival action
- Location: `DriftFeature/DriftView.swift`
- Triggers: User selects Drift tab
- Responsibilities: Show map; fog-of-war; ramble lifecycle; route preview
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

### Direct CoreLocation in Features

### Hardcoded Scoring Multipliers

### SwiftData Queries in View Models

## Error Handling

- **Location unavailable:** No fix → honor mode (always pass arrival check) (`AnchorViewModel.swift:104`)
- **Weather unavailable:** Return `.fog` to match offline default sky (`StubWeatherProvider` / `ExploreProviders.swift:122`)
- **Catalog unavailable:** Never happens in prod; tests use `StubPOICatalog` with fixtures
- **SwiftData failure:** `WorldStore.init` catches and uses `StubWorldStateProvider` as fallback (`AppContainer.swift:65–68`)
- **Hours unknown:** Soft penalty (0.6×) in scoring, not hard exclusion (`RulesRecommender.swift:52`)

## Cross-Cutting Concerns

- POI refs validated against `catalog.allowedRefs()` for quest grounding (`ExploreProviders.swift:26`)
- Coordinates validated in range checks within domain logic (`Coordinate` is just (lat, lon) tuple with no validation; callers must bounds-check)

<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:

- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
