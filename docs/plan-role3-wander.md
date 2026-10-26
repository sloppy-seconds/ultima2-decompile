# Plan — implement the role-3 wander (build when asked)

**Status: planned, not built.** Owner asked for a plan to request later, 2026-10-26.
Nothing here is started. To invoke: "build the role-3 wander plan".

Owner decisions already given, do not re-litigate:
* The diagonal melee range asymmetry is **parked as E6** in `docs/phase4-state.md`. Not part of this work.
* The town thief steal is **measured as not happening in the original** (G37 closed). This plan may
  reduce that symptom as a side effect; it does not decide the steal question.

---

## 1. The bug, in one line

`engine/src/game/ai.c` has `moves = (role == 1 || role == 2)`, so **role-3 creatures never move**.
Role 3 is the majority of populated town slots — 179 of the shipped `monx` role bytes — and in the
original they wander. Owner-visible symptom: the thief by LINDA's entrance is a statue that steals
every turn you stand next to it.

## 2. Evidence basis — read these first, do not re-derive

| fact | grade | where |
| --- | --- | --- |
| role dispatch is `al >= 3` → `L_001286` | measured | `asm/1035_sub_1035.asm` (`cmp $0x3,%al ; jae`) |
| `asm/1086..10E8` is **one routine cut into eight files** by the bulk wave | static | `asm/1086_creature_wander_step.asm` header has the whole chain |
| the chain loads a per-slot step vector, re-rolls it on 25% of turns, stages the candidate | static, high confidence | same header |
| the two arrays are `DS:1F7` (x) and `DS:217` (y), 32 slots each | measured, live | two memory dumps + live peeks, `captures/spice86/linda-thief`, `linda-aggro` |
| their live domain is exactly `{-1, 0, +1}` | measured | same |
| they are non-zero **only** in role-3 slots | measured | same |
| `monx` ships **zeros** there (`monx[192]`, `monx[224]` under `monx[0] → DS:137`) | measured | same |
| role-3 creatures move, and change direction during play | observed | `captures/spice86/linda-thief/readings.md` |
| no shipped sector has role > 3 | measured | census of all 33 `monx` files, in the asm header |

## 3. The model to implement

Per role-3 creature, per sweep:

```
if (reroll_branch) {                       /* 25% of turns */
    wx[slot] = sign_of_al(rand_byte());
    wy[slot] = sign_of_al(rand_byte());
}
cx = (mon_x[slot] + wx[slot]) & 0x3F;      /* the torus mask the engine already uses */
cy = (mon_y[slot] + wy[slot]) & 0x3F;
if (step_gate_accepts(slot, cx, cy)) {     /* the SAME asm/2199 gate the pursuit paths use */
    mon_x[slot] = cx;  mon_y[slot] = cy;
    /* re-stamp the grid cell, per the per-move stamp rule in ai.c */
}
```

Initial state: `wx = wy = 0` for every slot, matching the shipped zeros. A creature with a zero vector
does not move until the first re-roll — that is faithful, not a gap.

**One candidate, no fallback.** The pursuit path (`creature_step`) tries diagonal, then y-only, then
x-only. The wander stages exactly one cell and does not fall back. Do not reuse the three-candidate
helper for role 3.

## 4. The trap most likely to ruin this — read before writing code

`asm/50D8_sign_of_al` is **not** a uniform draw over `{-1, 0, +1}`. Its four bytes are:

```
cmp $0x0,%al ; je  -> 0
jns              -> +1        (0x01..0x7F)
fall-through     -> -1        (0x80..0xFF)
```

So over a uniform random byte: **`+1` 127/256, `-1` 128/256, `0` only 1/256.**

A wander vector is therefore **almost always a diagonal step**. Writing `rand() % 3 - 1` would give
`0` a third of the time, produce visibly different movement — lots of straight-line and no-move
turns — and pass any test that only checks "did it move eventually". Reproduce `sign_of_al` exactly.
The engine has no equivalent today: `ai.c:80`'s `step_toward` is the pursuit analogue and takes two
coordinates, so it cannot stand in for it. See § 5.4.

## 5. Where the code goes

1. **`engine/src/core/state.h`** — line 313 currently reads:

   ```c
   /* 0x1F7 */ uint8_t reserved_1F7[0x42];  /* 0x1F7..0x238 */
   ```

   That single block covers both arrays. Split it into `mon_wander_x[32]` at `0x1F7`,
   `mon_wander_y[32]` at `0x217`, and a 2-byte `reserved_237` for `0x237..0x238`. Line 442 already has
   the assert to update:

   ```c
   _Static_assert(U2_OFF(mon_role) + 32 == 0x1F7, "mon_role must end where reserved_1F7 starts");
   ```

   Add matching asserts that each wander array is 32 bytes and that `x + 32 == y`, in the same style
   as the other creature arrays. They are **outside the 256-byte save block** (`DS:36..0x135`), so they
   must not be persisted — say so in a comment, because "why isn't this saved" is the obvious next
   question.
2. **`engine/src/game/monsters.c`** — initialise both to zero on load. Do **not** load them from
   `monx`; the file's bytes there are padding-shaped zeros, and the original writes them at runtime.
   `monsters.c` already has the `MON_OFF_*` table and a load path that mirrors each array; add these
   two as zero-fills rather than `memcpy`s so the distinction is visible at the call site.
3. **`engine/src/game/ai.c`** — the role gate. `moves` becomes `role >= 1 && !(role & 0x80)`, which
   also fixes the latent `> 3` vs `>= 3` divergence. Add the wander branch as its own function; do not
   bolt it onto `creature_step`.
4. **Add a `sign_of_al` helper.** The engine does **not** have one. `ai.c:80` has `step_toward`, which
   is the *pursuit* analogue — it takes two coordinates and does a torus-aware comparison, so it is
   not a drop-in for `sign_of_al(rand_byte())`. Write the one-to-one port of `asm/50D8`: zero → 0,
   `!(al & 0x80)` → +1, else -1. Putting this in one place is what makes test 2 in § 7 meaningful.
5. **`asm/1086_creature_wander_step.asm`** — if the build learns anything new, the same commit updates
   this header. That is an AGENTS.md § 3 obligation, not a nicety.

## 6. Known unknowns — how to handle each, do not block on them

| unknown | decision |
| --- | --- |
| where the **y** candidate is staged (fragments after `asm/10CE`, not read to the end) | Mirror the x staging. It is the only shape consistent with `DS:24` being the pair `asm/2199` reads. Grade it `inferred` in the source comment. |
| what the three range guards at `asm/10CE` (`cmp $0x4`, `cmp $0x3c`, `cmp $0`) guard | **Do not implement them.** They exit to next-slot, and `asm/2199` already has its own edge guard on `DS:4A`. Implement without them, note the omission in-source with the addresses, and only revisit if a test shows a creature crossing an edge it should not. |
| identity of the index byte `DS:25` (`reserved_25`) | Use the slot index. Every fragment in the chain indexes with it. Note it as inference. |
| does a role-3 creature still take the **contact** branch (swing / steal) when adjacent | Untouched by this change — the contact test runs before the move gate today. Re-measure after, see § 8. |

## 7. Tests, and the controls that make them real

Project rule: **a gate that cannot go red is worse than a tool that lies.** Every assertion below needs
its control run and reported.

Add to `engine/tests/ai_check.c`:

1. **A role-3 creature moves.** Seed one role-3 creature with a non-zero vector, run N sweeps, assert
   its position changed. *Control:* set the vector to zero and assert it does **not** move — this is
   the exact current bug, so the control is also the regression that proves the old behaviour.
2. **The distribution is `sign_of_al`, not uniform.** Feed the known RNG state, collect a few hundred
   vectors, assert `0` is rare (~1/256) and `±1` are near-even. *Control:* swap in `rand()%3-1` and
   confirm the test goes red. This is the test that catches § 4.
3. **The 25% re-roll rate.** Assert the vector is unchanged across a run of turns where the roll is
   `>= 0x40`, and changes when it is `< 0x40`. *Control:* re-roll every turn and confirm red.
4. **One candidate, no fallback.** Put a blocked tile at the staged cell and assert the creature stays
   put — it must not try an orthogonal alternative. *Control:* route it through the three-candidate
   helper and confirm red.
5. **The step gate is the same one.** A role-3 creature must be refused by a tile that refuses a
   role-1 creature.
6. **Vectors are not persisted.** Save and reload a game state; assert they come back zero.

Then: `make -C engine test`, `bash tools/check_all.sh`, and `bash tools/assemble_clean.sh` must still
print `37344 bytes identical` (no `asm/` body should change — if it does, something went wrong).

## 8. Close the loop with the original bug report

After the code lands, **re-run the `linda-thief` scenario** (recipe is in
`captures/spice86/linda-thief/readings.md`) against the engine, not the original:

* Does the thief still sit in contact every turn? It should now drift, like the original's.
* Does the steal still fire every pass? If it stops firing, the freeze was the cause and the steal
  code may be fine as-is. If it still fires, G37's open question — what actually gates the steal —
  gets sharper.

Record the result in `docs/phase4-state.md` and, if it changes the steal picture, in
`docs/needs-gameplay.md`. Do not silently "fix" the steal in the same commit; that is a separate
unknown with its own item (G38).

## 9. Also still open, adjacent but not this

* **G38** — the aggro precondition for the thief. Needs the poll-and-aim driver described in
  `captures/spice86/linda-aggro/readings.md`. Note that plan says **never `--poke` positions**: the
  poke moves the creature arrays and not the grid stamp at `DS:1800`, which is what movement and the
  aim ray read.
* Whether the engine should ever write `mon_role` for wandering spawns (currently it does not, and on
  the world map `mon_role` is not consulted at all — correct per `asm/0A6D`).

## 10. Commit shape

Two commits, in this order:

1. `engine:` the implementation + `state.h`/`monsters.c` naming + the `ai_check` tests and their
   controls. Run the full suite.
2. `docs:` `phase4-state.md` status, the `asm/1086` header update if anything new was learned, and the
   § 8 re-measurement result.

Do not mix the provenance-number refresh into either; if new harvests are made, `--write-provenance`
gets its own commit, as it did in `bb89293`.
