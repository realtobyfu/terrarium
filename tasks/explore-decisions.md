# Explore (Drift & Anchor) — Build Decisions & Open-Question Answers

This is the running log of decisions made while building the PRD
(`tasks/prd-explore-drift-anchor.md`) across parallel coding agents. It records
the answers to the PRD's Open Questions and any contract choices, so every stream
builds against the same assumptions.

## Orchestration

- **Feature branch:** `explore-drift-anchor` (forked from `main`).
- **Wave 0 (Stream H)** landed first (serial), freezing the protocol contracts in
  `Domain/ExploreModels.swift` + `Domain/ExploreProviders.swift`.
- **Waves 1–3** built by subagents in isolated git worktrees, merged in dependency
  order (H → A/B/C/G → D/E → F). The only shared files across streams are
  `App/AppContainer.swift` and `App/RootView.swift`; conflicts there are reconciled
  at merge time.
- **Build/test destination:** iOS Simulator `iPhone 17`, OS 26.0
  (`id=E669E9FF-1333-4973-BB25-E6C1B308D2FC`). The plain "iPhone 16" simulator is
  not in the scheme's supported destinations on this machine.

## Contract note: `DayPart`

The Explore time-of-day bucket is named **`DayPart`** (`morning/afternoon/evening/
night`), NOT `TimeOfDay` — the codebase already has a debug `TimeOfDay`
(`dawn/midday/goldenHour/night`) in `DebugSkyCycler.swift`. Don't reintroduce the
name clash.

## Open Questions — answers

1. **Cells: H3 port vs geohash?** → **Geohash**, zero-dependency, pure, stable
   across launches. Pilot precision **7** (~153 m × 153 m cells) — a good walking
   granularity for fog-of-war. Cell id = geohash string. Neighborhood rollups use
   the geohash prefix. (H3 deferred; revisit post-pilot if hex rollups matter.)

2. **Places API for seeding (US-A2): Foursquare vs Google?** → **Foursquare**
   Places API (free tier, vibe-friendly tags). Used offline at curation time only,
   never at rank time. API key read from env var `FSQ_API_KEY`, never committed.

3. **Anchor default travel radius (per persona)?** → Default **1500 m**. Persona
   modifiers applied in onboarding (US-G1):
   - Restless Local → 2000 m
   - Newcomer → 1200 m
   - Weekend Drifter → 2500 m
   Stored in `UserPreferences.travelRadiusMeters`; the ranker applies a soft
   distance penalty beyond it (not a hard cutoff).

4. **Open-now unknown-hours penalty?** → **Soft.** `openNow` multiplier is `1.0`
   open, `0.0` closed (hard-excluded for Anchor), and **`0.6`** for unknown hours.
   Named constant `RulesRecommender.unknownHoursPenalty`. Anchor never surfaces a
   place evaluated *closed*; unknown is allowed but demoted.

5. **Specimen context variants per kind?** → Pilot ships **2 weather variants**:
   `foggy` vs `clear` (everything not fog maps to the clear/default look), keyed
   off `Discovery.context.weather`. Time-of-day variants deferred. Variant is a
   string suffix on the specimen appearance key; no new 3D art (FR-21).

6. **Honor-mode generosity when geofence unavailable?** → **Award optimistically**
   (like `PhotoVerifier`), but record the discovery with `verifierKind = .honor` so
   honor-mode arrivals stay distinguishable from geofenced ones. Loop closure
   (success metric) beats strictness when verification simply isn't available.

## Stream log

(Appended as each stream lands.)

- **H (Foundation):** ✅ DONE, committed `27af64a` on `explore-drift-anchor`.
  Domain types (`POI`, `RecommendationContext`, `UserPreferences`,
  `RambleSession`/`DiscoveryCell`, `Discovery`), provider protocols + offline
  stubs, `AppContainer` wiring + skeleton Anchor/Drift VMs. Build + tests green.

### Wave 1 — in progress (parallel worktree agents, forked from `27af64a`)

Each agent commits to its own worktree branch and reports back; merge in order
A → B → C → G into `explore-drift-anchor`, then I swap stubs→real in AppContainer.

| Stream | Agent ID | Sim | Status |
|---|---|---|---|
| A Catalog | a17062e463ccd6d1f | iPhone 17 | ✅ MERGED (40 POIs, 17 tests) |
| B Context | a8d31b2a317b591aa | iPhone 17 Pro | ✅ MERGED (62 tests) |
| C Ranker | a37163529f1aa12f7 | iPhone 17 Pro Max | ✅ MERGED (27 tests) |
| G Onboard/Shell | ab5800ea87ca93f1b | iPhone Air | running |

**Stream B integration TODOs (affect Waves 2/3):**
- `LocationSessionManager.currentCoordinate()` returns **nil while a session is
  active** (B chose breadcrumb stream as the primary path). Anchor (D) needs a
  current coord for distance/ranking, and the geofence verifier (F) needs a
  one-shot fix. **Fix at integration:** have `currentCoordinate()` return the last
  breadcrumb when active, else a momentary read — OR have D/F do a momentary read.
- WeatherKit entitlement is a deploy-time capability (App ID). Without it the
  provider returns the `.clear` fallback; app still works.
- Temporary full-accuracy needs `NSLocationTemporaryUsageDescriptionDictionary`
  (`ExploreAccuracy` key) added later.

C merged via `--no-ff` (branch `worktree-agent-a37163529f1aa12f7`); added
`OpenNowEvaluator.swift` + `RulesRecommender.swift` (+ tests). Integration branch
builds green. Named weights live in `RulesRecommender` (noveltyExplored=0.3,
weatherFit boosts, distancePenalty=0.75, persona additive bonuses).

**Merge / file-ownership notes for integration:**
- A, B, C do NOT touch `App/*`. Only **G** edits `RootView.swift` + `AppContainer.swift`.
- Only **B** edits `project.pbxproj` (the `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` build setting).
- After merging A/B/C/G: in `AppContainer`, swap `StubPOICatalog`→`BundledPOICatalog`,
  `StubWeatherProvider`→`WeatherKitProvider`, `StubLocationSession`→`LocationSessionManager`,
  `StubRecommender`→`RulesRecommender`. Keep stubs as the `inMemory`/test fallback.

### Known risks / merge-time checks
- **WeatherKit name collision:** `import WeatherKit` brings in `WeatherKit.Weather`,
  shadowing our `Weather` enum (symptom: `Type 'Weather' has no member 'clear'`).
  Stream B must disambiguate (e.g. a `typealias` in a non-WeatherKit file, or
  fully-qualify `WeatherKit.WeatherCondition`). Verify B's build is actually green
  before merging.

### Remaining waves
- **Wave 2:** D Anchor (needs A,B,C — concierge screen US-D1 + terrarium handoff US-D2), E Drift (needs B+cells — US-E1 session, US-E2 fog/geohash cells, US-E3 route gen). Run as 2 parallel worktree agents off the merged branch. D creates `AnchorView.swift`, E creates `DriftView.swift`; shell placeholders (from G) get swapped to these.
- **Wave 3 (serial):** F Integration — real `LocationVerifier` geofence (US-F1), discovery→specimen mapping w/ context variants (US-F2), discovery journaling (US-F3); wire D&E discoveries into `WorldStore`; full suite + both-mode Simulator smoke test.
