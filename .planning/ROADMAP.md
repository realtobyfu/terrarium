# Roadmap: Terrarium — Ship Anchor Card Redesign

## Overview

This is a contained, brownfield UI milestone on the live Anchor tab. The destination-card redesign already exists as preview-only explorations in `AnchorFeature/` (`DestinationCardVariants.swift`, `PaletteWorkshop.swift`, `ExperienceFlowDemo.swift`); the live `AnchorView` still renders its own internal hero card. The journey: first promote the chosen ticket-card (primary) and compact-stub (secondary) into a production component bound to real `AnchorViewModel` state with the approved palette; then prove interaction parity (re-roll, "I'm here" arrival, award ceremony) and clean up build hygiene so the workshop files never ship. Two phases, coarse granularity — kept deliberately tight.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Live Destination Card** - Promote the ticket card (primary) + compact stub (secondary) into the live AnchorView, bound to real pick data, in the approved palette
- [ ] **Phase 2: Parity & Hygiene** - Preserve re-roll / arrival / award behavior, gate workshop files out of production, and confirm build + tests green

## Phase Details

### Phase 1: Live Destination Card
**Goal**: The live Anchor tab shows the redesigned ticket card (primary) and compact-stub (secondary), rendered in the approved palette and populated by the real recommended POI — replacing the old internal hero card.
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: CARD-01, CARD-02, CARD-03, CARD-04, WIRE-01
**Success Criteria** (what must be TRUE):
  1. User opens the Anchor tab and sees the ticket-card layout as the primary destination card (not the old internal hero card)
  2. The compact-stub layout is available as the secondary/condensed destination presentation
  3. The card displays the current pick's real name, category, and supporting detail — no preview/demo placeholder values
  4. The card renders in the existing approved palette, with no Painted Ladies variant present on screen
**Plans**: TBD
**UI hint**: yes

### Phase 2: Parity & Hygiene
**Goal**: The redesigned card preserves the full Anchor interaction loop (re-roll, arrival verification, award ceremony) and the workshop/preview files are excluded from the production bundle, with the build and existing test suite green.
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: WIRE-02, WIRE-03, WIRE-04, BUILD-01, BUILD-02
**Success Criteria** (what must be TRUE):
  1. User taps "Another" on the card and it updates to the next pick in the re-roll pool
  2. User taps "I'm here" from the card and arrival verification runs (geofence / honor mode) exactly as before
  3. On successful arrival the award ceremony presents as before
  4. The workshop explorations (`DestinationCardVariants`, `ExperienceFlowDemo`, `PaletteWorkshop`) are excluded from the production bundle (gated behind `#if DEBUG` or removed)
  5. The app builds and the existing Swift Testing suite passes after the redesign is wired in
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Live Destination Card | 0/TBD | Not started | - |
| 2. Parity & Hygiene | 0/TBD | Not started | - |
