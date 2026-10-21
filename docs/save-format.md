# The `player` save file: format, proven fields, and teleporting

Everything currently known about the saved character record, what is proven and
how, and what is still missing. Written 2026-10-21 after building
`tools/u2_edit.py`.

Related: `docs/map-format.md` (sector maps), `docs/tooling-procedures.md`
(driving the emulator), `engine/src/core/state.h` (the DS offset authority).

## Evidence grades used here

| grade | meaning |
| --- | --- |
| proven | assignment or read site cited in `asm/`, or reproduced byte-for-byte |
| measured | observed from a live session, tool and inputs named |
| inferred | reasoned from a partial read; treat as a hypothesis |

## 1. Shape of the file

`player` is **384 bytes**. The interesting part is a 256-byte record that is the
game's DS working segment at `DS:36..135`, stored verbatim:

    save_offset = DS_offset - 0x36

Two independent proofs, and it is worth stressing that they are independent:

* **proven (static, CP2.5):** the creation routine's assignments and the FCB
  read/write sites in `asm/5400` and `asm/3823` establish the 256-byte record at
  `DS:36..135`. See `docs/phase4-implementation.md` § CP2.5.
* **measured (live, 2026-10-21):** loaded the TEST character into Spice86, read
  `DS:36..135` over the HTTP memory API and compared all 256 bytes against the
  file on disk. **254/256 identical.** The two exceptions are `DS:74/75`
  (live `47 3A`, saved `00 00`), which are scratch the game does not persist.

The static proof came first; the live check is corroboration, not a new finding.
That matters because the earlier offset table in `docs/spice86-live-findings.md`
mixes save content with live DS state - `DS:137` onward is the monster table and
is *not* saved.

Bytes `0x100..0x17F` of the file sit outside the record. `0x100` is `0x1A` in
every save examined; the rest read zero. Purpose unknown.

## 2. Proven fields

All offsets below are `DS:` values; subtract `0x36` for the file offset.

| DS | field | notes | grade |
| --- | --- | --- | --- |
| `0x36..45` | `name[16]` | cleared then typed, NUL padded | proven |
| `0x46` | `sex` | `'M'`/`'F'` as typed, not converted | proven |
| `0x47` | `pclass` | 0 fighter, 1 mage, 2 paladin, 3 thief (after `sub $0x31`) | proven |
| `0x48` | `race` | 0 human, 1 elf, 2 dwarf, 3 hobbit | proven |
| `0x49` | `sector_first` | first **decimal digit** of the sector filename | proven |
| `0x4A` | `sector_second` | second digit; outside a sector read it is the site kind: 0 overworld, 1 village, 2 town, 4 tower | proven |
| `0x4B..50` | `str agi sta cha wis int` | six stats, one byte each | proven |
| `0x51/52` | `hp` | **4-digit BCD pair**, hundreds byte first | proven + measured |
| `0x53..55` | `food` | 6-digit BCD; the status band prints only the top 4 digits | proven + measured |
| `0x56/57` | `exp` | 2-digit BCD pair | proven |
| `0x58/59` | `gold` | 2-digit BCD pair | proven |
| `0x5A/5B` | `entry_x`, `entry_y` | spawn point; the P path copies `[0x5A]->[0x00]`, `[0x5B]->[0x01]` | proven |
| `0x63` | `spell_pick` | readied spell slot | proven |
| `0x64..135` | **unknown** | inventory and equipment are expected here, not located | unknown |

### BCD, and why HP is not a byte

Several counters are packed decimal: the decimal digits live in the nibbles, so
byte `0x04` means the digits `04`, and `0x99` means `99`.

* Encoding: split the decimal digits into pairs and parse each pair as hex, so
  `400 -> 0x04 0x00` and `9999 -> 0x99 0x99`.
* Decoding: render each byte as two hex characters, then read the resulting
  string as **decimal**. Doing both steps in hex is the classic mistake and
  reports gold `400` as `1024`. It was made here and caught by checking against
  the on-screen `GOLD=0400`.

**`hp` is BCD, not a plain byte.** `hp=4` with `0x52=0` displays as `H.P.=0400`.
Writing a raw `255` puts `0xFF` in the high byte, whose nibbles are not decimal
digits, and the game prints `??` for them - which is exactly what the first
attempt at a maxed character produced. The maximum representable HP is `9999`.

### Sector is two digits, not a number

`DS:49/4A` are patched into the filename `MAPXFF` by `asm/2290`, so sector 20 is
stored as the pair `2, 0`. Reading that pair as an integer yields `512`, which is
a trap that produced a confusing readout before it was understood.

## 3. Teleporting the character

**Writing `DS:00/01` in a live emulator does not teleport.** The write lands and
reads back correctly, but movement then stops working entirely: `DS:00/01` is a
mirror the game updates, not the value it drives movement from. Discovered the
expensive way on 2026-10-21.

The working method is edit-the-save-and-reload, which is also the only way to
change sector:

```bash
python3 tools/u2_edit.py set    <save> sector 71
python3 tools/u2_edit.py setpos <save> 20 20
tools/spice86_start.sh --headless --name run --player <save> --patch-arrows
```

Verified: writing sector digits `1,0` boots the character into sector 10,
confirmed by `DS:49/4A` reading `1,0` and by a screenshot showing completely
different terrain. Combined with `entry_x/y` this is "start anywhere in any
sector", which removes the need to synthesise probe maps for most experiments.

## 4. The maxed test character

Superseded by section 6, which covers the full kit. Kept only for the note that
the stat value used is a conservative "strong", not a proven cap.

## 5. Equipment, consumables and inventory

**Correction, same day.** An earlier draft of this file said the item slots were
not located. They were - already proven and written up in
`docs/spice86-live-findings.md` section 11, which I did not check before
asserting a gap. That is the `AGENTS.md` rule about listing the corpus before
harvesting, broken again, and it produced a confidently wrong doc.

All offsets are `DS:`; the slots are inside the saved record, so they are
editable.

| DS | field | encoding |
| --- | --- | --- |
| `0x61` | readied weapon | index, 0 = HANDS |
| `0x62` | worn armour | index, 0 = SKIN |
| `0x64` / `0x65` / `0x66` | torches / keys / tools | BCD, one byte each |
| `0x6D` | boots count | non-zero gates the paralysis save at runtime `0x22FD` |
| `0x76 + i` | weapons owned | one count per weapon, 10 entries |
| `0xD6 + i` | items held | one count per item, 16 slots |

Name tables, cited to file offsets in `original/ultimaii.exe`:

* weapons at `0x4F53`: `HANDS DAGGER MACE AXE BOW SWORD "GREAT SWORD"
  "LIGHT SWORD" PHASER "QUICK SWORD"`
* armour at `0x4F9E`: `SKIN CLOTH LEATHER CHAIN PLATE REFLECT POWER NONE` -
  eight entries, which is why the damage roll masks `& 7`
* items at `0x501D`: `RING WAND STAFF BOOTS CLOAK HELM GEM ANKH "RED GEM"
  "SKULL KEY" "GREEN GEM" "BRASS BUTTON" "BLUE TASSLE" "STRANGE COIN"
  "GREEN IDOL" TRI-LITHIUM`

The plural handling proves this is the live table: the display appends a literal
`S` (`asm/4881`) but skips index 3, because `BOOTS` is already plural.

**Not independently re-verified this session.** The editor writes these fields and
round-trips them through the file, but the in-game inventory display was not
opened - `I` is not the inventory command, and the correct key is not yet
recorded. The slot identities rest on the earlier value-match proof, not on
today's run.

### Disputed: WIS versus CHA

`state.h` labels `DS:4E` `stat_cha` and `DS:4F` `stat_wis`; the live findings
table lists them the other way round. It is not provable from a character where
both are equal. The editor follows `state.h` because `state.h` is the authority,
but the labels for those two bytes should be treated as unsettled until a
character with different values settles it.

## 6. The maxed, fully kitted character

`python3 tools/u2_edit.py maxout <save>` sets stats to 40, `hp` 9999, `food`
999999, `gold` 9999, `exp` 9999, readies QUICK SWORD, wears POWER armour, gives
50 torches, 20 keys, 20 tools, boots, every weapon and one of every item.

Verified live: the loaded character displays `H.P.=9999 FOOD=9999 EXP=9999
GOLD=9999`. The equipment and inventory side is written and round-trips, but see
the verification caveat above.

The stat value 40 is a conservative "strong", **not a proven cap**. The TEST
character's `DS:4B` is `0x50`, which read as BCD is **50** - an earlier draft of
this file called that 80, having read the byte as an integer. Stats are BCD.


## 7. Safety

* `original/` and `references/` are never modified. `u2_edit.py` refuses to edit
  a path under `references/`, and refuses in-place edits under `original/`.
* The game rewrites its own `player` file in the working directory, which is why
  every run uses a per-launch copy under `tmp/`.
* Edits are verified by reading the file back and re-parsing, not by trusting the
  write.
