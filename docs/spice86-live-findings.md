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
