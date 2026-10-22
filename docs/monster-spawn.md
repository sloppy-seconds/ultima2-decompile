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
| dungeon spawns | computed in `asm/147F_dungeon_monster_spawn` — **now validated live, 54/54 slots, see § 9** | read + `tools/dungeon_spawn_check.py` |

**There is no "area override" rule.** That was the wrong frame. Sector 00 reads HP 255
for every monster because `monx00[64:96]` is literally all `0xFF`. Sector 20 matches the
spawn arms because `monx20[64:96]` is all zeros — that sector has no placed monsters, so
everything in it is a wandering spawn.

This retroactively explains the whole day's confusion: the compound at sector 0 was never
special, it was just fully authored.

## 2. `monxNN` layout — the documented format is wrong

`docs/phase4-implementation.md` described `monxNN` as "256 monster-ID slots (16x16) +
128 B tail". It is not. The file is **six parallel 32-byte arrays**, one entry per
monster slot, followed by a tail. (Five when this section was first written; the sixth
was found 2026-10-23 by the corpus-wide re-scan in § 6.)

| offset | field | live DS array | match, three captures |
| --- | --- | --- | --- |
| `0..31` | x | `DS:0x137+i` | 18/32, 27/32, 8/32 — **drifts, expected** |
| `32..63` | y | `DS:0x157+i` | 18/32, 29/32, 13/32 — **drifts, expected** |
| `64..95` | **HP** | `DS:0x177+i` | **32/32, 32/32, 31/32** |
| `96..127` | **type** | `DS:0x197+i` | **32/32, 32/32, 32/32** |
| `128..159` | kind | `DS:0x1B7+i` | 32/32, 28/32, 32/32 — **does not hold everywhere, see § 6** |
| `160..191` | **flag** | `DS:0x1D7+i` | new 2026-10-23; values `01..03` and `81..85` |

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
  have their own encoding — see § 9.
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

## 6. The layout re-checked across the whole corpus — B4, 2026-10-23

`tools/monx_layout_scan.py` reads the sector out of every capture on disk (from `DS:49/4A`,
never from the directory name), loads that sector's `monxNN`, and scores each array over
**only the slots the file actually authors** — a slot with `monx[96+i] == 0` holds no
placed monster, so whatever lives there came from a wandering spawn and is not the file's
business. That distinction is the whole reason this re-scan disagrees with a naive one:
scoring unauthored slots is what makes sector 20 look like a total layout failure when it
is actually an empty file.

| sector | captures | x | y | HP | type | kind | flag | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 00 | 4 | 85/124 | 85/124 | **124/124** | **124/124** | 107/124 | **124/124** | holds except `kind` |
| 03 | 5 | 78/160 | 89/160 | 158/160 | **160/160** | **160/160** | 144/160 | holds; HP misses are damage |
| 20 | 40 | — | — | — | — | — | — | **`monx20` authors nothing**; untestable |
| 31 | 12 | 207/384 | 275/384 | **384/384** | **384/384** | 349/384 | **384/384** | holds except `kind` |
| 32 | 1 | 7/32 | 10/32 | 31/32 | 31/32 | 29/32 | 24/32 | one capture; slot 16 is a killed monster (`type` cleared to 0) |

**`type` and `HP` hold everywhere they can be tested.** Every miss is explained: HP below
the file value is damage, `type` cleared to zero is a killed and cleared slot. No capture
shows HP *above* the file value, which is the property that would have broken the model.

**`kind` does not hold, and that is a finding.** Sector 03 matches 160/160, but sector 00
mismatches 17 slots (file `0x08`, live `0x0C` at slots 28–31), sector 31 mismatches 35
(file `0x70`, live `0x08` at slot 6), sector 32 mismatches 3. So `DS:0x1B7` is **not**
faithfully loaded from `monx[128:160]` — something rewrites it after the load. That is
consistent with § 9, where the dungeon spawner is proven to write `slot >> 1` into the
same field, and it means the earlier "`kind` matches 32/32" on sectors 00 and 03 was a
lucky sample rather than a rule.

### The sixth array, and what it looks like

`monx[160:191] → DS:0x1D7` matches live exactly in sectors 00 and 31, and drifts only
where a wandering spawn overwrote a slot in 03 and 32. Its values are `01`, `02`, `03`
and `81`–`85`. The high-bit set on `81..85` is the Apple II convention the `tlkx` files
use, so this array plausibly holds two things: a small group value `1..3` and a flagged
marker `1..5`. **What it means is not established**, but it now has readers, and one of
them is decisive enough to narrow the field a lot.

`asm/40C0` (a standalone 8-byte fragment, **not** part of `asm/4050_cmd_T.asm` — it is
reached from there by `jne L_0042c0` at `asm/4050_cmd_T.asm:103`) does
`mov 0x1d7(%di),%al ; cmp $0x80,%al ; jb ...`, i.e. it **branches on bit 7**. Found
2026-10-23 while decoding the TRANSACT path.

**`asm/3C2E_cmd_O` (OFFER GOLD) is the reader that gives the field its shape, and it
contradicts the aggro reading.** It reads `[DI+0x1D7]` with `DI = [DS:1F]` (the cursor
slot), and where bit 7 is **clear** it falls through to the generic `THANK YOU VERY
MUCH!`; where bit 7 is **set** it requires `[DS:4A]==2 && [DS:49]==3` (site kind/index)
and then **enumerates the individual high values**, each with its own scripted outcome
(observed bytes, `asm/3C2E_cmd_O.asm:94-150`):

| value | branch | cited consequence |
| --- | --- | --- |
| `0x81` | `L_003eed` | needs `[DS:27] >= 5`, prints `ENILNO IS YOURS!`, sets `[DS:7F]=1` |
| `0x82` | `L_003f10` | with `[DS:6C]==0` prints `EARN THE RING!`, else `THE RING IS YOURS!` and sets `[DS:D6]=1` — the **RING slot** from C5 |
| `0x83` | `L_003f52` | third scripted recipient |

`asm/2C38_sub_2c38` writes the constant `0x84` into `[DI+0x1D7]` immediately before
printing `SHE'S GONE!!!` — a departure transition, not a mood. And `asm/102B_sub_102b`
tests the slot for **zero**, which is what an empty-slot check looks like.

**Reading, graded `inferred` from the above `observed` bytes:** `DS:0x1D7+i` is a
per-slot **role / scripted-identity** byte — `0` empty, `1..3` ordinary classes, `0x81..0x85`
named recipients — and bit 7 means "this slot has a scripted response", not "awake".
**The owner's aggro-marker hypothesis is not supported by any consumer found so far**, and
this is the second field where the bytes declined to cooperate with it. It stays a
hypothesis about some *other* byte, not a dead one.

**Update, same day — the low nibble moves, and § 16 identifies what moves it.**
Two live runs showed an **attacked** Fighter (`type 0xF0`) go `0x03 -> 0x01`. A baseline
taken seconds after load shows guards are born `0x03`/`0x00`, so `0x01` is not a class value:
**it is an alarm.** Landing a blow on *anything* in a town flips every guard in the loaded
sector to `0x01` at once — including slots 46 tiles from the player — while a missed swing
flips nothing, and 65 s of idle on a fresh load flips nothing either. Distance from the
player did not predict which guards flipped, so for the guard class the alarm is
sector-wide.

So the handoff's instinct about this array was right and the bit was wrong: the aggro state
lives in the **low nibble**, not bit 7. What bit 7 still means (scripted recipients
`0x81/0x82/...`) is unchanged. Evidence: `docs/spice86-live-findings.md` § 16, capture
`captures/spice86/cp5-g25-aggro/`. Open: whether `0x01` is read back as a *cause* of
attacking (everything here set it by hitting things), and what distinguishes `0x00` from
`0x03` at load.

Writer attribution also corrected: the writer is `asm/114A_sub_114a` (`mov %al,0x1d7(%di);
dec %di; jns` — a downward fill loop at runtime `114A..1150`), which **precedes**
`asm/1151_dungeon_darkness` (`1151..12DA`) and is not part of it. An earlier note here
cited `1151`.

### Which sectors author monsters at all — and it is the site-kind scheme again

Scanning all 33 `monxNN` files directly:

* **16 sectors author monsters**: `00`, and every sector whose ones digit is 1, 2 or 3 —
  `03 11 21 22 23 31 32 33 41 61 71 81 82 92 93`.
* **17 author nothing** (all five arrays zero): every ones-digit 0 wilderness sector
  (`10 20 30 40 50 60 70 80 90`), every `X4` tower (`24 34 44`) and every dungeon
  (`15 25 35 45 85`).

So **`monxNN` is non-empty exactly where `tlkxNN` exists, plus sector 00.** That is a third
independent channel — after map signs and street dialogue (`docs/place-names.md` § 2c) —
agreeing with the ones-digit site-kind scheme, and sector 00 is again the exception: the
compound has authored monsters but no street dialogue.

It also explains a standing confusion in this file. § 1 says sector 20 matches the spawn
arms "because `monx20[64:96]` is all zeros" — the scan confirms it authors **nothing at
all**, so all 40 sector-20 captures are pure wandering spawns and the arms were the only
possible answer there.

### The `monx` tail is a pack-wide pattern

Every `monxNN` is 384 bytes, and in every one checked:

```
monx[256]          == 0x1A
monx[257:384]      == monx[129:256]      (byte-identical)
monx[192:256]      == all zeros
```

The `0x1A` at offset 256 is the same marker the `player` file carries at `0x100`, and
`mapxNN` carries one at the head of its own 128-byte tail — so `0x1A` at the start of a
file's tail region is a pack-wide convention, not a per-file oddity. **What the shifted
duplicate means is not known.** It is not a second monster table (it duplicates the
`kind` and `flag` arrays offset by one), and nothing has been found that reads it. The
open question in `docs/phase4-state.md` § Deferred decisions — "what is the `0x1A` tail"
— is narrower than it looked, and this is the shape of the answer: a marker plus a
shifted copy of the last two arrays.

## 7. Follow-ups opened by § 6

| item | note |
| --- | --- |
| Name the `flag` array (`monx[160:191]` / `DS:0x1D7`) | **narrowed 2026-10-23, not finished.** § 6 now reads it as a per-slot role/scripted-identity byte (`0` empty, `1..3` ordinary, `0x81..0x85` named recipients) from `cmd_O`'s enumerated branches. Remaining: prove the *low* group `1..3` means something, and find who writes the per-slot values — `asm/114A` is a constant fill, not a per-slot load |
| Find what rewrites `DS:0x1B7` after the `monx` load | `kind` mismatches in 3 of 4 testable sectors; the dungeon spawner is one such writer, the overworld writer is unnamed |
| G20 — enter a tower sector | `monx24/34/44` author nothing, so a tower is expected to behave like wilderness for spawning. Testable in one launch |
| Read the `monx` loader | § 4 notes `asm/22D5` reads it with `CX=0x100` = 256 bytes, which covers arrays 1–5 and **not** the sixth at `160..191`. Either the read is larger than recorded or the sixth array arrives another way |

## 8. Curiosity, unproven

The wizard's "gibberish" in `asm/19D7_magic_shop_menu` reads as **Turkish**:
`BIR IKI UC` (one two three), `LUTFEN EVET` (please yes), `GULE GULE` (go smiling /
goodbye), `UGURLA OLSUN` (may it be auspicious). Recorded as a curiosity, **not a
measurement** — it is one agent's inference from strings and wants a native speaker's
eye before it becomes a claim. The interesting version, if it holds, is that the magic
shop's "mystical language" is a real language rather than invented noise.

## 9. The dungeon encoding — A4, measured

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
dungeon and a kind index on the overworld. Anyone re-deriving this should read this
section rather than infer from that table.
