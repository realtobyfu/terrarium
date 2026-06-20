# Phase 1: Live Destination Card - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-19
**Phase:** 1-live-destination-card
**Areas discussed:** Card code location, Compact-stub scope, Dead-variant cleanup

---

## Discussion framing

Phase 1 is heavily pre-decided: the approved `01-UI-SPEC.md` locks the entire visual + interaction + data-binding contract, and the uncommitted working tree already wires `TicketDestinationCard` into the live `AnchorView` with real `AnchorViewModel` bindings. Three genuinely-open implementation decisions were surfaced, all concerning the Phase 1 ↔ Phase 2 boundary.

**User response to the discuss prompt:** *"just make best judgements for now"* — all three areas delegated to Claude's judgment.

---

## Card code location

| Option | Description | Selected |
|--------|-------------|----------|
| Extract keepers to a production file now | Move `TicketDestinationCard`/`CompactDestinationRow` + helpers out of `DestinationCardVariants.swift` so Phase 2 can gate/delete the workshop file cleanly | ✓ (Claude's judgment) |
| Leave cards in `DestinationCardVariants.swift` | Honor UI-SPEC "no structural edits"; Phase 2 does the split during gating | |

**User's choice:** Delegated to Claude.
**Notes:** Chose extraction (D-01/D-02). Reasoning: Phase 2 BUILD-01 cannot gate a file the live screen depends on; "promote to production" naturally means giving keepers a production home; keeps Phase 2 a clean wholesale delete rather than load-bearing surgery. Flagged as an intentional extension of the UI-SPEC "Files In Scope" table (code move only, no design change).

## Compact-stub scope

| Option | Description | Selected |
|--------|-------------|----------|
| Production-ready + real-data preview only | Compiles against real types, previewable, but not on the live screen in Phase 1 (matches UI-SPEC) | ✓ (Claude's judgment) |
| Surface on the live screen now | Add a secondary/condensed on-screen presentation in Phase 1 | |

**User's choice:** Delegated to Claude.
**Notes:** Chose production-ready + preview only (D-03). Reasoning: matches UI-SPEC §Secondary (no "more nearby" list yet; that's a Phase 2 decision); surfacing it now would invent new live-screen layout = scope creep. "Available" (CARD-02 / SC#2) is satisfied by a compiling, real-data-bound, previewable component.

## Dead-variant cleanup

| Option | Description | Selected |
|--------|-------------|----------|
| Remove cut variants + demo previews now | Delete `ImmersiveDestinationCard`/`PostcardDestinationCard` + Sutro/Wave-Organ `#Preview`s in Phase 1 | |
| Defer to Phase 2 hygiene (BUILD-01) | Leave them in the now-pure-workshop file for Phase 2 to gate/delete wholesale | ✓ (Claude's judgment) |

**User's choice:** Delegated to Claude.
**Notes:** Chose deferral (D-04). Reasoning: Phase 2 owns build hygiene; after the D-01 extraction the residual cut variants + demo previews live in a pure-workshop `DestinationCardVariants.swift` that Phase 2 gates/deletes alongside `PaletteWorkshop.swift` and `ExperienceFlowDemo.swift`. Keeps the Phase 1↔2 boundary clean.

---

## Claude's Discretion

- All three areas above delegated by the user ("just make best judgements for now").
- New production file name (`DestinationCard.swift`) is a suggestion; planner may rename.
- Compact-stub preview fixture POI is Claude's choice (real bundled POI / stub pick, not hardcoded demo data).
- Also captured D-05 (reconcile/build on the existing uncommitted working-tree wiring rather than re-derive it).

## Deferred Ideas

- "More nearby" / secondary on-screen list surfacing `CompactDestinationRow` live — Phase 2 or later.
- Workshop-file gating/removal (residual `DestinationCardVariants.swift`, `PaletteWorkshop.swift`, `ExperienceFlowDemo.swift`) — Phase 2, BUILD-01.
- Interaction parity (re-roll, "I'm here" arrival, award ceremony) — Phase 2, WIRE-02..04.
- Build + existing test suite green gate — Phase 2, BUILD-02.
