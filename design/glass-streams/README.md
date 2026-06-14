# Liquid Glass redesign — parallel streams

This is the orchestration brief for redesigning the remaining Explore screens in
the **Liquid Glass / "Hidden Garden"** language established by the Anchor
prototype (`Terrarium/Prototypes/DiscoveryGlassView.swift`). Each stream below is
**independent**: it creates its own new files and reuses the shared kit, so the
streams can be built in parallel git worktrees without merge conflicts.

## How to run a stream

Each stream has its own worktree + branch (created by the setup):

| Stream | Worktree | Branch |
|---|---|---|
| Drift | `../terrarium-drift` | `proto-drift` |
| Onboarding | `../terrarium-onboarding` | `proto-onboarding` |
| Journal + Reward | `../terrarium-journal` | `proto-journal` |
| Shell + Home | `../terrarium-shell` | `proto-shell` |

In each worktree, start a Claude session and say:

> Read `design/glass-streams/STREAM-<name>.md` and implement it. Build with
> `xcodebuild` for an iOS 26 simulator and verify a screenshot before finishing.

When a stream is green, merge its branch back into `explore-drift-anchor`.

## FROZEN CONTRACT — do not edit these in a stream

These are the shared design kit. Treat them as read-only; **reuse**, don't modify
(editing them in two worktrees at once causes conflicts):

- `Terrarium/Prototypes/DiscoveryGlassTokens.swift` — `Theme.Garden` palette,
  `Theme.Radius.hero/heroInner/glass`, `Theme.Spacing.xs`.
- `Terrarium/Prototypes/LiquidGlassKit.swift` — `WashiTape`, `OrganicPill`,
  `GlassIconButton`, `TactilePrimaryButtonStyle`, `DiscoveryTopBar`,
  `DiscoveryTabBar` / `DiscoveryNavItem`.
- `Terrarium/Prototypes/ScenicArtBand.swift` — `MeshGradient` scenic art +
  `ScenicRNG` / `Scenic.seed`.
- `Terrarium/Prototypes/DiscoveryHeroCard.swift`, `DiscoveryGlassView.swift` — the
  Anchor reference screen (read it as the canonical example).

Also reuse the existing design system: `SoftPanel`, `GlowButton`, `Wordmark`,
`Theme.Palette` / `Theme.Typography` (`Tokens.swift`, `Components.swift`).

### If you need a new token or shared component

Add it in **your own stream file** via an extension, e.g.

```swift
extension Theme.Garden { static let dusk = Color(hex: "…") }
```

Do **not** add it to the frozen files. We reconcile duplicates at merge time.

## Design language (the rules every stream follows)

- **Warm cream identity + moss garden accents.** Base background is the cream
  wash; greens (`Theme.Garden.moss/pine/leaf`) are the accent. Keep it warm — not
  generic glass.
- **Liquid Glass for chrome & secondary controls.** Top bar, bottom nav, chips,
  pills, secondary buttons, state cards → `.glassEffect(.regular[.tint(_)] , in:)`
  or `.buttonStyle(.glass)`. Primary CTA → `.buttonStyle(.glassProminent)` tinted
  `Theme.Garden.moss`. Group glass in `GlassEffectContainer`.
- **Tactile islands + washi tape** for content cards (see `DiscoveryHeroCard`).
- **MeshGradient** for any generative art (no photo assets exist).
- **Safe areas:** float bars with `.safeAreaInset(edge:)` so content never hides
  behind them; never let a title clip under the Dynamic Island.
- **Serif display** (`Theme.Typography.display`) for titles/place names; **rounded**
  (`Theme.Typography.body`) for everything else.
- **Accessibility:** Dynamic Type scales; status conveyed with icon+text, not hue
  alone; hit targets ≥44pt; meaningful `accessibilityLabel`s.
- **Min target is iOS 26** — use the glass APIs directly, no `#available` gate.

## Verify (every stream)

```sh
xcodebuild build -project Terrarium.xcodeproj -scheme Terrarium \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug
```

Then install + launch on a booted iOS 26 sim and screenshot to confirm it renders
(the app uses Xcode's debug-dylib mode — the real code is in
`Terrarium.app/Terrarium.debug.dylib`, so grep that, not the launcher stub, if you
verify strings). Leave each new view with `#Preview`s. Don't break existing tests.

Full design intent: `design/explore-design-spec.md`.
