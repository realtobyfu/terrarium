# Stream: Shell + Home integration — Liquid Glass redesign

Generalize the glass chrome into the real app shell so the prototype screens live
in one cohesive, runnable app. Read `design/glass-streams/README.md` first; study
`DiscoveryGlassView.swift` (how it uses `safeAreaInset` + `DiscoveryTabBar`).

## Goal

One world, one frame: a Liquid Glass tab shell hosting **Home (globe) · Drift ·
Anchor**, with a shared top bar, that wires in `DiscoveryGlassView` as the Anchor
tab. This is the **integration** stream — it edits real app files. The others only
add `Prototypes/` files, so there's no file overlap; still, merge this stream
**last**.

## Read for context / APIs

- `Terrarium/ExploreFeature/ExploreShellView.swift` — current shell: 3-tab enum
  (`home/drift/anchor`), holds `HomeViewModel`/`DriftViewModel`/`AnchorViewModel`
  from the container, custom `ExploreTabBar`. **This is what you're replacing.**
- `Terrarium/App/RootView.swift` — chooses Onboarding vs `ExploreShellView`.
- `Terrarium/App/AppContainer.swift` — `makeHomeViewModel()`,
  `makeDriftViewModel()`, `makeAnchorViewModel()` (already wire `worldStore` etc.).
- `Terrarium/Prototypes/LiquidGlassKit.swift` — `DiscoveryTabBar` /
  `DiscoveryNavItem` (4-item demo nav) and `DiscoveryTopBar`. You'll generalize the
  tab bar to the real 3 tabs.

## Files

Create (yours):
- `Terrarium/Prototypes/GlassExploreShell.swift` — the new shell: a 3-tab
  (`home/drift/anchor`) Liquid Glass tab bar (model the selection morph on
  `DiscoveryTabBar`'s `matchedGeometryEffect` highlight), hosting `HomeView`,
  the current `DriftView`, and `DiscoveryGlassView` for Anchor. Preserve tab state
  across switches (gentle cross-fade), respect safe areas via `safeAreaInset`.

Edit (integration — only this stream touches these):
- `RootView.swift` — point the returning-user branch at `GlassExploreShell` instead
  of `ExploreShellView` (keep onboarding branch).

Do **not** edit the frozen kit. If you need a 3-tab nav distinct from the demo
4-item `DiscoveryTabBar`, build it in `GlassExploreShell.swift` (you may factor a
generic glass tab bar there).

## What to build

- **Glass tab shell**: floating glass bottom bar (Home·Drift·Anchor) with a refined
  selected state (icon + tinted highlight that glides between tabs), home-indicator
  safe area respected. Icons: Home `globe.americas.fill`, Drift `figure.walk`,
  Anchor `mappin.and.ellipse` (or keep current).
- **Shared top bar**: reuse/extend `DiscoveryTopBar` so every tab gets a consistent
  safe-area header (weather/time chip) that never clips the Dynamic Island.
- **Anchor tab** = `DiscoveryGlassView(viewModel: container.makeAnchorViewModel())`.
  Home tab = existing `HomeView`; Drift tab = existing `DriftView` for now (the
  Drift glass redesign merges separately — leave it swappable).
- Keep view models created once (state survives tab switches), as the current shell
  does.

## iOS 26 / a11y

- `GlassEffectContainer` + `.glassEffect` for the bar; `matchedGeometryEffect` for
  the selection highlight (avoid nesting glass-in-glass). Tabs are buttons with
  `accessibilityLabel` + `.isSelected`.

## Acceptance

- Builds green (README verify); launch the app and screenshot each tab (Home, Drift,
  Anchor) showing the glass shell + the Anchor glass screen live. `#Preview` for the
  shell. Existing tests pass.

Reference: `design/explore-design-spec.md` §4, §5.1, §10 (shell model).
