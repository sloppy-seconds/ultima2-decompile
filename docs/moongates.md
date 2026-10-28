# Moongates — the time doors, observed live (2026-10-29)

**What this page is.** The first observed account of the overworld time doors. Everything here was
filmed in one live owner session (`captures/spice86/moongate-cycle`) against `original/ultimaii.exe`,
driven by a person walking and by host-side memory reads. Grades are per `AGENTS.md` § 5 and they are
stated per claim, because three things on this page refute documents already in `docs/` and one
load-bearing attribution is still only inferred.

**Naming.** The owner calls these time doors or portals; `docs/tile-art-spec.md` and
`docs/contract-overworld-walk.md` call them moongates. Both names are kept here. Neither appears in
the binary: there is no string containing `DOOR`, `PORTAL`, `GATE` or `MOON` that refers to them.

---

## 1. The mechanic, observed

A gate is **placed at runtime**, appears as map byte `0xC0` in the live stamped grid, and **transits
the player the moment they step onto it**. There is no prompt and no `E`.

The two transits, from the watcher log, one line per change:

```
t= 13.3s pos=(42,24) DS:49=02 DS:4A=00 DS:6D=00 DS:6E=04 DS:6F=01 gates=[(42,24)]   step on
t= 13.8s pos=(42,24) DS:49=02 DS:4A=00 DS:6D=00 DS:6E=04 DS:6F=01 gates=[]          consumed
t= 15.4s pos=(33,23) DS:49=03 DS:4A=00 DS:6D=00 DS:6E=04 DS:6F=01 gates=[]          arrive, era 3
t= 16.7s pos=(33,23) DS:49=03 DS:4A=00 DS:6D=00 DS:6E=06 DS:6F=08 gates=[]          index advances
t= 17.0s pos=(34,23) DS:49=03 DS:4A=00 DS:6D=00 DS:6E=06 DS:6F=07 gates=[(20,52)]   new gate

t=126.1s pos=(33,23) DS:49=03 DS:4A=00 DS:6D=00 DS:6E=04 DS:6F=03 gates=[(33,23)]   step on
t=126.3s pos=(33,23) DS:49=03 DS:4A=00 DS:6D=00 DS:6E=04 DS:6F=03 gates=[]          consumed
t=127.9s pos=(42,24) DS:49=02 DS:4A=00 DS:6D=00 DS:6E=04 DS:6F=02 gates=[]          arrive, era 2
```

* **Era 2 `(42,24)` → era 3 `(33,23)`, and era 3 `(33,23)` → era 2 `(42,24)`.** The doors are
  **reciprocal pairs**, not a forward march through the eras. This matters for the engine: the
  obvious implementation, `tens++` on transit, would be wrong, and nothing in `docs/` had ever
  considered it.
* `DS:4A` stayed `00` on both sides — wilderness to wilderness.
* `DS:6D`, the world byte, stayed `00` throughout. See § 4.
* The transit also advances the rotation index, so arriving somewhere always shows a *different*
  gate than the one you left.

## 2. The rotation, observed

One gate is active at a time. It is replaced on a fixed cycle driven by two bytes:

| byte | role | observed |
| --- | --- | --- |
| `DS:6F` | countdown | reloaded to exactly **8** on each rotation, then decrements about every **4.2 s** with no input at all |
| `DS:6E` | gate index | advances by **2**, wrapped to 3 bits, so the cycle is `00 → 02 → 04 → 06 → 00` |

The full rotation as watched in era 2, with the gate cell in the live grid:

| `DS:6E` | gate cell |
| --- | --- |
| `0x00` | `(16,16)` |
| `0x02` | `(48,24)` |
| `0x04` | `(42,24)` |
| `0x06` | `(19,52)` |

This is the owner's recollection — *one door active, a new one every 8 turns, always at the same
coordinates* — and it is right in every particular except the unit: **it is time, not turns.** The
countdown ran at a steady rate while the player stood completely still. Grade: observed, and the
"8 turns" half of the memory is corrected by the frame where nothing moved and the door turned anyway.

## 3. The gate table — decoded, 12/12

The candidate coordinates come from a table in the code segment. **File offset `0x2998`**, which is
the runtime displacement `%cs:0x2798` plus the `0x200` file/runtime offset — note this is the
*opposite* direction to the one that maps instruction addresses, and getting it backwards is what made
the first two readings of the table look like garbage.

The layout is **4 gates per era, 8 bytes per era row**, indexed exactly the way `asm/2708` computes
it: byte offset `8 * DS:49 + DS:6E`, with `DS:6E` taking `0, 2, 4, 6`.

| era | gate 0 | gate 1 | gate 2 | gate 3 |
| --- | --- | --- | --- | --- |
| 0 | `(29,56)` | `(31,56)` | `(33,56)` | `(35,56)` |
| 1 | `(34,8)` | `(47,28)` | `(36,56)` | `(20,37)` |
| 2 | `(16,16)` | `(48,24)` | `(42,24)` | `(19,52)` |
| 3 | `(56,52)` | `(28,12)` | `(33,23)` | `(20,52)` |
| 4 | `(18,23)` | `(50,34)` | `(52,24)` | `(8,11)` |

Every gate cell observed live in eras 1, 2 and 3 — twelve of them, across three sectors and two
watchers — is the table entry for that era and index. Grade: **measured**, and the four-per-era shape
matches the owner's recollection of four gates on a map.

### The transit rule: same index, different era

Three transits, expressed as `(era, index)`:

```
era2 idx2 (42,24)  <->  era3 idx2 (33,23)
era2 idx1 (48,24)   ->  era1 idx1 (47,28)
```

**The destination is the gate at the same index in the destination era.** Not a random cell, not a
fixed coordinate — the index is preserved and only the era changes. That is why the pairs looked
reciprocal: they are the same column of the table in two rows.

**What is still open is the destination era per index.** Observed so far: index 1 pairs eras 2 and 1,
index 2 pairs eras 2 and 3. Indices 0 and 3 are unobserved, and the behaviour at the era boundaries
(era 0 and era 4) is unknown. A gate therefore has a *partner era* per index, and that mapping is not
yet derived from the bytes.

## 4. G45 resolved: the tens digit is the era axis

`docs/needs-gameplay.md` G45 carried a collision: `asm/3546_time_index_message.asm` reads `DS:49` as
the era index behind the `ANOS:` dates, while `asm/7030_space_collision.asm` writes `DS:49` from
`DS:6D`, the world byte. One byte, two claimed meanings, and the shipped content seemed to argue for
worlds because every tens group has its own wilderness and sites.

**The transit settles it: `DS:49` moved `02 → 03 → 02` while `DS:6D` stayed `00`.** On Earth the tens
digit is the era axis and the world axis is a separate byte that a time door does not touch. The
`asm/7030` write is therefore the *off-Earth* case, not a competing meaning for the same situation —
which is why reading the two routines side by side could never decide it. The frame corroborates
without needing bytes: the ground in era 3 is a different colour from era 2.

This does not close G45's step 2, which asks what `DS:49` reads as on a planet. That still needs the
G39 rocket.

## 5. Three corrections to documents already in this repo

1. **`docs/contract-overworld-walk.md` "premise check on time-door spawning" does not refute runtime
   placement, and its evidence was the wrong map.** It censused `mov $0xc0,%al` — *stores* — and
   cited the four `0xC0` cells in `mapx03`. But `mapx03` is a **castle** sector (the ones digit is the
   site kind), and **every wilderness map has zero `0xC0` cells**: `mapx00`, `10`, `20`, `30`, `40`
   all contain none. So nothing in the overworld is authored for that byte, and the gates observed on
   this page are placed at runtime. The refutation was about placement inside a site and was read as
   a verdict on the whole mechanic.
2. **A 2-row offset between the authored map and the live grid.** The stamped grid at `DS:1800` is the
   `mapxNN` grid **shifted down two rows**: before the shift, 1020 of 4096 cells disagree with
   `mapx20`; after it, 8 do, and those 8 are the runtime stamps. This is also why
   `contract-overworld-walk.md` records `mapx03`'s gates at `(x,25)` where the file offset says
   `(x,23)`. Worth its own line in `docs/map-format.md`.
3. **"You enter a gate with `E`, like a town" is wrong.** Towns and towers need `E` on a gate cell. A
   time door fires on the step onto the tile, consumed within one tick.

## 6. The attribution that is NOT proven

`asm/2708`, `asm/2731`, `asm/2735` and `asm/2744` are an unreviewed bulk-wave region whose shape
matches everything above: `DS:1F = DS:49 * 8`, index `DS:1F + DS:6E`, a coordinate pair read from
`%cs:0x2798(%di)`, a `call` to the map tile pointer at `asm/50B3`, a `cmp $0xc0,%al`, and on the
mismatch path `mov $0x8,%al ; mov %al,0x6f` followed by `incb 0x6E ; incb 0x6E ; and $0x7,%al`.

**That is a shape match, not a causal proof.** A stop armed at `17D:2908` in sector 00 did **not** fire
during 20 s of standing and walking, and no stop has ever been armed in a sector where a gate was
actually rotating. So the routine that demonstrably runs is not yet demonstrably *this* routine. The
files are not renamed and no name is asserted; see their headers for the proposal.

**The experiment that would close it:** arm `bp_read --ip 2908` in a sector where the gate is known to
rotate — sector 20, era 2, is now a known-good place — and confirm it is hit at the rotation, with
`DS:6E` and the table index visible at the stop. Until then § 6 is the honest ceiling.

## 7. What the engine owes

Nothing here is implemented. `cmd_C`-style gating does not apply; this is overworld movement, so the
work lands in `engine/src/game/overworld.c` and the sector-change path, and it needs: a runtime stamp
of `0xC0` at the indexed table cell, a countdown and index pair, the reciprocal destination map, and
the era change on `DS:49`. None of it is modelled today. It is also, unlike most of what is parked,
entirely overworld work.
