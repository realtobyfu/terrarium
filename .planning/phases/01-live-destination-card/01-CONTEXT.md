# Phase 1: Live Destination Card - Context

**Gathered:** 2026-06-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Promote the redesigned **ticket card** (primary) and **compact stub** (secondary) from the preview-only workshop into the live `AnchorView`, bound to real `AnchorViewModel` pick data, rendered in the approved cream/brown + Garden-moss palette — replacing the old internal hero card.

**Requirements (from REQUIREMENTS.md / ROADMAP.md):** CARD-01, CARD-02, CARD-03, CARD-04, WIRE-01.

**In scope:** ticket card as primary live destination card; compact stub as a production-ready secondary component; real POI data binding (name, category, supporting detail); approved palette only (no Painted Ladies).

**Out of scope (this phase):** re-roll / "I'm here" arrival / award-ceremony parity verification (Phase 2, WIRE-02..04); gating/removing workshop files (Phase 2, BUILD-01); build+test green gate (Phase 2, BUILD-02); any AnchorViewModel logic or scoring changes; any edits to frozen contracts (`ExploreModels.swift`, `ExploreProviders.swift`).

</domain>

<decisions>
## Implementation Decisions

> The user delegated all open gray areas ("just make best judgements for now"). D-01..D-05 below are Claude's best-judgment calls and are open to user override after review.

### Card Code Organization
- **D-01:** Extract the keeper cards — `TicketDestinationCard`, `CompactDestinationRow`, and the private helper/shape structs they depend on (`PostageStamp`, `CategoryBadge`, `TicketShape`, `DashedRule`, `Line`, `HTicketShape`, `VDashedRule`, `VLine`) — out of `DestinationCardVariants.swift` into a **new production file** (suggested name `Terrarium/AnchorFeature/DestinationCard.swift`; planner may rename). This is a **code move only** — no edits to card internals or design. **Why:** Phase 2's BUILD-01 wants to gate/remove the workshop files, but `DestinationCardVariants.swift` can't be gated while the live screen depends on cards defined inside it. Promoting to production = giving the keepers a production home now; Phase 2 then becomes a clean wholesale gate/delete instead of risky surgery.
- **D-02:** ⚠ This intentionally **extends the UI-SPEC "Files In Scope" table** (which said `DestinationCardVariants.swift` needs "no structural edits" in Phase 1). The move preserves the SPEC's design intent ("do not re-invent the design") — only the struct location changes. Flag this as a deliberate, reconciled deviation for any UI-checker re-run.

### Compact-Stub Scope
- **D-03:** `CompactDestinationRow` ships as a **production-ready component bound to real `POI`/`AnchorViewModel` data types**, with a **real-data `#Preview`** (driven by stub providers / a representative bundled POI — never hardcoded demo data). It is **NOT wired onto the live Anchor screen** in Phase 1. **Why:** Honors UI-SPEC §"Secondary — CompactDestinationRow" (no "more nearby" list exists yet; that's a Phase 2 decision) and avoids scope creep. CARD-02 / Success-Criterion 2's "available as the secondary presentation" is satisfied by a compiling, real-data-bound, previewable component.

### Cut-Variant & Demo Cleanup
- **D-04:** Cut variants (`ImmersiveDestinationCard`, `PostcardDestinationCard`) and the demo `#Preview` blocks (hardcoded Sutro Baths / Wave Organ data) are **NOT removed in Phase 1**. After the D-01 extraction they remain in a now-pure-workshop `DestinationCardVariants.swift`, removed/gated in **Phase 2 (BUILD-01)** alongside `PaletteWorkshop.swift` and `ExperienceFlowDemo.swift`. **Why:** Keeps the Phase 1↔2 boundary clean — Phase 1 promotes, Phase 2 cleans.

### Working-Tree Reconciliation
- **D-05:** The uncommitted working tree already wires `TicketDestinationCard` into `AnchorView.scrollContent` (lines 94–103) with the exact UI-SPEC bindings, replaces the old hero branch, and adds presentation props to `AnchorViewModel` (+69 lines). The plan should **reconcile and build on this in-progress work**, not re-derive it: confirm the bindings match the UI-SPEC data-binding table, then layer the remaining Phase 1 work (D-01 extraction + D-03 compact-stub productionization + real-data previews) on top.

### Claude's Discretion
- New production file name (`DestinationCard.swift`) is a suggestion — planner may pick a name matching any existing convention.
- Exact preview-fixture POI for the compact-stub real-data preview is Claude's choice (use a real bundled POI from `sf-pois.json` or a stub-provider pick, not a hardcoded `DemoSpot`).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Locked design contract (read first — do NOT re-invent)
- `.planning/phases/01-live-destination-card/01-UI-SPEC.md` — **APPROVED, LOCKED** visual + interaction + data-binding contract. Fixes shapes, palette, typography, copy, SF-Symbol→category mapping, and every card field's `AnchorViewModel` source. Note: D-01/D-02 above intentionally extend its "Files In Scope" table.

### Requirements & roadmap
- `.planning/REQUIREMENTS.md` — Phase 1 requirement IDs CARD-01..04, WIRE-01 (and Phase 2 IDs for boundary awareness).
- `.planning/ROADMAP.md` — Phase 1 goal + 4 success criteria; Phase 2 scope.
- `.planning/PROJECT.md` — milestone scope, locked workshop decisions, Key Decisions table, constraints.

### Codebase concerns
- `.planning/codebase/CONCERNS.md` — flags (a) `AnchorViewModel` torn-state risk across `pool`/`poolIndex`/`pick`/`arrivalResult`/`arrivalBlocked`/`context`; (b) preview/workshop files not filtered from production (the Phase 2 hygiene target).

### Source files in scope
- `Terrarium/AnchorFeature/AnchorView.swift` — live screen; `scrollContent` pick branch already references `TicketDestinationCard`; pinned `safeAreaInset` action area.
- `Terrarium/AnchorFeature/AnchorViewModel.swift` — already exposes `pick`, `pool`, `context`, `vibeLine`, `walkInfo`, `arrivalProximity`, `arrivalHint`, `pickIsLikelyOpen`, `arrivalBlocked` (the full binding surface).
- `Terrarium/AnchorFeature/DestinationCardVariants.swift` — current home of keeper cards (`TicketDestinationCard` L307, `CompactDestinationRow` L218) + helpers + cut variants + demo `#Preview`s; source for the D-01 extraction.
- `Terrarium/DesignSystem/Tokens.swift`, `Terrarium/DesignSystem/GardenTokens.swift` — palette / spacing / radius / typography tokens (read-only).
- `Terrarium/DesignSystem/ScenicArtBand.swift` — procedural art component used by both cards (read-only; do not modify).
- `Terrarium/Domain/ExploreModels.swift` — frozen contract (`POI`, `POICategory`, etc.); read-only, no signature changes.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TicketDestinationCard` / `CompactDestinationRow`: fully implemented in `DestinationCardVariants.swift` — Phase 1 relocates (D-01) and binds, not redesigns.
- `AnchorViewModel` presentation properties (`vibeLine`, `walkInfo`, `arrivalProximity`, `arrivalHint`, `pickIsLikelyOpen`): already exist — no new VM API needed for binding.
- `ScenicArtBand(poiRef:category:weather:)`: drives card art; both cards already call it correctly.

### Established Patterns
- `@Observable @MainActor` view models with `private(set)` published state; views read state directly.
- Cards are **purely presentational** — no business logic inside the card structs (CLAUDE.md constraint).
- Design via `Theme.*` tokens only (no magic numbers); iOS 26 Liquid Glass APIs (`.glassEffect`, `.buttonStyle(.glass/.glassProminent)`, `GlassEffectContainer`).
- Offline-first: must compile + preview against stub providers.

### Integration Points
- `AnchorView.scrollContent` pick branch (`else if let poi = viewModel.pick`) — already renders `TicketDestinationCard`; the integration is in place in the working tree.
- Pinned actions live in `safeAreaInset` (`showsActions`); their parity is a Phase 2 concern.
- Card re-roll identity: UI-SPEC requires `.id(viewModel.pick?.poiRef)` + `.opacity.combined(with: .scale(0.97))` transition (verify present/added).

</code_context>

<specifics>
## Specific Ideas

- Palette is the **original cream/brown + Garden moss**; the **Painted Ladies variant must not appear on screen** (CARD-03).
- **Ticket card = primary, compact stub = secondary** — locked from the workshop; do not revisit variant selection.
- Real-data preview fixtures must use real `POI` types, never `DemoSpot` / hardcoded `"Sutro Baths"`-style values reaching anything production-bound.

</specifics>

<deferred>
## Deferred Ideas

- **"More nearby" / secondary on-screen list** that would surface `CompactDestinationRow` live — Phase 2 (or later) decides whether the screen layout calls for it (UI-SPEC §Secondary).
- **Workshop-file gating/removal** (residual `DestinationCardVariants.swift`, `PaletteWorkshop.swift`, `ExperienceFlowDemo.swift`) — Phase 2, BUILD-01.
- **Interaction parity** (re-roll "Another", "I'm here" arrival, award ceremony) — Phase 2, WIRE-02..04. The action buttons already exist in the pinned action area; Phase 2 verifies their behavior survives the card swap.
- **Build + existing test suite green gate** — Phase 2, BUILD-02.

</deferred>

---

*Phase: 1-live-destination-card*
*Context gathered: 2026-06-19*
