# CP5 kickoff — the wiring that makes a fight reachable and visible

Written 2026-10-23 after the combat-mode audit, the live fight captures and G24/G25.
Reads: `AGENTS.md`, `docs/phase4-state.md` § CP5, `docs/handoff-cp5-2026-10-23.md`,
`docs/spice86-live-findings.md` § 14, § 15, § 16, § 17.

**Acceptance bar (owner's words):** *"lets get to a rendered fight in the game"*. Not a green
suite. The `phase4-plan.md` gate is "owner wins a fight".

**Comment standard (standing directive):** every new function cites the `asm/` file behind
each behaviour, or says plainly that it is a guess.

---

## 1. What already exists — do not rebuild any of this

| piece | where | state |
| --- | --- | --- |
| C1/C2/C4/C5/C6 mechanics | `engine/src/game/combat.c` | implemented, spec-covered, 4066 checks green |
| The spec and its controls | `engine/tests/combat_check.c`, `run_cp5.sh` | discriminates; controls and a zero-check self-test run every `make test` |
| Sector I/O for **both** `mapx` and `monx` | `engine/src/core/world.h` — `u2_world.mon[]`, `mon_loaded`, `mon_dirty`, `u2_world_load(ctx,w,is_map,id)` | **already loads and stores monx**; `U2_MON_TILES 256 /* CX at asm/22D5 */` |
| CMD window, status band, prompt | `engine/src/game/status.c`, `overworld.c` | CP4; the fight UI is a line in this window, so rendering cost is near zero |
| Save gates incl. the Earth gate | `u2_save_policy` in `overworld.h` | all three gates lifted already, `DS:6D` included |
| Paralysis counters | `state.h` `paral_legs/arms/sleep` at `0x26B/26C/26D` | present, with `_Static_assert` on the offsets |

**So CP5's remaining work is interpretation and wiring, not I/O and not mechanics.**

---

## 2. The evidence the wiring must honour

Each line is a finding with its citation; the detail lives in the findings doc, not here.

1. **Combat entry is `A` + a direction**, and the fight renders as one line of the world
   view's `CMD:` log — `ATTACK--EAST--HIT!!!`, `KILLED--GOLD+1--EXP.+02`. No battle screen,
   no mode. `asm/2B8F_cmd_A`, `asm/2BEC_combat_hit_msg`, `asm/2E3D_combat_attack_flow`,
   capture `cp5-fight`.
2. **A creature blocks movement**: stepping onto one prints `EAST--INVALID MOVE!` over a
   walkable tile. C3's paralysis rejection joins this existing path.
3. **The counter tick is time, not moves** — `asm/0C33..0C53`, observed decaying while the
   player stood still, in a 3000-turn recording and live. It ticks a **fourth, unnamed
   counter at `DS:26A`**.
4. **Status is not persisted and cannot be** — poked `07 09 08 08`, saved with `Q`, absent
   from the 384-byte file, `00 00 00 00` on reload. G24 closed.
5. **Hostility is provoked.** Landing a blow on anything in a town flips **every guard in
   the sector** to `[DI+0x1D7] == 0x01`; a missed swing flips nothing; 65 s idle flips
   nothing. Alerted guards converge and take HP. § 16, capture `cp5-g25-aggro`.
6. **The alarm cannot survive a save either** — `DS:1D7` maps to file `0x1A1`, past the end.
7. **Death zeroes four on-screen fields** and prints `<NAME> IS DEAD!` — `asm/0C62`
   (`0` into `DS:51..59`), confirmed on screen.
8. **Low HP draws `H.P.` in red** — a renderer state CP4 never produced.
9. **BCD fields wrap** — GOLD `9999 -> 0010`, EXP `9999 -> 0001` seen live; this is the B1
   ticket's `bcd_adc` landing with its first caller.

---

## 3. Work items, in build order

**W1 — creature state.** Add the six 32-slot arrays to `state.h` at `DS:137` x, `DS:157` y,
`DS:177` hp, `DS:197` type, `DS:1B7` kind, `DS:1D7` role, each with `_Static_assert` like the
paralysis fields. New `engine/src/game/monsters.c` maps `world.mon[]` offsets
`0..31/32..63/64..95/96..127/128..159/160..191` onto them at sector load, per
`docs/monster-spawn.md` § 6 (matched 32/32 live on type, hp and the role array).
Cite: `asm/22D5` (the 256-byte read), `docs/monster-spawn.md` § 6.
Test: load sector 31's `monx`, assert the arrays equal the values read live from the
emulator in this session (`captures/spice86/cp5-g25-aggro/roles-at-load.txt` is a
ready-made expected output).

> **Side finding to fold in:** `docs/monster-spawn.md` § 7 asks how the sixth array arrives
> when `asm/22D5` reads `CX=0x100` = 256 bytes, "which covers arrays 1–5 and not the sixth at
> `160..191`". Six arrays of 32 bytes is 192 bytes; a 256-byte read covers all six with 64 to
> spare. The premise looks like arithmetic slip, not a mystery. Verify against `asm/22D5` and
> close it.

**W2 — draw the creatures.** Art index is `(cell)>>2` from the **sector grid cell**, not the
monster type (`docs/art-index.md`, 256/256 on the disagreeing sample). Terminal mode needs a
glyph decision (see § 4 Q1).

**W3 — `cmd_A`.** Direction from the same source the original uses; find the target by
scanning the creature arrays for the adjacent cell; roll; on hit subtract from `[i].hp`
(`asm/2E3D`: `sbb` the damage byte, on borrow clear `x/y/hp/type/kind` — the record is
cleared, not flagged); print `MISS` / `--HIT!!!` / `KILLED--GOLD+n--EXP.+m`. Gold and exp
adds use the new `bcd_adc` (B1 ticket: mirror `bcd_sbb`, discard the carry, cite
`asm/2DC1`/`asm/2DEE`, pin the measured `9999 + 15 -> 14`).

**W4 — occupied tile rejects the move.** Same reject path as mountains and paralysis
(`asm/2423` region, `--INVALID MOVE!`). **Site not yet located at byte level** — implement
against the observation and say so in the comment until the branch is found.

**W5 — the alarm.** On a landed hit: set `role = 0x01` on the target, and on every creature
of the guard class in the loaded sector. **Site not located**; the behaviour is measured
(§ 16) and the capture is the citation. Keep it in one function so a later byte-level finding
is a one-place change.

**W6 — alerted creatures act.** Pursue when alerted, strike when adjacent. Observed
(convergence + HP `9999 -> 9796`), **not located at byte level**. Keep the pursuit rule
behind one function; § 16's open question (does `0x01` cause attacking, or record it) is
still open and this is where it gets settled.

**W7 — the tick.** Decrement `paral_legs/arms/sleep` and the unnamed `DS:26A` (add the field
to `state.h` with a `# NAME UNKNOWN:` comment, do not invent a name) on the engine's time
base, **not** on movement. Cite `asm/0C33..0C53` and § 15/§ 17.

**W8 — death.** Zero `DS:51..59`, print `<NAME> IS DEAD!` into the CMD window. Cite
`asm/0C62`.

**W9 — the gate.** A scripted headless fight (`engine/tests/run_cp5.sh` extension or a
`play_to` script): spawn, approach, `A`, hit, kill, assert the log lines and the BCD wrap.
Then the owner plays one and wins.

---

## 4. Two questions to settle before W2 and W7

* **Q1 (blocks W2):** in terminal mode, how does a creature appear? The original draws
  sprites; CP4's terminal path is a character grid. Options: a glyph per creature class, or
  creatures invisible in terminal and visible only in the SDL path (CP9). This is the owner's
  call, not an engineering preference.
* **Q2 (blocks W7):** what is the engine's time base? The original ticks on wall-clock, not
  on input. Candidates: real seconds, a frame count, or a fixed ticks-per-second constant.
  It changes determinism: `phase4-plan.md` requires a seed to reproduce a run exactly, and a
  wall-clock tick is not reproducible in a headless replay. **This one may need an explicit
  deviation ruling** — e.g. tick per input in replay mode, wall-clock when interactive.

---

## 5. Standing rules for this checkpoint

* No stubs. A stub for "resist paralysis" encodes boolean immunity and looks finished.
* Anything guessed says *guess* in the comment, with what would settle it.
* `make -C engine test` and `bash tools/assemble_clean.sh` green at every commit that can
  break something.
* If a behaviour turns out to need a battle screen or a combat-mode flag, **stop and ask** —
  the owner ruled there is no leaves-combat state, and that is now screen-proven.
