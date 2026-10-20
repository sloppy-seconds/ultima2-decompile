# CP4 kickoff — overworld + movement

Start here. CP3 is gate-passed (owner, 2026-10-27). This checkpoint replaces the
`[engine] OVERWORLD GOES HERE (CP4)` placeholder that `P` currently prints.

**Gate:** the owner walks around a map.

Read first: `docs/phase4-plan.md` § 4a (fidelity policy, deviations D1-D13),
§ 7 (evidence-backed corrections — several apply to CP4), and
`docs/phase4-acceptance.md` (the standing gate rule: audit every user-reachable
branch against its asm entry point before calling the checkpoint done).

---

## 1. The map is runtime data, not extracted content

This is the decision that shapes everything else in CP4, and it is settled by the
files themselves:

```
original/mapx00  original/mapx03  original/mapx10 ... original/mapx71
```

Roughly thirty files, **every one exactly 4224 bytes**. The map is not inside
`ultimaii.exe`, so the extractor has nothing to extract from it. The engine must
**read these files at load/use, the way the original did**, from a content
directory the player supplies.

Consequences:

* Add a content-directory seam (like `--save-dir`, so `--data-dir`), not a
  generated header. Do not bake map bytes into C.
* "Zero game content committed" stays trivially true — the files never enter the
  repo. They are gitignored already (`original/`, `references/`).
* The extractor's job for CP4 is limited to any *in-code* tables (terrain
  properties, encounter rates, direction messages) — not the tiles.

## 2. Open questions to settle before writing any rendering

Do these in order; each is cheap and each changes the design.

1. **How is the filename built?** There is no `mapx` string literal anywhere in
   `asm/` — grep proves it — so the name is assembled arithmetically or written
   as encoded bytes into an FCB. Find the construction site and the sector
   arithmetic that picks which file. The plan calls this `map_tile_ptr`.
2. **What is a tile?** 4224 = 4096 + 128. Candidates: 32x32 tiles x 4 bytes plus
   a 128-byte header, or 1056 x 4-byte entries. Do not guess — dump a file,
   compare two adjacent maps, and find where the world coordinate indexes in.
3. **How do the two-digit names map to world coordinates?** `mapx00`, `mapx03`,
   `mapx10`..`mapx11`, `mapx15`, `mapx20`..`25`, `mapx30`..`35`, `mapx40`,`41`,
   `44`,`45`, `mapx50`, `mapx60`,`61`, `mapx70`,`71`. The gaps are informative:
   they are probably ocean or unimplemented sectors.
4. **Which read path?** The save path turned out to be FCB random read/write
   (`AH=27h`/`28h`) through the generic DOS wrapper at `asm/52CA`, which is why
   static grep found nothing. Expect the same shape here.
5. **What is the viewport, and how is it centred?** Owner's recollection of the
   original (2026-10-27, from memory, **not yet verified**): the map shows 5 tiles
   above and below the character, and about 10 to each side — possibly asymmetric,
   9 on one side and 10 on the other.

   The arithmetic that has to fall out of the asm: 5 + 1 + 5 = **11 rows**, and
   either 10 + 1 + 10 = **21 columns** (symmetric) or 9 + 1 + 10 = **20 columns**
   (asymmetric). So the candidates are 21x11 or 20x11, which is 231 or 220 tiles —
   not the 40x25 grid, and not a clean fraction of it either.

   The asymmetry is the informative part. A symmetric window is what you get from
   centring a viewport; an uneven split is what you get from `left = player_x - N`
   with a fixed `N`, which also predicts how the view behaves at a sector edge.
   Do not settle this by eye. Find the map draw loop and read its row and column
   bounds and the offset it derives from the player position, the same way the
   status block positions were proven from the code that sets `DS:0x2E` and
   `DS:0x2F`.

6. **Does the viewport ever straddle two sectors?** The viewport is a window onto
   a larger map, so the map scrolls as the player moves (owner, 2026-10-27). That
   makes the sector files a partition of one continuous world rather than
   self-contained screens, and it forces a second question: when the player walks
   across a sector boundary, does the view scroll smoothly through it, or does the
   display jump to the new sector's origin?

   The two answers need different loaders. Smooth straddling means the engine must
   hold an adjacent sector (or two, at a corner) and index across them, and the
   sector-to-coordinate mapping has to be exact at the seam. Boundary snapping
   means one sector at a time and a much simpler loader.

   Decide it from the draw code and the sector arithmetic, not from how it feels to
   play. A 21x11 viewport inside a sector that is plausibly 32x32 means most
   movement is within-sector and only the edges are in question, so the seam
   behaviour is a small, specific thing to find rather than a pervasive design.

   This also predicts a visible artefact worth checking in the original: if the
   view scrolls smoothly and the loader only ever had one sector resident, the
   edge tiles would have to come from somewhere, and the way they do is a clue to
   the mapping.

   Related constraint already known: the status block occupies column 30 and rows
   20-23, and `right_margin` alternates between `0x28` (40) and `0x1d` (29), so
   the map region cannot use the full width. A 21-wide window inside a 40-column
   grid means the map is inset, which probably also means there is a border or
   frame to account for.

## 3. Facts already established that CP4 must respect

* **Grid is 40x25**, not 80x25. Evidence in plan § 7.
* **`rand_byte` is a six-byte feedback shift register** at `DS:0x23F..0x244`,
  seeded once at launch. Already reimplemented correctly in `core/rng.c`, so
  encounters replay deterministically from the start. Do not reintroduce a
  clock read: game logic never reads the clock, only presentation delays may.
* **HP / FOOD / EXP / GOLD are 4-digit packed decimal** in a little-endian word,
  and the original prints the bytes low-first, so food 3 displays `0300`.
  Reproduced in `game/status.c`, quirk included. Ceiling is 9999, not 255. This
  matters the moment movement consumes food.
* **`key_poll` consumes and upper-cases** (`asm/4F4D`: INT 16h AH=01h then
  AH=00h, `and $0xdf`).
* **`right_margin` is stateful.** `asm/5396` leaves it at `0x1d` after the status
  block; anything that draws a full-width screen must set its own margin. This
  bit us on the title menu.

## 4. Scope

In scope: `map_tile_ptr` sector model, loading a sector file, drawing the
viewport, direction movement, `invalid_move_msg`, `move_only_on_foot` (the
foot/ship/plaques gate), terrain encounter rolls.

Out of scope: combat (CP5), towns and the full command set (CP6), the SDL2 CGA
renderer (CP9). Until CP9 the map renders as text cells, so pick terrain glyphs
that read clearly in a terminal and note them as provisional.

## 5. How to work

* `make test` is the fast loop (4.8s: engine suites + cheap Phase 3 guard).
  `make test-full` adds the jwasm clean rebuild (~73s); CI runs it on every push,
  so do not pay for it locally unless `asm/` moved.
* Verification is semantic review against `asm/` plus scripted playthroughs.
  There is no automated differential testing against the original (owner
  decision), and no live DOSBox capture unless a real decision point needs one.
* When the asm is a db blob and decodes wrong, use `tools/redecode.py --range
  START:STOP` (file offsets, runtime + 0x200). That is how the creation flow,
  the validator at `asm/5C66` and the BCD printer at `asm/55B5` were finally
  read.
* Every engine module cites its asm spec by **file offset**, and no game string
  or tile byte is hardcoded — it comes from the extractor or from the player's
  own files.
* Do not use subagents (GPU contention with the owner's local model).

## 6. Suggested order

1. Settle § 2 items 1-2 and write the answer into `docs/phase4-implementation.md`
   with citations, before writing engine code.
2. `--data-dir` seam + a sector loader, with a test that loads a file and asserts
   its size and a checksum-free structural property (no game bytes committed).
3. Tile decode + viewport draw. Prove it with `--dump-each` on a scripted route.
4. Movement + `invalid_move_msg` + `move_only_on_foot`.
5. Encounter rolls, then hand it to the owner to walk.

Add a CP4 suite (`engine/tests/run_cp4.sh`) as you go, and keep the acceptance
criteria derivable from committed artefacts.
