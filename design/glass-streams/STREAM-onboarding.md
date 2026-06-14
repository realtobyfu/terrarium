# Stream: Onboarding flow — Liquid Glass redesign

Redesign the 5-step onboarding in the Hidden Garden / Liquid Glass language so it
matches the rest of the app (today it's the "cream + serif" outlier). Read
`design/glass-streams/README.md` first; study `DiscoveryGlassView.swift` as the
canonical example.

## Goal

A warm, confident, cohesive flow. The existing **persona picker** is the strongest
screen — make the other steps match its quality. Build over the existing
`OnboardingViewModel` (do not change the VM).

## Wire to: `Terrarium/OnboardingFeature/OnboardingViewModel.swift` (read it)

Key surface (`@MainActor`, `@Observable`):

- `currentStep: OnboardingStep` (`.persona, .interestTags, .vibe, .radius, .locationPrime`), `isLastStep`
- `selectedPersona: PersonaKind`, `selectPersona(_:)` (also pre-fills radius)
- `selectedCategories: Set<POICategory>`, `toggleCategory(_:)`
- `selectedVibes: Set<Vibe>`, `toggleVibe(_:)`
- `travelRadiusMeters: Double`
- Navigation: `advance()`, `skip()`, `proceedWithLocation()`
- Enums: `PersonaKind` (`restlessLocal, newcomer, weekendDrifter`), `POICategory`,
  `Vibe` (`quiet, lively, cozy, scenic, quirky`) — in `Domain/ExploreModels.swift`.

Look at the existing step views in `Terrarium/OnboardingFeature/` for current copy
and structure (`PersonaPickerView`, `InterestTagsView`, `VibePickerView`,
`RadiusPickerView`, `LocationPrimingView`, `OnboardingFlowView`).

## Files to create (yours — no conflicts)

- `Terrarium/Prototypes/OnboardingGlassView.swift` — the flow container + a
  progress affordance + Skip/Continue, switching on `currentStep`.
- `Terrarium/Prototypes/OnboardingGlassComponents.swift` — `PersonaCard`,
  `SelectableChip` (interests/vibe grid), `RadiusSlider`, priming illustration.

## Screens & states (all 5 steps)

1. **Persona** — "Who are you exploring as?" 3 `PersonaCard`s (Restless Local,
   Newcomer, Weekend Drifter). Selected = moss fill + check. Calls `selectPersona`.
2. **Interests** — multi-select category chip grid (park, coffee, bookstore,
   restaurant, viewpoint, market, museum, bar). `SelectableChip` + `toggleCategory`.
3. **Vibe** — multi-select (`quiet, lively, cozy, scenic, quirky`) via `toggleVibe`.
4. **Radius** — `RadiusSlider` bound to `travelRadiusMeters`; show value + a human
   label ("a short walk" … "willing to travel"). Persona pre-fills it.
5. **Location priming (US-G2)** — warm, reassuring screen that explains *why*
   location is used ("draw your map as you walk") **before** the system prompt.
   Primary "Enable location" → `proceedWithLocation()`; secondary "Maybe later".

Global: a progress indicator, **Skip** at any step → `skip()` (defaults), and a
**Continue** that calls `advance()`. Use a generative `MeshGradient` / garden motif
for warmth instead of flat backgrounds.

## iOS 26 / a11y

- Glass for chips, the priming card, and the bottom Continue bar; primary CTA
  `.buttonStyle(.glassProminent)` tinted `Theme.Garden.moss`. `GlassEffectContainer`
  around chip grids if you glass them.
- Selected state never hue-only (check/fill + label). Dynamic Type scales; chip
  grid reflows. Hit targets ≥44pt.

## Acceptance

- Builds green (README verify) and renders in the sim (screenshot persona +
  interests + priming). Construct an `OnboardingViewModel(store: PreferencesStore())`
  for previews.
- `#Preview` per step. No VM/logic changes. Existing tests pass.

Reference: `design/explore-design-spec.md` §5.2, §6, §8.
