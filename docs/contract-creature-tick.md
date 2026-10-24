# Contract 2 — creature movement tick (the 32-slot sweep)

Same format as `docs/contract-overworld-walk.md`. Grades per claim: **observed** = a byte in
`asm/`, **measured** = derived by a named tool, **inferred** = reasoned from a partial read.

This system is split across many one-instruction `asm/` fragments because of the CP3
label-preservation rule, and most of those fragments carry `confidence: low` and "behavior not
yet reviewed" in their own headers. That is respected below: the contract states the parts that
are established and names the parts that are not, rather than smoothing the seam over.

## System: creature movement tick

* **Primary entry address:** runtime `0x0A6D` = file `0x0C6D` (function head,
  `asm/0A6D_monster_sweep_head.asm`)
* **Identifying instruction:** `mov $0x1f,%bl` immediately followed by `mov %bx,%di`. That
  immediate 31 is the sweep width and it has caught people before — it is **not** a read of
  `DS:1F`. See `docs/monster-spawn.md` § 11.
* **Span:** the sweep is `0x0A6D..0x0AA6`; the per-slot step lives at `0x2122..0x2259`; the
  pursuit vector is at `0x4F36` and `0x152E`.

### When it runs

Every completed command runs the sweep exactly once. The sweep is entered only from
`asm/0A38_post_command_tail` and `asm/0A5F_sub_0a5f` (observed: those are the only two
callers named in `asm/`). So creature motion is turn-based on player commands, not on a timer.

### Memory state touched

| address | role | grade |
| --- | --- | --- |
| `DS:137+x` | creature **x** for slot `x` | observed |
| `DS:157+x` | creature **y** for slot `x` | observed |
| `DS:177+x` | creature **HP** for slot `x` | observed |
| `DS:197+x` | creature **type/kind** for slot `x` | observed |
| `DS:1B7+x` | per-slot mirror table, read and written around the commit | observed, meaning unknown |
| `DS:19`, `DS:1A` | the movement delta, signed, one byte per axis | observed |
| `DS:23`, `DS:24` | candidate new position, staging | observed |
| `DS:27`, `DS:28` | second staging pair; `DS:27` also carries the slot index into the melee path | observed |
| `DS:1F` | result of the `0x50B3` test, and separately a slot index in `asm/0CC0` | observed, dual use unresolved |
| `DS:20` | contact counter, `incb` on a creature landing on the player | observed |
| `DS:00`, `DS:01` | player position, read only | observed |
| `DS:4A` | world/interior context byte, gates several branches | see `docs/phase4-state.md` |
| `DS:6` | word pointer to a table indexed by slot | observed, contents not decoded |

### Algorithm breakdown

**1. The sweep** (`0x0A6D`, observed, high confidence for the shape)

`DI = 31`, then `dec %di ; jne` walks down to 1. **Slot 0 is never examined** — the same blind
spot as `asm/23E6_find_creature_at_cursor.asm`. For each slot: if `DS:197[di] == 0` the slot is
free and the sweep moves on. When `DI` reaches 0 the loop does not jump, it **falls through**
into `asm/0AA4_monster_spawn_entry`, which is `jmp 0x0E9C` — the only branch in the binary into
the wandering-spawn cluster. A caller search that follows only `call` sites concludes that
cluster is dead code. It is not; it is reached by fall-through once per sweep.

**2. The pursuit vector.** Two variants exist and they are not interchangeable:

* `asm/4F36` (observed, high confidence): `DS:19 = DS:00 - DS:137[di]`,
  `DS:1A = DS:01 - DS:157[di]`. Plain `sub`, **no wrap adjust**, so the delta is signed and can
  be a large negative.
* `asm/152E` (observed): the same difference but routed through `asm/50D8`, which applies a
  torus wrap.

**3. Wounded creatures retreat** (`0x0B07`/`0x0B0F`, observed):

```
if (DS:177[di] >= 0x0F)  pursue        ; jae skips the negate
else                     DS:19 = -DS:19; DS:1A = -DS:1A   ; retreat
```

The negate is the `stc; mov al,0; cmc; sbb [0x19],al` idiom — `stc` then `cmc` is a
CF-clearing pair, not arithmetic, and `al = 0 - DS:19`.

**4. Low HP regenerates** (`asm/2122`/`asm/212A`, observed): on the non-contact path, if
`DS:177[di] < 0x10` then `incb DS:177[di]`. One HP per tick, below 16 only. Note the threshold
here is `0x10` while the flee threshold above is `0x0F`; they are different constants and that
is not a transcription error.

**5. The step** (`asm/212E`, observed):

```
DS:23 = (DS:137[di] + DS:19) & 0x3F
DS:24 = (DS:157[di] + DS:1A) & 0x3F
call 0x50B3            ; result -> DS:1F ; what it tests is NOT established
```

The `& 0x3F` is the toroidal wrap of the 64x64 sector grid, and it is applied here, on the
creature side, independently of the identical mask the player path applies inside `0x2423`.

**6. Contact test** (`asm/2201`/`asm/220A`, observed): if the candidate cell equals the player
cell on **both** axes, the creature attacks instead of moving. Otherwise the no-contact path at
`asm/2216` stages the candidate into `DS:27`/`DS:28`, re-stages the current position into
`DS:23`/`DS:24`, and calls `0x50B3` again.

**7. The commit** (`asm/2233`, observed): `DS:137[di] = DS:27` and `DS:157[di] = DS:28`. The
write goes through the staging pair, never directly from the arithmetic.

**8. On contact** (`0x0B4D`, observed): `incb DS:20`, `DS:27 = di`, then a type dispatch —
`DS:197[di] == 0xFC` falls through to the thief steal attempt at `asm/0B5F`, anything else
jumps to the melee hit roll at `asm/0B62`. The melee roll is `rand & 7` compared against
`DS:62`, i.e. a 1-in-8 chance scaled by `DS:62`.

### C behavioral contract

```c
/* Only the parts marked observed below are a specification. The body of the
 * per-slot gate at step 0 and the meaning of the 0x50B3 test are NOT established,
 * so this function is deliberately not executable ground truth end to end. */

#define CREATURE_X(s)   DS[0x137 + (s)]
#define CREATURE_Y(s)   DS[0x157 + (s)]
#define CREATURE_HP(s)  DS[0x177 + (s)]
#define CREATURE_KIND(s) DS[0x197 + (s)]

#define FLEE_HP_THRESHOLD   0x0F   /* below this, the creature retreats   */
#define REGEN_HP_THRESHOLD  0x10   /* below this, it regains 1 HP per tick */
#define KIND_THIEF          0xFC   /* contact with this kind steals instead */
#define GRID_WRAP_MASK      0x3F   /* 64x64 toroidal sector grid          */

/* Not established: what this tests. It is called with the candidate cell in
 * DS:23/DS:24 and its result lands in DS:1F. Do not model a verdict here. */
extern uint8_t test_50B3(void);

static void wander_spawn_attempt(void);   /* asm/0AA4 -> runtime 0x0C9C cluster */
static void on_contact(int slot);         /* asm/0B4D: steal roll + melee roll  */

void creature_sweep(void)                 /* runtime 0x0A6D */
{
    for (int di = 31; di >= 1; di--) {    /* slot 0 is never examined */
        if (CREATURE_KIND(di) == 0) continue;

        /* --- unproven gate: DS:13 == 0x22, the sign of DS:26, and the
         * --- 0x48 / 0x3C / 0x2C kind compares. See asm/0A7C and asm/0A83.
         */
        if (!slot_gate_unproven(di)) continue;

        /* Pursuit vector, no-wrap variant (asm/4F36). The torus-wrapped variant
         * is asm/152E and is used from a different caller. */
        int8_t dx = (int8_t)(DS[0x00] - CREATURE_X(di));
        int8_t dy = (int8_t)(DS[0x01] - CREATURE_Y(di));

        if (CREATURE_HP(di) < FLEE_HP_THRESHOLD) {   /* wounded: retreat */
            dx = (int8_t)-dx;
            dy = (int8_t)-dy;
        }

        if (CREATURE_HP(di) < REGEN_HP_THRESHOLD)    /* slow regen */
            CREATURE_HP(di)++;

        uint8_t nx = (uint8_t)((CREATURE_X(di) + dx) & GRID_WRAP_MASK);
        uint8_t ny = (uint8_t)((CREATURE_Y(di) + dy) & GRID_WRAP_MASK);

        if (nx == DS[0x00] && ny == DS[0x01]) {      /* would land on player */
            on_contact(di);                          /* does NOT move it     */
            continue;
        }

        DS[23] = nx; DS[24] = ny;  (void)test_50B3();

        DS[27] = nx; DS[28] = ny;                    /* commit via staging   */
        CREATURE_X(di) = nx;
        CREATURE_Y(di) = ny;
    }

    wander_spawn_attempt();   /* reached by fall-through, not by call */
}
```

### What this contract deliberately does not claim

* **`test_50B3` is a black box.** It is called three times in this path with different staging
  in `DS:23`/`DS:24`, and its result goes to `DS:1F`. Nothing here establishes what it
  evaluates. Any engine test that asserts a creature moved or failed to move is asserting an
  unknown until this is decoded.
* **The per-slot gate is unread.** `asm/0A7C` and `asm/0A83` test `DS:13 == 0x22`, the sign of
  `DS:26`, and compare the kind against `0x48`, `0x3C`, `0x2C`. The owning header says
  explicitly: "NOT ESTABLISHED: what the DS:13 / DS:26 tests and the 0x48/0x3C/0x2C kind
  compares mean." The contract keeps that as a named hole, `slot_gate_unproven`.
* **`DS:1F` looks like it has two lives.** It is written as the `0x50B3` result in `asm/2199`
  and read as a slot index in `asm/0CC0`. Unresolved, and `asm/0CC0` warns that a
  `MEMORY_WRITE` breakpoint on a fixed `DS:137+n` will miss writes whenever `DS:1F` holds a
  different `n`.
* **`asm/0CC0` is placement, not movement.** Its own header is explicit: "This is a PLACEMENT
  store, not movement: nothing here computes a new coordinate." Do not fold it into this tick.
* **Dungeons are out of scope.** `asm/1151` and `asm/147F` also write `DS:137[di]` and belong
  to the dungeon encoding, which `AGENTS.md` parks.

## Apple II cross-reference

Not attempted for this system, and there is a specific reason worth recording: the sweep is
driven by the player's command loop, and contract 1 already established that the Apple build
has no counterpart to the DOS command-echo layer. The creature tables on the Apple side are
`monx`-shaped data (`M/ON.NN`, confirmed byte-identical to `monxNN` in
`docs/apple2-reference.md` § 7), so the **data layout** is cross-checkable even where the
**code path** is not. That is the useful direction for this system: compare the slot tables,
not the AI.

## Verification

```bash
python3 tools/check_func.py 0A6D
python3 tools/check_func.py 4F36
grep -rn "0x137(%di)" asm/*.asm | grep "mov    %al"      # the position writers
grep -rn "and    \$0x3f" asm/212E_sub_212e.asm asm/0B25_sub_0b25.asm
```

The two thresholds `0x0F` (flee) and `0x10` (regen) are the details most likely to be
"corrected" into one value. They are two different constants in two different fragments and
both are observed.
