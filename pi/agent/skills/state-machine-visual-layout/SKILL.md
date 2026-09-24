---
name: state-machine-visual-layout
description: "Use when editing, generating, or reviewing state-machine definition JSON layout (positionX/positionY) for the admin-portal flow editor."
---
# State Machine Visual Layout

## When to use

Any time you touch a state-machine **definition JSON** — adding/removing states or
transitions, regenerating the flow, fixing positions, or checking why the diagram
renders badly in the admin portal. Where the definition JSONs live depends on the repo:

- **e2e-performance-tests**: `scripts/afsSeed/definitions/state-machine/`
  (e.g. `afs-los.json`), applied by the seed domains
  (`scripts/afsSeed/domains/60-state-machine.sh` PATCHes the whole flow,
  positions included).
- **bpm/flow-generator**: `tenants/<tenant>/flows/<flow>/definitions/state-machine/`
  (e.g. `tenants/afs/flows/onboarding/definitions/state-machine/afs-los.json`),
  applied by the state-machine seed domain (`seed/domains/60-state-machine.sh`,
  which PATCHes the whole flow, positions included).

## How the admin portal renders a flow (facts, verified against the code)

Frontend repo: `front-end/admin-portal`, feature dir
`src/features/admin/state-machine/flow/` — editor view
`views/state-flow-update.tsx` (React Flow via `@xyflow/react`).

- **Node position is raw pixels.** Each state becomes a React Flow node with
  `position: { x: positionX, y: positionY }` — used as-is, no scaling or offset.
  Drag-and-drop in the editor updates `positionX`/`positionY` and the Save
  button PATCHes them back.
- **Nodes are content-sized boxes** (`components/node-header.tsx` +
  `src/components/base-node.tsx`, `p-5` padding, no fixed width). A box shows
  the state name (title) plus `Target:` and `Action: <name> [<TYPE>]` lines.
  Long names/actions ⇒ wide boxes — worst case ≈ **500px wide × 140px tall**.
  Budget for this when spacing states.
- **Edges attach top/bottom** (target handle at top, source handle at bottom),
  so a vertical spine reads naturally.
- **Edges are `step` (orthogonal) with a label** `name [condition]` drawn by
  React Flow at the edge midpoint. The label text comes straight from the
  transition's `name` + `condition` — long transition names produce unreadable
  labels (keep them short; detail belongs in `description`).
- **The viewport scales to fit**: `fitView` (padding 0.2) with `minZoom 0.2` /
  `maxZoom 4`. The whole canvas is shrunk to the editor pane (height ≈
  `window.innerHeight - 200`), so a large flow is initially tiny — users zoom.
  Readability therefore means: at zoom ≈ 1, boxes never touch and labels sit in
  empty space.
- Editor extras: dot background, MiniMap, controls; a draft is autosaved to
  localStorage (`sm_flow_draft_<machineId>`).

## General layout rules (any flow, any tenant)

These are deliberately general — they apply to a 10-state sub-flow and a
100-state main flow alike.

1. **Read top-to-bottom.** The main happy path is a near-vertical **spine**,
   ordered by transition sequence. A flow diagram should be **taller than it is
   wide**.
2. **Terminals live at the edges.** REJECT / ERROR / CANCELLED / end states
   belong at the canvas margins (left or right of the spine), not interleaved
   with the happy path — "where can this flow end" should be legible at a glance.
3. **Branches cluster near their gate.** Side steps (loops, manual tasks,
   sub-chains, rejection notices) sit beside or just below the state they branch
   from, so branch edges stay short. States that loop back to the spine stay
   close to it.
4. **No overlaps — the hard rule.** Nodes are content-sized (~500×140 worst
   case). Adjacent lanes need ≥ ~600px pitch; adjacent rows ≥ ~200px pitch.
   Enforce it programmatically: never ship a definition with two states sharing
   the same (x, y).
5. **Give every edge label room.** Each edge carries `name [condition]`. Keep
   transition names ≤ ~25 chars and space states so labels land in empty gaps,
   not on top of boxes.
6. **Fan out, don't stack.** When a gate has several outgoing edges, offset the
   targets vertically (e.g. manual tasks one row below the gate) so the edges
   diverge instead of overlapping.
7. **Deterministic layout beats hand-placing.** Regenerate positions from a
   script — idempotent, reviewable diffs, and it can fail loudly on unplaced
   states or collisions.

## Reference points

- **Hand-crafted reference**: the PTF flow `10baca70-cb71-475c-993e-59439256516b`
  in the dev state-machine DB (`state_machine.state_machines.flow`) is the
  platform's best hand-made layout: ~100 states, canvas ≈ 4400×7600, minimum
  clearances ≈ 290px horizontal / ≈ 180px vertical, terminals at the edges,
  task clusters below their triggers. A good target for "airy" spacing.
- **The e2e repo's generator**: `scripts/afsSeed/lib/layout_flow.py` implements the
  rules above for the AFS LOS flow (spine lane + left ERROR edge + right
  notice/branch, terminal and task clusters, collision check, fail-on-unplaced).
  It is invoked automatically by `scripts/afsSeed/domains/60-state-machine.sh`
  before the PATCH. Follow its structure when laying out a new flow.
- **The flow-generator repo's generator**: `seed/lib/layout_flow.py` implements the
  same rules for the AFS LOS flow. It is invoked automatically by
  `seed/domains/60-state-machine.sh` before the PATCH.

## Checklist when touching a definition JSON

- [ ] Every state has `positionX` / `positionY` (missing ones render at 0,0 and
      collide).
- [ ] No two states share the same (x, y) — run a collision check.
- [ ] Adjacent lanes ≥ ~600px apart, adjacent rows ≥ ~200px apart (node boxes
      are ~500×140).
- [ ] Transition `name`s short enough for edge labels (≤ ~25 chars); long
      explanations live in `description`.
- [ ] Happy path is a top-to-bottom spine; terminals at the canvas edges;
      branches near their gate.
- [ ] After applying (e.g. re-run `60-state-machine.sh`), verify the stored
      definition read-only: collisions = 0, expected x/y ranges.
