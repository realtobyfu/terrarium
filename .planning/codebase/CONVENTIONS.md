# Coding Conventions

**Analysis Date:** 2026-06-17

## Naming Patterns

**Files:**
- Feature-organized: `[Feature]/[ComponentName].swift` (e.g., `AnchorFeature/AnchorView.swift`)
- Test files mirror production structure: `[ComponentName]Tests.swift` (e.g., `AnchorViewModelTests.swift`)
- View models suffix with `ViewModel` (e.g., `HomeViewModel.swift`, `DriftViewModel.swift`)
- Protocols named with `Providing` or `Managing` suffix for clarity (e.g., `POICatalogProviding`, `LocationSessionManager`)
- Enum-heavy for state: `HomeSheet`, `DiscoveryNavItem`, `RambleSummary`

**Functions:**
- camelCase throughout
- Verb-first for action methods: `refresh()`, `startRamble()`, `rollAnother()`, `arrive()`
- Getter-like computed properties: `current()`, `all()`, `allowedRefs()`
- Single responsibility principle: `activateSession()`, `requestFullAccuracyIfNeeded()`
- Async methods use `await`: `refresh() async`, `arrive() async`

**Variables:**
- camelCase for all variables
- Prefix with underscores for private computed properties (rare, used strategically)
- Published state in view models uses `private(set)` (e.g., `private(set) var pick: POI?`)
- Boolean properties use `is` prefix when interrogative: `isActive`, `isLoading`, `arrivalBlocked`
- Immutable computed properties return values directly: `var globeSignature: String { ... }`

**Types:**
- PascalCase for all types (classes, structs, enums)
- Protocols: descriptive gerunds with `Providing` or `Managing` (e.g., `SkyStateProviding`, `LocationManaging`)
- Enum cases: camelCase (e.g., `.growthLog`, `.specimenJournal(UUID)`)
- Associated values in enums are supported and type-checked strictly

## Code Style

**Formatting:**
- 4-space indentation (Swift standard)
- Line width respected but not strictly enforced
- Trailing comma patterns used in multi-line arrays/dicts for clean diffs
- Comments separated from code with blank lines where appropriate

**Linting:**
- No explicit linter configuration detected (Swift Lint/SwiftFormat not present)
- Style is enforced by team convention and code review
- Consistent with Xcode defaults and SwiftUI best practices

## Import Organization

**Order:**
1. Standard library: `import Foundation`, `import Combine`
2. Apple frameworks: `import SwiftUI`, `import SwiftData`, `import MapKit`, `import CoreLocation`
3. Testing frameworks: `import Testing`, `import simd`
4. Module-internal: `@testable import Terrarium`

**Path Aliases:**
- No custom path aliases detected
- Fully qualified imports used throughout

## Error Handling

**Patterns:**
- Most async functions do NOT throw; instead they return optional results or `.clear` defaults
- `WeatherProviding.current()` returns `Weather` (never throws); implementations fall back rather than error
- Core Data operations use `try?` with silent failure for non-critical operations (`try? ctx.delete(model:)`)
- Location permission denied/restricted paths degrade gracefully to "honor mode" (nil coordinates)
- No custom error types detected; instead enums and optionals carry error information
- `@MainActor` guards ensure thread-safe mutations without explicit error handling

## Logging

**Framework:** console (no external logging library detected)

**Patterns:**
- Strategic comments explain non-obvious behavior (see `LocationSessionManager.currentCoordinate()`)
- Debug cycler (`DebugSkyCycler`) used for manual testing, not logging
- Comments describe *why*, not *what*: "Yield so the Task fires" vs "Yield"
- Inline comments use ASCII dashes for visual separation: `// ────────`

## Comments

**When to Comment:**
- Explain complex business logic (e.g., "pool is ranked; we cycle through it to avoid flickering")
- Document concurrency considerations: "@MainActor guards main-thread mutations"
- Mark architectural decisions: "Honor-friendly: only set when we have a fix"
- Use comment blocks for section headers: `// MARK: - Section Name`

**JSDoc/TSDoc:**
- No formal documentation style detected
- Inline comments are Markdown-ish, using quotes for code samples
- Block comments use /// style occasionally for visibility; not systematic

## Function Design

**Size:**
- Prefer small, focused functions (typically 10–30 lines)
- Example: `activateSession()` is 8 lines; `requestFullAccuracyIfNeeded()` is ~5 lines
- Longer functions signal refactoring opportunity (see `refresh()` at 45 lines with extensive comments explaining pooling)

**Parameters:**
- Dependency injection standard: `init(catalog: POICatalogProviding, weather: WeatherProviding, ...)`
- Named parameters required; positional argument chaining avoided
- Async methods accept trailing closures: `.task { await vm.refresh() }`
- Default parameters used sparingly, only for optional configuration: `func init(..., preferences: UserPreferences = .default)`

**Return Values:**
- Optionals for "may not exist": `func anchor(_ context: RecommendationContext) -> POI?`
- Arrays for collections: `func all() -> [POI]`, `func driftSeeds(...) -> [POI]`
- Computed properties for derived state: `var tierProgress: Double { ... }`
- Never use empty collections to signal failure; use `nil` instead

## Module Design

**Exports:**
- Public `class` for main types (e.g., `final class AnchorViewModel`)
- Public `struct` for value types and protocols (e.g., `struct POI: Codable`)
- Private helpers marked `private` or `fileprivate` (never internal)
- Test fixtures marked `private struct` within test suites

**Barrel Files:**
- No explicit barrel/re-export files detected
- Each feature module is self-contained: `AnchorFeature/` exports what it needs internally
- No top-level `__all__.swift` or similar aggregation

## Architecture Patterns

**MVVM with Observation:**
- View models use `@Observable @MainActor` from Swift 5.9+
- No `ObservableObject` / `@Published` (Combine-based); pure Observation instead
- Views access state directly from view model: `viewModel.pick`, `viewModel.isLoading`

**Dependency Injection:**
- Constructor-based injection is standard; no service locator or global singletons (except `AppContainer`)
- Protocols define contracts; stubs implement them for offline/test use
- Stream-based architecture (Streams A–H) means dependencies are frozen at compile time

**Provider Pattern:**
- Protocols like `POICatalogProviding`, `WeatherProviding` encapsulate external concerns
- Stubs (`StubPOICatalog`, `StubWeatherProvider`) are minimal offline implementations
- Real implementations are stream-specific (e.g., `LocationSessionManager` from Stream B)

---

*Convention analysis: 2026-06-17*
