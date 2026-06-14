# Stream: Journal + Reward moment — Liquid Glass redesign

Two related pieces: the **reward overlay** (the celebratory beat when a specimen
grows) and the **Journal** (where discoveries are revisited). Both in the Hidden
Garden / Liquid Glass language. Read `design/glass-streams/README.md` first; study
`DiscoveryGlassView.swift` (its `ArrivalCard` is a rough first cut of the reward
beat — make it a proper reusable overlay).

## Goal

Make discovery feel **earned**: a satisfying grow/sparkle when a specimen lands,
and a warm Journal to revisit it. Build over existing models/stores (don't change
domain logic).

## Read for context / APIs

- `Terrarium/JournalFeature/JournalView.swift`, `SpecimenJournalView.swift`,
  `GrowthLogView.swift` — current journal UI + how entries are read.
- `Terrarium/Domain/WorldStore.swift` — `addJournal(to:questId:text:placeName:)`,
  how `JournalEntry` / `WorldProp` are stored/queried.
- `Terrarium/Domain/Models.swift` — `WorldProp` (`kind: .tree/.building/.flowers`,
  `variant: "clear"/"foggy"`), `Quest`.
- Reward triggers already exist: `AnchorViewModel.arrive()` →
  `arrivalResult.specimenGrown`; `DriftViewModel` grows specimens per new cell.

## Files to create (yours — no conflicts)

- `Terrarium/Prototypes/RewardOverlayGlass.swift` — `RewardOverlay` reusable view
  + a `.rewardOverlay(isPresented:poiName:specimenKind:variant:)` view modifier.
- `Terrarium/Prototypes/JournalGlassView.swift` — the redesigned journal (list of
  discoveries + a detail/reflection sheet).

## What to build

1. **RewardOverlay** — a brief celebratory beat: the specimen icon (map
   `WorldProp.Kind` → SF Symbol: tree→`tree.fill`, building→`building.2.fill`,
   flowers→`leaf.fill`/`camera.macro`) growing/sparkling on a soft glass card over
   a dimmed scrim, with "Your terrarium grew!" + place name, then a "View on globe"
   / dismiss. Use `.symbolEffect(.bounce)` / a `phaseAnimator` grow, sparkles
   (Canvas or `MeshGradient` glow), and **respect Reduce Motion** (cross-fade
   fallback). Honor the `variant` ("foggy" cooler vs "clear" warmer) like the sky.
   Expose it as a modifier so Anchor/Drift can present it on
   `specimenGrown == true`.
2. **JournalGlassView** — warm list of past discoveries (specimen icon, place name,
   weather/time, date) as tactile glass rows; tapping opens a detail sheet with the
   discovery text and an optional reflection/photo field. Reuse `SoftPanel`, washi
   accents, `Theme.Garden`. Use `.sheet(item:)` for the detail. Pull data the same
   way the existing journal views do (read them).

## iOS 26 / a11y

- Glass cards/rows; primary actions `.buttonStyle(.glassProminent)` tinted
  `Theme.Garden.moss`. `GlassEffectContainer` for grouped glass.
- VoiceOver: the reward reads as one announcement ("Your terrarium grew at …");
  journal rows are meaningful elements. Dynamic Type scales.

## Acceptance

- Builds green (README verify) and renders in the sim (screenshot the reward
  overlay + journal list). `#Preview`s for the overlay (clear + foggy variants) and
  the journal list. No domain/logic changes; existing tests pass.

Reference: `design/explore-design-spec.md` §5.1 (reward), §5.5, §7.
