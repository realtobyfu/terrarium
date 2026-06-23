# Terrarium

## What This Is

Terrarium is a native iOS app (iOS 26+, SwiftUI + RealityKit) that turns real-world exploration into a living terrarium you grow. It has three tabs: **Home** (a 3D globe/terrarium that grows and gains vitality as you explore), **Drift** (a location-tracked walking "ramble" with a breadcrumb stream and geohash fog-of-war map), and **Anchor** (a concierge that recommends a nearby place to go, lets you re-roll, and verifies arrival to award a specimen). It is built for someone who wants going outside to feel rewarding.

## Core Value

The recommend → arrive → grow loop must feel rewarding: going somewhere real and watching the terrarium respond is the one thing that has to work. Everything else serves that loop.

## Requirements

### Validated

<!-- Inferred from existing code (brownfield). All shipped + relied upon. -->

- ✓ Home — 3D globe/terrarium rendering (RealityKit), dynamic solar+weather sky, growth tiers, tappable specimens with journal — existing
- ✓ Drift — location-tracked ramble: breadcrumb stream, geohash fog-of-war, route generation, point spots — existing
- ✓ Anchor — deterministic ranked POI pick, re-roll pool ("Another"), "I'm here" geofence/honor-mode arrival verification, award ceremony — existing
- ✓ Domain — pure `RulesRecommender` scoring (category, open-now, weather fit, distance, novelty, persona bias); provider-protocol DI with stubs; offline-first — existing
- ✓ Persistence — SwiftData `WorldStore` (world props, completed quests, journal, points/vitality) + `PreferencesStore` (UserDefaults) — existing
- ✓ Onboarding + `RootView` routing (onboarding vs. `ExploreShellView`) — existing
- ✓ Test suite (Swift Testing) covering the points engine, recommender, and world store — existing

### Active

<!-- This milestone: ship the Anchor destination-card redesign into the live screen. -->

- [ ] Promote the destination-card redesign — **ticket card = primary** layout, **compact-stub = secondary** — from the `AnchorFeature/` workshop into the live `AnchorView`
- [ ] Wire the chosen card variant to real `AnchorViewModel` state (pick, re-roll, arrival) — no preview-only/demo data
- [ ] Preserve the existing color palette; do not reintroduce cut variants (Painted Ladies)
- [ ] Keep preview/workshop explorations out of the production bundle (gate behind `#if DEBUG` or remove)
- [ ] Interaction parity with the current flow: re-roll ("Another"), "I'm here" arrival, and award ceremony all still work

### Out of Scope

<!-- Explicit boundaries for THIS milestone. -->

- AI/ML-driven recommendations — `RulesRecommender` stays as-is; deferred to a separate milestone (candidate: AI-native recommendations)
- Production hardening (WorldStore silent-error logging, `os_log` observability, breadcrumb multi-consumer fix) — real, but a separate concern from this UI milestone
- `PhotoVerifier` and reverse-geocoding stubs — pre-existing placeholders, not part of the card redesign
- New Drift/Home features — this milestone touches the Anchor surface only

## Context

- **Brownfield.** The Explore feature (Drift & Anchor) was built via parallel worktree agents on the `explore-drift-anchor` branch and merged in PR #1.
- The redesign already exists as **preview-only explorations** in `AnchorFeature/`, currently uncommitted: `DestinationCardVariants.swift` (615 lines), `ExperienceFlowDemo.swift` (492), `PaletteWorkshop.swift` (404). None are wired into live screens — `CONCERNS.md` flags them as "preview/demo files not filtered from production."
- Prior workshop decisions: ticket card = primary, compact-stub = secondary, original palette kept, Painted Ladies cut.
- Codebase mapped 2026-06-17 — see `.planning/codebase/` (ARCHITECTURE, STACK, STRUCTURE, CONVENTIONS, INTEGRATIONS, TESTING, CONCERNS).

## Constraints

- **Tech stack**: Swift 5, SwiftUI + RealityKit + SwiftData + CoreLocation + WeatherKit; iOS 26.0+; no external SPM/CocoaPods dependencies — system frameworks only.
- **Concurrency**: MainActor default isolation, strict concurrency (`SWIFT_APPROACHABLE_CONCURRENCY=YES`); all view models are `@Observable @MainActor`.
- **Frozen contracts**: `ExploreModels.swift` and `ExploreProviders.swift` signatures must not change unilaterally — coordinate any bump.
- **Architecture**: features import Domain; Domain imports only Foundation + simd. Keep card UI in `AnchorFeature/`; keep logic in `AnchorViewModel`.
- **Offline-first**: must compile and run fully against stub providers (previews/tests).

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Ship the Anchor "ticket card" as the primary destination card, compact-stub as secondary | Chosen in the destination-card workshop; ticket reads as the clearest primary surface | — Pending |
| Keep the original palette; drop the Painted Ladies variant | Palette workshop concluded the original palette holds up | — Pending |
| Gate preview/workshop files out of production rather than ship them | `CONCERNS.md` flags them as an accidental-ship risk and added code size | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-17 after initialization*
