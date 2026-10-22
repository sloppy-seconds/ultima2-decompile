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
| dungeon spawns | computed in `asm/147F_dungeon_monster_spawn` | read, not yet validated live |

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
* **Dungeon sectors do not use this.** `dungeon-35-live` matched `monx35` at 0/27.
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
