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
| `DS:1B7+x` | the **terrain byte currently under creature x** — the save-and-restore slot for the grid stamp. Written at spawn by `asm/0CEE_spawn_tile_store`, read back and written into the old cell on every move by `asm/2233`, re-saved from the new cell by `asm/225A` | observed (three sites agree), role inferred |
| `DS:19`, `DS:1A` | the movement delta, signed, one byte per axis. **Two different values occupy it in one slot**: the raw delta from `asm/4F36`, then the clamped -1/0/+1 step from `asm/4F11` | observed |
| `DS:13` | the player's riding/stamp byte. `0x22` = on a horse (`asm/2FD6_vehicle_horse`), `0x78` = on foot. Gates the sweep at `asm/0A7C` | observed |
| `DS:26` | sign-tested by the sweep gate at `asm/0A83`. Meaning here NOT established — it is the torch counter inside a tower and was measured flipping `00`/`FF` on overworld movement | see `asm/0A83` |
| `DS:23`, `DS:24` | candidate new position, staging | observed |
| `DS:27`, `DS:28` | second staging pair; `DS:27` also carries the slot index into the melee path | observed |
| `DS:1F` | **shared scratch with 20+ writers, not a dedicated variable.** In this system `asm/2199` stores the candidate tile byte here and the step gate reads it back. In the placement cluster `asm/0CC0`/`asm/0CDC` use the same byte as a slot index, and `asm/2677`/`asm/269F` use it to carry the player stamp (`DS:13`) across a call. The live reading of 120 that ruled out "slot cursor" is the on-foot stamp `0x78` | observed, contradiction resolved — see § "The `DS:1F` contradiction" |
| `DS:26A` | the fourth of the four status counters ticked by `asm/0C33..0C53`. **While non-zero the step gate refuses every move, for every species and every tile.** Only non-zero writer: `asm/3C04_coin_rub`, which sets `0x14` | observed |
| `DS:20` | contact counter, `incb` on a creature landing on the player — **but it is not readable as state between turns**: it read 0 after every turn while contacts were demonstrably happening (HP was falling). `asm/2362` zeroes `DS:1F/20/19/1A` | observed, meaning partial |
| `DS:00`, `DS:01` | player position, read only | observed |
| `DS:4A` | world/interior context byte, gates several branches | see `docs/phase4-state.md` |
| `DS:6` | the **resolved tile address**, written by `map_tile_ptr` (`asm/50B3`) and read back by `asm/2233` and `asm/225A` | observed |

### Algorithm breakdown

**1. The sweep** (`0x0A6D`, observed, high confidence for the shape)

`DI = 31`, then `dec %di ; jne` walks down to 1. **Slot 0 is never examined** — the same blind
spot as `asm/23E6_find_creature_at_cursor.asm`. For each slot: if `DS:197[di] == 0` the slot is
free and the sweep moves on. When `DI` reaches 0 the loop does not jump, it **falls through**
into `asm/0AA4_monster_spawn_entry`, which is `jmp 0x0E9C` — the only branch in the binary into
the wandering-spawn cluster. A caller search that follows only `call` sites concludes that
cluster is dead code. It is not; it is reached by fall-through once per sweep.

**1b. The per-slot gate** (`asm/0A7C`/`asm/0A83`, observed — this was the `slot_gate_unproven`
hole, and it is now a rule)

```
if DS:13 != 0x22                              -> the creature takes its turn
else if DS:26 >= 0                            -> the creature takes its turn
else if mon_type[di] in {0x48, 0x3C, 0x2C}    -> the creature takes its turn
else                                          -> skip this slot for this sweep
```

`DS:13 == 0x22` is the horse riding state: `asm/2FD6_vehicle_horse` stores `0x22` into `DS:13`,
and `[DS:13]` was measured live as `0x22` on a horse and `0x26` in the plane
(`asm/2FAD_vehicle_board_dispatch`). So the gate reads: **while the player is mounted and
`DS:26` has its sign bit set, land creatures do not move at all** — and the three exemptions are
the frigate, the balron and the sea creature, i.e. the same three species the step gate singles
out. What `DS:26`'s sign means here is **not** established; see `asm/0A83`.

**2. The pursuit vector.** Three routines write `DS:19`/`DS:1A` and they are not
interchangeable. `asm/4F36` runs first, `asm/4F11` overwrites it before the step.

* `asm/4F36` (observed): `DS:19 = DS:00 - DS:137[di]`, and the same for the y pair. The `stc`
  in front of it does nothing — x86 `SUB` does not subtract CF, only `SBB` does — so this is
  the plain difference. Unclamped, so it can be a large negative. It feeds the **magnitude**
  tests only: `asm/0AAA` compares `|DS:19|` against 3 and `asm/1040` against 4.
* `asm/4F11` (observed, and **measured at runtime**), called from `asm/0AFC`, which every path
  through the special-attack dispatch passes through:
  `DS:19 = sign(4 * (DS:00 - DS:137[di]))`, same for y. The `add al,al` twice is what makes
  this the **torus-shortest** direction: `4*d` overflows the signed byte at `|d| >= 32`, which
  is exactly half the 64-cell grid, so a creature more than half the map away is sent the short
  way round instead of the long way. Checked over all 4096 `(player_x, mon_x)` pairs: **0
  mismatches** against the true shortest torus direction, once the 64 exact-antipode cells are
  set aside. **This is the value `asm/212E` steps with.** `asm/50D8` is a sign function
  (`-1/0/+1`), not a wrap — the wrap behaviour is the `add` pair in its caller.
* `asm/152E` (observed): `sign(player - creature)`, written with `stc ; cmc ; sbb` where the CF
  pair genuinely matters because `SBB` reads it. Reached only from `asm/1151_dungeon_darkness`,
  i.e. the dungeon side of the split, which `AGENTS.md` § 3 parks. It is not part of this tick.

> **A retraction belongs here.** This contract previously stated the delta was
> `player - creature - 1`, on the grounds that `stc` set CF and `sub` subtracted it, and
> derived from it that a creature approaching from above or left parks one cell short. **That is
> false, and it was false because the flag semantic was recalled instead of looked up:** `SUB`
> ignores CF on x86. The live measurement in `captures/spice86/g28-pursuit` read `DS:19/DS:1A`
> after each sweep in 20 trials with a valid control in every one, and the vector is the plain
> symmetric difference — a creature at `(player-1, player-1)` steps straight onto the player.
> The `stc` is a translated 6502 `SEC ; SBC`, where the `SEC` was required on the 6502 and is
> merely dead here.

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

**5. The step, and the three cells it tries** (`asm/212E..asm/218B`, observed)

```
DS:23 = (DS:137[di] + DS:19) & 0x3F          ; DS:19/1A are the clamped -1/0/+1 from asm/4F11
DS:24 = (DS:157[di] + DS:1A) & 0x3F
call map_tile_ptr        ; asm/50B3 -> AL = tile at (DS:23,DS:24), ZF if zero, DS:6 = address
call creature_step_gate  ; asm/2199 -> AL = 0 accept, 0xFF refuse (ZF is what is tested)
```

`map_tile_ptr` is a **fetch, not a test**. Its body is `y*64 + x + word[DS:472]`, and
`word[DS:472]` is `0x1800` in every live capture, so it returns the byte of the 64-wide sector
grid at the staged cell. It has 25 caller files and is byte-proven. What decides whether the
creature moves is the caller's classification of the returned tile, `asm/2199..asm/2200`,
decoded in full below.

If the **diagonal** cell is refused the routine does not give up; it retries on one axis at a
time, in this order:

| order | cell | code | guard |
| --- | --- | --- | --- |
| 1 | `(mon_x + dx, mon_y + dy)` — diagonal | `asm/212E` → `asm/214D` | — |
| 2 | `(mon_x, mon_y + dy)` — vertical only | `asm/215C` → `asm/2166` | skipped when `DS:1A == 0` (`asm/2155`) |
| 3 | `(mon_x + dx, mon_y)` — horizontal only | `asm/216E` → `asm/2186` | — |
| — | all three refused | `asm/218B` | no move this sweep |

That is the mechanism behind the per-species geometry measured live in
`captures/spice86/cp5-g28-approach/` (Orc 190/190 diagonal, Fighter 164/164 diagonal,
Merchant 123/124 axis). Note what that means: the split is **terrain-driven**, not a per-species
movement rule. The only species-dependent clause in the whole gate is the `0x5C` test.

The `& 0x3F` is the toroidal wrap of the 64x64 sector grid, and it is applied here, on the
creature side, independently of the identical mask the player path applies inside `0x2423`.

**5b. The step gate** (`asm/2199_creature_step_gate`, runtime `0x2199..0x2200`, observed)

Entry: `AL` is the tile `map_tile_ptr` just fetched, and the routine's first instruction stores
it to `DS:1F`. Two returns, each ending in `cmp $0x0,%al` so the callers can branch on ZF:
`asm/21F7` returns 0 (accept) and `asm/21FC` returns `0xFF` (refuse).

```
if DS:26A != 0                       -> refuse            (asm/21A3; every species, every tile)
if mon_type in {0x2C, 0x48}          -> accept iff tile == 0x00   (asm/21A6, 21AE, 21D8)
else:
    if mon_type < 0x78 and tile == 0x5C -> accept        (asm/21B2, 21B6)
    if tile in {0x10, 0x04, 0x00}       -> refuse        (asm/21BD, 21C5, 21C9)
    if tile <  0x14                     -> accept        (asm/21CD, jb)
    if tile == 0x70                     -> accept        (asm/21D1)
    otherwise                           -> refuse        (asm/21D5)
accept then passes a site guard: if DS:4A != 0, candidate x == 0 or candidate y == 0 is
refused (asm/21E2, 21E9, 21F0).
```

Read against the tile bytes that actually occur in a sector map — every one of them a multiple
of 4, `docs/passability-findings.md` F12, so 64 values — the accepted set is five bytes out of
sixty-four:

| tile | art | what it is | kind < 0x78 | kind >= 0x78 | kind 0x2C / 0x48 |
| --- | --- | --- | --- | --- | --- |
| `0x00` | `0x00` | water (proven impassable for the player, F11) | refuse | refuse | **accept** |
| `0x04` | `0x01` | sparse pixels | refuse | refuse | refuse |
| `0x08` | `0x02` | grass (proven passable for the player, F11) | **accept** | **accept** | refuse |
| `0x0C` | `0x03` | forest (proven passable for the player, F11) | **accept** | **accept** | refuse |
| `0x10` | `0x04` | mountain (proven impassable for the player, F11) | refuse | refuse | refuse |
| `0x14`..`0x58`, `0x60`..`0x6C`, `0x74`..`0xFC` | — | everything else, 57 bytes: structures, letters, the `0x78` building blocks | refuse | refuse | refuse |
| `0x5C` | `0x17` | **the force field** — exactly −1000 HP with no ring, nothing with one (`captures/spice86/g29-field`); 72 cells in `mapx03`, 4 in `mapx71` | **accept** | refuse | refuse |
| `0x70` | `0x1C` | magenta vertical dashes; 12691 cells in the 4096-byte grids over 15 sectors (`engine/src/game/overworld.c` cites 12889, which is the same count including each file's 128-byte container tail — both are right for their own domain), and in the `*x1/*2/*3` sectors it forms the street and open-ground runs between the `0x78` blocks | **accept** | **accept** | refuse |

Grades: the ladder, the ordering and the verdict polarity are **observed** (the bytes are in
`asm/2199..asm/21FC`). The `art = type >> 2` reading of the species clauses and of the tile
names is **inferred** from `docs/art-index.md` and `disasm/tile-art.tsv`. The sector counts and
the spatial distribution of `0x70` and `0x5C` are **measured** over `original/mapx*` by a
throwaway pass in this session, and the reading of `0x70` as "town ground" is **inferred** from
that distribution.

Three things about this table are worth saying out loud:

* It **agrees with the player's proven passability on all four bytes that have been settled by
  walking** (`0x00` blocks, `0x08` and `0x0C` pass, `0x10` blocks) — and it is a completely
  different mechanism, since `docs/passability-findings.md` F1 and F10 established that the
  player's routine does not read a tile at all. Two independent gates, same four verdicts. And
  `0x70` is the fifth agreement from a different direction again: `engine/src/game/overworld.c`
  admits art `0x1C` for the player on an owner report from a town ("the terrain I'm not standing
  on (cobblestone) should be passable"), which the creature gate reaches from bytes alone.
* The `0x2C`/`0x48` arm is the first place in this tree where those two species are separated
  by **behaviour** rather than by art, and both move only on water. `0x2C >> 2` is the sea
  creature and `0x48 >> 2` is the frigate.
* The `DS:4A` site guard is what makes the wrapped edge a wall inside a settlement while the
  wilderness stays a torus, and it is the same byte `cmd_A` gates on.

**6. Contact, tested twice** (`asm/0B25`/`asm/0B39` before the gate, `asm/2201`/`asm/220A`
after it; observed). Both compare the candidate against `DS:00`/`DS:01` on **both** axes. The
second is not redundant: the axis-substituted candidates from `asm/215C` and `asm/216E` can
land on the player where the diagonal candidate did not. The first one leads to the attack
path; the second one leads to `asm/218B`, which is the no-move tail and the Minax proximity
check, not an attack (`docs/monster-spawn.md` § 13).

**7. The commit** (`asm/2233`/`asm/225A`, observed): the write goes through the staging pair,
never directly from the arithmetic. And it is a **stamp-and-restore pair**, which is what
`DS:1B7` is for: `asm/2233` writes `DS:1B7[di]` into the grid cell `DS:6` addresses (the
creature's old cell) to put the terrain back, commits `DS:27`/`DS:28` into `mon_x`/`mon_y`,
re-fetches the new cell, then `asm/225A` saves that new cell's terrain byte into `DS:1B7[di]`
and stamps `mon_type` into the cell. `asm/0CEE_spawn_tile_store` writes `DS:1B7` the same way
at spawn, and the spawn arms read it back with `cmp $0x8,%al` — three sites, one meaning.

**8. On contact** (`0x0B4D`, observed): `incb DS:20`, `DS:27 = di`, then a type dispatch —
`DS:197[di] == 0xFC` falls through to the thief steal attempt at `asm/0B5F`, anything else
jumps to the melee hit roll at `asm/0B62`. The melee roll is `rand & 7` compared against
`DS:62`, i.e. a 1-in-8 chance scaled by `DS:62`.

### C behavioral contract

```c
/* Everything below is transcribed from bytes and the parts marked measured were read
 * out of live memory, but this function is still NOT executable ground truth: the
 * DS:26 clause of the per-slot gate is unproven and the engine does not yet wire the
 * 0x5C force field. See § "What this contract deliberately does not claim". */

#define CREATURE_X(s)   DS[0x137 + (s)]
#define CREATURE_Y(s)   DS[0x157 + (s)]
#define CREATURE_HP(s)  DS[0x177 + (s)]
#define CREATURE_KIND(s) DS[0x197 + (s)]
#define CREATURE_SAVED_TILE(s) DS[0x1B7 + (s)]  /* terrain under it; restored on move */

#define FLEE_HP_THRESHOLD   0x0F   /* below this, the creature retreats   */
#define REGEN_HP_THRESHOLD  0x10   /* below this, it regains 1 HP per tick */
#define KIND_THIEF          0xFC   /* contact with this kind steals instead */
#define GRID_WRAP_MASK      0x3F   /* 64x64 toroidal sector grid          */
#define KIND_SEA_MONSTER    0x2C   /* water-only movers  */
#define KIND_FRIGATE        0x48   /* "                  */
#define KIND_BALRON         0x3C   /* sweep-gate exempt  */
#define RIDING_HORSE        0x22   /* DS:13 value set by asm/2FD6 */

/* asm/50B3 map_tile_ptr. Returns the sector-grid tile byte at the staged cell:
 * word[DS:472] + DS:24*64 + DS:23, with the resolved address left in DS:6 and ZF
 * set when the tile is 0. It decides nothing; the caller classifies the tile. */
extern uint8_t map_tile_ptr(void);

/* The grid write behind asm/2233's `mov %al,(%bx,%si)` and asm/225A's stamp,
 * where DS:6 is the address map_tile_ptr resolved for the staged cell. */
extern void write_grid(uint16_t addr, uint8_t byte);
extern void minax_proximity_check(int slot);  /* asm/1040, docs/monster-spawn.md § 13 */

static void wander_spawn_attempt(void);   /* asm/0AA4 -> runtime 0x0C9C cluster */
static void on_contact(int slot);         /* asm/0B4D: steal roll + melee roll  */

/* asm/2199_creature_step_gate. May this creature step onto (DS:23, DS:24)?
 * The tile is the value map_tile_ptr left in AL; the routine stores it to DS:1F and
 * reads it back. Returns 0 to accept and 0xFF to refuse; the callers branch on ZF,
 * which both returns set with an explicit cmp before the ret. */
static int creature_step_gate(uint8_t tile, uint8_t kind)
{
    if (DS[0x26A] != 0) return 0xFF;      /* asm/21A3: freeze, every species */

    int accept;
    if (kind == KIND_SEA_MONSTER || kind == KIND_FRIGATE) {
        accept = (tile == 0x00);          /* asm/21A6, 21AE -> 21D8 */
    } else if (kind < 0x78 && tile == 0x5C) {
        accept = 1;                       /* asm/21B2, 21B6 */
    } else {
        accept = (tile != 0x10 && tile != 0x04 && tile != 0x00)  /* asm/21BD, 21C5, 21C9 */
              && (tile < 0x14 || tile == 0x70);                  /* asm/21CD, 21D1, 21D5 */
    }
    if (!accept) return 0xFF;

    /* asm/21E2, 21E9, 21F0: inside a settlement the wrapped edge is a wall. */
    if (DS[0x4A] != 0 && (DS[0x23] == 0 || DS[0x24] == 0)) return 0xFF;
    return 0;
}

/* asm/4F11_monster_step_vector. The clamped step, per axis: the short way round a
 * 64-cell torus. Measured at runtime, not inferred — see the retraction in step 2. */
static int8_t step_axis(uint8_t player, uint8_t mon)
{
    int8_t d = (int8_t)(player - mon);       /* the stc before the sub is a no-op */
    int8_t s4 = (int8_t)(4 * d);             /* add al,al twice; overflows at |d| >= 32 */
    return s4 == 0 ? 0 : (s4 > 0 ? 1 : -1);  /* asm/50D8 sign_of_al */
}

void creature_sweep(void)                 /* runtime 0x0A6D */
{
    for (int di = 31; di >= 1; di--) {    /* slot 0 is never examined */
        if (CREATURE_KIND(di) == 0) continue;

        /* asm/0A7C, asm/0A83: mounted + DS:26 negative freezes land creatures. */
        if (DS[0x13] == RIDING_HORSE && (int8_t)DS[0x26] < 0) {
            uint8_t k = CREATURE_KIND(di);
            if (k != KIND_FRIGATE && k != KIND_BALRON && k != KIND_SEA_MONSTER)
                continue;
        }

        /* asm/0AAA tests |raw delta| < 3 for the special-attack gate, using the
         * unclamped asm/4F36 value. Then asm/0AFC overwrites DS:19/1A with the
         * clamped step below — the order matters and is easy to lose. */
        int8_t dx = step_axis(DS[0x00], CREATURE_X(di));
        int8_t dy = step_axis(DS[0x01], CREATURE_Y(di));

        if (CREATURE_HP(di) < FLEE_HP_THRESHOLD) {   /* wounded: retreat */
            dx = (int8_t)-dx;
            dy = (int8_t)-dy;
        }

        if (CREATURE_HP(di) < REGEN_HP_THRESHOLD)    /* slow regen */
            CREATURE_HP(di)++;

        uint8_t nx = (uint8_t)((CREATURE_X(di) + dx) & GRID_WRAP_MASK);
        uint8_t ny = (uint8_t)((CREATURE_Y(di) + dy) & GRID_WRAP_MASK);

        if (nx == DS[0x00] && ny == DS[0x01]) {      /* asm/0B25/0B39: would land on player */
            on_contact(di);                          /* does NOT move it     */
            continue;
        }

        /* asm/212E..asm/218B: three candidate cells, diagonal first, then vertical
         * only (skipped when dy == 0), then horizontal only. First one the gate
         * accepts wins; if none is accepted the creature does not move. */
        int moved = 0;
        for (int c = 0; c < 3 && !moved; c++) {
            DS[23] = (c == 1) ? CREATURE_X(di) : nx;
            DS[24] = (c == 2) ? CREATURE_Y(di) : ny;
            if (c == 1 && dy == 0) continue;         /* asm/2155 */
            uint8_t tile = map_tile_ptr();           /* -> DS:1F via asm/2199 */
            if (creature_step_gate(tile, CREATURE_KIND(di)) != 0) continue;

            nx = DS[23]; ny = DS[24];
            if (nx == DS[0x00] && ny == DS[0x01]) break;  /* asm/2201/220A -> 218B */

            /* asm/2216/2233/225A: restore the old cell, commit, stamp the new one. */
            uint8_t ox = CREATURE_X(di), oy = CREATURE_Y(di);
            DS[23] = ox; DS[24] = oy; map_tile_ptr();     /* DS:6 := old cell */
            write_grid(DS[6], CREATURE_SAVED_TILE(di));
            CREATURE_X(di) = nx; CREATURE_Y(di) = ny;
            DS[23] = nx; DS[24] = ny;
            CREATURE_SAVED_TILE(di) = map_tile_ptr();     /* terrain under me now */
            write_grid(DS[6], CREATURE_KIND(di));
            moved = 1;
        }
        if (!moved && DS[0x4A] != 0) minax_proximity_check(di);  /* asm/218B -> asm/1040 */
    }

    wander_spawn_attempt();   /* reached by fall-through, not by call */
}
```

## The `DS:1F` contradiction, closed

Contract 2 used to record `DS:1F` as having "two lives" that could not both be right: `asm/2199`
stores a tile byte and `asm/0CC0` reads a slot index. **There is no contradiction, and the way
the question was framed was the error.** `DS:1F` is a general-purpose scratch byte with more
than twenty writers, and different code paths give it different meanings. That answer was
already on disk — `asm/0CB0_sub_0cb0.asm`'s header has said since 2026-10-23 that `DS:1F` is
shared scratch and cites a live reading of 120 that rules out a slot index. The task was
reconciliation, not extraction.

The three readings, all correct in their own path:

| path | meaning of `DS:1F` | sites |
| --- | --- | --- |
| the creature step | the candidate **tile byte**, stored by `asm/2199` and read back at `asm/21B6`/`21BD`/`21D8` | observed |
| the placement cluster | a **slot index**, written from `DI` by `asm/0CB0` and read into `BL` by `asm/0CC0`/`asm/0CDC`/`asm/0CEE` | observed |
| the player stamp | the saved **`DS:13` value**, written by `asm/2677` and restored by `asm/269F` | observed |

The third one explains the live reading that broke the first two theories: 120 = `0x78` is the
on-foot player stamp, and `asm/2677`/`asm/269F` carry it across a call.

**The trap in the grep is still there and still bites.** `mov $0x1f,%bl` is the immediate 31, not
a read of `DS:1F` — it appears in `asm/0A6D`, `asm/0C9C`, `asm/1015`, `asm/1151`, `asm/147F`,
`asm/23E6`, `asm/330C`, `asm/4660` and `asm/2E3D`. Discard those before counting uses
(`docs/monster-spawn.md` § 11).

**Is `asm/0CC0`'s instrumentation warning still load-bearing? Yes, and it is not built on a
misreading.** Inside the placement path `DS:1F` really does hold the slot index, so a
`MEMORY_WRITE` breakpoint on a fixed `DS:137+n` really will miss writes when it holds a
different `n`. What must not be carried away from it is the idea that `DS:1F` *is* a slot index
as a matter of record — it is a slot index in that path, a tile in this one, and a stamp in a
third.

## Falsification

A contract that cannot be wrong is not a contract. These are the checks that would break it, and
they are cheap:

1. **`0x0C` must accept and `0x10` must refuse** for an ordinary kind (`0x30`, Orc). These are
   adjacent multiples of 4 and both verdicts are independently proven for the *player* by the
   live walk in `docs/passability-findings.md` F11. If a creature ever steps onto a mountain, or
   refuses a forest, this table is wrong.
2. **`0x5C` must accept for kind `0x30` and refuse for kind `0xF0`** (Fighter). Same tile, two
   verdicts — this is the only clause that splits on species, and if both kinds get the same
   answer the `jae` at `asm/21B2` has been misread.
3. **`0x00` must refuse for kind `0x30` and accept for kind `0x2C`.** If a sea creature is seen
   on grass, or an orc in the water, the water-only arm is wrong.
4. **`0x70` must accept and its neighbour `0x74` must refuse.** `0x70` is the only byte above
   `0x14` that is accepted unconditionally, and it is the one that makes town movement possible
   at all.
5. **A creature at `(player_x - 1, player_y - 1)` must step onto the player.** This was written
   as the derived consequence of a `-1` in `asm/4F11` and it **failed when it was run**, which is
   the whole point of listing it: `SUB` does not subtract CF, there is no `-1`, and the step is
   the plain symmetric difference. Closed by `captures/spice86/g28-pursuit`, 20/20 trials with a
   valid control in each.
6. **The gate must refuse everything while `DS:26A != 0`.** **Done 2026-10-28** in
   `captures/spice86/g28-pursuit`: poking `DS:26A = 0x14` froze both test creatures for three
   commands and movement resumed the moment it was cleared, with the counter falling 14 → 13 → 12
   → 11, i.e. exactly one per completed command. A/B/A, so the freeze is not an artefact of the
   creatures having nowhere to go.

## What this contract deliberately does not claim

* **`0x50B3` was called a black box here, and that was wrong.** It is `asm/50B3_map_tile_ptr`,
  already named, byte-proven, live-observed in 49 of 60 harvests, and cited by 25 caller files.
  The header even spells out the addressing. Calling it undecoded was a process failure: the
  first move was `ls asm/ | grep -i <word>`, and it was skipped. The real unread piece was the
  **caller's tile classifier** at `asm/21A6..asm/21D8`, and that is now decoded above.
* **The per-slot gate is no longer a hole.** `asm/0A7C`/`asm/0A83` are the horse-and-`DS:26`
  freeze described in step 1b. What is *still* not claimed: what `DS:26`'s sign means in that
  clause. It has two unrelated documented meanings (torch counter indoors, movement flip
  outdoors) and neither is verified here.
* **`0x5C` is the force field, and it was measured, not inferred.** Closed 2026-10-28 in
  `captures/spice86/g29-field`: stepping onto a `0x5C` cell in sector 03 with no ring costs
  **exactly 1000 HP**, observed on six separate crossings; with the ring (`DS:D6 != 0`) it costs
  nothing; stepping onto a plain `0x70` town tile costs nothing. So the gate's species clause
  reads: monsters walk through force fields, the four NPC classes (`mon_type >= 0x78`) may not.
  This also means the reasoning in `docs/phase4-state.md` § CP5 that ruled a tile trigger out for
  C5 was a units error — it searched `mapx00` for the **mode** byte `0x2e`, which is
  `map_byte >> 1`, and map bytes are multiples of 4, so that test could not have found it either
  way. The `0x5C -> 0x2E` sample already sitting in `asm/2FAD_vehicle_board_dispatch`'s header
  was the missing half all along.
* **The `-1` claim is retracted, and it is worth keeping the retraction.** This contract asserted
  `player - creature - 1` on the grounds that `stc` sets CF and `sub` subtracts it. **`SUB` does
  not subtract CF on x86; only `SBB` does.** The claim was arithmetically tidy, explained
  something nobody had measured, and was wrong. It survived into a written contract because it
  was derived from bytes that were read correctly and combined with a flag semantic recalled
  incorrectly. It died the same day it was written, when `captures/spice86/g28-pursuit` read
  `DS:19/DS:1A` after each sweep: 20/20 trials, plain symmetric difference, valid control in
  every trial. The `stc` is a translated 6502 `SEC ; SBC` — needed on the 6502, dead on x86 — and
  it is a harmless port artefact, not a bug.
* **`asm/0CC0` is placement, not movement.** Its own header is explicit: "This is a PLACEMENT
  store, not movement: nothing here computes a new coordinate." Do not fold it into this tick.
* **Dungeons are out of scope.** `asm/1151` and `asm/147F` also write `DS:137[di]` and belong
  to the dungeon encoding, which `AGENTS.md` parks. `asm/152E` — the clamped step vector with
  **no** off-by-one — is reached only from `asm/1151`, so it is on the parked side too.

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
python3 tools/check_func.py 2199          # the step gate head
python3 tools/check_func.py 4F11          # the clamped step vector
python3 tools/check_func.py 4F36
python3 tools/check_func.py 50D8          # sign_of_al
grep -rn "0x137(%di)" asm/*.asm | grep "mov    %al"      # the position writers
grep -rn "and    \$0x3f" asm/212E_sub_212e.asm asm/0B25_sub_0b25.asm
```

The two thresholds `0x0F` (flee) and `0x10` (regen) are the details most likely to be
"corrected" into one value. They are two different constants in two different fragments and
both are observed.

The step gate is the part most likely to be "simplified". Three things in it are load-bearing
and look like accidents: the `cmp $0x0,%al` before each `ret` (that is the calling convention),
the `stc` without a matching `cmc` in `asm/4F11`, and the `add al,al` pair that turns a clamp
into a torus direction. None of the three is a transcription error.
