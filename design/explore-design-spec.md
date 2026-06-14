# Terrarium Explore — Design Spec (Drift & Anchor)

**Purpose:** a working brief to refine the Explore UI with a designer. It captures
what exists today, what's wrong with it, the design language to pull toward, and
per-screen requirements with all states. The engineering is done and behind stable
view models — this is a **visual/UX refresh**, not a re-architecture. Anything a
designer changes maps to existing SwiftUI views + a shared token file
(`Terrarium/DesignSystem/Tokens.swift`, `Components.swift`).

Feature context lives in `tasks/prd-explore-drift-anchor.md`. Two modes over one SF
catalog: **Drift** (aimless ramble, fog-of-war map, glanceable) and **Anchor**
("give me one good place," concierge, feels like a friend's pick). Both feed the
existing terrarium globe.

---

## 1. Current state (honest critique)

Screens that exist today (screenshots in `design/` review): **Onboarding persona
picker**, **Anchor**, **Drift**, plus the existing **Home/globe** and a custom
**tab bar** (Home · Drift · Anchor).

What's wrong:

1. **Three modes look like three different apps.** Onboarding = cream + serif;
   Anchor = warm amber gradient; Drift = full-bleed Apple-Maps green with a floating
   cream panel. There's no shared frame, so it feels stitched together.
2. **Header collides with the Dynamic Island.** Anchor's title/weather chip sit
   under the island and clip. No consistent top safe-area treatment.
3. **The design system isn't being used.** `SoftPanel`, `GlowButton`, `LocationChip`,
   the cream palette and serif/rounded type exist and look good on Home — but the
   Explore screens reinvent backgrounds and buttons instead of composing these.
4. **Drift map is raw Apple Maps.** Default green/blue MapKit styling clashes with
   the warm terrarium world; the bottom control panel floats with no connection to
   the map; no visible "start ramble" hero; the fog-of-war (the whole point) isn't
   expressed visually.
5. **Anchor's hero card under-sells the pick.** It's a flat card; for a "one great
   place" concierge moment it should feel editorial/premium (imagery, stronger
   hierarchy, confident single CTA).
6. **Tab bar is generic.** Functional but visually plain; doesn't echo the brand.
7. **No empty/loading/permission art.** States are bare text.

The bones are good (warm, calm, distinctive palette). The fix is **consistency,
hierarchy, safe-area discipline, and giving each mode one strong idea.**

---

## 2. Design principles (pull toward these)

- **One world, two moods.** Drift and Anchor share a frame, type, palette, tab bar,
  and the terrarium warmth. They differ in *energy*, not *vocabulary*: Anchor =
  warm/amber/still ("a friend picked this"); Drift = cool/atmospheric/in-motion
  ("you're out walking").
- **Glanceable Drift, editorial Anchor.** Drift is "look once, pocket the phone" —
  big legible live stats, minimal chrome. Anchor is a confident single
  recommendation you'd screenshot and send a friend.
- **Lean into SF + fog.** "Karl the Fog" is a feature. Weather should visibly tint
  the experience (foggy = cooler, softer; clear = warmer). This already drives the
  sky/globe and specimen variants — extend it to Explore surfaces.
- **Reuse the terrarium reward.** Discovery → specimen growth on the globe is the
  payoff. Make the handoff moment feel earned (a celebratory beat), not a toast.
- **Friend, not search result.** Copy and layout should never read like a listings
  app. Warm, first-person, specific.

---

## 3. Existing design tokens (extend, don't replace)

From `Terrarium/DesignSystem/Tokens.swift`:

| Token | Value | Use |
|---|---|---|
| `accent` | `#2A9D8F` (teal) | primary CTA, selected state, brand |
| `atmosphere` | `#9FE8EF` (pale cyan) | crystal/fog accents |
| `cardSurface` | `#FFF8EE` (cream) | panels/cards |
| `chipSurface` | `#FBF2E0` | chips, tab bar |
| `cardBorder` | `#ECD2AB` | 1px soft borders |
| `title` | `#56392C` (brown) | headlines |
| `secondary` | `#917A64` | body |
| `label` | `#B08A66` | eyebrow/labels |
| Radius | card 18 · chip 12 · panel 16 | |
| Spacing | s 8 · m 12 · l 16 · xl 24 | |
| Type | `display` = serif (titles/wordmark) · `body` = rounded (everything else) | |

Components that already exist and should be the building blocks: `SoftPanel`,
`GlowButton`, `LocationChip`, `Wordmark`, `QuestCard`.

**Likely token gaps to design:** a **cool/Drift palette** (fog blues that still
feel part of the family), a **map tint/overlay** spec (so MapKit reads as
terrarium, not Apple Maps), elevation/shadow scale, an explicit **safe-area top
bar** pattern, and **Dynamic Type** behavior for the serif display sizes.

---

## 4. Information architecture

```
RootView
 ├─ First launch → Onboarding (persona → interests → vibe → radius → location priming)
 └─ Returning → ExploreShell (tab bar)
       ├─ Home   (existing globe)        ← the terrarium / reward surface
       ├─ Drift  (ramble + fog map)
       └─ Anchor (concierge pick)
    Discovery (from either mode) → specimen grows on Home globe → tap specimen → Journal
```

Design question for the designer: **is a 3-tab bar the right shell**, or should Home
be the persistent backdrop with Drift/Anchor as overlays/sheets? (See §10.)

---

## 5. Screen specs

For each: purpose, layout intent, content, and **all states**. Redlines/sizes are
the designer's to set; these are requirements + the data each screen has.

### 5.1 Global frame (applies to every Explore screen)
- **Top safe-area bar:** consistent zone below the Dynamic Island holding a left
  title/wordmark and a right `weather + time` chip (`LocationChip` pattern). Must
  never clip under the island; same vertical rhythm across modes.
- **Bottom:** custom tab bar (Home · Drift · Anchor), floating cream pill. Needs a
  refined selected state (current: icon scales + teal). Respect home-indicator
  safe area.
- **Background system:** define how the warm (Anchor/Home) vs cool (Drift) moods
  share a base so switching tabs feels like one app.

### 5.2 Onboarding (US-G1/G2)
Steps: **persona → interest tags → vibe → travel radius → location priming**.
- **Persona** (exists): "Who are you exploring as?" — 3 cards: Restless Local,
  Newcomer, Weekend Drifter. Selected = teal fill + check. Progress indicator +
  Skip + Continue. *Keep this; it's the strongest screen — make the rest match it.*
- **Interests:** multi-select category chips (park, coffee, bookstore, restaurant,
  viewpoint, market, museum, bar). Needs a chip-grid spec + selected style.
- **Vibe:** multi-select (quiet, lively, cozy, scenic, quirky).
- **Radius:** slider; persona pre-fills (Local 2000m / Newcomer 1200m / Drifter
  2500m). Show value + a human label ("a short walk" … "willing to travel").
- **Location priming (US-G2):** explains *why* location is used ("draw your map as
  you walk") **before** the system prompt. Needs warm, reassuring illustration +
  primary "Enable location" + "Maybe later".
- **States:** Skip at any step → defaults (Restless Local). Progress affordance.

### 5.3 Anchor (US-D1/D2) — "one great place"
Data available: top pick `POI` (name, category, neighborhood, vibe tags, price,
open-now/`hoursRef`), walk distance/time (when location known), current weather +
time, ranked re-roll pool.
- **Hero pick:** make this editorial — the place's **name** is the hero (serif),
  with neighborhood eyebrow, a one-line **vibe sentence** ("A cozy indoor escape ·
  quiet · scenic"), an **open-now** indicator, **walk time/distance**, and price.
  Consider a category glyph or generative/scenic art band (no photos in catalog yet
  — see §10). Weather-aware framing copy already exists.
- **Primary CTA:** `[Take me there]` (Maps handoff) — one confident button.
- **Secondary:** `[Another]` (re-roll to next-best) and `[I'm here]` (arrival →
  grows a specimen). Today these are equal-weight side-by-side; designer should set
  hierarchy (arrival is the rewarding action).
- **Weather expression:** rainy/foggy → cozy-indoor framing + cooler tint; clear →
  warmer. Tie to the palette.
- **States:**
  - *Loading:* assembling a pick (skeleton of the hero card).
  - *Empty:* no open pick right now (rare) — friendly fallback + retry.
  - *Permission off:* show a pick without distance; explain distance needs location.
  - *Arrived:* celebratory confirmation that a specimen grew (links to Home globe).

### 5.4 Drift (US-E1/E2/E3) — the ramble
Two distinct states; design both:
- **Idle / pre-ramble:** the hero is **"Start a ramble."** Show the route controls:
  **Duration** (e.g. 30 min) and a **Randomness dial** ("Guided ↔ Surprise me").
  Optionally a suggested loop preview on the map. Currently the start CTA isn't
  prominent — make it the focal point.
- **Active ramble:** glanceable live stats (elapsed time, distance, cells lit,
  specimens earned), a prominent **End** control, and the **fog-of-war map** filling
  in as you walk (this is the magic and is currently invisible).
- **Fog-of-war map:** the core visual. Explored cells revealed, unexplored = fog;
  **new-this-session cells visually distinct**; user location marker. **Restyle
  MapKit** to feel terrarium (muted/warm map tint, custom cell overlay colors using
  `accent`/`atmosphere`, soft fog mask) instead of stock green/blue.
- **End-of-ramble summary:** cells lit, distance, time, specimens earned, "view on
  globe."
- **States:** permission off (priming → enable), no movement yet (encouraging
  empty), session restored after backgrounding.

### 5.5 Terrarium handoff + Journal (US-D2/F2/F3)
- **Reward moment:** on arrival/new cell, a brief celebratory beat as the specimen
  grows on the globe (weather variant: foggy vs clear look). Design this transition.
- **Journal:** discovery can seed a `JournalEntry`; tapping a specimen opens it
  (reuses existing journal). Spec the entry point + the optional reflection/photo.

---

## 6. Component inventory

**Reuse:** `SoftPanel`, `GlowButton`, `LocationChip`, `Wordmark`, `QuestCard`.

**New/needs design:**
- `ExploreTopBar` (safe-area title + weather chip, shared)
- `ExploreTabBar` (refined selected state, brand-aligned)
- `PersonaCard`, `SelectableChip` (interests/vibe), `RadiusSlider`
- `AnchorHeroCard` (the editorial pick), `OpenNowBadge`, `WalkTimePill`
- `SecondaryButton` / button hierarchy (re-roll, arrival)
- `DriftStatStrip` (live elapsed/distance/cells), `RouteControls` (duration +
  randomness dial), `StartRambleButton`
- `FogMapStyle` (MapKit tint + cell overlay + fog mask spec)
- `RewardOverlay` (specimen-grew celebration)
- State views: `LoadingSkeleton`, `EmptyState`, `PermissionPrompt`

---

## 7. Motion
- Tab switch: state preserved, gentle cross-fade (current) — refine.
- Re-roll ("Another"): card swap should feel like dealing a new card.
- Arrival reward: a satisfying grow/sparkle as the specimen lands on the globe.
- Fog reveal: cells fade in as you walk; new cells get a brief highlight.
- Respect **Reduce Motion** (provide cross-fade fallbacks).

## 8. Accessibility (requirements)
- **Dynamic Type:** all text scales; verify the serif display sizes don't clip the
  hero card. Provide layout that reflows.
- **Contrast:** check brown-on-cream and label `#B08A66` on `#FBF2E0` meet WCAG AA
  for their sizes; the teal CTA white text passes — confirm secondary text.
- **VoiceOver:** hero pick reads as one meaningful element; map cells summarized
  ("12 areas explored"); controls labeled.
- **Hit targets:** ≥44pt (tab bar items, sliders, secondary buttons).
- **Color independence:** open-now / new-cell not conveyed by color alone.

## 9. Platform notes
- iOS 26, SwiftUI. Liquid Glass is available — consider it for the floating tab bar
  / top chips, but keep the warm cream identity (don't go default-glass-generic).
- Safe areas: Dynamic Island top, home indicator bottom — both currently mishandled.

---

## 10. Open design questions (decide with the designer)
1. **Shell model:** 3-tab bar vs Home-as-backdrop with Drift/Anchor as overlays?
2. **Anchor imagery:** catalog has no photos (pilot). Generative/illustrated art per
   category/neighborhood, a styled map snapshot, or type-only editorial?
3. **Map styling:** how far to restyle MapKit toward "terrarium" without losing
   wayfinding legibility? Custom tile look vs overlay-only?
4. **Fog-of-war metaphor:** literal fog mask, paper-map reveal, or glowing
   constellation of explored cells?
5. **Warm vs cool moods:** how different can Anchor (amber) and Drift (fog-blue) be
   before the app feels split? Define the shared base.
6. **Reward moment:** in-place celebration vs auto-cut to the globe?
7. **Onboarding length:** 5 steps may be heavy — collapse interests+vibe?

## 11. What I'd like back from the designer
- High-fidelity mocks for: Onboarding (all steps), Anchor (loading/empty/permission/
  arrived), Drift (idle/active/summary/permission), tab bar, reward moment.
- Updated/extended **token set** (cool palette, map tint, elevation, type scale)
  expressed so it drops into `Tokens.swift`.
- A redlined **component sheet** matching §6.
- Light/dark + Dynamic Type @ XXL + foggy/clear variants for at least Anchor & Drift.
- Motion notes (or a short prototype) for re-roll, fog reveal, and the reward beat.

**Handoff:** components are isolated SwiftUI views with `#Preview`s; tokens are
centralized. A designer's changes should land as token edits + per-component
restyles without touching view models or logic.
