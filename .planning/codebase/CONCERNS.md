# Codebase Concerns

**Analysis Date:** 2026-06-17

## Tech Debt

**Stub implementations blocking real integrations:**
- Issue: Multiple TODOs across `ExploreProviders.swift` and `Providers.swift` mark placeholder stubs that must be replaced with real implementations before launch.
  - `StubPOICatalog` with hardcoded 3 SF fixtures → must be replaced by `BundledPOICatalog` loading `sf-pois.json` (Stream A)
  - `StubWeatherProvider` returning hardcoded `.fog` → must be replaced by `WeatherKitProvider` mapping real WeatherKit conditions (Stream B)
  - `StubLocationSession` with no-op breadcrumbs → must be replaced by real `LocationSessionManager` wrapping CLLocationManager (Stream B)
  - `StubRecommender` using naive catalog order → must be replaced by `RulesRecommender` with full scoring (Stream C)
  - `InMemoryDiscoveryStore` ephemeral in-memory → must be replaced by SwiftData-backed persistent store (Stream F)
- Files: `Terrarium/Domain/ExploreProviders.swift` (lines 93, 121, 128, 139, 157)
- Impact: App cannot function with real location, weather, or personalized recommendations until Stream implementations land. Protocol signatures frozen to allow parallel development but any needed signature changes require coordinated bumps.
- Fix approach: Each TODO has a clear stream assignment. Stream leads must land replacements in priority order. Never edit the frozen signatures unilaterally — surface signature needs for coordinated bumps.

**Missing test coverage for domain layers:**
- Issue: Several critical domain modules lack unit tests despite being called in hot paths.
  - `QuestVerifier.swift` (line 84): `PhotoVerifier` is a stub returning true; no test for the Vision/escalation contract
  - `WeatherKitProvider.swift` (line 140): Real WeatherKit fetch untested (by design — tests only exercise `WeatherMapping`); but the fallback/error handling in `current()` is never exercised
  - `ExploreProviders.swift`: Protocol stubs have no tests (only real implementations tested)
  - `PersistenceModels.swift` and `Models.swift`: No corresponding test files
- Files: `Terrarium/Domain/QuestVerifier.swift`, `Terrarium/Domain/WeatherKitProvider.swift`, `Terrarium/Domain/ExploreProviders.swift`, `Terrarium/Domain/PersistenceModels.swift`, `Terrarium/Domain/Models.swift`
- Impact: Stubs cannot regress if tests don't exercise them. Real implementations (especially async fallback paths) are at risk during refactoring.
- Fix approach: Add unit tests for QuestVerifier behavior (degradation to honor mode when location is nil); test WeatherKitProvider fallback path with a mock WeatherService; add snapshot tests for model serialization in PersistenceModels.

**Silent error swallowing in persistence:**
- Issue: `WorldStore` uses `try?` throughout all SwiftData operations, silently discarding failures. In production, a corrupt database or I/O failure goes unlogged and unobserved.
  - Lines 33, 41–42, 75, 89, 107, 110, 117–118, 123, 134, 142, 165, 186, 192, 198, 202, 222–223
  - Example: `try? context.save()` on line 89 and 165 — a failed save is indistinguishable from success; vitality gain is lost silently.
- Files: `Terrarium/Domain/WorldStore.swift`
- Impact: User progress (specimens, vitality, points) can be lost without any signal to the user or developer. Silent data loss erodes trust.
- Fix approach: Implement a lightweight error logging mechanism (in-memory error journal or OSLog); wrap critical save/fetch operations with error capture; surface data-loss warnings to users if persistence fails (e.g., "Changes may not have saved").

**Logging and observability gap:**
- Issue: The codebase has no logging at all — no `print`, `Logger`, `os_log`, or observability hooks. When things go wrong in the field, developers have no visibility.
- Files: All domain and view-model files
- Impact: Hard to diagnose why quests fail to complete, why discoveries aren't recorded, why location permission requests hang, or why recommendations come back empty.
- Fix approach: Adopt `os_log` (lightweight, free on iOS 14+) for critical paths: location permission state changes, discovery recording, recommendation scoring, WorldStore mutations. Mark logs with subsystem and category so users can toggle them in Console.

## Known Bugs

**Breadcrumb stream multi-consumer issue:**
- Symptoms: When multiple consumers request a breadcrumb stream from `LocationSessionManager.breadcrumbStream()`, each new call finishes the previous stream.
- Files: `Terrarium/Domain/LocationSessionManager.swift` lines 136–148
- Trigger: Call `breadcrumbStream()` twice without cancelling the first one. The first stream is finished on line 138.
- Workaround: Only create one breadcrumb stream per session. Refactor `DriftViewModel` to store the stream if multiple views need it.
- Severity: **Medium** — currently only `DriftViewModel` consumes breadcrumbs, but if future code (e.g., analytics, a secondary map) tries to subscribe, the first consumer loses data.

**One-shot coordinate race condition:**
- Symptoms: If multiple callers invoke `requestOneShotCoordinate()` concurrently, they all await the same `withCheckedContinuation` and are queued in `oneShotWaiters`. The first `didUpdateLocations` callback resumes all of them, but a second callback for the same fix will try to resume an empty queue (safe) or a stale queue (if called between `clm.requestLocation()` and the callback).
- Files: `Terrarium/Domain/LocationSessionManager.swift` lines 179–182, 207–213
- Trigger: Rapid "I'm here" taps or concurrent Anchor + Drift proximity checks before the first fix returns.
- Workaround: Callers coalesce requests; `requestOneShotCoordinate()` is currently called sequentially.
- Severity: **Low** — the callback always clears the queue (line 210), so no waiter is left hanging, but multiple overlapping requests may return stale fixes.

**Geofence containment accuracy below map scale:**
- Symptoms: `LocationVerifier` uses a hardcoded 80m geofence radius to validate "I'm here" arrivals. In dense urban areas (SF), this 80m circle may not align with the POI's actual footprint or the user's perceived location on the map. Users may be marked as "not there yet" despite being visually at the pin, or vice versa.
- Files: `Terrarium/Domain/QuestVerifier.swift` line 56, `Terrarium/Domain/LocationSessionManager.swift` line 104 (distanceFilter)
- Trigger: Attempt arrival verification at a POI with a complex shape (park boundary, building entrance vs. main plaza) or when GPS accuracy is degraded (urban canyon, indoors).
- Workaround: Degrade to honor mode by observing `LocationVerifier` degradation rule (decisions.md #6) — if location is unavailable, award optimistically. No hard geofence required.
- Severity: **Medium** — affects user experience but has a fallback path; a future phase can refine geofence shapes per POI.

## Security Considerations

**Location permission over-request:**
- Risk: `LocationSessionManager` always requests `.whenInUse` authorization, even when the user only wants to browse Anchor (no Drift). This may be perceived as aggressive tracking.
- Files: `Terrarium/Domain/LocationSessionManager.swift` lines 116, 118
- Current mitigation: Only requested when the user explicitly starts a Drift (via `startRamble()`). Anchor's one-shot `requestOneShotCoordinate()` only fires on explicit "I'm here" tap.
- Recommendations: Clarify the `NSLocationWhenInUseUsageDescription` key to users. Consider a "Share live location for this discovery?" prompt before requesting authorization during Anchor arrival. Document the permission lifecycle in the Info.plist and onboarding.

**WeatherKit entitlement and fallback:**
- Risk: `WeatherKitProvider` silently falls back to `.clear` if the WeatherKit capability is not enabled on the App ID or if the network is offline. The app still works, but with degraded recommendations (weather-fit scoring is neutral).
- Files: `Terrarium/Domain/WeatherKitProvider.swift` lines 140–147
- Current mitigation: The fallback is safe (returns `.clear`, not a crash or throw). Unit tests never call WeatherKit, only `WeatherMapping`, so tests pass in any environment.
- Recommendations: Log a non-fatal warning when WeatherKit fails (so developers know to enable the capability before production). Add an integration test in a test harness that can enable the capability.

**Optimistic quest completion (honor mode):**
- Risk: `LocationVerifier` and `PhotoVerifier` both degrade to `true` when verification is unavailable (no location, no permission). This means a user can complete any quest without actually being there or submitting a photo by ensuring location/camera is disabled.
- Files: `Terrarium/Domain/QuestVerifier.swift` lines 40–45 (LocationVerifier), line 87 (PhotoVerifier)
- Current mitigation: Stamped with `verifierKind` in the CompletedQuest record for analytics. Backend can audit suspicious completion patterns later.
- Recommendations: In a production analytics dashboard, surface quests completed in honor mode vs. geofenced mode. Flag accounts with suspiciously high honor-mode completion rates. Consider limiting honor-mode completions per user per day in future.

## Performance Bottlenecks

**RulesRecommender scoring is O(n*m):**
- Problem: `RulesRecommender.driftSeeds()` and `anchor()` iterate over all POIs in the catalog, applying the full scoring formula to each (haversine distance, category match, weather fit, novelty lookup). With a large catalog (100+ POIs), this is done on every "Another" tap and every Drift start.
- Files: `Terrarium/Domain/RulesRecommender.swift` lines 100+ (scoring loop not shown in snippet)
- Cause: Stateless scoring — no caching of scores between calls. The recommender is deterministic by design (same moment → same ranking), but the cost is recomputed scores.
- Improvement path: Cache scores keyed by (context, time_bucket). Invalidate on context change (weather, time, location). For now (small pilot dataset), acceptable; if catalog grows 10x, add an LRU cache.

**Novelty lookup in DiscoveryStore is O(n) per POI:**
- Problem: `RulesRecommender` calls `discoveries.exploredRefs()` once and filters each POI against the set — set membership is O(1), but exploredRefs() fetches all discoveries from SwiftData on every call.
- Files: `Terrarium/Domain/RulesRecommender.swift` (calls `discoveries.exploredRefs()` in the scoring loop)
- Cause: `InMemoryDiscoveryStore` and future SwiftData store compute the set on every call rather than caching.
- Improvement path: Cache `exploredRefs()` in-memory with a version counter; invalidate only when `record()` is called. Ditto for `exploredCells()`.

**Geohash cell computation on every breadcrumb:**
- Problem: `DriftViewModel` converts every breadcrumb (every ~10m) to a geohash cell at precision 7, records a discovery, checks novelty, and updates fog. With a 30-minute ramble, that's ~180 breadcrumbs, each with a geohash decode and a SwiftData insert.
- Files: `Terrarium/Domain/DriftViewModel.swift` (breadcrumb task)
- Cause: No deduplication — if the user lingers in one cell for 5 minutes, the cell is "discovered" 30 times.
- Improvement path: Track the last emitted cell; only record a discovery when the cell ID changes. Can be done in `DriftViewModel` without touching the discovery store.

## Fragile Areas

**AnchorViewModel state synchronization:**
- Files: `Terrarium/AnchorFeature/AnchorViewModel.swift`
- Why fragile: State is split across `pool`, `poolIndex`, `pick`, `arrivalResult`, `arrivalBlocked`, and `context`. Roll and arrival both mutate multiple fields; if a refresh happens mid-operation, the view sees a torn state (e.g., old `pick` with new `context`).
- Safe modification: Use `defer { isLoading = false }` pattern (already in place) to ensure atomicity. Add synchronous helpers like `currentPick()` instead of exposing `pick` directly. Test re-roll / arrival / refresh concurrency.
- Test coverage: `AnchorViewModelTests.swift` covers happy paths; add tests for rapid re-roll+refresh race conditions.

**DriftViewModel session lifecycle:**
- Files: `Terrarium/DriftFeature/DriftViewModel.swift`
- Why fragile: `startRamble()`, `endRamble()`, and the breadcrumb task all touch `session`, `newCells`, `distanceMeters`, `elapsedSeconds`. If `stop()` is called while the breadcrumb task is mid-iteration, or if a user taps "End" twice, the cleanup is complex.
- Safe modification: Ensure `endRamble()` atomically clears `breadcrumbTask` and `timerTask` before emitting the summary. Idempotent guards (already in place on line 148) help but don't fully serialize state mutations.
- Test coverage: Tests mark as `@MainActor` and inject a mock stream; add tests for rapid start/stop/start cycles.

**WorldStore idempotency with SwiftData:**
- Files: `Terrarium/Domain/WorldStore.swift`
- Why fragile: `award()` and `awardPoints()` both check idempotency (already completed, reached tier limit) but do so outside a transaction. If two concurrent `complete()` calls happen, both may pass the idempotency check and insert duplicate props.
- Safe modification: SwiftData doesn't support explicit transactions; rely on `@MainActor` isolation to serialize mutations. Ensure all callers are `@MainActor`. Add a `fetchRecord()` + `alreadyCompleted()` guard pattern directly in `award()` rather than separated.
- Test coverage: `WorldStoreTests.swift` covers the happy path; add a concurrent award test to catch race conditions.

**Preview/demo files not filtered from production:**
- Files: `Terrarium/AnchorFeature/DestinationCardVariants.swift` (615 lines), `Terrarium/AnchorFeature/ExperienceFlowDemo.swift` (492 lines), `Terrarium/AnchorFeature/PaletteWorkshop.swift` (404 lines)
- Why fragile: These are pure UI explorations (variants, workshops, design playgrounds) that compile into the app but should not be shipped. They add code size and could be accidentally integrated into screens during refactoring.
- Safe modification: Move to a separate `#if DEBUG` target or a `Previews` group excluded from the production bundle. Add a build-time check to ensure production builds don't include these files.
- Test coverage: None needed; these are preview-only. But enforce via build rules.

## Scaling Limits

**Catalog size scalability:**
- Current capacity: ~3 items in `StubPOICatalog` (pilot); `sf-pois.json` likely ~50–100 POIs for SF pilot.
- Limit: At 1000+ POIs, the O(n) scoring in RulesRecommender becomes perceptible (100ms+ per refresh). Haversine distance and category/weather filtering are cheap, but the novelty lookup + sorting can bottleneck.
- Scaling path: Implement spatial indexing (geohash or quadtree) to filter POIs by distance before scoring. Cache scores. Paginate driftSeeds results.

**Discovery store growth:**
- Current capacity: In-memory array grows unbounded; no limit on discoveries per session or lifetime.
- Limit: After 1000+ discoveries, fetching all refs for novelty scoring and all cells for fog-of-war become expensive (O(n) SwiftData fetches).
- Scaling path: Archive old discoveries (older than 30 days) to a separate table. Implement lazy loading with pagination for journal entries.

**Breadcrumb storage:**
- Current capacity: Every breadcrumb is a discovery + a potential geohash cell record. A 30-minute Drift at 10m granularity = 180 breadcrumbs = 180+ records.
- Limit: With 100+ drifts per user lifetime, the discovery table grows to 10K+ records. Journal entries and photos (Stream F) add more.
- Scaling path: Implement data retention policies (archive discoveries older than 3 months). Compress historical breadcrumb trails into cell heatmaps.

## Dependencies at Risk

**WeatherKit entitlement requirement:**
- Risk: The app compiles without WeatherKit enabled, but falls back to `.clear` weather. If the deployment pipeline doesn't include the capability, production builds will silently lose weather-fit scoring.
- Impact: Recommendations degrade silently; users don't know they're missing weather personalization.
- Migration plan: Document the WeatherKit capability as a required deploy step. Add an entitlement check to `WeatherKitProvider` that logs a warning on first run if missing.

**SwiftData persistence (locked to iOS 17+):**
- Risk: SwiftData is iOS 17+ only. If a future phase requires iOS 16 support, `WorldStore` and persistence must be rewritten.
- Impact: Blocks downgrade; terrarium player progression is locked to iOS 17+.
- Migration plan: Keep `DiscoveryStore` protocol-based so real implementations can be swapped. If iOS 16 support is needed, implement a `CoreDataDiscoveryStore` conforming to the same protocol.

**CLLocationManager background/ambient tracking gap:**
- Risk: The app uses `.whenInUse` location only. If a future phase wants to record drifts in the background (e.g., notify the user when a landmark is nearby), the permission model is insufficient.
- Impact: Cannot implement background discovery or push notifications for POI proximity without a larger iOS integration.
- Migration plan: Adopt `.always` permission in a future phase, with explicit user opt-in. Implement background-friendly breadcrumb recording (less frequent updates to save battery).

## Missing Critical Features

**Photo verification stub (PhotoVerifier):**
- Problem: `PhotoVerifier.verify()` is hardcoded to return `true` (line 87). There's a comment `// TODO(Phase 2): Vision quick-check + async backend escalation.` The feature is a placeholder; no actual photo upload or Vision analysis exists.
- Blocks: Stream F photo-backed journal entries, on-device verification of "here's proof you were here," backend analytics.
- Workaround: Existing callers (Anchor "I'm here" in honor mode, Drift discovery) don't use PhotoVerifier yet; Stream F will wire it in.

**Reverse geocoding (address display):**
- Problem: `Providers.swift` line 31 marks `StubSkyStateProvider` returning hardcoded `locationName: "SF"`. Real reverse geocoding (lat/lon → place name) is not implemented.
- Blocks: Displaying the user's current location on the Drift map, pinning discoveries to place names for the journal.
- Workaround: `LocationSessionManager` and `ContextAssembler` can be extended with a `ReverseGeocoderProviding` protocol; for now, place names come from the POI catalog.

**Machine-learning personalization:**
- Problem: `RulesRecommender` is deterministic rules-based only. No ML, no learning from user history beyond novelty demotion.
- Blocks: Truly personalized recommendations that adapt to user behavior over time, cross-device preferences, social signals.
- Workaround: The rules engine includes persona bias (restlessLocal, newcomer, weekendDrifter) hardcoded as additive offsets. This is sufficient for MVP.

## Test Coverage Gaps

**LocationSessionManager degradation paths:**
- What's not tested: Permission denied, restricted, or not-yet-determined states; the behavior of `requestOneShotCoordinate()` when location is unavailable; breadcrumb loss when `didFailWithError` fires.
- Files: `Terrarium/Domain/LocationSessionManager.swift` lines 112–124 (permission handling), 167–183 (one-shot), 264–273 (error handling)
- Risk: A permission flow change in iOS or a real location error could break the honor-mode fallback without detection.
- Priority: **High** — location is a critical integration point and degradation behavior is user-facing.

**WeatherKitProvider fallback:**
- What's not tested: The `current()` method's catch block (line 146). Tests exercise `WeatherMapping` only, not the actual fetch and fallback.
- Files: `Terrarium/Domain/WeatherKitProvider.swift` line 140–147
- Risk: A change to the fallback logic (e.g., switching from `.clear` to a different default) won't be caught.
- Priority: **Medium** — fallback is simple but touches the hot path; integration test in a build with WeatherKit enabled would help.

**ExploreProviders stubs (no tests):**
- What's not tested: The stub catalog, recommender, discovery store are never verified to match their protocol contracts outside of integration.
- Files: `Terrarium/Domain/ExploreProviders.swift` lines 92–173
- Risk: Stubs can silently diverge from the protocol as protocol-based code evolves. When real implementations land, integration failures are hard to debug.
- Priority: **Medium** — add unit tests for each stub's basic behavior (all() returns fixtures, allowedRefs() is consistent, recommender ranks in catalog order).

**Concurrent quest completion:**
- What's not tested: Two rapid `complete()` calls for different quests, or two `awardPoints()` calls with tier boundaries, hitting the WorldStore simultaneously.
- Files: `Terrarium/Domain/WorldStore.swift` (all methods)
- Risk: Race conditions in SwiftData mutations, duplicate props, lost points.
- Priority: **Medium** — all mutations are `@MainActor` so sequentialized, but test confirms the idempotency logic.

---

*Concerns audit: 2026-06-17*
