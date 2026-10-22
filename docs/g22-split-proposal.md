# G22 — function-boundary proposal for `asm/19D7` and the region past its end

**Status: proposal only. Nothing here is executed.** Splitting a function boundary is a
Phase 2/3 change to the byte-proof harness and needs the owner's approval, plus a
`check_func.py` run per new range. Opened by ticket G22; this document is task A5 of
`docs/overnight-2026-10-23.md`.

Grades per `AGENTS.md` § 5. Every address below is **observed** from
`original/ultimaii.exe` (runtime = file − `0x200`) or **measured** from the `asm/` tree.

## 1. The premise in G22 was half wrong, and the correction matters

G22 and `docs/commerce.md` § 3 recorded that the first observed purchase executed
`2052..2130`, entirely **past** `asm/19D7_magic_shop_menu.asm`'s declared end of `2027`,
and concluded the span was "short at the top" and that a split "must extend the range
upward".

**It must not.** Three measurements say the region past `2027` is not shop code at all:

1. **Only three addresses in `2028..2130` are inbound `call` targets**, and their caller
   sets are broad, not shop-local:

   | entry | inbound callers |
   | --- | --- |
   | `2028` | `15E1_tavern_menu`, `1869_cleric_shrine`, `19D7_magic_shop_menu`, `3B92_cmd_M`, `3C2E_cmd_O`, `3E9F_sub_3e9f`, `43F3_cmd_W` |
   | `2052` | `15E1_tavern_menu`, `1869_cleric_shrine`, `19D7_magic_shop_menu`, `3C2E_cmd_O`, `4282_sub_4282` |
   | `20AB` | `17B2_sub_17b2`, `1869_cleric_shrine`, `19D7_magic_shop_menu` |

   Seven, five and three callers respectively, spread across the tavern, the shrine, the
   shop, three command handlers and a fourth routine. **These are shared helpers.** A
   routine that seven unrelated callers invoke is not a fifth shop menu.

2. **The only `ret` instructions in the whole span `19D7..2140` are at `2051`, `20AA` and
   `2121`** — three of them, and each is the last byte before the next call target. The
   shop handlers inside `19D7..2027` contain none; they end in tail `jmp`s to the
   return-to-prompt path, which is why they read as menu blocks rather than functions.

3. **The fragments already tile `2028..2130` exactly**, with no gap and no overlap:
   `2028, 202C, 2031, 2035, 2039, 2048, 204D, 2052, 2070, 20A4, 20A7, 20AB, 20CF, 20D7,
   20EB, 2121`. Fifteen pieces for three routines. The mechanical clean wave cut on every
   branch target instead of on every *routine* boundary.

So the transaction did not run "past the end of the shop file". It ran **through three
shared helpers that already have their own files**, reached by ordinary `call`s from the
shop. The commerce code is not misfiled at the top of `19D7`; it is correctly inside
`19D7..2027` and it calls out.

## 2. Proposed boundaries for `2028..2130` — merge, do not extend

| proposed range | len | evidence | what it does |
| --- | --- | --- | --- |
| **`2028..2051`** | `0x2A` | entry = `call` target ×7; ends at the `ret` at `2051` | **Read one decimal digit from the keyboard.** Loops on a key read (`L_00514d`), rejects `AH != 0xFF` and anything outside `'0'..'9'`, converts with `stc; cmc; sbb $0x30; cmc`, keeps the value in `DI`, echoes the digit and then `0x8D`, and returns with `AL = digit`. Merges the seven fragments `2028, 202C, 2031, 2035, 2039, 2048, 204D`. |
| **`2052..20AA`** | `0x59` | entry = `call` target ×5; ends at the `ret` at `20AA` | **Charge `DS:27/28` to gold.** BCD `cmc;sbb;das;cmc` against `DS:58/59`; the trailing `cmc` inverts the flag so `jb` is the **affordable** path and tails to `20A7` (`mov $0,%al; ret`) with gold already reduced; the fall-through at `2070` adds the pair back and prints `YOU DONT HAVE THAT MUCH!`. Merges `2052, 2070, 20A4, 20A7`. |
| **`20AB..2121`** | `0x77` | entry = `call` target ×3; ends at the `ret` at `2121` | **BCD multiply by repeated addition.** Seeds `DS:27/28` and `DS:29/2A`, derives a loop count from `popcount([DS:50] + [DS:4E])` — int plus charisma — sets `DI` to it, and the loop at `20EB` adds `DS:27/28` into `DS:29/2A` under `dec %di; jne`. Merges `20AB, 20CF, 20D7, 20EB, 2121`. |
| **`2122..`** | — | inbound `jmp` from `0B36`, `0B4A`, `107F` | A separate routine reached by jump, not part of any of the three. Its end is outside the window this document examined; **not proposed here.** |

Naming is deliberately left out of the proposal — `20AB`'s stat-derived count is the
open half of G23 and naming it before that settles would be a guess in a filename.

## 3. The real G22 defect is still inside `19D7..2027`

That is the part of the ticket that survives the correction. The declared span holds at
least four distinct shop handlers — armour (`1D20`/`1D39`), weapons (`1E52`/`1E69`),
horse (`1F93`), clue seller (`1B11`) — plus the magic shop the file is named after, each
ending in a tail `jmp` to the prompt path rather than a `ret`.

Because they end in tail jumps, **the `ret`-based boundary detector used in § 1 cannot
find them**, and neither can a call-target scan. The evidence for their boundaries is
different and each candidate needs to be stated with its own kind of proof:

| candidate | evidence available | what would prove it |
| --- | --- | --- |
| `1B11` clue seller | first string of the run; `1AE0` is a `jmp` target from `15BA` | the `jmp` target is an entry; `check_func.py 1AE0` proves the bytes from there |
| `1D39` armour shoppe | string label site; falls through from the handler above | only a tail-jmp/`jmp` target makes it a boundary; a fall-through does **not** |
| `1E69` weapons shoppe | same shape as the armour site | same |
| `1F93` horse shoppe | same shape | same |

**This is the honest limit of the proposal.** Four of these are *fall-through* neighbours,
not dispatched entries, and a fall-through boundary is a judgement about where one
routine ends and the next begins, not a fact the bytes assert. Splitting them would
invent boundaries the original does not contain. The recommendation is therefore:

* **Do** merge `2028..2051`, `2052..20AA`, `20AB..2121` — three routines with hard
  call-target and `ret` evidence, currently cut into fifteen files.
* **Do not** subdivide `19D7..2027` on fall-through grounds. If it is split at all, split
  it only at addresses that are `jmp` targets from elsewhere (`1AE0`, `1D1D`, `1E4F`,
  `1F75` are the ones with inbound jumps in the tree), and say in each header that the
  boundary is a dispatch target, not a return.

## 4. What `check_func.py` would need per new range

`tools/check_func.py <SEG>` assembles `asm/<SEG>_*.asm` in isolation, `.org`'d to its true
file origin, stubs out-of-function `L_xxxxxx` labels at their real addresses, and requires
the assembled bytes over `[start, end]` to equal `original/` **and** the body length to
match `disasm/function-map.tsv` exactly. So for each proposed range:

1. **`disasm/function-map.tsv` must carry the range first.** The length check reads the
   map, not the file, so a new or merged range with no map row fails at the length
   assertion rather than at the byte comparison. Add or amend the row before creating the
   file.
2. **The `# func` header must agree with the map row** (`START..END`, inclusive, and the
   `len` field), or the two sources disagree and the run is meaningless.
3. **Every branch that leaves the range must stay an out-of-function `L_xxxxxx`** so the
   stub mechanism encodes it. The three merges are safe on this point: their internal
   branches (`2039`'s retry loop, `206E`'s `jb 20A7`, `211F`'s `jne 20EB`) become
   intra-range once merged, which is the actual benefit — three of today's fifteen
   fragments branch into the next one.
4. **Run it and require exit 0**, then run `bash tools/assemble_clean.sh` for the whole
   tree and require `CLEAN REBUILD BYTE-MATCH: 37344 bytes identical`. A merge that is
   byte-correct per function but shifts a total will show up only there.
5. **`make -C engine test`** afterwards, because CP0 md5s every non-`#` line of `asm/` and
   a merge moves body lines between files. Labels must not be renamed while doing it —
   `L_xxxx` labels are body.

Suggested order, cheapest proof first: `2052..20AA` (five callers, one `ret`, contains a
string so a mis-slice shows immediately), then `2028..2051`, then `20AB..2121` (largest,
and its `20EB` loop is the one whose boundary is easiest to get wrong).

## 5. Corrections this forces elsewhere

* `docs/commerce.md` § 3 says the transaction body is "entirely **outside** that file's
  declared range" and that a split "must extend the range upward". **Wrong**, per § 1
  above; it needs amending when the owner rules on this proposal.
* `docs/commerce.md` § 3b's description of `asm/2052`'s branch polarity was corrected in
  place on 2026-10-23: the trailing `cmc` inverts the flag, so `jb` is the **affordable**
  path. Simulated against the instruction sequence: `9999 − 0200 → 9799` taken,
  `9959 − 0040 → 9919` taken, `0020 − 0200` not taken, `0004 − 0005` not taken.
