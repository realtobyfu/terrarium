# Spec: Fog-of-war polish + Points-to-Globe reward (replaces "grow a tree")

**Status:** brief for a future session. Not started. Branch off `explore-drift-anchor`
(or its successor) after the Liquid Glass integration (commit `ee23e93`).

**Why:** the current reward loop — every discovery *grows a specimen* (tree/building/
flowers) on the globe — doesn't feel good. We're cutting it. Instead: **Drift's
fog-of-war becomes the centerpiece**, walking lights the map and occasionally hits
**point spots**, and **points power the home globe / "house"** (it grows and gains
items as you earn). Two halves: (A) make the fog genuinely great, (B) swap the
reward model.

Design language is the established **Hidden Garden / Liquid Glass** kit
(`DesignSystem/LiquidGlassKit.swift`, `GardenTokens.swift`, `ScenicArtBand.swift`).
Reuse it; don't reinvent.

---

## Part A — Cut "grow a tree"

Remove specimen-growth-on-discovery. Touch points (search before editing):

- `AnchorFeature/AnchorViewModel.swift` — `arrive()` currently builds a `Quest` and
  calls `worldStore.complete(quest:…)` to grow a specimen + writes a journal entry.
  Keep recording the `Discovery` (and the journal note, repurposed) but **stop
  growing a specimen**. `ArrivalResult.specimenGrown` → repurpose to "points earned"
  (see Part B) or remove.
- `DriftFeature/DriftViewModel.swift` — `growSpecimen(forCell:…)` and its call in
  `handleBreadcrumb`. Remove specimen growth; a newly-lit cell now contributes to
  the fog + (sometimes) points, not a globe specimen.
- `AnchorFeature/AnchorView.swift` — `ArrivalCard` ("Your terrarium grew!") →
  reframe to the points reward (or a quiet "discovery logged").
- `JournalFeature/RewardOverlay.swift` — the celebratory overlay was built for
  specimen growth. **Repurpose it** for the points reward (it already supports a
  variant + sparkle + "view on globe"); or retire it.
- `Domain/WorldStore.swift`, `SpecimenMapping`, `SpecimenFactory`,
  `POIPlacement` — the specimen-growth machinery. Decide: keep for the globe's
  *own* growth (Part B may still place props as the globe levels up) vs remove. Do
  **not** rip out `WorldStore` wholesale — Home/Journal read from it.
- Tests: `AnchorViewModelTests`, `DriftViewModelTests`, `StreamFIntegrationTests`,
  `WorldStore`/specimen tests assert growth. Update them to the new model. The full
  suite must stay green.

Keep the existing **Journal** (it revisits past discoveries) — discoveries still
exist, they just don't sprout a specimen.

## Part B — Points → Globe / House

The new reward loop:

1. **Point spots.** Scatter a few bonus spots within the user's radius (seeded,
   deterministic per day/area — mirror the `ScenicRNG`/`Scenic.seed` discipline).
   On the fog map they read as glowing collectibles distinct from ordinary cells.
   Walking into one (breadcrumb enters its cell) **collects** it → awards points
   once. Ordinary new cells may give a small base point trickle; spots are the
   jackpots.
2. **PointsStore** (new, `Domain/`): on-device persisted running total + ledger of
   awards (date, source: cell vs spot vs arrival). Pure/testable like the other
   Domain stores; wire it through `AppContainer`.
3. **Globe/house growth.** Points drive the **Home globe**: as the total crosses
   thresholds, the globe "levels up" — add items (the existing `WorldProp`
   tree/building/flowers as *decor placed by leveling*, and/or a central "house"
   that upgrades). This is where specimen placement can live now (globe growth),
   instead of one-per-discovery. Define the curve (e.g. tiers at N points) and what
   each tier adds.
4. **Reward beat.** Reuse `RewardOverlay` for "you found a spot — +N points" and
   for tier-ups ("your garden grew to level K"), honoring Reduce Motion.
5. **Surfacing.** Show the points total in the shell/top bar or Home; show progress
   to the next tier. Keep it warm, not gamey-garish.

Open questions for the session to decide: point values + tier curve; do spots
respawn; does Anchor "I'm here" still award points (probably yes, a bigger chunk);
how the house vs scattered props read on the globe.

## Part C — Make the fog genuinely great

`DriftFeature/FogMapView.swift` today: muted `Map`, a radial vignette as "fog", lit
cells as polygons. Level it up:

- **Real fog-of-war mask**, not just a center vignette: unexplored area is fogged;
  explored/lit cells **carve clearings** out of the fog (mask/blend, e.g. a
  `Canvas`/`drawingGroup` compositing lit-cell shapes as holes in a fog layer).
- **Animated reveal**: cells fade/bloom in as you walk; the newest cell gets a brief
  highlight pulse. Respect Reduce Motion.
- **Terrarium tint**: push the base `Map` further from stock (warm/sage tint overlay,
  custom lit-cell glow using `Theme.Garden`), while keeping wayfinding legible.
- **Point spots** rendered as inviting glints with a subtle pulse; collected ones
  settle to a "found" state (icon + check, not hue alone — a11y).
- **Performance**: many cells → keep it smooth (flatten layers with `drawingGroup`,
  avoid per-frame geohash decode; precompute cell polygons).

## Reuse / constraints

- iOS 26 min target; Liquid Glass APIs directly. Reuse the kit + `Theme.Garden`
  (add new tokens via `extension Theme.Garden` in your own file).
- Don't change frozen public VM contracts casually; if a VM needs new surface for
  points, add it deliberately and update tests.

## Acceptance

- Grow-a-tree gone; no discovery sprouts a one-off specimen.
- Walking lights a well-rendered fog map; point spots are collectible and award
  points; the globe/house visibly grows with the points total.
- Build green on an iOS 26 sim; screenshot the active fog map (with a spot), a
  collect/tier-up reward, and the leveled globe. Full test suite green.
