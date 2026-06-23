# External Integrations

**Analysis Date:** 2026-06-17

## APIs & External Services

**WeatherKit (Apple):**
- Service: Real-time weather conditions via Apple Weather
- What it's used for: Current weather condition mapping to app's `Weather` enum (clear/cloudy/fog/rain/snow)
- SDK/Client: WeatherKit (system framework)
- Auth: Requires WeatherKit capability enabled in App ID on developer.apple.com
- Implementation: `Terrarium/Domain/WeatherKitProvider.swift`
- Graceful fallback: Returns `.clear` (safe default) if entitlement absent, network fails, or location unavailable
- Mapping logic: Pure, testable function `WeatherMapping.map(_ condition: WeatherCondition) -> Weather` isolated in `Terrarium/Domain/WeatherKitProvider.swift` lines 28-101
- Deploy note: Capability must be enabled in Xcode target's Capabilities tab

**MapKit (Apple):**
- Service: Map rendering and display
- What it's used for: Drift feature map view, route visualization, POI placement on maps
- SDK/Client: MapKit (system framework)
- Auth: None required (part of iOS SDK)
- Usage files: `Terrarium/DriftFeature/DriftView.swift`, `Terrarium/DriftFeature/FogMapView.swift`, `Terrarium/AnchorFeature/AnchorViewModel.swift`
- No fallback needed (core feature when available)

**CoreLocation (Apple):**
- Service: Device location tracking and authorization
- What it's used for: Real-time breadcrumb tracking during Explore sessions; one-shot fixes for geofence verification
- SDK/Client: CoreLocation + CLLocationManager
- Auth: NSLocationWhenInUseUsageDescription (set via `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` build setting)
- Authorization level: "When In Use" (.whenInUse) - active sessions only
- Activity type: `.fitness` (low-frequency, battery-efficient)
- Accuracy: Best accuracy by default; temporary full accuracy available on demand (iOS 14+)
- Implementation: `Terrarium/Domain/LocationSessionManager.swift`
- Permission handling: Surfaces `authorizationStatus` published property so UI can show permission recovery prompt
- Session lifecycle: `start()` / `stop()` controls when tracking is active
- Fallback: `StubLocationSession` when permission denied (Anchor/Drift still render without real coordinates)

## Data Storage

**SwiftData (Apple):**
- Provider: On-device SQLite-backed database
- Connection: Automatic via `ModelContainer` in `Terrarium/App/AppContainer.swift`
- Models:
  - `WorldStateRecord` - Global world vitality (0...1) and exploration points
  - `WorldPropRecord` - Placed specimens (trees/buildings/flowers) with SIMD2 coordinates
  - `CompletedQuest` - Quest completion ledger (idempotency via `questId`)
  - `JournalEntry` - User reflections on discoveries
- Schema:
  - Uses float pairs (not native SIMD) to store radians coordinates: `latitude` (x), `longitude` (y)
  - Specimen variants stored as plain string ("clear" or "foggy") for lightweight migration
  - Relationships deliberately minimal (one-to-many implicit; no explicit SwiftData relations)
- Persistence strategy: Values are stored; rendering derives from records (render-don't-store principle)
- Initialization: `ModelContainer` configured in `AppContainer.init()`, falls back to in-memory stub on failure
- Optional: CloudKit sync available but not currently wired
- Location: `Terrarium/Domain/PersistenceModels.swift`, `Terrarium/Domain/WorldStore.swift`

**UserDefaults:**
- Provider: Lightweight key-value store
- Storage: User preferences (persona, interest categories, vibes, travel radius) + onboarding flag
- Implementation: `Terrarium/Domain/PreferencesStore.swift`
- Keys:
  - `terrarium.userPreferences.v1` - JSONEncoded `UserPreferences` struct
  - `terrarium.onboardingCompleted.v1` - Boolean onboarding completion flag
- Encoding: JSON round-trip via `JSONEncoder`/`JSONDecoder` (forward-compatible)
- Thread-safety: UserDefaults itself is thread-safe; no explicit isolation required
- Fallback: Returns `UserPreferences.default` on first launch or decode failure

**File Storage:**
- Type: Local filesystem only (no cloud sync or external CDN)
- Bundled assets: `Terrarium/Resources/sf-pois.json` (POI catalog)
- Format: JSON
- Cardinality: Single curated POI dataset for San Francisco pilot

## Authentication & Identity

**Auth Approach:**
- Authentication: None - no user login system
- Identity: App-scoped (single device, per-installation state)
- Persona tracking: Stored in UserDefaults via `PreferencesStore`; reset on app uninstall

## Location Services

**Primary Endpoint:**
- CoreLocation device location (streaming via delegate callbacks during active sessions)
- Breadcrumb format: `Coordinate` (latitude/longitude in radians)
- Stream type: `AsyncStream<Coordinate>` - consumer polling pattern
- Consumers: Drift feature map, location verifier for quest geofencing

**Current Coordinate Access:**
- Method: `LocationSessionManager.currentCoordinate()` - one-shot async read
- Use case: Anchor proximity detection, honor-mode fallback when full session unavailable
- Returns: `Coordinate?` (nil when permission denied)

**One-Shot Coordinate Requests:**
- Method: `LocationSessionManager.requestOneShotCoordinate()` - fresh fix on demand
- Use case: Anchor arrival verification without starting a full Drift session
- Returns: `Coordinate?` (caches location from delegate, fetches fresh fix when needed)

## Monitoring & Observability

**Error Tracking:**
- Service: None detected
- Approach: Local error handling via do/catch; failures logged to console only

**Logs:**
- Approach: Console logging only (no remote aggregation)
- Framework: Standard `print()` and `debugPrint()` (no centralized logger wired)

**Debugging:**
- Sky cycler: `DebugSkyCycler` for manual time/weather progression in development
- No telemetry, no crash reporting, no analytics

## CI/CD & Deployment

**Hosting:**
- Platform: None (Terrarium is a native iOS app, not deployed to a server)
- Distribution: TestFlight or direct App Store (manual setup)

**CI Pipeline:**
- Service: None detected in codebase
- Build: Manual via Xcode or `xcodebuild` CLI

## Environment Configuration

**Required Environment Variables:**
- None detected in codebase
- All configuration via:
  - Xcode build settings (Capabilities, entitlements)
  - `Info.plist` keys (location usage description)
  - Runtime initialization in `AppContainer`

**Secrets Location:**
- No secrets hardcoded; framework entitlements (WeatherKit) are per-developer in provisioning
- Development team: 679K683SQ5 (set in build configuration)

**Launch Configuration:**
- Default composition: `AppContainer.init()` with offline stubs
- Production composition: `AppContainer.live()` wires real providers (BundledPOICatalog, WeatherKitProvider, LocationSessionManager, RulesRecommender)

## Webhooks & Callbacks

**Incoming:**
- None detected (app is fully client-side; no server-side API)

**Outgoing:**
- None detected (no external service callbacks)

**Local Callbacks:**
- `CLLocationManagerDelegate` - CoreLocation breadcrumb delivery (main thread)
- `URLSessionDelegate` - (if future API calls added)
- AsyncStream continuations - Location breadcrumb stream consumer binding

## Third-Party Dependencies

**Direct Dependencies:**
- None (zero SPM or CocoaPods dependencies)
- All functionality via Apple system frameworks

**Framework Availability:**
- iOS 26.0+ covers all frameworks: SwiftUI, SwiftData, WeatherKit, CoreLocation, MapKit, RealityKit

**Future Integration Points:**
- Apple Maps Server API (if map tiles become customized)
- CloudKit (optional SwiftData sync, not currently wired)
- Device Activity API (for usage tracking, not currently wired)

---

*Integration audit: 2026-06-17*
