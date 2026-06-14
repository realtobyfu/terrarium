# Stream: Drift (ramble + fog-of-war map) — Liquid Glass redesign

Redesign the **Drift** experience in the Hidden Garden / Liquid Glass language.
Read `design/glass-streams/README.md` first (frozen contract + design rules), and
study `Terrarium/Prototypes/DiscoveryGlassView.swift` as the canonical example.

## Goal

Drift is "you're out walking" — cooler, atmospheric, **glanceable**. Two states +
a summary, built over the existing `DriftViewModel` (do not change the VM).

## Wire to: `Terrarium/DriftFeature/DriftViewModel.swift` (read it)

Key surface (all `@MainActor`, `@Observable`):

- `session: RambleSession?` (`isActive`), `startRamble()`, `endRamble()`
- Live stats: `elapsedSeconds: TimeInterval`, `distanceMeters: Double`
- Fog: `newCells: Set<String>` (lit this session), `allExploredCells: Set<String>`
- `summary: RambleSummary?` → `{ newCellsCount, totalCellsCount, distanceMeters, durationSeconds }`
- Route: `routeWaypoints: [Coordinate]?`, `generateRoute(context:)`,
  `routeRandomness: Double` (0…1), `targetMinutes: Double`
- `Coordinate` is degrees (`latitude`/`longitude`).

Look at the current `Terrarium/DriftFeature/DriftView.swift` for what exists.

## Files to create (yours — no conflicts)

- `Terrarium/Prototypes/DriftGlassView.swift` — the screen (idle / active / summary)
- `Terrarium/Prototypes/FogMapView.swift` — restyled MapKit + fog-of-war overlay
- `Terrarium/Prototypes/DriftControls.swift` — `DriftStatStrip`, `RouteControls`
  (duration + randomness dial), `StartRambleButton`

(You may consolidate into fewer files; just don't touch the frozen kit.)

## Screens & states

1. **Idle / pre-ramble** — hero is **"Start a ramble."** Show `RouteControls`:
   a **Duration** stepper/slider bound to `targetMinutes` and a **Randomness dial**
   ("Guided ↔ Surprise me") bound to `routeRandomness`. Optional suggested-loop
   preview (`routeWaypoints` via `generateRoute()`). Make Start the focal CTA
   (`.buttonStyle(.glassProminent)` tinted `Theme.Garden.pine`).
2. **Active ramble** — `DriftStatStrip` with big glanceable live stats: elapsed
   (`elapsedSeconds`), distance (`distanceMeters`), cells lit (`newCells.count`).
   Prominent **End** control. The **fog-of-war map** fills the screen.
3. **Fog-of-war map** (the magic, currently invisible) — `Map` (MapKit/SwiftUI)
   **restyled to feel terrarium**: muted/warm tint, custom cell overlays using
   `Theme.Palette.accent` / `Theme.Garden`, soft fog mask over unexplored area.
   `newCells` render visually distinct from `allExploredCells`; show the user
   location. Cells are geohash ids — render each as a small region/marker (decode
   roughly or place dots along `session?.breadcrumbs`). It's a prototype: a
   convincing fog/lit-cell look matters more than exact geohash polygons.
4. **End-of-ramble summary** — glass card: cells lit, distance, time (from
   `summary`), "view on globe" affordance.

## iOS 26 / motion

- Glass: `DriftStatStrip` and controls as glass; reuse `DiscoveryTopBar` for the
  header (pass a cool weather glyph). Consider a cool/fog `MeshGradient` base so
  Drift reads cooler than Anchor (define any new colors via `extension Theme.Garden`
  in your file).
- Fog reveal: cells fade in; new cells get a brief highlight. Respect Reduce Motion.

## Acceptance

- Builds green (see README verify block) and renders in the sim (screenshot the
  idle + active states; a stubbed `DriftViewModel` is fine for previews — see the
  stub providers in `Terrarium/Domain/ExploreProviders.swift`).
- `#Preview`s for idle, active, and summary. No VM/logic changes. Tests still pass.

Reference: `design/explore-design-spec.md` §5.4, §6, §7.
