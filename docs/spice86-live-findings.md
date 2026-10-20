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
