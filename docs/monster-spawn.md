# Monster spawn — two sources, and `monxNN` is the second one

Found 2026-10-22 while trying to trigger a shop. It closes the HP question that was open
all day, and it corrects a documented claim about the `monx` file format.

Grades per `AGENTS.md` § 5.

## 1. There are two spawn sources, not an area override

Everything earlier today was confused because one model was assumed for all monsters.
There are two:

| source | HP comes from | evidence |
| --- | --- | --- |
| **placed monsters** | `monxNN[64 + slot]` — a byte in the sector's data file | **32/32, 32/32, 31/32** across three captures in two sectors |
| **wandering spawns** | the nine per-kind immediates in the spawn arms | ~40 captures in sector 20 match the arms exactly |
| dungeon spawns | computed in `asm/147F_dungeon_monster_spawn` — **now validated live, 54/54 slots, see § 7** | read + `tools/dungeon_spawn_check.py` |

**There is no "area override" rule.** That was the wrong frame. Sector 00 reads HP 255
for every monster because `monx00[64:96]` is literally all `0xFF`. Sector 20 matches the
spawn arms because `monx20[64:96]` is all zeros — that sector has no placed monsters, so
everything in it is a wandering spawn.

This retroactively explains the whole day's confusion: the compound at sector 0 was never
special, it was just fully authored.

## 2. `monxNN` layout — the documented format is wrong

`docs/phase4-implementation.md` described `monxNN` as "256 monster-ID slots (16x16) +
128 B tail". It is not. The file is **five parallel 32-byte arrays**, one entry per
monster slot, followed by padding:

| offset | field | live DS array | match, three captures |
| --- | --- | --- | --- |
| `0..31` | x | `DS:0x137+i` | 18/32, 27/32, 8/32 — **drifts, expected** |
| `32..63` | y | `DS:0x157+i` | 18/32, 29/32, 13/32 — **drifts, expected** |
| `64..95` | **HP** | `DS:0x177+i` | **32/32, 32/32, 31/32** |
| `96..127` | **type** | `DS:0x197+i` | **32/32, 32/32, 32/32** |
| `128..159` | kind | `DS:0x1B7+i` | 32/32, 28/32, 32/32 |

x and y under-match because monsters move after spawn; the file holds spawn positions.
The three static fields match at or near full width. The one 31/32 HP miss is a monster
that took damage.

Captures used: `shop-probe` (sector 03, taken today), `autoplay` (sector 00),
`castle-03-live` (sector 03).

## 3. This closes the townsfolk question

The open item was *where townsfolk HP is assigned*, given that no spawn arm covers Guard,
Merchant, Cleric or King. **They are placed monsters.** The Merchants, Clerics and Guards
in sector 03 are entries in `monx03`, and their HP is the byte at `monx03[64 + slot]`.
That is why no arm names them: arms only handle wandering spawns.

The static search had concluded "every write site of `[DI+0x177]` is enumerated and none
can be a town NPC spawner" — correct, and the reason is that there is no spawner to find.
The values are loaded from disk.

## 4. What this does not settle

* **Only two sectors tested.** 00 and 03. Nothing says the layout holds in sector 24 or
  45, though the field widths are consistent.
* **The loader is not yet identified.** Something reads `monxNN` into the DS arrays; that
  routine is unnamed. `asm/22D5` is documented as the `monx` read with `CX=0x100`, which
  is 256 bytes — inconsistent with a 160-byte used region and worth re-reading.
* **Dungeon sectors do not use this.** `dungeon-35-live` matched `monx35` at 0/27. They
  have their own encoding — see § 7.
* **The shop is still untriggered.** See § 5.

## 5. Why the shop capture failed

The player was placed at (16,25) in sector 03 beside a letter tile at (15,25) byte `0xC0`,
`T` was sent twice, and **zero executed addresses fell inside `19D7..2027`** — no shop ran.

The reason is visible in the same dump: **no NPC of any kind was within three tiles of
that shop tile.** The two Merchants in the sector were at (50,41) and (39,50), and neither
is adjacent to a letter tile in `mapx03`. So F13's owner report — *"`T` still works with a
shopkeeper standing on the other side of one"* — is not a description of a nicety, it is
the requirement. A shop tile alone does nothing; the transaction needs the shopkeeper
positioned at it, and in sector 03 no merchant is.

**G22 therefore stays open**, and the next attempt has to find a sector where a merchant
actually stands beside a letter tile, or place one there. That is a data question, not a
key-injection question.

## 6. Curiosity, unproven

The wizard's "gibberish" in `asm/19D7_magic_shop_menu` reads as **Turkish**:
`BIR IKI UC` (one two three), `LUTFEN EVET` (please yes), `GULE GULE` (go smiling /
goodbye), `UGURLA OLSUN` (may it be auspicious). Recorded as a curiosity, **not a
measurement** — it is one agent's inference from strings and wants a native speaker's
eye before it becomes a claim. The interesting version, if it holds, is that the magic
shop's "mystical language" is a real language rather than invented noise.

## 7. The dungeon encoding — A4, measured

`tools/dungeon_spawn_check.py` reads the monster record out of every capture on disk,
selects dungeon-shaped ones **by encoding rather than by directory name**, and checks
them against what `asm/147F_dungeon_monster_spawn.asm` computes. Result:

> **54 of 54 monster slots across both dungeon captures satisfy the formula exactly.**
> The captures are `dungeon-35-live` and `airport32`, and both are sector 35
> (`DS:49=3`, `DS:4A=5`) — the second is the stale name `docs/monster-spawn.md` § 5
> warns about, and its monster record is identical to the first.

### What `0x01`–`0x06` are

A dungeon `type` is **not** an overworld type byte and **not** an index into the same
creature table. It is drawn as `type = (rand & 7) + 1` with the value 7 rejected, so the
domain is **1..7** — seven dungeon creature slots, which is exactly the size of the
dungeon set the third-party table carries. Six of the seven appear in the captures; 7
needs a slot with `slot>>1 >= 12` and the draw to land on it.

### `[DI+0x1B7]` in a dungeon is the slot number, not a kind

`asm/147F` at `L_0016d1..L_0016d6` does `mov %di,%ax ; clc ; rcr $1,%al ; mov %al,0x1b7(%di)`.
`DI` is the slot index, so **`[slot+0x1B7] = slot >> 1`**, and the check confirms it on
54 of 54 slots. The values seen are `0x02..0x0F`, which is the range `slot>>1` produces
for the occupied slots 4..31.

This matters because `0x1B7` was re-labelled from "sprite" to "small kind index" on
2026-10-22 after a live read found `0x08`/`0x0C`. That reading was right for the
overworld and **wrong here**: in a dungeon the field holds no creature information at
all. It is a slot-derived operand the HP formula consumes.

### The slot index is the difficulty ladder

The accept test at `L_0016f0..L_0016f8` is `cmp 0x1b7(%di),%al` against `2*(type-1)`,
accepting on equal-or-below. So a monster is only admitted when

```
2 * (type - 1) <= slot >> 1        i.e.   type <= (slot >> 1) / 2 + 1
```

Slot 4 admits types 1–2; slot 31 admits 1–8, capped at 7 by the draw. **Higher-numbered
slots hold stronger creatures, and HP rises with the slot too**, because the same
`slot>>1` is an operand of the HP expression. That is the mechanism the overworld lacked
and the reason "area can raise HP" looked true from one sector: in a dungeon, strength is
a function of slot, not of place.

### The HP formula, and the third-party table

```
HP = ((2*type + (slot>>1)) * 8) | 0x10
```

— `L_001706..L_001714`: `add %al,%al` for `2*type`, `adc 0x1b7(%di),%al` to add the slot
term, three more `add %al,%al` for `*8`, then `or $0x10,%al`. The carry out of the `adc`
was 0 in all 54 observations, so its contribution is untested rather than proven absent.

Taking each type at its cheapest legal slot and at slot 31 gives the full envelope, and it
reproduces the third-party dungeon table **exactly, one lower, on both bounds and with
the same pairing**:

| type | our min | third-party min `17+32k` | Δ | our max | third-party max `153+32*(k//2)` | Δ |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 16 | 17 | −1 | 152 | 153 | −1 |
| 2 | 48 | 49 | −1 | 152 | 153 | −1 |
| 3 | 80 | 81 | −1 | 184 | 185 | −1 |
| 4 | 112 | 113 | −1 | 184 | 185 | −1 |
| 5 | 144 | 145 | −1 | 216 | 217 | −1 |
| 6 | 176 | 177 | −1 | 216 | 217 | −1 |
| 7 | 208 | 209 | −1 | 248 | 249 | −1 |

The previous status of that fit was *"measured against third-party numbers, which is not
the same as measured against the binary"* (`docs/bestiary.md` § 6). It now is: the shape,
the step of 32, the min/max pairing and the type ordering all fall out of the instruction
sequence, and the only disagreement is a uniform −1. **Grade: measured, with a named
systematic offset against the fan table.** The offset is not explained — the likeliest
reading is that the fan table quotes hits-to-kill plus one, but that is a hypothesis and
it is recorded as one.

### Where dungeon objects live, and what is still missing

The spawner stamps the type into the sector buffer at `L_00171b..L_001729`:
`mov 0x8,%bx ; mov (%bx,%si),%al ; or 0x197(%di),%al ; mov %al,(%bx,%si)` — a read-modify-
write that **ORs** the type into a cell, so a cell can carry a wall flag and a creature at
once. `word[DS:08]` is `0x183D` in the capture and `word[DS:472]` is `0x1800`.

The population claim holds: in `dungeon-35-live` the 4 KB buffer at `DS:1800` holds
exactly **27** bytes in `0x01..0x07`, and their per-value histogram
`{1:6, 2:10, 3:2, 4:4, 5:1, 6:4}` is **identical** to the per-type histogram of the 27
monster records. So the objects are in the grid, one stamp per monster.

**What is not established is the coordinate transform.** The monster record's `x` and `y`
are odd values in 1..15 — `and $0x7` then `add %al,%al` then `or $0x1` — a 16-wide crawl
space, while the stamps sit at rows 8..61 and columns 19..63 of a 64-wide buffer. No
linear map of the tested shapes (`y*16+x`, `y*64+x`, `x*16+y`, with or without a page
offset from `DS:25`) reproduces the cell from the record coordinates: the best attempt
matched 2 of 27. The stamp address comes from `%si`, which is set by a routine the tree
calls `L_00164c` — a five-byte fragment (`nop ; mov 0x1b7(%di),%al`) that cannot be
computing it, so **the fragment boundary is wrong there and the real index computation is
outside the declared range**. That is the same class of defect as G22, and it is where the
dungeon geometry question picks up.

### Correction to § 2 of `docs/sector-rulesets.md`

That table lists the dungeon `kind` column under the same record layout as the
overworld. The layout is the same but the **meaning** is not: `0x1B7` is `slot>>1` in a
dungeon and a kind index on the overworld. Anyone re-deriving this should read § 7 here
rather than infer from that table.
