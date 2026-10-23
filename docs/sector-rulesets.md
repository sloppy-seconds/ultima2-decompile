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
| 4 | 24 34 44 | none | tower | **visited 2026-10-23 — it is dungeon-shaped, see § 1b** |
| 5 | 15 25 35 45 85 | none | dungeon / cave | observed |

All 15 `tlkx` files land in ones-digit 1/2/3 and none in 0/4/5 — street dialogue exists
exactly where the scheme predicts towns. Two independent live observations agree:
entering a cave moved `DS:49/4A` from `3,0` to `3,5`, and `dungeon-35-live` is sector 35.

## 1b. The `X4` towers are dungeon-shaped — G20 closed

**observed live 2026-10-23**, sector 34, captures `tower-34` and `tower-34-open`. This
was the one site kind never entered, and the answer is neither "the same as the
overworld" nor "a third thing": **it is on the dungeon side of the split.**

| test | tower (34) | dungeon (35) | overworld (20, 03) |
| --- | --- | --- | --- |
| map bytes | 8 distinct, **all multiples of `0x10`** (`00 10 20 30 40 80 C0 E0`) | 7 distinct, all multiples of `0x10` | 11 and 50 distinct, **not** aligned |
| on entry | **`IT'S DARK!`** | dark, torch needed | lit |
| `I` | `IGNITE TORCH`, `DS:26` set to 149, decrements per step | same | inventory |
| arrow keys | **`TURN LEFT` / `TURN RIGHT`** — first-person rotation | same | grid movement |
| `A` | `ATTACK--MISS` | ADVANCE | ATTACK |
| monster `type` | `0x01..0x06` | `0x01..0x06` | `0x2C..0xFC` |
| monster `kind` | `slot >> 1` | `slot >> 1` | authored in `monxNN` |
| HP | matches the `asm/147F` formula, **22/22 and 18/18** | matches, 27/27 | arm immediates |
| grid stamps | small `0x01..0x06` appear in the live grid | same | full type byte stamped |
| `tlkx` | none | none | present in 1/2/3 |
| `monxNN` | authors **nothing** | authors nothing | authors placed monsters |

So the ones digit does predict the ruleset, but the split is not dungeon-versus-
everything-else — it is **`{4,5}` versus `{0,1,2,3}`**. The § 2 claim that "dungeons are
the only outlier" was an artefact of only ever having captured one kind of outlier, and
the § 3 caveat that *"`X4` towers have never been entered"* is what let it stand.

Two things did **not** carry over, so a tower is not simply a dungeon with a new name:

* **`A` is ATTACK here, not ADVANCE.** `docs/spice86-live-findings.md` § 13 records `A` as
  mode-aware, ATTACK outside and ADVANCE inside. The tower is inside for every other
  purpose and still attacks, so that dispatch keys off something narrower than
  inside/outside. `DS:29` is the candidate: `0x00` in the tower, `0x92` in
  `dungeon-35-live`.
* **The first-person viewport draws nothing.** Both captures show a bordered rectangle
  and no geometry — with the torch lit, and whether the player stood on a solid `0x80`
  cell or an open `0x00` cell with four open neighbours. So it is not darkness
  suppressing it. **Unexplained**, and the obvious next probe.

The `0x80`/`0x00` ratio is inverted too: the tower is 2807 `0x80` against 1058 `0x00`
where the dungeon is 1760 against 1919. A seeded position can land inside solid material
— the first attempt at (32,32) sat in a `0x80` block and every direction returned
`ADVANCE-BLOCKED!`, which is a seeding hazard worth knowing before anyone plans a tower
walk.

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
  scheme predicts it. **Updated 2026-10-23:** sector 34 is now captured as well, and it
  agrees with 35 — see § 1b.
* **`X4` towers were the one site kind never visited until 2026-10-23.** The "tower"
  label is inherited from `asm/343F`'s `-TOWER` string and the fan pack's `Files.txt`,
  never from a session; § 1b is the session.
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
| Visit an `X4` tower sector — the only unvisited ruleset | **done 2026-10-23** — see § 1b. It is dungeon-shaped; `A`-is-ATTACK and the empty viewport are the two open differences |
| Map the dungeon encoding: what `0x01`–`0x06` mean, where its objects are drawn from | G18 |
| HP area-override rule (sector 00 vs 03) | `docs/archive/handoff-2026-10-22.md` Next actions 4 |
| Townsfolk HP assignment — now narrowed: they occupy ordinary slots, so look on a path shared with the arms | G17 |

## 6. How a site is entered and left — `E` is the door, not a tile (2026-10-27)

The engine has never crossed from a world sector into a town, and the assumption in
`docs/passability-findings.md` F3 was that the trigger must be the unresolved
tile→mode mapping: the indirect store that fills `DS:2CB`/`DS:2DE`, which is what the
passability ladder reads. That assumption was wrong, and it made town entry look blocked
behind a problem it is not behind.

**Entering a site is the `E` command.** `asm/3389_cmd_E` prints `ENTER` and falls through
into the dispatch at `asm/33A6..0x33FF`:

```
3392  al := [DS:4A] ; if al != 0 -> " WHAT?"        ; already inside a site
33a6  al := [DS:13] ; if al >= 0x78 -> continue      ; else "-ONLY ON FOOT!"
33c3  v := [DS:14] >> 1
35cc  v == 5 -> L_00360f
35d4  v == 6 -> L_003647   -TOWN     (asm/343F)
35dd  v == 7 -> L_00367c   -TOWER    (asm/343F)
35e6  v == 8 -> L_0036b5   -CASTLE   (asm/34B5)
35ef  v == 9 -> L_0036ec   -DUNGEON  (asm/34E4)
35f8  v == 10 -> L_003725
```

`DS:13` is the player stamp (`0x78` on foot, `state.h`), so the gate is "you must be on
foot", and `DS:14` is `mode_a`, one of the four mode bytes `asm/5B71_mode_table_copy`
copies out of the `DS:2DF` region. So the *value* that says "this cell is a town gate"
still lives in the unresolved table — but it is read at the moment `E` is pressed, at the
player's own cell, and not during movement. That is a much smaller question than the one
F3 posed, and it is answerable by sweeping `E` over a world sector and reading `DS:14`.

`DS:4A == 0` means the world map, and `E` inside a site answers ` WHAT?`. The sibling is
`asm/334D_cmd_D` (DESCEND), which requires `[DS:4A]` to be 4 or 5 — a tower or a dungeon —
and refuses `-WHAT?` anywhere else. So the site grammar is: walk on the world map, press
`E` at a gate, go down with `D` inside a tower or dungeon.

### What each entry routine does, and it is the same six steps every time

`asm/341E` (v==5), `asm/343F` (-TOWN, -TOWER), `asm/34B5/34CF` (-CASTLE),
`asm/34E4` (-DUNGEON) all follow one shape:

```
str_out "-TOWN"                       ; the announcement, a suffix on the CMD line
[DS:5A] := [DS:00] ; [DS:5B] := [DS:01]   ; remember where we came in
call L_0024fd                        ; asm/22FD — store the outgoing sector
[DS:00] := 0x1f ; [DS:01] := 0x3e    ; arrive at (31, 62), bottom-centre
[DS:4A] := <site digit>              ; 1 village, 2 town, 3 third kind, 4 tower, 5 dungeon
call L_002490                        ; asm/2290 — load the sector map
call L_0024d5                        ; asm/22D5 — load the sector monsters
[DS:12] := 0x4                       ; the off-sector tile marker
jmp L_000c33                         ; asm/0A33 cmd_done
```

The tower and dungeon arms additionally zero `DS:25`, set `DS:03`/`DS:02` and start the
player at `(5,5)` rather than `(31,62)` — the first-person view has its own entry cell.

**Leaving is the sector-edge test**, `asm/242D`/`asm/2434`, which runs before the
coordinates are masked:

```
242d  if [DS:00] >= 0x40 -> 243e
2434  if [DS:01] >= 0x40 -> 243e
243e  [DS:00] := [DS:5A] ; [DS:01] := [DS:5B]   ; back to where we entered from
      [DS:4A] := 0                                ; the world map
      call L_002490                              ; reload
```

So a site is left by walking off any edge of it, and the player reappears at the cell they
pressed `E` on. That also explains why the engine's unconditional `& 0x3f` wrap is wrong
for site sectors: the original tests the unmasked coordinate first and only masks when the
test does not fire.

### What this does to the CP5/CP6 plan

* Town entry is **not** blocked behind F3. The machinery is six steps and a digit, and the
  engine already loads any sector a save names — sector 32 renders and plays today.
* The one unknown is the gate value of `DS:14` on the world map. Registered as **G28** on
  `docs/needs-gameplay.md`, agent-drivable: stand on each cell of a world sector, press
  `E`, and record the first cell where the answer is not ` WHAT?`, with `DS:14` beside it.
* The edge test belongs to the movement path and is independent of the gate, so it can be
  implemented and tested now.
