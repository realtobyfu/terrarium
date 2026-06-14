# Terrarium — Logo Concepts & Brief

Three starting concepts as **vector SVG** (open in any browser or Pixelmator Pro).
Pick a direction, then refine the winner in Pixelmator and export for Liquid Glass.

> Division of labor: these SVGs are *concepts/scaffolds* (clean geometry, layer-ready).
> The texture, hand-feel, and final polish happen in Pixelmator Pro.

---

## Creative direction

- **Subject:** a small bird's track / foot on a patch of soil.
- **Insight:** a footprint reads as a **trail** — "you walked here / go explore" — which is
  the heart of the app (rambling, the fog-of-war path you light up). Lean into that.
- **Tone:** warm, earthy, hand-made; cozy not corporate. Pairs with the in-app sky palette.
- **Must work at 60×60 px** (Springboard) — keep elements few and bold.

## Palette (soil + golden hour)

| Token        | Hex       | Use                                  |
|--------------|-----------|--------------------------------------|
| soil-900     | `#2E1F17` | deep track silhouette                |
| soil-700     | `#543926` | shadow / mound base                  |
| soil-500     | `#6E4B34` | ground line / mid soil               |
| clay-400     | `#9A6B47` | turned topsoil                       |
| clay-300     | `#B98A5E` | warm tan, rims                       |
| ground-200   | `#D6B388` | light clay                           |
| cream        | `#F7EFE4` | sky / negative space                 |
| dusk         | `#EFB867` | golden-hour accent (ties to SkyPalette) |
| feet-amber   | `#E2912F` | chick feet (Concept B focal pop)     |
| sprout       | `#88A86A` | leaves / growth                      |

Keep harmony with `Terrarium/DesignSystem/SkyPalette.swift` — the dusk accent should match
the in-app golden-hour band so icon and app feel like one world.

---

## The three concepts

| File | Name | Reading | Best when |
|------|------|---------|-----------|
| `concept-a-tracks.svg` | **Tracks** | three tracks walking up a hill into golden light | **product story** — exploration / the ramble. *My pick for the hero.* |
| `concept-b-first-steps.svg` | **First Steps** | chick feet + sprout on a soil mound | warmest, most literal, "growth + terrarium" |
| `concept-c-mark.svg` | **Mark** | one track on a ground line in a disc | **cleanest icon** — scales tiny, monochrome-friendly for tinted Liquid Glass |

Recommendation: **A** for personality/story, **C** for the actual app-icon glyph. They can
co-exist — C is the compact lockup of A's idea. B is the cutest if you want to foreground the
"chick" literally.

### View & compare

- Quickest: open the folder in Finder and Quick Look (spacebar) each `.svg`, or drag into a browser tab.
- Side-by-side: open all three browser tabs, or import into one Pixelmator canvas as layers.

---

## Pixelmator Pro workflow

1. **File → Open** the chosen `.svg` (Pixelmator Pro imports SVG as editable shapes).
2. Refine: adjust the track angle/weight, add **soil texture** (noise/grain on the ground layer),
   a soft inner shadow on the impressions, subtle paper grain on the cream.
3. Keep **two top-level groups** intact: `background` and `foreground` (already split in the SVG)
   so you can export them as separate Liquid Glass layers.
4. **Export** for the app icon master: **1024×1024 PNG**, sRGB, no transparency on the background
   layer, *full-bleed square* (do **not** round the corners — the system masks them).

---

## Liquid Glass support

> Liquid Glass is iOS 26 (WWDC25). iOS 27 (WWDC26, public Sept 2026) auto-refreshes the appearance —
> design for iOS 26 now; it carries forward. Verify specifics against current Apple docs.

### A) The app icon — use **Icon Composer**

iOS 26 app icons are **layered** and the system renders the glass/specular/tint, plus
light / dark / clear / tinted variants. So:

- Build the icon in **Icon Composer** (the WWDC25 tool) with layers from your `background` /
  `foreground` groups: e.g. *back* = soil/sky fill, *mid* = mound, *front* = the track.
- **Do not bake** highlights, shadows, blur, or gloss into the art — the system adds them. Ship
  flat layers with a limited palette.
- Give the front mark generous margins; it must survive the icon grid + corner mask.
- Baseline fallback: drop the **1024 PNG** into `Terrarium/Assets.xcassets/AppIcon.appiconset/`.
  Add the Icon Composer `.icon` for full Liquid Glass layering.

### B) In-app logo (splash / onboarding) — SwiftUI `glassEffect`

```swift
struct LogoBadge: View {
    var body: some View {
        LogoMark() // your vector mark as a SwiftUI Shape/Image
            .frame(width: 96, height: 96)
            .padding(28)
            .modifier(GlassBadge())
    }
}

private struct GlassBadge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular.tint(.brown.opacity(0.22)),
                                in: .rect(cornerRadius: 28))
        } else {
            content.background(.ultraThinMaterial,
                               in: RoundedRectangle(cornerRadius: 28))
        }
    }
}
```

- Group multiple glass elements in a `GlassEffectContainer` so they blend correctly.
- Use `.interactive()` only on tappable glass; a static logo stays `.regular`.
- API surface is iOS 26 — confirm signatures against the current SwiftUI docs before wiring.

---

## Open choices for you

1. **Symbol-only or symbol + wordmark?** (If wordmark: a warm humanist/rounded type; "Terrarium" lowercase reads cozier.)
2. **Duck (webbed) or chick (thin toes)?** Concepts use thin three-toe tracks; webbing is a quick variant.
3. **Disc background or full-bleed scene?** C is disc; A is scene. Icon usually wants a bleed.
