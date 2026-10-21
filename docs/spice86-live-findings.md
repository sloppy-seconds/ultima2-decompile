# Live capture findings — 2026-10-21

First session running the original under the vendored Spice86 with live memory
instrumentation. Everything here is observed, not inferred. Where it contradicts
the static analysis in `docs/phase4-implementation.md`, this file is right and
that file carries a retraction.

Tooling: `tools/spice86_start.sh`, `tools/spice86_stop.sh`, `tools/spice86_common.sh`.
Session: sector 20, character `TEST`, run dir `tmp/20261021-063019/`, harvest
`captures/spice86/create-test-live/` (901 blocks, 147 partitions).

## 1. Overworld passability is real and tile-based

The overnight CP4b claim that the walk loop never rejects a step was **false**.

| action | observed |
| --- | --- |
| EAST from (20,20) onto tile `0x00` | screen printed `CMD: EAST--INVALID MOVE!`; `DS:00` went 20 → 21 → back to 20 on **every** press |
| SOUTH onto tile `0x0C` | `DS:01` advanced 20 → 21 → 22 → 23 → 24 → 25, every step stuck |

The rollback happens **before the redraw**, which is why no screenshot could
ever have shown the illegal position and why the measured viewport evidence
never hinted at it. The owner's model — move, check the new tile, bounce back
without drawing — is confirmed.

Observed tile verdicts so far (only these two are proven):

| tile | verdict |
| --- | --- |
| `0x00` | **blocked** on foot (water) |
| `0x0C` | **passable** |

`mapx20` contains `0x00, 0x04, 0x08, 0x0C, 0x10, 0x18, 0x20, 0x24`; the rest are
unmeasured. The owner predicts a boat sitting on a water tile makes it
passable — plausible (the tile art set contains a ship, and `cmd_X` allows
casting over `0x00` only when the mode is `0x24`) but **untested**.

### Why the static read failed

The passability function was re-decoded as file `0x268B..0x2743` and treated as
complete. It is not: execution falls through at `0x2745` and continues to about
`0x2880`. The missing tail contains the decision:

* **accept** — runtime `0x2664` (file `0x2864`):
  `x &= 0x3F; y &= 0x3F; mov al,0; ret`. The overworld *does* wrap through the
  torus mask on an accepted move — the reading the project had previously
  retracted is back in play for this path.
* **reject** — runtime `0x25FF` (file `0x27FF`): `mov al,0xFF; cmp al,0; ret`.
* two inline copies of the `-19` food drain, runtime `0x2599` and `0x2626`.

Roughly 200 bytes short of the behaviour, and the absence was asserted anyway —
a direct violation of the standing rule that a negative result from a probe not
designed to detect the thing is not a negative result. What caught it was the
live CFG harvest, which enumerated the nine blocks calling the tile reader
(`0839, 2677, 2233, 2708, 0CDC, 212E, 215C, 216E, 2216`) in seconds.

## 2. Time and food, corrected

| event | food cost | evidence |
| --- | --- | --- |
| accepted move | **−19** | `039538 → 039519 → 039500 → 039481 → 039462` |
| idle auto-PASS | **−10** | owner observed the game passing itself when left idle; deltas match `sbb $0x0a` at file `0x0B0D` |

Both falsify notes in the CP4b report: "movement does not tick" (the −19 drains
are inline in the passability function, reached through a dispatch static grep
could not follow) and "no idle timer, so auto-PASS not implemented".

A fresh character holds `04 00 00` = 40000 units, displayed as `FOOD=0400`
because the band prints only `DS:53/54`. At 19 per move that is roughly 2100
moves to starvation; at 10 per idle tick, 4000 ticks.

Death on underflow jumps to runtime `0x248D`. Note the `stc; cmc; sbb; das; cmc`
idiom leaves carry inverted, so the following `jb` means "no borrow" — the
branch structure reads backwards unless you account for the trailing `cmc`.

## 3. Segment-register facts, live

`DS = 0x08BE` confirmed at the title screen and in the world (the capture doc's
value is right). Live landmarks that validate the read:

* `DS:26E` = `0E 19 05 17` — the direction codes, exactly as proven statically.
* `DS:5B0` = `30 06 72 06 B4 06 F6 06 …` → `0x0630, 0x0672, 0x06B4, 0x06F6`,
  deltas of exactly **66** — the tile index table stride, seen in live memory
  for the first time.
* Sector buffer is loaded at `DS:1800` (read from `DS:0x472`).
* The map buffer really holds `0x78` at the player's cell, because the game
  stamps the figure into the map data.

Corrections to field meanings:

* **`DS:13` is the player's own tile id**, not the travel mode. The Q-save
  "on foot" guard reading `DS:13 >= 0x78` needs revisiting.
* The walk loop passes `[DS:15]` to the passability call, and `DS:15` was
  observed **changing between moves** (`0x84, 0x06, 0x18, 0x98`). The mode
  dispatch is therefore not understood. Left open rather than guessed twice.

## 4. Character creation writes the save immediately

The record on disk after creating `TEST` was a complete, loadable character —
name, sector `2 0`, entry pair `20 20`, stats, hp `0400`, gold `0400`, and the
`0x1A` tail marker — even though `Q` was never pressed. Creation itself saves;
this matches the decoded creation tail ("sets entry pair, saves, clears, prints
TO PLAY ULTIMA"). Position itself is not in the record; the entry pair `DS:5A/5B`
is, and that is what `P` restores from.

Food in the saved record stayed `040000` while memory had drained to `039443`,
confirming the drained value only persists on an explicit save.

## 5. Spice86 tooling behaviour (measured, cost real time)

* **The CFG is not scraped from the API.** Spice86 writes it itself:
  `spice86dumpCfgBlocks.json`, `CfgPartitions`, `ExecutionFlow`, `MemoryDump`,
  `CpuRegisters`, `CfgReload`. The schema matches the committed
  `captures/spice86/spice86-cfg.json` exactly, confirming how the Phase-1
  artefact was produced.
* **`monitor dumpAll` is camelCase.** Lowercase `dumpall` is silently ignored
  and looks like a successful gdb call that writes nothing.
* **Headless and windowed Spice86 both ignore SIGTERM and SIGINT** — each sat
  through until SIGKILL. No signal produces the exit dump, so a harvest cannot
  depend on one: `stop.sh` forces `dumpAll` over the GDB port while alive and
  treats signalling as teardown.
* **`-r` does not pin the dump path.** Spice86 appends a subdirectory named
  after the SHA-256 of the emulated exe (`D7CC110C…` for `ultimaii.exe`).
* **Windowed Spice86 crashes under heavy API polling.** At ~40 req/s:
  `InvalidOperationException: Collection was modified` in
  `CfgCpuViewModel.CreateBlockHeaderTableEntry` (CfgCpuViewModel.cs:459) — a
  race between the CFG graph panel and the emulation thread. Keep polling to a
  few Hz and read one contiguous range.
* **`setsid --fork` reparents the emulator**, so `$!` is the dying setsid. The
  real pid is found by the unique free port the launcher picked.
* **`GET /api` self-documents**; `/api/status` reports CS:IP and cycles but not
  `DS`, and `/api/memory/<physical>/range/<n>` takes a physical address.
* The vendored build's own `--help` is the authority on options; upstream
  `main` differs (it documents `--mcp-http-port`, ours takes `--McpHttpPort`).
  Note `-h` is bound to **both** `--help` and `--HeadlessMode`.
* Harvest output must stay out of git: it lands in `captures/spice86/<label>/`
  subdirs, which the old top-level-only ignore patterns did not cover.

## 6. Open questions

1. The full passable-tile set for on-foot travel (only `0x00` blocked and `0x0C`
   passable are observed).
2. Whether a boat on a water tile makes it passable.
3. What `[DS:15]` actually is, and the real mode-dispatch semantics in the
   passability tail.
4. Monster record layout — the `DS:0x137` stride-`0x20` guess from the capture
   doc produced nonsense (`x=134, y=0, tile=0xFF`); derive it from the asm and
   a before/after diff instead.
5. Monster movement and combat — a monster was observed following the player;
   whether it engages, and at what range, is not yet captured.
6. Whether the `& 0x3F` accept-path wrap means the sector edge is a torus after
   all, and how that squares with the `DS:6E` arrival system.

## 7. Combat and monsters (second session, `play-test`)

Captured by diffing the CFG before and after a fight: 150 blocks appear only in
the post-fight harvest, which pins the combat code far more precisely than
reading the listing did.

### Controls (owner correction, recorded because my guess was wrong)

* `R` is **not** a combat key. `cmd_R` (`asm/3E50`, "READY WEAPON:") equips or
  swaps the readied weapon. With nothing in inventory there is nothing to swap,
  and the character fights bare-handed.
* `A` is the attack (`cmd_A`, `asm/2B8F`, prints `ATTACK--`).
* Arrow keys set facing/direction, and are also the dungeon turn keys.

### The attack path, from the new blocks

| runtime | what it does |
| --- | --- |
| `0x2BFB` | damage basis: `AL = [DS:61]` (readied weapon) `*8`, `adc [DS:4B]` (strength), then `rcr` twice — weapon and strength combine into the attack value |
| `0x2C2D` | `cmp [DI+0x197], 0x40` — monster slot active/sentinel check |
| `0x2CB5` | stamps `[DI+0x1B7]` (monster sprite) into the map cell |
| `0x2CD3`/`0x2CE5`/`0x2D22`/`0x2D60` | dispatch on the monster sprite: `0x60`, `0xFC`, `0xF0`, `0xF8` — distinct handlers per monster kind |
| `0x2D8C` | **kill**: zeroes `[DI+0x1B7]`, `0x177`, `0x137`, `0x157`, `0x197` — the whole monster record is cleared |
| `0x2DC1` | **gold award**: BCD `adc` into `DS:58/59` |
| `0x2DEE` | **exp award**: BCD `adc` into `DS:56/57` |
| `0x0C09` | **damage to player**: `sbb [DS:22]` from `DS:51` (HP), `das`, and `jae` to the death path |

So `DS:22` is the damage-about-to-be-applied scratch byte, and player damage and
death are the same BCD-subtract-and-test shape as the food drain.

### Monster record layout — the capture doc is wrong

Three **parallel byte arrays, stride 1**, 32 slots — not stride `0x20`:

```
x[i]    = DS:0x137 + i
y[i]    = DS:0x157 + i
sprite  = DS:0x1B7 + i
active  = DS:0x197 + i      (0x40 = empty sentinel, per 0x2C2D)
```

Reading it with stride `0x20` produces plausible-looking garbage, which is
exactly how I lost time on it earlier.

### Monsters move on the idle tick, and the world wraps

Observed while the player stood still at (16,20):

* food fell exactly **10** every ~7.6 s of real time at `--Cycles 3000` — the
  idle auto-PASS interval;
* on the same cadence the monster positions stepped one cell, i.e. **idle time
  advances monsters**. Standing still is not safe;
* monster 30 went `x = 63 -> 0 -> 1 -> 2`, direct live confirmation of the
  `& 0x3F` torus wrap in movement, independent of the accept-path instruction.

### Monsters are RNG-spawned, and the emulator makes them repeatable

`monx20` contains exactly one non-zero byte (`0x1A`, the tail marker), so
monster placement cannot come from the file — it is generated. The seed is taken
once at launch from the BIOS keyboard flags at `0x40:6C`, which in a freshly
started emulator is the same every time. Hence the owner's observation that it
was "the same monster as last time": it is not carried by the save, it is an
artifact of a frozen entropy source.

Worth stating plainly for the engine: our reproducibility comes from substituting
the clock and exposing `--seed`; the original under emulation is reproducible
only by accident. Do not mistake emulator determinism for game determinism.

### Also observed

* Walking into a **mountain** produced `--INVALID MOVE!` (owner report), so
  blocking is not water-only. The mountain's tile id was not captured — needs a
  read while standing next to one.
* Crossing a **land bridge** was accepted.
* Player HP fell `0399 -> 0397 -> 0396 -> 0395` during the logged fight.
* New walk-loop blocks `0x09AF` (`mov AL,[DS:18]; call 0x2423`) show the
  passability routine is called with `[DS:18]` from at least one arm, not only
  `[DS:15]` — so the "travel mode" argument has more than one source and the
  mode dispatch is still not fully understood.

## 8. Kill rewards — full loot model (resolved offline, no capture needed)

Derived from the harvested blocks cross-read against `asm/`. The harvest's
runtime addresses key directly onto the asm filenames, so `017D:2D8C` is
`asm/2D8C_combat_kill_reward.asm`.

### Sequence on a kill

1. **Per-monster-kind bonus**, dispatched on the monster sprite byte
   (`DS:1B7+i`) at `0x2CD3..0x2D8B`:

   | sprite | effect |
   | --- | --- |
   | `0x60` | `DS:65` (keys) `+= 2` |
   | `0xFC` | `DS:66` (tools) `+= 1`, **and** roll an item drop (below) |
   | `0xF0` | `DS:DB` `+= 1`, gated on `rand >= 0x40` |
   | `0xF8` | separate branch, not yet read |
   | other | straight to the reward |

2. **`0x2D8C` `combat_kill_reward`** — zeroes the whole monster record
   (`0x1B7`, `0x177`, `0x137`, `0x157`, `0x197`) and prints
   `KILLED--GOLD+`.

3. **Gold** at `0x2DB7`/`0x2DC1`: amount = `(rand & 0x17) | 1`, BCD-added into
   `DS:58/59`.

4. **Exp** at `0x2DE4`/`0x2DEE`: amount = `(rand & 3) + 1`, BCD-added into
   `DS:56/57`.

5. **Item drop** at `0x2D03`/`0x2D07`: `idx = rand & 0x0F`, then
   `DS:D6+idx += 1` (BCD). Only reached from the `0xFC` sprite branch.

So the owner's report — exp, gold *and* an item from one kill — is exactly the
`0xFC` path, and the item drop is not generic loot, it is specific to that one
monster kind.

### The item array, and its name table

`DS:D6+0..15` are **item counts**, sixteen slots, and the `rand & 0x0F` index
range matches the sixteen-entry item-name table in the binary exactly:

```
file 0x501d  [ 0] RING       [ 4] CLOAK      [ 8] RED GEM      [12] BLUE TASSLE
             [ 1] WAND       [ 5] HELM       [ 9] SKULL KEY    [13] STRANGE COIN
             [ 2] STAFF      [ 6] GEM        [10] GREEN GEM    [14] GREEN IDOL
             [ 3] BOOTS      [ 7] ANKH       [11] BRASS BUTTON [15] TRI-LITHIUM
```

Index 16 is `STRENGTH`, where the attribute table starts, so the sixteen-entry
boundary is real and not a parsing artifact.

Corroboration that this table is the right one: block `0x487A` special-cases
index **3** in the item display path, and index 3 is `BOOTS`, the only item with
bespoke messaging elsewhere in the binary.

### Measured final state, from the harvested memory dump

`DS` base `0x8BE0`, read out of `spice86dumpMemoryDump.bin`:

```
hp 0184 (184)   food 036244   exp 0010 (10)   gold 0452 (452, started 400)
str 0x50  dex 0x12  int 0x18   boots DS:6D = 00 (none)   ready DS:61 = 00
DS:76..0x8D  all zero          <-- NOT the inventory
DS:D6..0xED  00 00 01 00 00 00 00 00 00 00 01 00 00 00 00 00
             index 2 = STAFF, index 10 = GREEN GEM
```

The save file mirrors the same array at **save offset `0x0a0`**, holding only
index 2 — so the green gem was picked up after the last save. Save and live
memory agree.

### Resolved: there was never a gem discrepancy. I miscounted.

An earlier draft of this section claimed the second item sat at index 12
(`BLUE TASSLE`) and contradicted the owner's memory of a green gem. It does not.
`DS:D6[10] = 1`, and index 10 is `GREEN GEM`. The owner was right throughout.

The error came from splitting a hex string by eye instead of computing it, and
then reasoning confidently from the miscount. The table was never wrong.

The display confirms the table independently: `asm/4881` prints a literal `"S"`
for the plural, and `0x487A` skips that `S` when the index is 3 — which is
`BOOTS`, the one already-plural entry. So the screen rendering `STAFFS-01
GREEN GEMS-01` is `STAFF` + `S`, `GREEN GEM` + `S`, from the table at
`0x501d`. Index 3 being the special case is the proof that this table is the one
in use.

**Method note worth keeping:** derive indices in code, never by reading hex
aloud. Every other error this session came from an ambiguous byte; this one came
from arithmetic I did not do.

### Paralysis resist — now backed by a string, not just a byte test

`asm/0E70_combat_paralyzed_legs.asm` already exists and carries both
`LEGS PARALIZED!` and `SAVED BY MAGICAL BOOTS!`. The boots test seen at
`0x22FD` (`mov AL,[DS:6D]; or AL,AL; je ...; ret` — return early when boots are
present) is consistent with it. Still not proven to be the *same* call site as
the paralysis event; the string file and the boots gate have not yet been joined
by a traced edge.

### Theft

`asm/3F5D_steal_attempt.asm` holds the thief outcomes: `NO LUCK!`,
`STEAL FOOD!`, `STEAL ARMOUR!`, `STEAL WEAPONS!`. The matching decrement path
is `0x0FE7`: `sbb AL,1; das; mov [DI+0xD6],AL` — the inverse of the drop at
`0x2D07`, operating on the same item-count array. So a thief can remove an item
from `DS:D6+i`.

## 9. Provenance cross-reference, and a corpus defect it caught

`tools/xref_provenance.py` makes the docs <-> asm link machine-checkable in both
directions: every `asm/XXXX` citation in `docs/` must resolve to a real function
range, and every named function should carry a `# provenance:` line saying
whether its behaviour is `static` (read from the listing), `live:<harvest>`
(observed), `owner` (reported, not yet seen in bytes) or `retracted`.

Bare `0xXXXX` mentions are counted but not resolved: the first run flagged 47
" dangling" citations and nearly all were data addresses, segments or constants
like `0x9000` and `0x00FF`, not function references.

First run over the existing corpus:

```
functions parsed              1298  (named: 111)
named functions cited in docs   21
named functions with provenance  0 / 111
dangling asm/ citations           2   (asm/0964, asm/5002)
```

So 90 of 111 named functions are never cited by any finding, and none record
whether anything about them was ever observed rather than inferred. That is the
condition that let the T1 misreading stand for an hour as a confident finding.

### Defect: `2DC1` and `2DEE` are misnamed in `asm/`

`asm/2DC1_combat_exp_gain.asm` adds `DS:1F` into `DS:58/59`, which is **gold**
(`engine/src/core/state.h` pins `0x56/57 = exp`, `0x58/59 = gold` with
`_Static_assert`, cited to the display sites), and only *then* prints
`--EXP.+`. The string introduces the following operation, `2DEE`, which is the
one that writes `DS:56/57`. The namer assumed a printed string describes the
function that prints it.

Independent confirmation from the arithmetic and a live read: `2DC1` adds
`(rand & 0x17) | 1`, i.e. 1..23, and `2DEE` adds `(rand & 3) + 1`, i.e. 1..4.
The harvested dump had `DS:58/59 = 452` against a starting 400 and `DS:56/57 =
10` against a starting 0. Swapping them would require gold to have fallen 400 ->
10, which cannot happen from a reward path.

Correct reading: **`2DC1` = gold gain, `2DEE` = exp gain.** The filenames are
transposed. Renaming corpus files is a CP3-wide convention change, so this is
recorded rather than applied unilaterally.

### Corrected: the reward sequence, and why the boundary caused the mislabel

Owner's reading, confirmed against the blocks: each message announces the award
that *follows* it, not the one preceding it.

```
2D8C  clear monster record, print "KILLED--GOLD+"   <- announces the gold below
2DB7  gold_amount = (rand & 0x17) | 1  -> DS:1F
2DC1  DS:58/59 += DS:1F                  (GOLD)
      print "--EXP.+"                                <- announces the exp below
2DE4  exp_amount  = (rand & 3)  + 1  -> DS:1F
2DEE  DS:56/57 += DS:1F                  (EXP)
```

The string `--EXP.+` lives at the tail of the block CP3 named `2DC1..2DE0`, while
the exp roll and add are `2DE4` and `2DEE`. The block boundary cuts through the
middle of one semantic unit, so "the function that prints `--EXP.+`" and "the
function that awards exp" genuinely are different files. Both renames are now
applied: `2DC1_combat_gold_gain.asm` and `2DEE_combat_exp_gain.asm`, each citing
the display site that proves which pair it writes.

**Every kill awards both, minimum 1 each.** Neither roll can produce zero: the
`| 1` on the gold mask forces an odd non-zero value, and the exp roll is
`(rand & 3) + 1`, i.e. 1..4. So gold is not a chance drop; only the amount is
random. The item drop at `0x2D07` is the part that is conditional, and it is
gated on the monster sprite being `0xFC`.

### Also: `asm/2423` declares a boundary that is wrong, and it is on purpose now

`asm/2423_sub_2423.asm` declares `func 2423..242C`, ten bytes, while the
passability routine runs to roughly runtime `0x2680`. Reading only that file
makes the routine look like it performs no rejection whatsoever, which is exactly
how the static pass on 2026-10-21 produced the retracted "no passability"
finding. The file now carries a WARNING and a provenance line so the next reader
does not repeat it. The boundary itself is still wrong and needs a CP3 re-decode
of `2423..2680`.

### Also already named, from the same listing

`asm/` already contains `0E70_combat_paralyzed_legs`, `0EC2_combat_paralyzed_arms`
(two distinct paralysis effects, not one), `0FCD_combat_thief_steal`,
`0F12_combat_magic_missile`, `0F48_combat_sleep_spell`, `0F8E_combat_minax_attack`,
`2BEC_combat_hit_msg`, `2E09_combat_miss_msg` and `2E3D_combat_attack_flow`. The
thief-steal and paralysis questions raised during live play had named functions
sitting in the tree the whole time.

## 10. The screen is recoverable from the memory dump — `tools/vga_screen.py`

The owner's question: is the fight and reward text that Spice86's UI fails to
show actually present in the captured data?

**Yes.** Ultima II runs in a text video mode. The dump's framebuffer at `B8000`
is character/attribute pairs — 16384 bytes, exactly half printable — so the
screen as the player saw it renders straight out of a capture we already have.
No trace and no replayer needed.

```
 0| TEST                        A LEVEL 00 MALE HUMAN FIGHTER
 1|                             WEAPON-HANDS        TORCHES-00
 2|   ARMOUR-SKIN    KEYS-00    SPELL-NONE          TOOLS-00
 3| STRENGTH-50  STAMINA-18  WISDOM-10  AGILITY-12  CHARISMA-10  INTELL.-15
 4|                             WEAPONS:
 6| ARMOUR:
 7| SPELLS:
 9| ITEMS: STAFFS-01 GREEN GEMS-01
```

Diffing two harvests shows the gain directly: the earlier dump has a bare
`ITEMS:` and the later one has `ITEMS: STAFFS-01 GREEN GEMS-01`.

### The honest limit

This is a **snapshot at dump time, not a recording**. Both dumps above caught the
inventory screen, and the combat messages had already scrolled away. So the
missing fight text is not preserved retroactively; it is preserved only if the
dump happens while it is still on screen.

Consequences for how we capture:

* dump immediately after an event of interest, before the player scrolls it off;
* a real replayer would need Spice86's execution-trace recording, which the
  current start script does not enable — the harvest holds CFG, execution flow,
  registers and one memory snapshot, and no per-instruction trace;
* cheap middle ground: poll the framebuffer at a few Hz into a ring of dumps, so
  the last few screens survive any event.

That last one is worth building before the next fight, because it converts "I
missed the text" into "read the last screen".

## 11. Offsets and lookup tables for a save / live-memory editor

Everything here was written and read back through the Spice86 MCP on a live
session on 2026-10-21, so the DS column is byte-proven. The save column is
partly inferred and marked as such.

> **Layout authority: `engine/src/core/state.h`, not this table.** This section
> is the live *evidence*; the struct is the *table*, because it is compiled and
> every named field is pinned by a `_Static_assert`, so drift there is a build
> failure rather than a stale document. Per `AGENTS.md § 3` there is one lookup
> table per domain and derived views are generated, not hand-kept. Where the two
> disagree, `state.h` wins and this section is the bug. Two entries below are
> already known to be wrong and are corrected in the struct: `0x13` is the
> player stamp, not a "player tile id", and `0x20` is scratch, not an
> invalid-move counter.

### Live data segment

`DS = 0x08BE` this session. The MCP takes **decimal** integers for segment and
offset, not hex strings: `segment=2238, offset=75`.

| DS | field | encoding | notes |
| --- | --- | --- | --- |
| `0x00` / `0x01` | player x, y | byte | **viewport** coords; masked `& 0x3F` on accept |
| `0x13` | player tile id | byte | `0x78` = on foot |
| `0x20` | invalid-move counter | byte | increments on each rejected step |
| `0x23` / `0x24` | attempted destination | byte | valid to read on a reject; nothing scrolls |
| `0x49` / `0x4A` | sector hi / lo | byte | |
| `0x4B` | STRENGTH | BCD | |
| `0x4C` | AGILITY | BCD | gates weapon equip: `index*8 < AGILITY` |
| `0x4D` | STAMINA | BCD | |
| `0x4E` | WISDOM **or** CHARISMA | BCD | order not provable from this character — see note |
| `0x4F` | CHARISMA **or** WISDOM | BCD | order not provable from this character — see note |
| `0x50` | INTELLIGENCE | BCD | attribute order is STR, AGI, STA, WIS, CHA, INT |
| `0x51` / `0x52` | HP | BCD, high pair first | `0x40 0x00` = 4000 |
| `0x53..0x55` | food | BCD, 3 bytes | the turn odometer: -19 per move, -10 per pass |
| `0x56` / `0x57` | EXP | BCD | display site runtime `0x5167` loads `[56]`,`[57]` |
| `0x58` / `0x59` | GOLD | BCD | display site runtime `0x5188` loads `[58]`,`[59]` |
| `0x61` | readied weapon | index | into the weapon table below; `0` = HANDS |
| `0x62` | worn armour | index | into the armour table below; `0` = SKIN |
| `0x64` / `0x65` / `0x66` | torches / keys / tools | BCD | |
| `0x6D` | boots | count | non-zero gates the paralysis save at runtime `0x22FD` |
| `0x76 + i` | weapons owned | count | `i` indexes the weapon table |
| `0xD6 + i` | items held | count | `i` indexes the item table, 16 slots |
| `0x137+i` `0x157+i` `0x1B7+i` `0x197+i` | monster x, y, tile, kind | byte | stride 1, 32 slots |
| `0x23F..0x244` | PRNG state | 6 bytes | |
| `[0x472]` | sector map buffer | 4096 B | 64x64 tile bytes, player and monsters stamped in |

### Name tables (file offsets in `original/ultimaii.exe`)

Weapons, from `0x4F53` — `DS:61` and `DS:76+i` index this:

```
0 HANDS   1 DAGGER  2 MACE    3 AXE     4 BOW     5 SWORD
6 GREAT SWORD       7 LIGHT SWORD      8 PHASER  9 QUICK SWORD
```

Armour, from `0x4F9E` — `DS:62` indexes this. Eight entries, which is why the
damage roll is masked `& 7`:

```
0 SKIN  1 CLOTH  2 LEATHER  3 CHAIN  4 PLATE  5 REFLECT  6 POWER  7 NONE
```

Items, from `0x501D` — `DS:D6+i` indexes this. Exactly sixteen entries; index 16
is `STRENGTH`, where the attribute table begins.

```
0 RING      1 WAND      2 STAFF     3 BOOTS     4 CLOAK     5 HELM
6 GEM       7 ANKH      8 RED GEM   9 SKULL KEY 10 GREEN GEM 11 BRASS BUTTON
12 BLUE TASSLE  13 STRANGE COIN  14 GREEN IDOL  15 TRI-LITHIUM
```

The display appends a literal `S` for the plural (`asm/4881`) and skips it for
index 3 only, because `BOOTS` is already plural — which is what proves this table
is the one in use.

### Not proven: which of `0x4E` / `0x4F` is WIS and which is CHA

The test character has WISDOM 10 and CHARISMA 10, so the live block cannot tell
them apart, and the save bytes match either reading. `engine/src/core/state.h`
labels `0x4E` as `stat_cha` and `0x4F` as `stat_wis`; an earlier draft of this
section asserted the opposite as fact and was not entitled to. Settle it with a
character whose WIS and CHA differ, or by reading the status draw code, before
any editor ships a label for those two bytes.

### Save file (`player`, 384 bytes)

| offset | field | confidence |
| --- | --- | --- |
| `0x00..0x0B` | name, NUL-padded | proven (`TEST`) |
| `0x15..0x1A` | STR, AGI, STA, WIS, CHA, INT | proven by value match against the live block |
| `0x22..0x23` | gold | proven by value match |
| `0x0A0..0x0AF` | item counts, same 16-slot table | proven by value match |
| `0x100` | `0x1A` | the DOS EOF marker, not data |

### Two traps for whoever writes the editor

1. **Packed BCD, not binary.** Writing `0x9A` into a counter produces invalid
   BCD and corrupts it. Validate both nibbles are `0..9`.
2. **The status band is a cached render, and `Z` pauses the game on it.** Writes
   take effect in memory immediately and combat reads them live, but the screen
   only repaints on the game's own status draw. A frozen `Z` screen will keep
   showing pre-write values, and while paused the game generates no turns, so a
   turn-triggered recorder records nothing.

## 12. Caster gauntlet, theft, force field and the plane tile (2026-10-21)

Harvests `captures/spice86/airport-castle` and `captures/spice86/castle-03-live`.
Turn evidence is 3000 per-turn DS+VGA snapshots from `tools/turn_recorder.py`,
kept in `captures/spice86/fight-20261021-castle03/` (`index.jsonl` plus `turns/`,
64 MB, gitignored as derived dumps of the copyrighted binary).

The session started by seeding a maxed character (`tools/u2_edit.py maxout`) into
sector 00 at (30,32), which turned out to be a walled compound holding 31
simultaneous monsters. Four of the seven monster types present cast, and the
owner's guess of "final boss" was wrong: `MINAX CRIES: DIE FOOL!` never executed,
and it is reached from a different site (file `0x126A`). Grade for everything in
this section: **measured**, from `ExecutedInstructions` plus live DS, not from
discovered blocks.

### The four monster specials, and what actually resists them

`asm/0AD3` dispatches on the monster type byte at `[DI+0x197]`:

| monster type | attack | function | resist item, live gate |
| --- | --- | --- | --- |
| `0x34` | `LEGS PARALIZED!` | `asm/0E70` | BOOTS, `[DS:D9]` |
| `0x38` | `ARMS PARALIZED!` | `asm/0EC2` | CLOAK, `[DS:DA]` |
| `0xF8` | `MAGIC MISSILE!` | `asm/0F12` | **none** |
| `0x3C` | `SLEEP SPELL!` | `asm/0F48` | GREEN IDOL, `[DS:E4]` |

The three gates are the item array slots themselves: `DS:D6+i` with BOOTS at `i=3`,
CLOAK at `i=4`, GREEN IDOL at `i=14`, which is the same order as the name table at
file `0x501D`. Arms and legs are independent counters (`DS:26B`, `DS:26C`) with
independent items, so a character can be paralysed in one and free in the other,
and both were observed non-zero at once (9 and 8) alongside sleep at `DS:26D`.

Two things that are easy to get wrong and are now settled:

1. **Owning the item is not immunity.** With the item present the roll from
   `L_005417` must be `>= 0x40`, so each is a roughly 75% resist. Without the item
   the effect lands unconditionally, with no roll at all.
2. **The magnitude is random, not fixed.** On a failed resist the counter is set to
   `rand & 0xF`, i.e. 0..15 turns.

`asm/0AAA` is the gate in front of the whole dispatch: `[DS:19] < 3`,
`[DS:1A] < 3`, and `rand < 0x20`, so a special is attempted on about 12.5% of
monster turns. `[DS:19]` and `[DS:1A]` are zeroed by the force field (below), which
is the only link found between the two systems; what the counters mean is not
proven.

### Correction: the boots gate is `DS:D9`, not `DS:6D`

Section 8 recorded a `[DS:6D]` test at runtime `0x22FD` as consistent with the legs
resist but untraced. It is the wrong byte. During this session a thief took the
boots, and `[DS:D9]` fell to 0 while `[DS:6D]` stayed 1 and the resist stopped
firing. `DS:6D` is the save-record slot and does not track theft; the live gate is
`[DS:D9]`, tested inside `asm/0E70` at file `0x108D`. Anyone writing a save editor
should treat the two as separate fields, not as one field with two spellings.

### Theft is permanent

`asm/0FCD` is the steal routine and it identifies the thief by type: the loop tests
the type byte against `0x40` at file `0x1244`, so **the thief is monster type
`0x40`**. Type `0x40` was present in the recording, which supplies the traced edge
section 8 said was missing.

Measured over the whole fight: eight items went `1 -> 0` (RING, GEM, ANKH,
TRI-LITHIUM, BLUE TASSLE, BOOTS, GREEN GEM, SKULL KEY) and **none ever came back**.
The kill that ended the fight paid `HELM 1 -> 2` and gold +15, indistinguishable
from any other kill's drop (compare `STAFF 1 -> 2` with gold +17 earlier in the
same run). There is no restore-stolen-goods path in the binary. The engine must
therefore delete a stolen item from the array rather than flag it, because the
resist gates read that array live.

### The force field, and why the theft mattered

`asm/24B5` gates on `[DS:D6]`, the RING slot, at file `0x26B8`. Non-zero prints
`RING PROTECTS FROM FIELD!` and does nothing. Zero takes the damage path: it clears
`[DS:19]` and `[DS:1A]`, then subtracts with `stc; sbb al,0x10; das` on `[DS:51]`, the
high byte of the 4-digit BCD HP, which is exactly **-1000**. The owner's HP went
`8842 -> 7842` on the tile, and after `[DS:D6]` was set to 1 the protect branch
fired with no damage. Both branches are now in the executed set, where previously
they had only ever been discovered.

If the subtract borrows, the branch at file `0x271B` goes to the death handler, so
this tile kills any character under 1000 HP outright. That makes it a difficulty
gate rather than a tax.

The causal chain is worth keeping as an example of why these systems are not
independent: the thief took the ring, so the field cost 1000 HP.

### The plane tile, and an open transform

The plane is map byte **`0x34`**, art index 13, which decodes to an unmistakable
side-view aeroplane. The mapping from art index to the location-description table
in `asm/4C50` (`... NEAR A HORSE. NEAR A FRIGATE. NEAR A PLANE. NEAR A ROCKET.` at
entries 11, 12, 13, 14) is corroborated independently by the horse, frigate and
rocket art, so the identification does not rest on the drawing alone. Only eight
plane tiles exist across all 33 sectors: `mapx00` x3, `mapx03` x3, `mapx32` x1,
`mapx93` x1. Sector 03 is the town one, with a vehicle yard: frigates at y=14,
planes at (43,16) and (45,16), rockets at y=18.

`asm/2FAD` dispatches BOARD on `[DS:14]` against `0x22` horse, `0x24` ship,
`0x26` plane, `0x28` rocket, and the callees write the mounted vehicle into
`[DS:13]`. `asm/38B0` (LAUNCH) reads `[DS:13]`, and landing a plane is accepted only
on tile `0x08` (grass).

**Open, and deliberately not smoothed over:** `[DS:14]` cannot be the raw map byte.
Every byte in every `mapx` file is a multiple of 4, and `0x22` and `0x26` occur zero
times across all 33 sectors, yet those are the horse and plane codes. The plane tile
is `0x34` and the plane code is `0x26`, so a transform exists and it is unproven.
`[DS:14]` is written at file `0x6238` from a call to `0x6AC0`, whose index arithmetic
came out as `y*16 + x` against a 64-wide grid, which is itself unexplained.

### The castle is not a separate map

Entering the castle printed `-CASTLE` (`017D:34B5`) but did not load a new file: the
live grid at `DS:1800` matched `mapx03` on 4066 of 4096 cells and `DS:49/4A` read
`0`/`3`. The 30 differing cells were not accounted for. The interior is the sector
map, and the `A`-`Z` letter tiles spell its room names in situ, which is the
strongest support yet for F13:

```
y=0   SHADOW  GUARD      CHAMBER ONE
y=29  TIMEZ  ONE         MUSEUM
y=34  TORTURE  CHAMBER
y=36  APOTHECARY
y=46  THIEVES            MORGUE
y=48  GUILD
y=62  DEVIL              WORKSHIP?
```

### Corrections and defects this session produced

* `tools/u2_edit.py` documented class as `0 fighter, 1 mage, 2 paladin, 3 thief`.
  The game's own table at file `0x50E8` is `FIGHTER, CLERIC, WIZARD, THIEF`. There
  is no paladin.
* `tools/u2_edit.py set` crashes on its own verification step for text and char
  fields (`int('AIRTEST')`), after the write has already landed. The write is fine;
  the check is wrong. Cosmetic, but it makes a successful edit look like a failure.
* `tools/turn_recorder.py`'s `screen` field is useless here: the game runs in CGA
  graphics mode, so `0xB800` holds pixels, not a text page. Every message claim in
  this section comes from `ExecutedInstructions` instead. The recorder logged 76
  odometer anomalies across 3000 turns, so single-turn boundaries in dense combat
  are not fully trustworthy and should be re-checked against the raw `.ds` files.

### Still unexplained

* Gold went `9999 -> 14` in one turn at turn 209. Cause not identified; not
guessing at it.
* Which map byte the force-field tile is, and what drives its animated
  white/blue/purple render.
* The `map byte -> vehicle code` transform behind `[DS:14]`.
* The 30 live-grid cells that differ from `mapx03`.
