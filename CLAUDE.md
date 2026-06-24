# Terrarium

A native iOS app (iOS 26+, SwiftUI + RealityKit) that turns real-world exploration into a living terrarium you grow. Three tabs:

- **Home** — a 3D globe/terrarium that grows and gains vitality as you explore.
- **Drift** — a location-tracked walking "ramble" with a breadcrumb stream and geohash fog-of-war map.
- **Anchor** — a concierge that recommends a nearby place, lets you re-roll, and verifies arrival to award a specimen.

**Core loop:** recommend → arrive → grow. Going somewhere real and watching the terrarium respond is the one thing that has to work. Everything else serves that loop.

## Constraints

- **Tech stack:** Swift 5, SwiftUI + RealityKit + SwiftData + CoreLocation + WeatherKit; iOS 26.0+. System frameworks only — no SPM/CocoaPods.
- **Concurrency:** MainActor default isolation, strict concurrency (`SWIFT_APPROACHABLE_CONCURRENCY=YES`). All view models are `@Observable @MainActor` (Observation, not Combine `@Published`).
- **Architecture:** features import Domain; Domain imports only Foundation + simd. Keep card UI in `AnchorFeature/`; keep logic in `AnchorViewModel`.
- **Frozen contracts:** `ExploreModels.swift` and `ExploreProviders.swift` signatures must not change unilaterally — coordinate any bump.
- **Offline-first:** must compile and run fully against stub providers (previews/tests).

## Layout

| Path | Responsibility |
|------|----------------|
| `App/` | DI container (`AppContainer`), root router, app entry point |
| `Domain/` | Pure logic: models, provider protocols, recommender, persistence (SwiftData/UserDefaults) |
| `HomeFeature/` | Globe, sky state, growth progress, journal |
| `DriftFeature/` | Ramble: location tracking, breadcrumbs, geohash cells, fog-of-war |
| `AnchorFeature/` | Concierge: ranked pick, re-roll, arrival verification, award |
| `OnboardingFeature/` | Persona/preference onboarding flow |
| `WorldRendering/` | RealityKit globe render, prop placement, specimens |
| `DesignSystem/` | Design tokens, Liquid Glass components |

## Conventions

- 4-space indentation; camelCase vars, PascalCase types.
- View models suffixed `ViewModel`; published state is `private(set)`.
- Provider protocols suffixed `Providing` / `Managing`; every external integration sits behind one with a stub for offline/test use.
- Most async functions don't throw — they return optionals or graceful defaults (e.g. weather falls back to `.clear`/`.fog`, location-denied → honor mode).
- Comments explain *why*, not *what*.
- Dependency injection via init; `AppContainer.live()` wires real implementations, tests/previews use stubs.
