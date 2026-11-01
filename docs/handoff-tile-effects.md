# Handoff — tile effects: implement swamp damage, and the tile-effect table

**Status: not started.** Written 2026-11-02 from a live owner playtest plus a static
read of the walk span. Everything below is graded; `observed` means a byte or a live
memory value, `measured` means derived by a named tool, `owner` means Paul played it.

> **Read this first, because it cost a whole session:** there are **two** numbers per
> tile and they are constantly confused. A **map byte** is the raw byte in `mapxNN`.
> A **mode** is `map_byte >> 1`. The passability ladder and every tile effect test the
> **mode**. `asm/5B71_mode_table_copy.asm` already recorded the resolution in its own
> header: `0x5C >> 1 == 0x2e` "explains the mode without it". When you write or read a
> rule, say which one you mean.

## 0. What is being asked for

1. Implement the **swamp** damage rule in the engine (below, fully specified).
2. Record the **tile-effect table** so it stops being re-derived.
3. Fix the naming ambiguity in `engine/src/game/overworld.c` that made a previous
   session believe the engine called the damaging tile "grass". It does not — it
   calls a *different* tile grass, and never names the damaging one.

## 1. The mechanism, end to end

All of it is in the `asm/2423` passability span, which the bulk wave cut into
fragments (`2423`, `242D`, `2434`, `243B`, `243E`, `2453`, `245A`, `2474`, `2488`,
`248B`, `2495`, `24B1`, `24B5`). Read the span, not a fragment.

```
asm/2423  L_002623  mov [DS:29],al          ; save the mode the walk arm passed in
                  mov al,[DS:4A]
                  cmp al,0x00
                  je  L_00268b              ; on the world map -> straight to the effects
asm/248B  L_00268b  mov al,[DS:29]
                  and al,0x7F
                  cmp al,0x02               ; mode 2 == map byte 0x04
                  jne L_0026b1              ; not swamp -> next effect
asm/2495  L_002695  stc / mov al,[DS:52] / cmc / sbb al,0x05 / das / cmc
                      mov [DS:52],al        ; HP low BCD byte
                  mov al,[DS:51] / cmc / sbb al,0x00 / das / cmc
                      mov [DS:51],al        ; HP high BCD byte
                  jb  L_0026b1              ; underflow -> death tail
                  jmp L_000e62              ; else the redraw/continue tail
asm/24B1  L_0026b1  cmp al,0x2E             ; mode 0x2E == map byte 0x5C
                  jne L_002720              ; not the force field -> done
asm/24B5          mov al,[DS:D6]            ; ring counter
                  cmp al,0x00
                  je  L_0026E0              ; no ring -> full damage
                  str_out "RING PROTECTS FROM FIELD!"
          L_0026E0  str_out "FIELD CAUSES 1000 DAMAGE!"
                  ... sbb al,0x10 on [DS:51] ; 0x10 in the HIGH byte == 1000
```

The mode arrives from the walk arm: `asm/5B71` copies `DS:2CB -> DS:15` and
`DS:2DE -> DS:18`, and the four walk arms pass `DS:15` or `DS:18` as AL. `DS:2CB`
and `DS:2DE` have **no direct writers** — see the open question in § 5.

## 2. The tile-effect table

Counts are `measured`: every `mapxNN` byte across all 33 sector files, first 4096
bytes each. Passability is the engine's existing `foot_ladder`, which is correct.
The two damage rows are what is missing.

| map byte | mode | tiles | on foot | effect on **entry** | message |
|---|---|---|---|---|---|
| `0x00` | `0x00` | 36283 | **reject** | open sea | `--INVALID MOVE!` |
| `0x04` | `0x02` | 1571 | accept | **−5 HP** | **none** |
| `0x08` | `0x04` | 37541 | accept | none — this is **grass** | — |
| `0x0C` | `0x06` | 14181 | accept | none | — |
| `0x10` | `0x08` | 4971 | **reject** | mountain | `--INVALID MOVE!` |
| `0x44` | `0x22` | 12 | accept | horse tile | — |
| `0x48` | `0x24` | 14 | accept | ship tile | — |
| `0x4C` | `0x26` | 17 | accept | plane tile | — |
| `0x50` | `0x28` | 4 | accept | rocket tile | — |
| `0x5C` | `0x2E` | 76 | accept | **−1000 HP**, unless `[DS:D6]` ring protects | `FIELD CAUSES 1000 DAMAGE!` / `RING PROTECTS FROM FIELD!` |
| `0x70` | `0x38` | 12691 | accept | town paving | — |
| any with mode `>= 0x16` | — | — | **reject** | the threshold rule: sign letters, building walls, closed door | `--INVALID MOVE!` |

**There are exactly two HP-costing tiles in the whole walk span.** That is a
`measured` claim: a scan of every `asm/` file whose runtime span falls in
`0x2423..0x2700` for `cmp $imm,%al` and `sbb/sub $imm,%al` returned only mode `0x02`
(−5) and mode `0x2E` (−1000). It agrees with the owner's memory: force field and
swamp, nothing else.

## 3. The rule to implement

> On the world map (`[DS:4A] == 0`), a step **onto** a tile whose **map byte is
> `0x04`** costs **5 HP**, packed decimal, borrow propagated into the high byte.
> Underflow is death, via the existing tail. **No message.**

Evidence for each clause:

- **onto, not standing** — `owner`, three-way control: PASS while standing on swamp
  costs nothing; safe -> swamp costs 5; swamp -> safe costs nothing.
- **exactly 5** — `observed`: HP read live at `DS:51/52` across nine consecutive
  steps went 0370, 0365, 0360, 0355, 0350, 0345, 0340, 0335, 0330. Every delta −5.
  Reproduced earlier at 0400 -> 0385 over three steps.
- **packed decimal** — `observed`: the bytes are BCD pairs, and the asm uses the
  house `stc; cmc; sbb; das; cmc` idiom.
- **silent** — `observed`: the message log during the walk showed only `PASS`. The
  original prints nothing. Per AGENTS § 3 the engine stays silent **and says so in a
  comment at the mutation site**, citing `asm/2495`.
- **world map only** — `observed`: the branch into the effects is gated on
  `[DS:4A] == 0`.

Engine pieces that already exist and should be reused, not reinvented:

- `bcd_sbb()` in `overworld.c` — the same helper `food_spend()` uses, and
  `food_spend` is the precedent for a deliberately silent BCD drain with a citation.
- `u2_death(ctx)` — the existing underflow target.
- `foot_ladder()` already computes `(tile >> 1) & 0x7F`; the damage belongs beside
  it, not inside it, because `foot_ladder` returns a verdict and a cost is not a
  verdict.

## 4. Vehicle arms — yes, there are separate tables

`observed`, from the arm bodies. The engine models these in `u2_mode_passable()` and
that part is **already correct**; none of them carries a damage rule.

| mode | arm | rule |
|---|---|---|
| rocket | `asm/2542` | `jmp` to unconditional reject — a rocket never walks |
| ship | `asm/2619` | `cmp [DS:29],0x00` — **water only**. The `cmp $0x80` in that routine can never match, since the largest possible mode is `0xFC >> 1 = 0x7E` |
| plane | `asm/2604` | loops, refusing mode `0x06` (map `0x0C`) |
| horse | `asm/2557` | its own arm; **G40 records that a horse refuses the swamp tile** |

**Unresolved and worth checking while implementing:** G40 says the horse *refuses*
shallow water. If "shallow water" in G40 is this same map byte `0x04`, then foot
enters-and-pays and horse refuses, and the two rules must be written to agree. Read
`asm/2557` and the G40 entry in `docs/phase4-state.md` before finalising, or the
engine may end up with a horse that wades.

## 5. Open questions, named rather than guessed

1. **`DS:2CB` / `DS:2DE` / `DS:2E0` / `DS:2F3` have no direct writers** anywhere in
   the exe — `asm/5B71_mode_table_copy.asm` says so itself and points at
   `docs/passability-findings.md` F3. They are filled by an indirect store. The
   Apple II crosswalk closed the watchpoint ticket as a DOS-port artefact, so this
   may be unresolvable and may not matter — but it means the *provenance* of the mode
   byte is inferred, even though the mode's *value* is confirmed by live reads.
2. **Is map byte `0x04` "swamp"?** `owner` says it looks like swamp, and 1571 tiles
   scattered in patches fits. The art index may name it. Do not promote a guessed
   name into an `asm/` filename without a second witness.
3. **Does the force field damage exist in the engine at all?** Not checked. If
   `asm/24B5` is unimplemented, this handover is hiding a second missing effect, and
   it is the more dramatic one — 1000 HP is instant death for any character.

## 6. Suggested order of work

1. Check whether the force field effect is implemented. If not, do it in the same
   change — they are one table and one code path.
2. Read `asm/2557` and G40, settle the horse interaction.
3. Implement the swamp cost beside `foot_ladder`, silent, with the citation.
4. Gate it with **all three** owner controls, not just the happy path:
   PASS on swamp costs nothing; safe -> swamp costs 5; swamp -> safe costs nothing.
   A naive implementation passes only the middle one, which is exactly the one that
   would fool a reviewer.
5. Rename `asm/2495_sub_2495.asm` -> `asm/2495_swamp_damage.asm` and
   `asm/248B_sub_248b.asm` -> `asm/248B_swamp_damage_gate.asm`, writing headers that
   cite this document and the live HP readings. Per AGENTS § 3 the rename and the
   header go in the same commit as the finding.
6. Fix the `overworld.c` comment so it never again reads as if a map byte were a
   mode.

## 7. Method notes, so the next session does not repeat the cost

- **`MEMORY_WRITE` breakpoints in this Spice86 build report a plausible but wrong
  IP.** Two attempts pointed at runtime `0x24b1`, which the byte-proven tree shows is
  inside `mov dx,[DS:472]` — a read. The static grep that found the truth in one
  shot was: search `asm/` for `sbb $0x5,%al` followed by `mov %al,0x52`.
- **The file byte offset in `ultimaii.exe` equals the runtime address; the `asm/`
  filename is runtime minus `0x200`.** Docs in this repo use "file" loosely for
  both, and that cost several wrong claims in one session.
- **The answer was already in the tree.** `asm/5B71`'s header contained
  `0x5C >> 1 == 0x2e`, and `docs/passability-findings.md` F14 already stated the
  gate variable is `map_byte >> 1`. Two live breakpoint attempts were spent
  rediscovering what a header already said. Look before measuring.
