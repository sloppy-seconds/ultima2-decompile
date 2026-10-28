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

## What a new game is — there is no default game state

Asked directly on 2026-10-23, because CP5 wanted a character to fight with and the
engine's `--play-map` entry was running on a zeroed state. The assumption worth
testing was that the original keeps a stock starting character somewhere.

It does not. **`DS:36` is the first byte of the character name**, and that single
byte is the whole "is there a game yet?" test:

| evidence | grade |
| --- | --- |
| `asm/5400`: `cmp byte [0x36],0` gates the character-creation flow | observed |
| `state.h` declares `/* 0x36 */ uint8_t name[16]` | observed |
| across 107 `player` files harvested from `tmp/` run dirs, `file[0]` equals the first byte of the name in every one: `TEST`→`0x54`, `AIRTEST`→`0x41`, `STRANGER`→`0x53`, `SHOPTEST`→`0x53`, `G23MAX`→`0x47`, `AGENT34`→`0x41`, `ARTTEST`→`0x41`, and `0x00` wherever the name is empty | measured |

The record is the file's first 256 bytes, so `file[0] == DS:36`. The blank `player`
file shipped on the disk is all zeros, which means an empty name, which means
"generate a character". So:

* **a new game is not a state, it is the absence of one** — the creation flow is the
  starting state, and it is reached by the same test on every boot;
* the engine needs no stock character and must not invent one. `u2_save_ensure`
  seeds a missing `PLAYER` from the pristine blank template, which is byte-identical
  to the shipped disk image, and `DS:36 == 0` then routes to creation exactly as the
  original does. Being faithful and being pragmatic are the same code path here,
  which is the sign that the mapping is right;
* `--play-map` now loads the record first, as the title's own `P` path already did
  (`title.c` `run_play`). Before this it entered the world on zeros, so a scripted
  fight could not be shown at all: `agi` 0 never lands a hit, and the sector was
  whatever the zero bytes happened to say.

## 8. The saved window is not the same set as the saved fields (found 2026-10-29)

The record is 256 bytes at `DS:36`, and the game saves that whole span — but some bytes inside
the span are **runtime state that happens to live there**, and they do not survive a round trip
through the original unchanged. The first one measured:

| byte | field | why it is not save state |
| --- | --- | --- |
| `DS:74/75` | `speed` | `asm/06AC_clock_tick_wait` calibrates it at **every** startup by counting busy passes inside a 20-tick `INT 1Ah` window. The engine has no clock calibration, so its mirror holds 0; the original writes whatever this machine measured. |

Observed directly: the engine wrote `00 00` there, the original loaded the record and its live
`DS:74` read `04 3a` (0x3A04 — the same neighbourhood as the documented 0x3A17 measurement in
`docs/spice86-live-findings.md`). So a byte-for-byte "our file vs the original's memory"
comparison can never be exact across those two bytes, and a harness that demanded it would be
asserting that the engine should fake a clock calibration it does not have.

This matters for anyone writing a save comparison: **exclude by name with a reason, and print
what both sides held.** A tolerance that prints nothing is indistinguishable from a tolerance
that never fired.

## 9. Cross-loading with the original — `tools/save_cross_load.py`

Local, on demand, **not in CI and not in `make test`**. Two reasons, both owner decisions
2026-10-29: it needs `original/` and `references/`, which are gitignored by policy, and
re-running it on every push would be measuring a game binary that has not changed since the
last time it passed.

**Run it when save handling changes**: `engine/src/core/save.c`, the write-back in
`engine/src/core/world.c`, the DS layout in `engine/src/core/state.h`, or the harness itself.

```sh
python3 tools/save_cross_load.py                  # A only, no emulator, a few seconds
python3 tools/save_cross_load.py --with-emulator  # A + B, boots the original, about a minute
```

* **A, original -> engine.** Loads a real record (default `references/ultima2/player`) and
  asserts `DS:36..0x135` matches the file byte for byte. Proves our *reader*.
* **B, engine -> original.** Builds a record with the engine's own reader and writer, boots the
  original with it, presses `ESC`+`P`, and peeks `DS:36..256` out of the live process. Proves
  our *writer* produces a file the real game accepts. It checks the name at `DS:36` first, so a
  green means the original loaded **our** character rather than sitting on a title screen.

Both directions pass as of 2026-10-29. Two things learned doing it, both now encoded in the
harness rather than left as prose:

* the shipped `references/ultima2/player` is the **blank creation template**, and the original
  will not "load previous character" from it — the first attempt read `DS:13 = 0x00` and a blank
  name. Direction B therefore starts from the engine's own seed record, which is the thing under
  test anyway.
* the live peek is read from memory, not from the run dir's `player` file, because the game
  rewrites that file as it plays and it is not a stable witness.

`engine/tests/save_check.c` still owns the byte-format assertions in CI: it runs on
engine-authored filler and proves sizes, offsets and tail preservation. What it cannot prove is
that the real game accepts what we write, and that is the gap this harness closes.

## 10. What the game writes back: the player record, and the outdoors sector (measured 2026-10-29)

**Corrected the same evening.** The first version of this section said the player record was
the only thing the game ever writes. That was wrong, and it was wrong because the save that
would have shown otherwise had silently refused. The full picture, measured with
`captures/spice86/save-wilderness`:

| action | what lands on disk |
| --- | --- |
| crossing a site edge (leave or enter a town) | **nothing** but nothing at all — `mapx`/`monx` byte-identical to pristine |
| `Q` outdoors, gate satisfied | `player`, **and `mapxNN` and `monxNN` of the sector you are standing in** |
| `Q` inside a town | refused: `ONLY OUTDOORS!`, nothing written |
| `Q` outdoors with `DS:6D != 0` | refused: `ONLY ON EARTH!`, nothing written |

So the save is real and it does persist the world — but only the **outdoor** sector, and only
when its gate passes. The owner's reading of why, offered before the measurement and borne out
by it: the overworld is the persistent world, and towns and dungeons are instances the game
declines to save at all. That is a design, not an oversight, and it is why "towns reset when
you enter them" is true even though the engine has a working sector store.

What a wilderness save actually wrote, in sector 30, against the pristine file:

* **`mapx30`: 3 cells**, each a creature standing on that cell at the moment of the save —
  `0x0C -> 0x30`, `0x0C -> 0xFC`, `0x08 -> 0x30`. The saved grid is the **stamped** grid, not
  the authored terrain. This is the mechanism behind `docs/map-format.md` § 9's odd fact that
  shipped `mapx` files contain creature art baked into the terrain: somebody saved a game with
  monsters standing there.
* **`monx30`: 15 bytes**, three creature slots (29, 30, 31) that were empty in the shipped
  file and now carry x, y, hp, type and kind. Those are wandering spawns, persisted.

### The engine now implements the guards, and enhanced mode drops them

`u2_overworld_save()` runs all three, in the order the bytes put them, behind `u2_save_policy`
so the save path never branches on fidelity: `U2_SAVE_POLICY_ORIGINAL` refuses, and
`U2_SAVE_POLICY_ENHANCED` (selected by `--enhanced`) allows all three, which is the owner's
"save anywhere" of 2026-10-29. Gate: `engine/tests/save_gate.py`, wired as CP5 V3.

Two things that fell out of implementing it:

* The engine had the outdoors guard and had stubbed the other two as "cannot happen until
  CP6/CP7" — vehicles exist now, and `DS:6D` turned out to be a live byte rather than a planet
  counter. A guard left stubbed because the state that feeds it looked unreachable is a
  standing invitation to this exact mistake.
* Making the on-foot guard real broke `vehicle_board.py`, which observed the tile BOARD leaves
  by saving and reading the sector back — and the original cannot save while aboard a vehicle.
  The gate was not wrong about the rule, only about the route to the disk, so that one case now
  saves under `--enhanced` and says why in its comment. `save_q_check.c` also had to be fixed:
  it hand-rolled a world without the on-foot stamp, which is a state the game cannot be in.


### `DS:6D` is the world byte, and our own tool named it wrong

`DS:6D` is **which world the player is on**: 0 = Earth, 1..9 = the planets, 0x0A = deep space.
`asm/3DFA`'s `ONLY ON EARTH!` is a literal description of the save test, not a metaphor.

The byte was called `boots_count` for two years because of a bug in our own tooling.
`tools/u2_edit.py` defined a `boots` field at `DS:6D` and `maxout` wrote `1` into it, so every
maxed test character was silently standing on planet 1 — and `state.h` then named the field
after the write our editor was making. Boots are `items_held[BOOTS]` at `DS:D9`, which is what
the paralysis resist actually reads. That also retires the `STALE COPY` note that used to sit
against the field: a byte that never was boots did not change when a thief took the boots,
which was never a paradox about the game at all.

The evidence is in `asm/7030_space_collision`, the only writer of the byte in the tree: it
stores `0x0A` beside `YOU ARE IN DEEP SPACE.`, stores a world index beside `YOU ARE ORBITING `,
dispatches on `cmp $0x0`/`$0x1`/`$0x2`…, and answers `cmp $0xa` in the landing path with
`REQUEST DENIED!`. Then `mov 0x6d,%al ; mov %al,0x49` copies it into the sector **tens** digit,
so the world and the high digit of the sector number are the same value. The shipped `player`
record carries `0x00` there — Earth, and therefore savable.

Practical consequence, now fixed: `maxout` no longer writes `DS:6D`, so a maxed character can
save again. Any test character built by an older `maxout` and left on disk is sitting on planet
1 and will refuse `Q` until the byte is cleared with `u2_edit.py set <file> world 0`.

**The sweep was run on 2026-10-29.** 271 save-shaped files were scanned across the project and
`/var/tmp/u2`; 171 carried `world = 1` and 147 were repaired through the tool and re-verified
(size still 384, byte reads 0). Every working seed is now on Earth — `engine/saves/PLAYER`,
the container's `spice86-runs/seed-player`, and the scratch characters under `/var/tmp/u2/`.
Two groups were deliberately left alone:

* **`captures/spice86/cp5-g26-layout/player`** — a named capture is the evidence record. That
  file legitimately recorded a character on planet 1, and rewriting evidence to tidy up a tool
  bug is exactly the kind of edit that makes a corpus untrustworthy.
* **23 files under `/var/tmp/u2/spice86-runs/*/player`** — dead per-launch copies, and they are
  owned by **root** because the container ran under `sudo podman` before that was fixed today.
  They cannot be repaired without sudo, and nothing will ever load them again.

