# Testing Patterns

**Analysis Date:** 2026-06-17

## Test Framework

**Runner:**
- Apple's Testing framework (swift-testing, Swift 6+, not XCTest)
- Config: Xcode project settings (no separate config file)
- Import: `import Testing`

**Assertion Library:**
- Built-in Swift Testing macros: `#expect(condition)`, `#require(optional)`, `#expect(throws:)`

**Run Commands:**
```bash
xcodebuild test -scheme Terrarium                    # Run all tests
xcodebuild test -scheme Terrarium -only-testing TestName  # Run single test
swift test                                           # If using SPM (not used here)
```

## Test File Organization

**Location:**
- Parallel directory structure: `TerrariumTests/` mirrors `Terrarium/`
- Example: `Terrarium/AnchorFeature/AnchorViewModel.swift` → `TerrariumTests/AnchorViewModelTests.swift`

**Naming:**
- `[ComponentName]Tests.swift` (e.g., `HomeViewModelTests.swift`, `LocationSessionManagerTests.swift`)
- Test suites use `@Suite("Name")` decorator with optional `.serialized` flag for SwiftData isolation

**Structure:**
```
TerrariumTests/
├── AnchorViewModelTests.swift
├── DriftViewModelTests.swift
├── LocationSessionManagerTests.swift
├── WorldStoreTests.swift
└── [30+ more test files]
```

## Test Structure

**Suite Organization:**
```swift
@MainActor
@Suite("ComponentName", .serialized)  // .serialized = single-threaded for shared state
struct ComponentNameTests {
    // MARK: - Fixtures
    
    private struct FixtureCatalog: POICatalogProviding { ... }
    
    // MARK: - Test helpers
    
    private func makeViewModel() -> ComponentName { ... }
    
    // MARK: - Tests
    
    @Test("Human-readable test name")
    func testName() { ... }
}
```

**Patterns:**
- Setup: Fixtures and helper functions defined at suite level
- Each test is a small, focused function with a `@Test` decorator
- Test names are full sentences describing behavior: `"Re-roll advances to a different pick"`
- No `setUp()` or `tearDown()` methods; instead use fresh instances per test
- `@MainActor` at suite level for view models; `@MainActor` at individual test level for async code

## Mocking

**Framework:** Hand-crafted mocks (no Mockito or third-party library)

**Patterns:**
```swift
// Example from AnchorViewModelTests
private struct FixtureCatalog: POICatalogProviding {
    let pois: [POI]
    func all() -> [POI] { pois }
    func allowedRefs() -> Set<String> { Set(pois.map(\.poiRef)) }
}

// Controllable weather stub
private final class ControlledWeather: WeatherProviding {
    var nextWeather: Weather = .clear
    func current() async -> Weather { nextWeather }
}
```

**What to Mock:**
- External providers: `POICatalogProviding`, `WeatherProviding`, `LocationSessionProviding`
- Data stores: `InMemoryDiscoveryStore`, `MockLocationSession`
- System frameworks: `MockLocationManager` wraps `CLLocationManager`
- Never mock internal business logic; test the real implementation

**What NOT to Mock:**
- Value types (`POI`, `Coordinate`, `Discovery`)
- View models under test (test them directly with mocked dependencies)
- Data models (use real instances in fixtures)

## Fixtures and Factories

**Test Data:**
```swift
// Helper function approach (e.g., from AnchorViewModelTests)
private func makePOI(ref: String, name: String = "Test", kind: WorldProp.Kind = .tree) -> POI {
    POI(
        poiRef: ref, name: name, category: .park,
        neighborhood: "Test",
        coordinate: Coordinate(latitude: 37.76, longitude: -122.42),
        // ... remaining fields with sensible defaults
    )
}

// Fixture struct approach (e.g., from ExploreModelsTests)
private func samplePOI(_ ref: String = "poi.sample.sf") -> POI {
    POI(poiRef: ref, name: "Sample", category: .coffee, ...)
}
```

**Location:**
- Fixtures defined as private structs/functions at the top of test suites
- Mark as `// MARK: - Fixtures` for organization
- Reusable across multiple tests in the same suite
- No separate test data files (JSON fixtures, etc.)

## Coverage

**Requirements:** None enforced (no coverage threshold detected)

**View Coverage:**
- Every view model has a corresponding test file
- Example: `AnchorViewModel` has `AnchorViewModelTests` covering refresh, re-roll, arrival logic
- Not all View files tested (SwiftUI views are typically tested via their view models)

## Test Types

**Unit Tests:**
- Scope: Single component (view model, provider, store)
- Approach: Inject mocks, call a method, assert state changes
- Example: `AnchorViewModelTests.refresh()` calls `vm.refresh()`, checks `vm.pick` changed
- Assertion style: `#expect(vm.pick != nil)`, `#expect(firstPick.poiRef == "poi.a")`

**Integration Tests:**
- Scope: Multiple components working together
- Approach: Use real implementations of stubs + mock system frameworks
- Example: `StreamFIntegrationTests` wires Drift + Anchor + location verifier
- SwiftData tests (`WorldStoreTests`) use real `ModelContainer` with shared lifecycle

**E2E Tests:**
- Framework: `TerrariumUITests/` directory (minimal coverage)
- Scope: App launch → navigation → basic flow
- Approach: Drive via Xcode UI testing framework (not shown in detail in source)
- Not extensively used (production focus is on unit/integration)

## Common Patterns

**Async Testing:**
```swift
@Test("Arrival awards points and records a discovery")
async func arrivalAwardsPointsAndRecordsDiscovery() async throws {
    let poi = makePOI(ref: "poi.ocean-beach.sf", kind: .tree)
    let vm = AnchorViewModel(...)
    
    await vm.refresh()  // No special wrapping needed
    await vm.arrive()
    
    #expect(worldStore.totalPoints() > before)
}
```

**Error Testing:**
```swift
@Test("Empty catalog yields no pick")
func emptyCatalogNoPick() async {
    let catalog = FixtureCatalog(pois: [])
    let vm = AnchorViewModel(catalog: catalog, ...)
    
    await vm.refresh()
    #expect(vm.pick == nil)  // Assert the fallback/nil case
}
```

**Optional Unwrapping:**
```swift
@Test("Re-roll advances to a different pick")
func rerollAdvancesPick() async throws {
    let vm = AnchorViewModel(...)
    await vm.refresh()
    
    let firstPick = try #require(vm.pick)  // Fail test if nil
    #expect(firstPick.poiRef == "poi.a")
}
```

**Shared Container (SwiftData):**
```swift
@MainActor
@Suite("WorldStore", .serialized)
struct WorldStoreTests {
    static let container: ModelContainer = {
        let url = URL.temporaryDirectory.appending(path: "terr-shared-\(UUID().uuidString).store")
        return try! ModelContainer(
            for: WorldStateRecord.self, WorldPropRecord.self,
            CompletedQuest.self, JournalEntry.self,
            configurations: ModelConfiguration(url: url)
        )
    }()
    
    private func freshStore() -> WorldStore {
        let ctx = Self.container.mainContext
        try? ctx.delete(model: WorldStateRecord.self)  // Wipe before each test
        try? ctx.save()
        return WorldStore(context: ctx)
    }
}
```

**Main Actor Isolation:**
```swift
// Test suite tagged with @MainActor
@MainActor
@Suite("LocationSessionManager")
struct LocationSessionManagerTests {
    
    // Async helper for triggering delegate callbacks
    @MainActor
    private func grantAuthorization(_ status: CLAuthorizationStatus,
                                     to manager: LocationSessionManager,
                                     mock: MockLocationManager) async {
        mock.authorizationStatus = status
        manager.locationManagerDidChangeAuthorization(CLLocationManager())
        await Task.yield()  // Let the @MainActor Task complete
    }
}
```

## Test Coverage Highlights

**Tested Areas:**
- `AnchorViewModelTests.swift`: Pick selection, re-roll, arrival logic, idempotency
- `DriftViewModelTests.swift`: Session lifecycle, cell discovery, distance accumulation
- `LocationSessionManagerTests.swift`: Permission handling, breadcrumb streaming, lifecycle
- `WorldStoreTests.swift`: Specimen growth, vitality progression, quest completion
- `ExploreModelsTests.swift`: Codable round-trips, enum raw values, store partitioning
- `RouteGeneratorTests.swift`: Path-finding and waypoint generation
- `RulesRecommenderTests.swift`: Ranking logic, open-now filtering, novelty
- `QuestGroundingTests.swift`: POI grounding against catalog

**Untested Areas (by design):**
- Pure SwiftUI views (tested via their view models instead)
- Design system components (`LiquidGlassKit.swift`, `SkyPalette.swift`) — visual regression is manual
- App-level initialization and environment wiring (manual testing only)

## Naming Convention

**Test names as sentences:**
- ✓ "Re-roll advances to a different pick"
- ✓ "Arrival awards points and records a discovery"
- ✗ "testReroll" (too terse)
- ✗ "check_arrival_awards" (doesn't read naturally)

**Each test does one thing:**
- Test a single behavior or assertion path
- Multiple related assertions OK if they test one scenario
- Complex multi-step scenarios split into separate tests with clear names

---

*Testing analysis: 2026-06-17*
