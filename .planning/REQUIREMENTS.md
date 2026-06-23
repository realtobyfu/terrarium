# Requirements: Terrarium — Ship Anchor Card Redesign

**Defined:** 2026-06-17
**Core Value:** The recommend → arrive → grow loop must feel rewarding; the Anchor surface is where "recommend" happens, so its destination card is the first thing that has to read well.

## v1 Requirements

Requirements for this milestone. Each maps to a roadmap phase.

### Destination Card

- [ ] **CARD-01**: User sees the ticket-card layout as the primary destination card in the live Anchor tab
- [ ] **CARD-02**: User sees the compact-stub layout as the secondary/condensed destination presentation
- [ ] **CARD-03**: The card renders using the existing approved palette (Painted Ladies variant is not present)
- [ ] **CARD-04**: The card displays the real recommended POI's name, category, and supporting detail for the current pick

### State Wiring

- [ ] **WIRE-01**: The destination card reflects the live `AnchorViewModel` pick — no preview/demo placeholder data
- [ ] **WIRE-02**: User can tap "Another" to re-roll and the card updates to the next pick in the pool
- [ ] **WIRE-03**: User can tap "I'm here" from the card and arrival verification runs (geofence / honor mode) exactly as before
- [ ] **WIRE-04**: On successful arrival the award ceremony presents as before

### Build Hygiene

- [ ] **BUILD-01**: Preview/workshop explorations (`DestinationCardVariants`, `ExperienceFlowDemo`, `PaletteWorkshop`) are excluded from the production bundle (gated behind `#if DEBUG` or removed)
- [ ] **BUILD-02**: The app builds and the existing Swift Testing suite passes after the redesign is wired in

## v2 Requirements

Acknowledged but deferred — not in this roadmap.

### AI-Native Recommendations

- **AINR-01**: LLM-driven place recommendation that adapts to user history (replaces/augments `RulesRecommender`)

### Production Hardening

- **HARD-01**: `WorldStore` surfaces persistence failures instead of silently swallowing them
- **HARD-02**: `os_log` observability on critical paths (location, discovery, scoring, world mutations)
- **HARD-03**: `LocationSessionManager.breadcrumbStream()` supports multiple consumers without cutting off the first

## Out of Scope

| Feature | Reason |
|---------|--------|
| AI/ML recommendations | Separate milestone; `RulesRecommender` stays as-is for this work |
| Production hardening (logging, error handling, breadcrumb bug) | Real concerns, but orthogonal to a UI redesign |
| `PhotoVerifier` / reverse geocoding | Pre-existing stubs, unrelated to the Anchor card |
| New Drift/Home features | This milestone is scoped to the Anchor surface only |

## Traceability

Each requirement maps to exactly one phase.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CARD-01 | Phase 1 | Pending |
| CARD-02 | Phase 1 | Pending |
| CARD-03 | Phase 1 | Pending |
| CARD-04 | Phase 1 | Pending |
| WIRE-01 | Phase 1 | Pending |
| WIRE-02 | Phase 2 | Pending |
| WIRE-03 | Phase 2 | Pending |
| WIRE-04 | Phase 2 | Pending |
| BUILD-01 | Phase 2 | Pending |
| BUILD-02 | Phase 2 | Pending |

**Coverage:**
- v1 requirements: 10 total
- Mapped to phases: 10 ✓
- Unmapped: 0 ✓

---
*Requirements defined: 2026-06-17*
*Last updated: 2026-06-17 after roadmap creation (traceability populated)*
