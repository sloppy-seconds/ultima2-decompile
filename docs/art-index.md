# The art index — the renderer reads the grid cell, not the monster record

Closes **G1** and the remaining half of **G18**. Opened because `engine/src/core/view.h`
appeared to claim two mutually exclusive transforms (`>>1` and `>>2`) and because the
bestiary names were attached to art indices derived from the monster `type` byte, which
this document shows is the wrong field.

Grades per `AGENTS.md` § 5. Capture: `captures/spice86/art-index/`, sector 00, character
`ARTTEST` at (31,35), 2026-10-23.

## 1. The transform is `>>2`, and it was never in doubt

`view.h`'s two-step — `u2_view_index()` returns `(map_byte >> 1) & 0xFE`, then
`u2_view_art()` halves it — composes to `((b>>1)&0xFE)>>1`, which equals `b >> 2` for
every one of the 256 byte values. Checked exhaustively. The ticket that said otherwise
was quoting line 54 without reading 78–94, and it is recorded as misframed in
`docs/handoff-2026-10-22.md` triage row L2. **Nothing here reopens that.**

What was open is a different question: **which field** the renderer applies it to.

## 2. The two fields are almost always equal, which is why it stayed open

The overworld spawner stamps the monster's `type` byte into the sector grid, so
`DS:1800[y*64+x] == type` for a monster standing where it spawned. Across the whole
corpus that holds **776 times and fails 3 times** — and all three failures are the same
slot in the same sector, captured three times in one session. A sample of one is not a
sample, so the corpus could not settle it, and `docs/monster-spawn.md` § 9's note that
"grid stamping is a memory fact, not a rendering fact" was the correct hedge.

## 3. The one disagreeing sample, measured against the drawn pixels

Sector 00 slot 6, at (31,33): **`type = 0x34`, grid cell `= 0x38`.** Those predict
different art — `0x34 >> 2 = 0x0D` versus `0x38 >> 2 = 0x0E`.

The viewport geometry from `docs/phase4-state.md` CP4 puts a tile at 16×16 px, the window
at 20×10 tiles, and the player at window tile (9,5). The player was seeded at (31,35), so
(31,33) lands at window tile (9,3), pixel (144,48). Cropping that 16×16 region out of the
headless MCP screenshot and comparing it against every one of the 64 extracted tiles:

| candidate | pixel agreement with what is drawn |
| --- | --- |
| **art `0x0E`** (= `cell >> 2`) | **256 / 256** |
| art `0x0D` (= `type >> 2`) | 171 / 256 |

> **The renderer reads the sector grid cell. The monster record's `type` field is not
> what gets drawn.** Measured, perfect pixel agreement on the only sample where the two
> fields disagree.

## 4. The geometry was checked before the conclusion was drawn

A single perfect match could be a lucky crop, so the same comparison was run over every
monster slot that was inside the viewport at the time of the screenshot. **18 of 19
matched their predicted art at 256/256**, across art indices `0x0D`, `0x0E`, `0x0F`,
`0x3D` and `0x3E`. That is what establishes the window arithmetic; slot 6 is what
establishes the field.

The nineteenth, slot 3, matched a *terrain* tile at 256/256 rather than either candidate.
That is not a counterexample: the monster had moved between the memory read and the
screenshot — its coordinates read (33,34) and then (32,35) on successive polls — which is
the standing read-pause hazard, not a rendering disagreement. It is reported rather than
quietly dropped.

## 5. What this changes

* **The bestiary join is keyed on the right index by luck, not by rule.** It matched
  third-party creature names to art indices derived from the `type` byte. Since `type`
  and the cell agree 776/779 times, the names land on the right art almost always — but
  the field being named is the grid cell. Where they disagree, a bestiary row keyed on
  `type` would name the wrong creature. Sector 00 slot 6 is exactly that case: keyed on
  `type` it is art `0x0D` (Daemon), and what is actually drawn is art `0x0E` (Devil).
* **`engine/src/core/view.h` is correct as written** and needs no change: it already takes
  the map byte. Anyone wiring a renderer to the monster record instead would reproduce
  this bug.
* **The stamp is load-bearing for appearance, not just for lookup.** If a future engine
  keeps monsters in a side table and never stamps the grid, the map will render correctly
  for terrain and wrongly for creatures. `docs/monster-spawn.md` § 9 already records that
  dungeons do **not** stamp the grid the same way — so in a dungeon the appearance must
  come from somewhere else, and that is still unproven.

## 6. Still open

* **One sample.** The conclusion rests on a single disagreeing monster. It is a perfect
  pixel match and the geometry is independently confirmed 18 times over, but a second
  disagreement in a different sector would make this a rule rather than a very strong
  inference. Engineering one is easy now: stamp a cell with a value the record does not
  hold, via `--seed-map` plus a seeded save, and look at what draws.
* **What writes the cell without the record agreeing.** Slot 6's cell says `0x38` while
  its record says `0x34`. Either the record was rewritten after the stamp or the stamp is
  stale from an earlier occupant. Not established, and it is the same "something rewrites
  these fields after load" family as the `kind` mismatches in `docs/monster-spawn.md` § 6.
