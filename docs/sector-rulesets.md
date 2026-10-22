# Sector rulesets — what is actually the same and what is not

**Question this answers:** do the overworld and towns share gameplay mechanics, and is
the dungeon the only thing that works differently?

**Short answer: yes.** One mechanics set covers wilderness, towns, castles and the
sector-0 compound. Dungeons are the only outlier found so far. And the split is not a
coincidence of what was captured — it is encoded in the sector number itself.

Grades follow `AGENTS.md` § 5. `observed` = read from a dump or a live session,
`measured` = derived by a named tool, `inferred` = reasoned from a partial read.

## 1. The sector number encodes the ruleset

Sector lives at `DS:49/4A` as **two decimal digits** (`docs/map-format.md:110`), and the
ones digit is also the **site kind** (`docs/phase4-implementation.md`, the `asm/2423`
passage). Those two readings looked like a contradiction; they are the same fact.

| ones digit | sectors shipped | `tlkx` dialogue | reading | evidence |
| --- | --- | --- | --- | --- |
| 0 | 00 10 20 30 40 50 60 70 80 90 | none | wilderness | observed |
| 1 | 11 21 31 41 61 71 81 | all | village | measured (file set) |
| 2 | 22 32 82 92 | all | town | measured (file set) |
| 3 | 03 23 33 93 | all | town, third kind | measured (file set) |
| 4 | 24 34 44 | none | tower | **inferred, never visited** |
| 5 | 15 25 35 45 85 | none | dungeon / cave | observed |

All 15 `tlkx` files land in ones-digit 1/2/3 and none in 0/4/5 — street dialogue exists
exactly where the scheme predicts towns. Two independent live observations agree:
entering a cave moved `DS:49/4A` from `3,0` to `3,5`, and `dungeon-35-live` is sector 35.

## 2. What is the same across wilderness, towns and castles

Measured over all 49 dumps that contain monsters (`tools/monster_record_scan.py`,
plus the per-sector classification described in § 4):

| property | sector 20 (wild) | sector 03 (town) | sector 32 (wild) | sector 00 (compound) | sector 35 (dungeon) |
| --- | --- | --- | --- | --- | --- |
| monster record layout `0x137/0x157/0x177/0x197/0x1B7` | yes | yes | yes | yes | yes |
| type encoding | `0x2C`–`0xFC` | `0x2C`–`0xFC` | `0x2C`–`0xFC` | `0x2C`–`0xFC` | **`0x01`–`0x06`** |
| grid stamp `DS:1800[y*64+x] == type` | 100 % | **31/31** | **31/31** | 30/31, 31/31 | **0/27** |
| HP from the nine spawn arms | yes | yes | yes | **overridden to 255** | **no — computed** |
| townsfolk present (Guard/Merchant/Cleric) | no | **yes** | **yes** | yes (Cleric) | no |

So towns are not a separate mode. They are the same grid, the same record, the same type
values and the same stamping, with townsfolk occupying ordinary monster slots. The
compound in sector 00 shares all of it too and differs only in HP.

**The dungeon is a different representation**, not a different flavour of the same one:
small kind indices instead of type bytes, no grid stamping at all, and HP built
arithmetically in `asm/147F_dungeon_monster_spawn` (`or $0x10,%al`) instead of stored as
an arm immediate.

## 3. What this does *not* prove

* **Only one dungeon and one town sector were ever captured.** The table generalises from
  sector 35 and sector 03. Nothing says sector 15 behaves like sector 35, though the
  scheme predicts it.
* **`X4` towers have never been entered.** The "tower" label is inherited from
  `asm/343F`'s `-TOWER` string and the fan pack's `Files.txt`, not from a visit.
* **Grid stamping is a memory fact, not a rendering fact.** It shows the type byte lands
  in the cell. It does not show which art the renderer draws from it. That is still G18's
  open half.
* **The HP area-override rule is unknown.** Sector 00 saturating to 255 while sector 03
  shows buffed-but-varied values means something raises HP above the arm base. Not found.

## 4. Method, so this is reproducible

Per-capture classification read `DS:49`, `DS:4A`, `DS:29`, the monster record at
`DS:0x137/0x157/0x177/0x197` and the 4 KB grid at `DS:0x1800` out of every
`captures/spice86/*/spice86dumpMemoryDump.bin`.

One trap worth recording: the active-slot filter `type not in (0, 0x40)` is an
**overworld-shaped assumption**. In a dungeon it admits the kind indices `0x01`/`0x02`,
which made two different encodings look like one broken grid and produced a false
finding before it was caught. Any filter over this record must be written per ruleset.

## 5. Follow-ups this opens

| item | where |
| --- | --- |
| Visit an `X4` tower sector — the only unvisited ruleset | `docs/needs-gameplay.md` G20 |
| Map the dungeon encoding: what `0x01`–`0x06` mean, where its objects are drawn from | G18 |
| HP area-override rule (sector 00 vs 03) | `docs/handoff-2026-10-22.md` Next actions 4 |
| Townsfolk HP assignment — now narrowed: they occupy ordinary slots, so look on a path shared with the arms | G17 |
