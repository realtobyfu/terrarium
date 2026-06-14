# PRD: Terrarium Explore — Drift & Anchor

## Introduction

Terrarium is pivoting from a quest-completion globe toward a **real-world urban exploration** app. Today the globe grows specimens when a user completes a suggested quest. This feature turns the *source* of that growth into the real city: the user goes out, explores, and what they discover feeds their terrarium.

The feature ships **two modes** over one shared, curated POI backend:

- **Drift** — the ramble. A session-based aimless walk. The app records a breadcrumb trail (only while the session is active), lights up a fog-of-war map, and drops specimens into the terrarium for newly explored areas. The journey is the point.
- **Anchor** — the Saturday-morning concierge. "I have no plans — give me one good place to go." A single curated destination, ranked by weather, time of day, location, and the user's stated tastes. Reaching it grows a specimen too, and can seed a Drift around the neighborhood.

Both modes are **context-aware** (weather + time + location + persona), use **session-based location only** (`When In Use`, no background surveillance, data on-device), and are **fully wired into the existing terrarium** (specimens, globe, journal, vitality). The pilot is **curated San Francisco**: candidates pulled from Places APIs, then hand-tagged for taste.

This document specifies the feature and a plan to **parallelize the build across multiple coding agents** by exploiting the existing protocol/stub architecture.

---

## Goals

- Ship Drift and Anchor as two modes over one curated SF POI catalog.
- Make every discovery feed the existing terrarium (specimen + globe + journal + vitality), reusing `WorldStore`, `POIPlacement`, `SpecimenFactory`, and the solar/sky system.
- Recommend places using a **deterministic, rules-based ranker** (no ML in the pilot) that reads weather, time, location, and persona.
- Keep location tracking bounded to active sessions (`When In Use`) and all exploration data on-device.
- Establish a rich **POI tag schema** as the core asset, seeded from APIs and refined by hand.
- Structure the work so 5–6 agents can build in parallel behind protocol contracts, with a clean integration phase.

## Non-Goals (Out of Scope)

- **No ML / learned recommender** in the pilot. The rules-based ranker is the whole brain. ML is a post-pilot phase once behavioral data exists.
- **No AR.** A lightweight AR "reveal on arrival" is explicitly deferred to a later polish phase.
- **No background / ambient discovery** (`Always` permission, `CLVisit`). Session-based only.
- **No social features** (sharing, friends, leaderboards) in the pilot.
- **No multi-city expansion.** SF only. The catalog format must *allow* expansion, but no second city ships here.
- **No server-side recommendation service.** Ranker runs on-device against the bundled + API-fetched catalog.
- **No new 3D specimen art** beyond mapping POI categories onto the existing `tree` / `building` / `flowers` kinds (see FR-21). New specimen models are a fast-follow.

---

## Personas (drive ranker bias, set during onboarding)

- **The Restless Local** — knows the city, bored, "surprise me." *Primary persona for SF.*
- **The Newcomer** — new in town; fog-of-war discovery is the hook.
- **The Weekend Drifter** — no-plans Saturday; Anchor mode's person.

Persona is captured as a few onboarding taps (interest tags + vibe + travel radius), not separate apps. It biases the ranker; it does not branch the UI.

---

## POI Tag Schema (the core asset — FR-1)

Each POI carries rich, hand-verifiable metadata. This schema is the moat; the ranker is only as good as these tags.

| Field | Type | Notes |
|---|---|---|
| `poiRef` | String (stable id) | e.g. `poi.sightglass-coffee.sf`. Feeds `POIPlacement` + `QuestGrounding`. Immutable. |
| `name` | String | Display name. |
| `category` | enum | `park`, `coffee`, `bookstore`, `restaurant`, `viewpoint`, `market`, `museum`, `bar`, `other`. |
| `neighborhood` | String | e.g. "SoMa". Used for Drift seeding + novelty rollups. |
| `coordinate` | (lat, lon) | Real-world degrees. |
| `indoorOutdoor` | enum | `indoor` / `outdoor` / `mixed`. Drives `weatherFit`. |
| `bestTime` | [enum] | `morning`, `afternoon`, `evening`, `night`. |
| `weatherFit` | [enum] | Subset of `clear`, `cloudy`, `fog`, `rain`, `snow` where this place shines. |
| `goodFor` | [enum] | `solo`, `date`, `group`. |
| `vibe` | [tag] | free-ish controlled tags: `quiet`, `lively`, `cozy`, `scenic`, `quirky`. |
| `price` | enum | `free`, `$`, `$$`, `$$$`. |
| `hoursRef` | String? | Hours source key (API-backed) for open-now checks; null = unknown. |
| `specimenKind` | enum | Which terrarium specimen this grows (pilot: maps to `tree`/`building`/`flowers`, FR-21). |
| `source` | enum | `curated`, `foursquare`, `google`, `osm` — provenance for QA. |

---

## User Stories

Stories are grouped by **work stream (epic)**. Each is sized for one focused agent session. iOS UI stories verify in the **iOS Simulator** (via the `simulator-workflows` / `xcode-workflows` skills), not a browser.

### Stream H — Foundation & Contracts (must land first)

#### US-H1: Define new domain value types
**Description:** As a developer, I need the new pure value types so every other stream compiles against them.

**Acceptance Criteria:**
- [ ] Add `POI` value type matching the tag schema (FR-1), `Equatable`, `Codable`.
- [ ] Add `RecommendationContext` (weather, date/time, optional coordinate, persona prefs).
- [ ] Add `Persona`/`UserPreferences` value type (interest tags, vibe, travel radius).
- [ ] Add `RambleSession` + `DiscoveryCell` (hex/geo cell id + state) value types.
- [ ] Add `Discovery` event type (poiRef or cell, timestamp, context snapshot).
- [ ] All new types `Equatable`; placed in `Domain/`; build + existing tests pass.

#### US-H2: Define new provider protocols + offline stubs
**Description:** As a developer, I need protocols + stubs so streams build independently and the app keeps running offline.

**Acceptance Criteria:**
- [ ] `POICatalogProviding { func all() -> [POI]; func allowedRefs() -> Set<String> }` + bundled-JSON stub.
- [ ] `WeatherProviding { func current() async -> Weather }` + stub returning `.fog` (matches current behavior).
- [ ] `LocationSessionProviding` (start/stop session, breadcrumb stream, current coord) + stub.
- [ ] `PlaceRecommending { func anchor(_:RecommendationContext) -> POI?; func driftSeeds(_:RecommendationContext) -> [POI] }` + stub.
- [ ] `DiscoveryStore` protocol (record discovery, explored cell set, explored refs) + in-memory stub.
- [ ] All protocols wired into `AppContainer` with stubs; app builds and runs offline; existing tests pass.

#### US-H3: Extend AppContainer composition root
**Description:** As a developer, I need the container to vend the new providers so view models receive them via injection.

**Acceptance Criteria:**
- [ ] `AppContainer` constructs catalog, weather, location, recommender, discovery store (stubs by default).
- [ ] New view-model factory methods added (`makeAnchorViewModel`, `makeDriftViewModel`).
- [ ] `inMemory` path still degrades gracefully; build + tests pass.

### Stream A — POI Catalog & Tag Schema

#### US-A1: Bundled catalog loader
**Description:** As a developer, I want a JSON-backed catalog so the app has offline POIs and a stable `allowedRefs` set.

**Acceptance Criteria:**
- [ ] `BundledPOICatalog` loads `sf-pois.json` from the bundle into `[POI]`.
- [ ] Conforms to `POICatalogProviding`; `allowedRefs()` returns all `poiRef`s for `QuestGrounding`.
- [ ] Malformed/missing file degrades to empty catalog without crashing; unit tests cover parse + degrade.

#### US-A2: API-seed ingestion script/tool
**Description:** As a curator, I want to pull POI candidates from a Places API into the schema so I can hand-tag them.

**Acceptance Criteria:**
- [ ] A script/dev-tool fetches candidates (Foursquare or Google Places) for SF by category and emits schema-shaped JSON with `source` set.
- [ ] Output includes coordinate, name, category guess, hours ref; tag fields left blank for hand-tagging.
- [ ] Documented run instructions; no API keys committed.

#### US-A3: Curated SF dataset (pilot content)
**Description:** As a curator, I want ~150–300 hand-tagged SF spots so recommendations feel like a friend's pick.

**Acceptance Criteria:**
- [ ] `sf-pois.json` contains ≥150 POIs across all categories and ≥8 neighborhoods.
- [ ] Every POI has `vibe`, `indoorOutdoor`, `bestTime`, `weatherFit`, `goodFor`, `price` filled.
- [ ] Validation test: no duplicate `poiRef`, all enums valid, all coordinates within SF bounds.

### Stream B — Context Signals

#### US-B1: WeatherKit provider
**Description:** As a user, I want recommendations to reflect real weather.

**Acceptance Criteria:**
- [ ] `WeatherKitProvider` conforms to `WeatherProviding`, maps WeatherKit conditions → `Weather` enum.
- [ ] Falls back to `.clear` (or last-known) on failure; never blocks UI.
- [ ] Mapping is unit-tested with representative condition inputs.

#### US-B2: Session location manager
**Description:** As a user, I want the app to track me only during an active session, with a friendly permission prompt.

**Acceptance Criteria:**
- [ ] `LocationSessionManager` conforms to `LocationSessionProviding`, requests `When In Use`.
- [ ] Emits breadcrumbs (`activityType = .fitness`, `desiredAccuracy = .best`) only between `start()` and `stop()`.
- [ ] Requests temporary full accuracy if user granted reduced accuracy.
- [ ] No location calls outside an active session; `Info.plist` purpose string added.
- [ ] Permission-denied path surfaces a recoverable state (no crash); logic unit-tested with an injected mock `CLLocationManager`.

#### US-B3: Context assembler
**Description:** As a developer, I want one place that assembles `RecommendationContext` from weather + clock + location + persona.

**Acceptance Criteria:**
- [ ] Pure assembler builds `RecommendationContext`; deterministic given inputs.
- [ ] Unit tests cover morning/evening, each weather, with/without coordinate.

### Stream C — Recommendation Ranker

#### US-C1: Rules-based scorer
**Description:** As a user, I want suggestions that fit the moment without any ML.

**Acceptance Criteria:**
- [ ] Pure `RulesRecommender` conforms to `PlaceRecommending`.
- [ ] Score = `categoryMatch × openNow × weatherFit × distance × novelty`; weights are named constants.
- [ ] `novelty` reads the `DiscoveryStore` explored set (already-explored POIs rank lower).
- [ ] `anchor()` returns the single best open-now place; `driftSeeds()` returns N ranked seeds.
- [ ] Fully unit-tested: weather flips indoor/outdoor ranking; closed places excluded; explored places demoted; persona bias applied.

#### US-C2: Open-now evaluation
**Description:** As a user, I never want to be sent somewhere closed (critical for Anchor trust).

**Acceptance Criteria:**
- [ ] `openNow` resolves from `hoursRef`; unknown hours treated as a configurable soft penalty (not hard-excluded).
- [ ] Unit tests cover open, closed, and unknown-hours cases.

### Stream D — Anchor Mode

#### US-D1: Anchor suggestion screen
**Description:** As a Weekend Drifter, I want one great place to go when I have no plans.

**Acceptance Criteria:**
- [ ] Screen shows the top Anchor pick: name, category, walk time/distance, open-now, a vibe line.
- [ ] Reflects current weather + time (e.g. rainy → cozy indoor).
- [ ] `[Another]` re-rolls to the next-best pick; `[Take me there]` opens directions (Maps handoff).
- [ ] Empty/permission-off state handled gracefully.
- [ ] Build + tests pass; verify in iOS Simulator.

#### US-D2: Anchor → terrarium handoff
**Description:** As a user, reaching my Anchor should grow my terrarium.

**Acceptance Criteria:**
- [ ] On verified arrival (LocationVerifier, FR-15), a discovery is recorded and a specimen grows via `WorldStore.award`.
- [ ] Honor-mode fallback available when location verification is unavailable.
- [ ] Verify specimen appears on globe in Simulator.

### Stream E — Drift Mode

#### US-E1: Ramble session lifecycle
**Description:** As a user, I want to start and end a ramble that records my path.

**Acceptance Criteria:**
- [ ] "Start a ramble" requests/uses `When In Use`, begins a `RambleSession`, shows live elapsed time/distance.
- [ ] "End ramble" stops tracking and shows a summary (cells lit, specimens earned).
- [ ] Session survives screen-off via background-location capability while active; ends cleanly.
- [ ] Verify start→walk(simulated route)→end in Simulator.

#### US-E2: Cell discovery + fog of war
**Description:** As a user, I want the map to fill in as I explore.

**Acceptance Criteria:**
- [ ] Breadcrumbs map to discrete cells (hex via H3 port, or geohash) recorded in `DiscoveryStore`.
- [ ] Map renders explored cells revealed and unexplored as fog.
- [ ] New cells this session are visually distinct.
- [ ] Cell math is pure + unit-tested (coordinate → cell id stable across launches).
- [ ] Verify fog reveal in Simulator.

#### US-E3: Route generation (loop walks + randomness dial)
**Description:** As a Restless Local, I want a suggested loop of roughly N minutes.

**Acceptance Criteria:**
- [ ] Generates a loop walk from current location targeting a chosen duration, returning near start.
- [ ] A randomness dial spans "surprise me / random heading" → "loop hitting a park + coffee" using `driftSeeds()`.
- [ ] Safety filter: public/walkable only; respects time of day; no private land.
- [ ] Route-shaping logic unit-tested with fixture seeds.

### Stream F — Terrarium Integration

#### US-F1: Real LocationVerifier (geofence)
**Description:** As a developer, I need arrival at a POI to actually verify so discoveries are real.

**Acceptance Criteria:**
- [ ] `LocationVerifier.verify` performs a real geofence test against the quest/POI coordinate using a momentary location read.
- [ ] Honors the session-only rule; degrades to honor mode when unavailable.
- [ ] Geofence containment math unit-tested (inside/outside/edge).

#### US-F2: Discovery → specimen mapping with context variants
**Description:** As a user, what I collect should vary by weather and time, like the sky already does.

**Acceptance Criteria:**
- [ ] `category → specimenKind` mapping (FR-21) drives `WorldStore.award`.
- [ ] Specimen variant/appearance keys off the `Discovery` context snapshot (e.g. foggy vs sunny).
- [ ] Placement uses existing `POIPlacement.sphereCoordinate(forPOIRef:)` so a place always grows in the same spot.
- [ ] Mapping + variant selection unit-tested; verify a foggy vs clear discovery differs in Simulator.

#### US-F3: Discovery journaling
**Description:** As a user, I want my discoveries logged with optional reflection/photo.

**Acceptance Criteria:**
- [ ] Each discovery can create a `JournalEntry` via existing `WorldStore.addJournal` (place name from POI).
- [ ] Tapping a specimen opens its discovery journal (existing interaction reused).
- [ ] Verify journal entry round-trips in Simulator.

### Stream G — Onboarding, Permissions & Mode Shell

#### US-G1: Persona/preference onboarding
**Description:** As a new user, I want to set my tastes so suggestions fit me.

**Acceptance Criteria:**
- [ ] Onboarding captures interest tags, vibe, and travel radius into `UserPreferences` (persisted).
- [ ] Skippable with sensible defaults (Restless Local).
- [ ] Verify flow in Simulator.

#### US-G2: Location pre-permission priming
**Description:** As a user, I want context before the system asks for location.

**Acceptance Criteria:**
- [ ] A priming screen explains *why* location is used (draw your map during walks) before the system prompt fires.
- [ ] Only triggers the system prompt after the user proceeds; never on cold launch.
- [ ] Verify ordering in Simulator.

#### US-G3: Mode shell (Drift / Anchor toggle)
**Description:** As a user, I want to switch between the two modes.

**Acceptance Criteria:**
- [ ] A shell hosts Drift and Anchor with a clear toggle/entry, integrated into `RootView`.
- [ ] State preserved when switching; existing Home/globe reachable.
- [ ] Verify navigation in Simulator.

---

## Functional Requirements

- **FR-1:** POIs must carry the full tag schema above; `poiRef` is stable and immutable.
- **FR-2:** The catalog must load offline from a bundled JSON and expose `allowedRefs()` for `QuestGrounding` (no recommendation may reference a POI outside the catalog).
- **FR-3:** API-seeded candidates must be hand-taggable; provenance stored in `source`.
- **FR-4:** The pilot catalog must contain ≥150 hand-tagged SF POIs across all categories and ≥8 neighborhoods.
- **FR-5:** Weather must come from WeatherKit, mapped to the existing `Weather` enum, with a non-blocking fallback.
- **FR-6:** Location tracking must occur **only** during an active session and use `When In Use`; no background/ambient tracking.
- **FR-7:** A purpose string and pre-permission priming screen must precede the system location prompt.
- **FR-8:** All exploration data (breadcrumbs, cells, discoveries) must persist on-device only.
- **FR-9:** The recommender must be a pure, deterministic, rules-based function (no ML, no network at rank time).
- **FR-10:** Anchor must never surface a place evaluated as closed; unknown-hours places get a soft penalty.
- **FR-11:** Anchor must re-roll on demand and hand off directions to Maps.
- **FR-12:** Drift must record breadcrumbs → discrete cells and render a fog-of-war map.
- **FR-13:** Drift must generate loop walks targeting a chosen duration with a randomness dial.
- **FR-14:** Drift route generation must apply a safety filter (public/walkable, time-of-day aware).
- **FR-15:** `LocationVerifier` must perform a real geofence arrival test, with honor-mode fallback.
- **FR-16:** A verified discovery must grow a specimen via `WorldStore.award` and place it via `POIPlacement`.
- **FR-17:** Specimen variant must key off the discovery's weather/time context snapshot.
- **FR-18:** Discoveries must be journalable via existing `WorldStore.addJournal`.
- **FR-19:** Persona preferences must persist and bias the ranker.
- **FR-20:** The app must offer a Drift/Anchor mode shell integrated with the existing globe Home.
- **FR-21:** In the pilot, `category → specimenKind` maps onto existing kinds: `park/viewpoint → tree`, `coffee/restaurant/bookstore/market/museum/bar → building`, `other → flowers`. New art is out of scope.
- **FR-22:** All new domain logic (ranker, cell math, geofence, weather mapping, catalog parse) must be unit-tested following the existing pure-domain test pattern.

---

## Design Considerations

- **Reuse the protocol/stub pattern.** Every new capability is a `protocol` + offline stub composed in `AppContainer`, exactly like `SkyStateProviding` / `WorldStateProviding` / `QuestSuggesting`.
- **Render-don't-store** holds: `DiscoveryCell`/fog state are derived value types over SwiftData records.
- **Reuse existing components:** `WorldStore` (award/journal/vitality), `POIPlacement`, `SpecimenFactory`, the solar/sky system, `QuestGrounding`, `JournalView`/`GrowthLogView`.
- Anchor copy must feel like a friend, not a search result. Drift UI must be glance-able ("look once, pocket the phone").
- Lean into SF identity (fog/"Karl the Fog" as a feature, not a downgrade).

## Technical Considerations

- **WeatherKit** entitlement + capability required (Apple Developer config).
- **Location**: `When In Use` + background-location *capability* for screen-off during active Drift sessions only; `Info.plist` purpose strings.
- **Cells**: prefer an **H3 Swift port** (uniform hexes, neighborhood rollups); geohash is an acceptable simpler fallback. Cell→id must be pure and stable across launches (mirror the determinism discipline in `POIPlacement`).
- **Places API** (Foursquare free tier or Google Places) used **only offline at curation time**, never at rank time. Keys never committed.
- **SwiftData**: add records for discoveries/cells/preferences alongside the existing flat model; keep relationships minimal (the codebase deliberately avoids SwiftData relationships).
- **Determinism for tests**: ranker, cell math, and geofence are pure functions injected with context — no clocks/RNG/location read inside them.

---

## Parallelization & Agentic Orchestration Plan

The build is designed to fan out across **5–6 coding agents** working concurrently in **isolated git worktrees**, coordinated by the protocol contracts. The key enabler is the existing architecture: **protocols are the API between agents**, and **stubs keep the app compiling** while real implementations land independently.

### Principle: contracts first, then fan-out

Wave 0 is a **single serialized agent** that lands Stream H (types + protocols + stubs + container wiring). Once merged, the protocol signatures are frozen as the integration contract and every other stream builds against them — including against *other streams' stubs* — so no agent waits on another's implementation.

### Dependency graph

```
        ┌──────────────────────────────┐
        │  WAVE 0 (serial): Stream H    │
        │  types · protocols · stubs ·  │
        │  AppContainer wiring          │
        └───────────────┬──────────────┘
                        │ contracts frozen
   ┌──────────┬─────────┼─────────┬──────────┬──────────┐
   ▼          ▼         ▼         ▼          ▼          ▼
 WAVE 1 (parallel, leaf providers — no cross-deps)
 A: Catalog  B: Context  C: Ranker*  G: Onboard/Shell
   │            │          │            │
   └─────┬──────┴────┬─────┘            │
         ▼           ▼                  │
 WAVE 2 (parallel features, depend on Wave-1 impls)
   D: Anchor (needs A,B,C)   E: Drift (needs B + cells)
         │           │
         └─────┬─────┘
               ▼
 WAVE 3 (serial-ish): F Terrarium integration
   geofence verifier · discovery→specimen · journaling
   wires D & E discoveries into WorldStore
```

\*C (Ranker) can start in Wave 1 against A's and B's *stubs* (it only needs the `POI` and `RecommendationContext` types from H), then swap to real data when A/B merge.

### Work-stream assignment

| Stream | Scope | Depends on | Parallel with | Suggested agent |
|---|---|---|---|---|
| **H** Foundation | Types, protocols, stubs, container | — | (none — runs alone) | 1 agent, `swiftui-expert` |
| **A** Catalog | Loader, API-seed tool, SF dataset | H | B, C, G | 1 agent + curator (you) for A3 |
| **B** Context | WeatherKit, location session, assembler | H | A, C, G | 1 agent, CoreLocation/WeatherKit |
| **C** Ranker | Rules scorer, open-now, novelty | H (types) | A, B, G | 1 agent (pure logic, test-heavy) |
| **D** Anchor | Concierge screen + terrarium handoff | A, B, C | E | 1 agent, `swiftui-expert` |
| **E** Drift | Session, fog of war, route gen | B, cells | D | 1 agent, `swiftui-expert` |
| **F** Integration | Geofence verifier, discovery→specimen, journaling | D, E, WorldStore | (last) | 1 agent (owns the merge) |
| **G** Onboarding/Shell | Persona, priming, mode toggle | H | A, B, C | 1 agent, `swiftui-expert` |

### Execution mechanics

- **Isolation:** each Wave-1/2 agent runs in its own git worktree (`Agent` tool `isolation: "worktree"`) so file edits never collide. Streams touch mostly disjoint files; the only shared file is `AppContainer.swift`, frozen after Wave 0 (later additions are small, append-only, and reconciled by the integration agent).
- **Contract stability:** treat the protocol signatures from US-H2 as a frozen API. A stream that needs a contract change must surface it for a coordinated bump, not edit unilaterally.
- **Build/test per stream:** every agent must keep `xcode_build` green and add unit tests in the existing pure-domain style; pure-logic streams (C, parts of B/E/F) are validated by tests with **no simulator needed**, which is what makes them safe to parallelize.
- **Simulator verification** (D, E, G, F UI bits) uses the `simulator-workflows` / `ui-automation-workflows` skills; run these after the pure streams are green to avoid simulator contention.
- **Integration phase (Wave 3):** a single agent merges worktrees in dependency order (H→A/B/C/G→D/E→F), swaps stubs for real providers in `AppContainer`, and runs the full suite + a Simulator smoke test of both modes.
- **Coordination ledger:** track the eight streams as tasks (status, owner agent, blocked-by) so wave gating is visible. Priority Forge is the natural home for this.

### What stays serial (don't parallelize)

- Wave 0 (H) — it defines the contracts everyone shares.
- Wave 3 (F + final container swap) — it's the convergence point and touches everyone's seams.
- The SF dataset taste pass (US-A3) — curation is a human judgment call; an agent seeds candidates, you make the calls.

---

## Success Metrics

Pilot validates the *loop*, not scale:

- **Activation:** ≥60% of new users complete onboarding and trigger one mode in session 1.
- **Anchor trust:** <5% of Anchor picks reported "closed/bad pick" (open-now correctness is the proxy).
- **Drift engagement:** median ramble session ≥10 minutes; ≥3 cells lit per session.
- **Loop closure:** ≥40% of sessions end with ≥1 specimen added to the terrarium.
- **Retention:** D7 retention ≥20% for pilot cohort (the Randonaut failure mode is the thing we're beating).
- **Quality of build:** every new pure-domain module has unit tests; both modes pass a Simulator smoke test.

## Open Questions

1. **Cells:** H3 Swift port (nicer rollups) vs geohash (simpler, zero-dep)? Pick before Stream E starts.
2. **Places API:** Foursquare (free tier, vibe-friendly) vs Google Places (richest, $$) for US-A2 seeding?
3. **Anchor distance default:** what's the default travel radius (and does it differ by persona)?
4. **Open-now unknown-hours penalty:** how soft? (Trust vs catalog coverage trade-off.)
5. **Specimen variants:** how many context variants per kind in the pilot (just fog vs clear, or finer)?
6. **Honor-mode generosity:** when geofence is unavailable, do we award optimistically (like `PhotoVerifier`) or withhold?
