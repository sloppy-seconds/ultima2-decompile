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
| `DS:6F` | countdown | reloaded to exactly **8** on each rotation, and falls by one **per turn** — measured at 1.00 drops per landed turn |
| `DS:6E` | gate index | advances by **2**, wrapped to 3 bits, so the cycle is `00 → 02 → 04 → 06 → 00` |

The full rotation as watched in era 2, with the gate cell in the live grid:

| `DS:6E` | gate cell |
| --- | --- |
| `0x00` | `(16,16)` |
| `0x02` | `(48,24)` |
| `0x04` | `(42,24)` |
| `0x06` | `(19,52)` |

This is the owner's recollection — *one door active, a new one every 8 turns, always at the same
coordinates* — and **it is right in every particular.** An earlier draft of this page claimed the unit
was time rather than turns; that was wrong, and the correction is below.

### Turns, not seconds — a wrong "correction" retracted

The claim was: `DS:6F` fell about every 4.2 s with the player standing still, therefore the cycle is
time and the recalled "every 8 turns" was wrong in the unit. The owner's answer was that the game runs
on turns and a turn also ends on the idle auto-PASS timeout, so standing still *is* turns, just slow
ones. That is right, and it is measured (`captures/spice86/turn-or-second`):

| condition | turns | `DS:6F` drop | drops per turn |
| --- | --- | --- | --- |
| idle, 20 s, no input | ~2 auto-PASS turns | 2 | 1.0 |
| 12 direction keys, 0.55 s apart, all 12 verified as moving the player | 12 | 12 | **1.00** |

One drop per turn, exactly. The idle rate measured here is about one auto-PASS turn every 10 s, so the
earlier 4.2 s figure was itself an artifact of a session where keys were being pressed.

**The lesson, and it is the third one today:** a rate measured while standing still is a turn rate
through a timeout, and calling it "time" is a distinction that was never there. Measure the thing the
model actually claims — here, spend turns deliberately and count — before "correcting" someone's
recollection of how their own game works.

### A wrong conclusion, retracted, and the trap that caused it

An earlier draft of this page claimed `DS:6F` was a general timer the gate code merely
borrows, because in era 0 it decremented for 130 s while `DS:6E` sat still and the stop at
`17D:2908` never fired. **That is wrong and it has been reverted.** Era 0 rotates exactly
like the other eras — forced proof at `captures/spice86/era0-probe`, where poking `DS:6F`
to 1 produced, within one tick:

```
before        era=0 DS:6E=0x00 DS:6F=0xfe gates=[]
after poke    era=0 DS:6E=0x00 DS:6F=0x01 gates=[]
t+5s          era=0 DS:6E=0x02 DS:6F=0x08 gates=[(31,56)]
```

and then slot 2 → `(33,56)` and slot 3 → `(35,56)`, all three matching the era-0 row of the
table.

**The trap, stated so it does not happen again: at load `DS:6F` is `0x00`, so it wraps to
`0xff` and needs roughly 255 ticks — about 25 minutes at the measured rate — before the
first expiry.** Any era-0 observation shorter than that cannot see a rotation no matter
what the code does. This is the second time this session a too-short window produced a
confident wrong answer; the first was the CAST damage formula.

### What load state actually looks like

One real finding came out of the retraction: **at load nothing is stamped.** `DS:6E = 0`,
`DS:6F = 0`, and there is no `0xC0` anywhere in the grid — slot 0's cell is ordinary ground.
The first door appears only when the rotation first fires. The engine models this with
`ow->gate_stamped`, which is set by the rotation and required by the transit, and
`gate_check.c` asserts the refusal.

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

## 6. The attribution: proposed, then refuted

`asm/2708`, `asm/2731`, `asm/2735` and `asm/2744` are an unreviewed bulk-wave region whose shape
looks exactly like the mechanic: `DS:1F = DS:49 * 8`, index `DS:1F + DS:6E`, a coordinate pair read
from `%cs:0x2798(%di)`, a `call` to the map tile pointer at `asm/50B3`, a `cmp $0xc0,%al`, and on the
mismatch path `mov $0x8,%al ; mov %al,0x6f` then `incb 0x6E ; incb 0x6E ; and $0x7,%al`. An earlier
revision of this page, and of those four headers, said that was the rotation.

**It is not. Refuted the same day by the experiment this page proposed.** A stop armed at `17D:2908`
in era 2, with the expiry forced by `DS:6F = 1`, sat there for 120 s across **two demonstrated
rotations** — `DS:6E` advanced and the `0xC0` stamp moved to a new cell inside the armed window — and
the breakpoint never fired:

```
armed on 17D:2908
NO STOP within 120s at 17D:2908
```

So the shape match was coincidence, or at best a different path over the same data. **The behaviour on
this page is fully observed and stands on its own measurements; the routine that implements it is
still undiscovered.** The four files stay unnamed, their headers now say refuted, and the table at
file `0x2998` remains confirmed by 15 live cells regardless of who reads it.

Two lessons, both cheap and both paid for:

* **A plausible shape is not a causal link.** The bytes matched the behaviour in every particular and
  were still the wrong routine. Only a stop across a demonstrated instance counts.
* **Arm the stop and then force the trigger.** The first attempt failed because a 20 s window cannot
  contain a 25-minute countdown. Forcing `DS:6F = 1` makes the experiment take seconds, and it is the
  difference between a negative result and a meaningless one.

## 7. Engine status — implemented for the observed subset

`engine/src/game/gates.{c,h}` now carries the mechanic, wired into the walk loop after a step is
accepted, and `engine/tests/gate_check.c` is the spec (45 checks, run from CP4).

Modelled: the table for all five eras, the countdown and index rotation, the transit on the step onto
the active cell, and the era change on the sector's tens digit with the world byte left alone. The
door is now also **drawn** — see the stamp note below.

**Deliberately not modelled, each for a stated reason:**

* **Slots 0 and 3.** Never transited, so `u2_gate_partner_era()` returns unknown and no transit is
  offered there. The spec asserts that unknown-ness on every era, so filling those slots with a guess
  goes red rather than shipping a door that opens onto an invention. They **are** drawn, because the
  original draws them: all four slots stamp in every era, and only the destination is unknown.
* **The stamp into the resident sector.** The door is stamped into the **view**, not the map. The
  original stamps `0xC0` into the resident grid, and whether that survives a save back into `mapxNN`
  is untested — so the engine draws the door without dirtying the sector it stands on, which keeps an
  unmeasured question out of the write path.

**A wrong objection, removed.** An earlier revision of this page said the stamp was blocked partly
because the substitute art for that byte is under cleanroom control. That was wrong and the owner
pointed it out: the stamp byte was already known from the live grid, and the engine's own proven
mapping takes it the rest of the way — map byte `0xC0` → staging `(0xC0>>1)&0xFE = 0x60` → art
`0x60>>1 = 0x30`, which is the moongate record in `docs/tile-art-spec.md` (whose index is written in
hex). The stamp goes through `u2_tiles`, which is whichever set is loaded, so **the normal path and the
`--cleanroom` path both render a door at the same index with no extra plumbing.** The cleanroom set
already has a moongate at `tile_30.svg`, drawn under amendment A9 from the owner's own description.

What the cleanroom path lacks is not a tile but a passing one: `tools/tile_rules.py` has `RULES[0x30]`
and `0x30` is in `PENDING_REDRAW` — PROVENANCE records it as "`30` moongate (no top rule)". So the
substitute door renders and is reported as debt on every `make test`, which is the arrangement working
as designed. **This raises its priority** — it went from a map tile nobody had yet reached to the only
depiction of a feature the engine now has — but the redraw cannot be done by whoever read the live
screenshots, and this session read several. It needs a fresh implementer working from the spec alone,
per `docs/cleanroom-procedure.md`.
* **The countdown unit.** The original's is wall-clock (~4.2 s per unit, measured with the player
  standing still). The engine is turn-driven, so `u2_gate_turn()` counts turns. That substitution is
  inferred from the idle auto-PASS advancing turns and is **not proven** — anyone wiring this to a
  real-time backend should revisit it before trusting the pacing.

Still open for a future session, in the order that would unblock the most: transit era-2 slot 0
`(16,16)` and slot 3 `(19,52)` to complete the partner map; measure whether a stamped gate survives
a save; find the countdown's real timebase; and arm `bp_read --ip 2908` in a sector where a gate is
rotating, which is the one thing that would let `asm/2708`–`2775` finally be named.
