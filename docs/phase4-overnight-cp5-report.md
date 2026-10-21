# Overnight CP5-prep report — 2026-10-22 run

Autonomous run of `docs/phase4-overnight-cp5.md` (T1..T10). Owner asleep; the
contract is *prove or pass*. Statuses: `DONE` / `PASSED — reason` / `BLOCKED — need`.
Grades per `AGENTS.md` § 5: observed / measured / inferred / recalled.

Running log — updated as each task lands. Commit hashes are appended after each
logical commit.

| task | status |
| --- | --- |
| T1 | DONE |
| T2 | DONE |
| T3 | DONE |
| T4 | DONE |
| T5 | DONE |
| T6 | DONE |
| T7 | DONE |
| T8 | PASSED — trigger is mode byte 0x2e, not a tile byte; map byte needs a capture |
| T9 | todo |
| T10 | todo |

---

## T1 — `tools/cfg_printed.py` silently dropped an executed print site

**Status: DONE.**

### Diagnosis (observed)

Reproduced against the committed capture `captures/spice86/dungeon-35-live`:

```
$ python3 tools/cfg_printed.py captures/spice86/dungeon-35-live --contains LAND
1435 blocks, 136 str_out sites, 4141 executed instructions in this harvest
=== PRINTED (1 sites, call instruction confirmed executed)
  017D:3B5A  'LAND PLANE.'
```

`LAND--NOT HERE!!!!!` (runtime `0x3B72`) is absent, yet its call instruction's
linear address `0x5342` **is** in `ExecutedInstructions` (verified directly).

The site is *not* lost to block discovery — CFG block `017D:3B71` contains the
`call near 0x4FDF` at runtime `0x3B72`. The loss is in `extract()`:

* The inline bytes at file `0x3D75` are `b'LAND--NOT HERE!!!!!\rCMD: \x00...'`.
* `LAND--NOT HERE!!!!!` is terminated by `0x0D` (CR), and the **next** inline
  string `CMD: ` follows before the next `0x00`.
* The old `extract()` split on the first `0x00`, yielding
  `LAND--NOT HERE!!!!!\rCMD: `. The embedded `0x0D` fails the `PRINTABLE`
  regex, so it returned `None` and the site was silently dropped.

This is the exact failure class `AGENTS.md` § 5 warns about: a silent filter
returning a plausible-looking empty result.

### Fix

Rewrote `tools/cfg_printed.py`:

1. **Primary source is now `ExecutedInstructions`.** Print sites are found by
   scanning the executed code-segment instructions for the 3-byte near call
   `E8 <rel16>` whose target resolves to str_out (runtime `0x4FDF`). CFG blocks
   are demoted to a secondary seed, used only for the `--all`
   discovered-but-never-executed list. This matches `AGENTS.md` § 4.
2. **The code segment is derived, not hardcoded** — it is the segment in which the
   str_out entry itself executed. If str_out never ran the tool says so.
3. **`extract()` terminator model fixed.** It now strips leading control markers
   and reads printable bytes up to the *first* non-printable byte, instead of
   splitting on the first NUL and requiring the whole run to be printable. This is
   what dropped `LAND--NOT HERE!!!!!` (terminated by `\r`, followed by `CMD: `).
4. **Fails loudly** rather than returning an empty list when the dump shape is not
   understood: missing/empty `ExecutedInstructions`, entries that are not
   `{Offset,Segment,Linear}` dicts, str_out not executed, zero executed call
   sites, or a CFG that parses to zero blocks (with `--all`). Each prints a
   specific reason and exits non-zero.
5. **Sites with no printable inline message are counted and reported** (e.g. the
   genuine single-char prints `S`, `-` at `0x4881`/`0x4886`), not silently dropped.

### Verification (measured, against committed captures)

* `LAND--NOT HERE!!!!!` (runtime `0x3B72`) is now reported PRINTED in
  `dungeon-35-live`; `LAND PLANE.` (`0x3B5A`) still is.
* Negative controls hold: `MINAX IS DEAD!!`, `RING PROTECTS FROM FIELD!`,
  `FIELD CAUSES 1000 DAMAGE!` appear only under `--all` (discovered, not executed)
  in `dungeon-35-live`, and `RING/FIELD/MAGIC MISSILE/SLEEP SPELL/A THIEF STOLE`
  are correctly PRINTED in `castle-03-live` (matches findings § 12).
* `create-test-live` (creation-only) reports no combat strings — clean negative.
* Output is deterministic across repeated runs (diffed).
* Loud-failure paths exercised with synthetic bad dumps (empty, wrong-shape,
  str_out-not-executed) — each exits non-zero with a specific message.

### Test added

`tools/cfg_printed.py --selftest` runs the built-in positive/negative control
(`LAND--NOT HERE!!!!!` present in `dungeon-35-live`; `MINAX CRIES: DIE FOOL!` and
all combat strings absent there and in `create-test-live`). It SKIPs cleanly (exit
0) when the gitignored captures or `original/ultimaii.exe` are absent, so CI stays
honest. Result: `SELFTEST PASSED`.

Note: captures and `original/` are gitignored, so this test runs offline against
the local working copy, not in CI. That is the same constraint the CP4 screenshot
tests already accept.

### Files

* `tools/cfg_printed.py` (rewritten)
* `docs/phase4-overnight-cp5-report.md` (this file)

`asm/` untouched, so the byte-exact invariant is unaffected. `make -C engine test`
green.

**Commit: `2c2f3c4`.**

---

## T2 — `tools/xref_provenance.py --strict` dangling citations

**Status: DONE** (the named defect — the four dangling citations — is fixed;
see the scope note on the `--strict` exit code below).

### Diagnosis (measured)

The task framed this as a binary — either the *addresses* are wrong or the
*functions are missing from `asm/`*. The evidence shows it is a **third cause**:
`resolve()` had an off-by-one on the range end. Neither suggested fix was
correct, and applying either would have been wrong.

The two cited addresses are the **inclusive last byte** of functions that
already exist in `asm/`:

* `asm/0964` → last byte of `sub_0962` (`# func 0962..0964  len 0003`)
* `asm/5002` → last byte of `sub_5000` (`# func 5000..5002  len 0003`)

The project-wide convention is that a function range is **inclusive of its end
byte**. This is not an assumption — it is what the byte-proof tool enforces:
`tools/check_func.py` computes `length = sfe - sfs + 1` and compares
`orig[sfs:sfe+1]`, i.e. it treats the map end as the last real byte. Independently,
for all 1298 rows of `disasm/function-map.tsv` and every asm header,
`end - start + 1 == len` (verified: 0 exceptions). So `0962..0964` is three bytes
(`0962`, `0963`, `0964`), and `0964` is a real code address inside `sub_0962`.

`resolve()` however tested `f["start"] <= addr < f["end"]` (exclusive end), so the
last byte of *every* function resolved to nothing. That is the whole bug.

### Fix

Changed the containment test in `resolve()` to `f["start"] <= addr <= f["end"]`
(inclusive), with a comment naming the convention and its proof. This is a
tool-correctness fix, not a regex change — `ASM_CITE_RE` is untouched, so the
task's "do not paper over it by widening the regex" constraint is respected. The
tool now agrees with `check_func.py` about what a function range means.

### Verification (measured)

* Dangling doc citations: **4 → 0**.
* `0x0964` now resolves to `0962_sub_0962.asm`; `0x5002` to `5000_sub_5000.asm`.
* Previously-resolving citations are unchanged (`0x0962`→sub_0962, `0x5003`→char_print).
  Because function ranges do **not** overlap under the inclusive reading (verified:
  0 overlaps across all 1298), widening each range by its end byte can only turn a
  former dangling byte into a resolution — it can never re-point an existing hit.
* The tool still catches real dangles: a genuine gap address (e.g. `0x0000`, one of
  273 uncovered bytes in `[0,0x9000)`) still resolves to `None`.
* `asm/` untouched, so the byte-exact invariant is unaffected. `make -C engine test`
  green (CP0..CP4).

### Note on the `asm/0964` citation being a retraction

The `asm/0964` mention in `phase4-implementation.md:312` is inside a retraction —
the author is quoting a *past mistake* ("My first pass ... cited `asm/0964`, which
is the file offset of runtime `0x764`"). The tool cannot distinguish a quoted-bad
citation from a live one, and `0964` is a genuine runtime code byte (last of
`sub_0962`), so resolving it is correct and the retraction text is left untouched
and still visible (rule 6). Editing the doc to dodge the regex would have obscured
the retraction — the wrong fix.

### Scope note: `--strict` still exits 1

`--strict` fails on `dangling or no_prov`. The dangling half is now 0. The exit
code stays 1 **only** because of the 101 named functions with no `# provenance:`
line, which the overnight task states is "a known backlog, not part of this task"
and forbids bulk-filling. So the T2 deliverable (the four dangling citations) is
complete; a fully-green `--strict` exit code is not reachable without the
explicitly-excluded provenance backlog. Flagged rather than silently re-scoped.

### Files

* `tools/xref_provenance.py` (`resolve()` inclusive-end fix)
* `docs/phase4-overnight-cp5-report.md` (this file)

**Commit: `521e4ab`.**

---

## T3 — `tools/turn_recorder.py` defects

**Status: DONE.** Both defects fixed. The odometer anomalies are a **tool/trigger
artifact, not a mechanic finding** — the food model is confirmed correct by the
recorded bytes.

### Defect 1 — the 76 odometer anomalies: model is right, trigger was wrong

The task asked me to decide between two explanations and say which, with evidence
from the recorded turns (`captures/spice86/fight-20261021-castle03/`, 3000 turns).

**Verdict (measured): the food model is correct; the trigger over-coupled it to a
non-atomic position read.** Evidence, computed over the committed `index.jsonl`:

* Across all 3000 records there are 87 positive food deltas. **Every one is
  exactly 10 or 19** — 0 non-decomposable, 0 negative. So `-19` per move and
  `-10` per pass is never contradicted by a byte. This matches the model already
  recorded in `docs/spice86-live-findings.md` § 11 (`0x53..0x55` = "-19 per move,
  -10 per pass"). It is therefore **not** a mechanic finding and nothing new is
  added to the findings doc on that count.
* The old `ok` test required the decomposed move count to agree with the
  per-sample `moved` flag: `(dec[0] > 0) == moved`. But the game writes player
  position and food **non-atomically**, so a single accepted move is caught
  across two 50 Hz polls as `(delta=0, moved=True)` then `(delta=19,
  moved=False)`. Categorising the 76 anomalies: 45 were `delta=0, moved=True`
  and 31 were `delta=19, moved=False` — the two halves of the same split, plus
  zero-cost rejects. None was a non-decomposable delta.
* This is exactly the mechanism the existing backlog predicted ("position and food
  update non-atomically, so one move can split across two samples and show as a
  false odometer anomaly", `docs/phase4-state.md` backlog). The data confirms it.

**Fix.** The odometer verdict is now the **food model alone**: a delta is an
anomaly only if it is negative or cannot be written as `19a + 10b`. It no longer
depends on the per-sample `moved`/`rejected` flags (those are still recorded as
advisory data). Validation against the recorded deltas: the new verdict reports
**0 anomalies** on the 3000-turn capture, while a synthetic torn read (`delta=7`)
or a food increase (`delta=-5`) still fails — so the check still catches a real
model violation or a torn read, which is its actual purpose. Because `ok` no
longer reads the reject flag, the verdict is also immune to the separate
`DS:20`-is-scratch backlog item (that item — removing `DS:20` from the change
signature — is out of T3 scope and left untouched).

### Defect 2 — the junk `screen` field

The game runs in **CGA graphics mode 4**, so `0xB800` holds pixels, not a text
page; `screen_text()` was decoding pixel bytes as ASCII (the committed capture's
`screen` values are the tell-tale scattered `" "` noise, not text). Per the task
I replaced it with an honest signal rather than deleting outright:

* `vga_ink = sum(1 for b in vga if b)` — non-zero pixel bytes in the video span,
  the same metric that proved a blank frame was real darkness in
  `tools/dungeon_capture.py`.
* `video_mode` — the BIOS mode read at physical `0x449` (`0x40*16 + 0x49`), the
  value that *shows* why a text read would be junk. The `0x449`-not-`0x449*16`
  trap is called out in a comment, matching `dungeon_capture.py`.

`screen_text()` is deleted; no `screen` field is emitted any more.

### Verification

* `python3 -m py_compile tools/turn_recorder.py` clean; `--help` runs (argparse
  path exercised without the emulator — the recorder itself is live-only and was
  **not** launched, per the no-emulator rule).
* New odometer verdict re-run over the committed 3000-turn `index.jsonl`: 0
  anomalies; `decompose` spot-checked for 0/10/19/29/38 (ok) and 7/-5 (fail).
* `asm/` untouched; `make -C engine test` green (CP0..CP4).

### Files

* `tools/turn_recorder.py` (odometer verdict + honest VGA frame; `screen_text` removed)
* `docs/phase4-overnight-cp5-report.md` (this file)

**Commit: `efef0bb`.**

---

## T4 — the gold that vanished

**Status: DONE.** The mechanism is identified with byte evidence. It is **not**
a theft, a bribe, or invalid-nibble corruption. It is a **2-byte packed-BCD
overflow wrap on a legitimate kill reward**, added to a character that
`tools/u2_edit.py maxout` had already pinned at the 9999 ceiling.

**Grade: measured** — from the recorded raw DS blobs plus the write targets in
`asm/`, not inferred.

### What actually happened at turn 209 (observed)

Diffing the **whole** DS block across turns 205..213 (not just the gold field)
shows the gold change is not isolated. At turn 209 exactly one monster record was
zeroed and one map cell was restored, i.e. a monster died:

```
DS:013B 1F -> 00   monster slot 4 x   (0x137+4)
DS:015B 20 -> 00   monster slot 4 y   (0x157+4)
DS:017B 11 -> 00   monster slot 4 ?   (0x177+4)
DS:019B 34 -> 00   monster slot 4 kind(0x197+4)  0x34 = legs caster
DS:01BB 08 -> 00   monster slot 4 tile(0x1B7+4)
DS:201F 34 -> 08   map cell (31,32): monster stamp -> grass
DS:0056 99 -> 00   EXP_hi
DS:0057 99 -> 01   EXP_lo
DS:0058 99 -> 00   GOLD_hi
DS:0059 99 -> 14   GOLD_lo
```

Those five monster fields zeroed together are exactly what
`asm/2D8C_combat_kill_reward.asm` does — it writes `0x0` to `0x1b7(%di)`,
`0x177(%di)`, `0x137(%di)`, `0x157(%di)`, `0x197(%di)` for the killed slot. So
the byte evidence ties the gold change to a **kill**, not to a thief's turn.

Two further observations rule out the three candidate mechanisms the task named:

* **food delta = 0 across the change** (turn 208 and 209 both `food = 999871`).
  A theft or a bribe is a game turn and would spend food (19/move or 10/pass,
  findings § 11). No food moved, so no tax was paid.
* **gold and exp both went *down* together.** A kill *adds* gold and exp
  (`asm/2DC1`, `asm/2DEE`). They only read as a drop because both fields were
  already at the packed-decimal ceiling `0x99 0x99 = 9999` from `maxout`
  (`tools/u2_edit.py` sets gold and exp to 9999). Adding a positive reward to a
  saturated 2-byte BCD field wraps it.

### The arithmetic (measured, forced by the asm)

`asm/2DC1_combat_gold_gain.asm` adds `[DS:1F]` into the gold pair with `adc` +
`daa` and stores back to only `DS:58`/`DS:59` — there is **no third byte and no
saturation clamp**, so the carry out of the high byte is discarded:

```
clc ; mov 0x59,%al ; adc 0x1f,%al ; daa ; mov %al,0x59   ; low byte
    ; mov 0x58,%al ; adc $0x0,%al ; daa ; mov %al,0x58   ; high byte, carry dropped
```

`asm/2DB7_sub_2db7.asm` sets the reward `DS:1F = (rand & 0x17) | 1`, so the raw
reward byte is one of `{01,03,05,07,11,13,15,17}`. Read as packed decimal, `0x15`
= 15. The observed `9999 -> 14` is only produced by a **+15** reward:

```
0x99 0x99 + 0x15 (BCD) = 10014 -> keep 4 digits -> 0x00 0x14 = 14   (unique)
```

`0x15` is in the achievable reward set, so the value is not invented — it is the
unique solution the bytes force. The exp path is identical: `asm/2DE4_sub_2de4.asm`
sets `DS:1F = (rand & 3) + 1` ∈ {1,2,3,4}, and `9999 -> 1` is only produced by
**+2**:

```
0x99 0x99 + 0x02 (BCD) = 10001 -> 0x00 0x01 = 1   (unique)
```

Both were verified by an 8-bit `daa` emulation (script `/var/tmp/t4_track.py`,
`/var/tmp/t4_diff.py`). The result nibbles `0,0,1,4` and `0,0,0,1` are all valid
BCD, so this is **not** the invalid-nibble corruption the task listed as a
candidate — the field is well-formed, it simply overflowed.

### Why it looked like a single mysterious vanishing

Turn 209 is the **first kill of the whole session** (monster count held at 31 for
turns 0..208, then 31->30 at 209). Because the character was seeded at the 9999
gold/exp ceiling, the very first kill's reward wrapped both fields at once, which
reads as "9999 gold vanished in one turn." Later kills (turns 543, 704, 1001,
…) show the same code adding normally to the now-small values (14->17->18->31…),
which is the same reward path behaving correctly on an unsaturated field.

### Mechanic finding for the engine

Gold and EXP are **unsaturated 2-byte packed-BCD counters that wrap modulo 10000**
when a reward is added at the 9999 ceiling. A reconstruction that clamps at 9999,
or that stores gold in a wider/binary field, will not reproduce this. Recorded in
`docs/spice86-live-findings.md` § 12 (the open item is now resolved).

### Files

* `docs/phase4-overnight-cp5-report.md` (this section)
* `docs/spice86-live-findings.md` § 12 (open item resolved, retraction-style: the
  original "cause not identified; not guessing" line stays visible)

`asm/` untouched; no engine code changed. `make -C engine test` green.

**Commit: `7856653`.**

---

## T5 & T6 — the live grid vs the shipped `mapx` file

**Status: DONE.** T5 and T6 are **the same mechanism**, decided explicitly below.
That mechanism is the overworld half of what findings § 13 proved for dungeons:
**the sector grid is the live object store.** Runtime objects are stamped into the
64x64 grid at their current cell and the shipped `mapxNN` file is the *spawn*
layout, so a mid-play grid legitimately differs from the file wherever an object
has moved. Grade: **measured**, from the committed `live-ds.bin` DS dumps diffed
byte-for-byte against `original/mapxNN`.

### Method

The 64x64 grid is at `DS:0x1800` in the live DS segment (confirmed: the fight
capture's cell (31,32) is `DS:201F` = `0x1800 + 32*64 + 31`). Sector digits at
`DS:49/4A` are decimal pairs, so sector 30 is `(3,0)`. For every capture that has
a `live-ds.bin` I diffed `live[0x1800:0x2000]` against `original/mapxNN[:4096]`
and classified each differing cell (scripts `/var/tmp/t56_grid.py`,
`/var/tmp/t56_classify.py`).

### The mechanism: monsters live in the grid, stamped by type byte

A live monster's grid cell holds its **type byte** (`DS:197+i`); `DS:1B7+i` holds
the terrain it stands on. The shipped `mapx` file bakes monsters in at their
spawn cells as those same type bytes — `mapx03` on disk contains **43 cells whose
byte is a monster type** (`0x34/38/3C/40/60/68/F0/F4/F8/FC`). When a monster moves
it vacates its spawn cell (reverting to terrain `0x70`) and stamps its type at the
new cell. So each moved monster produces exactly two grid diffs: one `sprite->70`
(vacated spawn) and one `70->sprite` (new cell).

Measured, every capture that was mid-play in an overworld sector:

| capture | sector | diffs | monster-stamp | vacated-spawn | vehicle | unexplained |
| --- | --- | --- | --- | --- | --- | --- |
| castle-03-live | mapx03 | 46 | 23 | 23 | 0 | **0** |
| airport-castle | mapx03 | 12 | 6 | 6 | 0 | **0** |
| flight-32-live | mapx32 | 50 | 24 | 25 | 1 | **0** |
| play-test-live | mapx20 | 5 | 4 | 0 | 0 | 1 (see below) |
| create-test-live | mapx20 | 1 | 1 | 0 | 0 | 0 |
| baseline-fight | mapx20 | 4 | 4 | 0 | 0 | 0 |

The single `vehicle` cell in flight-32 is `cell (4,10) disk 4C -> live 08` — the
plane tile the owner boarded (findings § 13: boarding rewrites the tile to ground,
`DS:13` stamp = `0x26`). That is the documented vehicle-relocation mechanism, not a
new anomaly.

**T6 (the 30 cells that differed from `mapx03`) is fully accounted for**: they are
moved monsters, the same grid-is-the-object-store mechanism as § 13's dungeon
objects (`0x01..0x07` stamped into `0x00` cells). dungeon-35-live reproduces
exactly that dungeon signature here (27 cells `0x00 -> 0x01..0x06`), confirming the
overworld and dungeon grids use one mechanism with different value ranges.

### T5: the two `mapx30` cells resolve to one mislabel and one unreproduced byte

The only sector-30 capture (`flight-launched-live`, plane stamp `0x26`) differs
from `mapx30` in **exactly one cell**, not two:

* **`(27,11) = 0x30` "boat art" — does not reproduce, and was a mislabel.** In
  this capture (27,11) is `0x08` in **both** disk and live. `0x30` is decimal 48,
  which is in the observed **monster-type** list (findings § 12 / T9), not a boat.
  So the § 13 note's "boat art `0x30`" is the same class of error as the § 12 plane
  tile: a small integer read as art when it is a runtime stamp. Grade: the
  non-reproduction is **measured**; "it was a monster stamp" is **inferred** (the
  capture does not contain the instant § 13 observed it).
* **`(0,0) = 0x50` rocket — real, but a single unreproduced byte, not a mechanism.**
  It is genuinely present in the live grid and absent from `mapx30` on disk. But it
  is **not** a monster (no monster at (0,0); the only monster record is a null
  slot), **not** the player's vehicle (the player rides a plane, board byte `0x4C`,
  not `0x50`), and it appears in **1 of 8** captures. No capture shows the write or
  a second occurrence, so I cannot attribute it to a proven mechanism and do not
  invent one. **This specific byte is PASSED-unexplained**: what is missing is
  either a second sector-30 capture reproducing it, or a turn-resolved capture of
  sector-30 entry showing what writes a `0x50` at (0,0).

### Explicit decision on "one anomaly or a mechanism"

The grid-vs-disk differences are a **mechanism** (grid = live object store;
monsters stamped by type byte, disk file = spawn layout) — proven across six
overworld captures with 0 unexplained cells except the two residuals below. The
sector-30 `(0,0)=0x50` rocket is a **single anomaly**, not that mechanism and not a
proven vehicle-placement path; it is left unexplained with the missing evidence
named rather than guessed.

### Residuals (recorded, not guessed)

* `mapx30 (0,0) = 0x50` rocket: 1-of-8 capture, no attributed writer. PASSED.
* `play-test-live (19,52) disk 0C -> live C0`: one cell, not a monster/vehicle
  stamp; single occurrence, no mechanism claimed.

### Mechanic finding for the engine

The overworld grid is a **mutable object store**: the shipped `mapxNN` file is the
monster *spawn* layout (monster type bytes baked into grid cells), and at runtime
monsters relocate within the grid, vacating their spawn cell to terrain and
stamping their type byte at their current cell. A reconstruction that loads the
file once and treats the grid as immutable static art will not reproduce monster
movement, and will misread every moved-monster cell as a discrepancy. This is the
same store § 13 found for dungeons and vehicles.

### Files

* `docs/phase4-overnight-cp5-report.md` (this section)
* `docs/spice86-live-findings.md` § 13 (open items resolved / corrected)

`asm/` untouched; no engine code changed. `make -C engine test` green.

**Commit: `aaf9bb0`.**

---

## T7 — the `y*16 + x` anomaly at file `0x6AC0`

**Status: DONE.** The array is the **dungeon grid**, not the overworld sector
grid. Grade: **measured** (the addressing arithmetic, the base value, the caller
chain and the dungeon coordinate range), with one **inferred** piece (that
`[DS:25]` is a floor/page selector).

### The addressing, decoded (measured)

`asm/68C0` (file `0x6AC0`) builds a DS address from three bytes and dereferences
it. Reading the body instruction by instruction:

```
mov 0x25,%ah ; mov $0x0,%al ; add 0x472,%ax   ; AX = word[DS:472] + [DS:25]*256
mov %ah,0x488                                  ; [DS:488] = high byte (page)
mov 0x24,%al ; add %al,%al x4 ; adc 0x23,%al   ; AL = [DS:24]*16 + [DS:23]  (low byte)
mov %al,0x487                                  ; [DS:487] = low byte
mov 0x487,%bx ; mov (%bx,%si),%al              ; return byte at DS:word[DS:487]
```

So the effective address is **`word[DS:472] + [DS:25]*256 + [DS:24]*16 + [DS:23]`**.
This is the *same* map-grid buffer that `asm/50B3 map_tile_ptr` reads —
`map_tile_ptr` computes `word[DS:472] + y*64 + x` (the 64-wide sector grid) —
but `asm/68C0` reads it with a **16-wide** row stride and a **256-byte page
selector** `[DS:25]`. The low byte of `word[DS:472]` is discarded and replaced by
`y*16+x`, which is only correct because `word[DS:472]` is 256-aligned.

Measured against every live DS dump: `word[DS:472] = 0x1800` (the map grid base,
matching the T5/T6 finding that the grid lives at `DS:1800`) and `[DS:25] = 0` in
all 10 captures. So in every captured state the address is `0x1800 + y*16 + x`.

### Why it is the dungeon grid, not the sector grid (measured)

Three independent facts converge:

1. **Caller chain.** `asm/68C0` is called only from `asm/6000` and `asm/6078`;
   `asm/6000` is called only from `asm/1151 dungeon_darkness` (the dark-dungeon /
   torch routine). The whole cluster is dungeon-only. `asm/6000` sets
   `[DS:23]/[DS:24]` to `(0,1)`, `([DS:2], 1+[DS:3])`, `(-[DS:2], 1-[DS:3])` and
   stores the three reads to `[DS:14]`, `[DS:15]`, `[DS:16]` — a forward-cell
   probe around the player, not a tile-under-player lookup.
2. **Dungeon coordinates are 0..15.** In `dungeon-35-live` the player is at
   `(4,5)` and all 27 live monsters have `x,y ∈ 1..15`. A 64-wide grid would
   allow 0..63; the observed range is exactly a 16-wide grid. (Contrast the
   overworld `castle-03-live`, player x = 62.)
3. **`mapx35` is 16 pages of 16×16.** Splitting the 4096-byte dungeon map into
   sixteen 256-byte pages, every page uses the same 7 dungeon geometry bytes
   (`0x00,0x10,0x20,0x40,0x80,0xC0,0xE0`) with ~130-190 non-zero cells each. So
   the dungeon map is a stack of 16×16 pages, and `[DS:25]` (the `*256` term)
   selects the page.

So `y*16 + x` is the row-major index **within a 16×16 dungeon page**, and the
"against a 64-wide grid" framing was the error: the array was never the overworld
sector grid.

### The `[DS:14]` non-contradiction

`asm/6000` is a **dungeon-path** writer of `[DS:14]`. The proven
`[DS:14] = map_byte >> 1` was measured on overworld **walk** samples and is
written by a different routine (`asm/5B71`/`asm/5C49 mode_table_copy`, which set
`[DS:14] = [DS:2DF]`). Two mode-specific writers of the same scratch byte; the
T7 finding does not touch the proven walk-path relationship.

### Inferred, stated as such

`[DS:25]` as a **floor/page** selector is inferred from the `*256` term plus the
16-page structure of `mapx35` and the 0..15 coordinate range. It is `0` in every
capture, so the multi-page path is reasoned from the code, not witnessed. The
full dungeon geometry (how a 16×16 page becomes the first-person wireframe) is
the existing backlog item and was **not** attempted here (out of scope).

### Files

* `asm/68C0_sub_68c0.asm` → `asm/68C0_dungeon_grid_byte.asm` (renamed, header written; body byte-identical)
* `asm/6000_sub_6000.asm` → `asm/6000_dungeon_sample.asm` (renamed, header written; body byte-identical)
* `docs/spice86-live-findings.md` § 12 (open item resolved, retraction-style: the original "Unexplained" line stays visible)
* `docs/phase4-state.md` (C7 note: the `y*16+x` residual struck through and resolved)
* `docs/phase4-overnight-cp5-report.md` (this section)

`check_func.py 68C0` and `6000` PASS; `bash tools/assemble_clean.sh` prints
`CLEAN REBUILD BYTE-MATCH: 37344 bytes identical`; `make -C engine test` green
(CP0..CP4).

**Commit: `b71c6a1`.**

---

## T8 — the force-field tile byte

**Status: PASSED — the trigger is a mode byte, not a map byte; the map byte needs
a capture.** The task said "do not guess a byte" and "this may be unreachable
without a capture; if so, pass it and say what capture would settle it." That is
exactly the outcome, but the trigger was narrowed from "unknown" to a specific,
measured mode byte. Grades are named per claim.

### What the caller walk found (measured)

`asm/24B5 force_field_event` has no `call`/`jmp` to it from a tile check. It is
reached by **fall-through** inside the passability routine `asm/2423`, through a
comparison ladder that reads **no map tile at all**:

```
asm/2423 entry:  mov [DS:29],%al        ; [DS:29] = the travel-mode byte (AL)
                 mov [DS:4A],%al; cmp $0; je 0x268b   ; ladder runs when [DS:4A]==0
asm/248b:        mov [DS:29],%al; and $0x7f,%al; cmp $0x2,%al; jne 0x26b1
asm/24b1:        cmp $0x2e,%al; jne 0x2720
                 ; falls through to force_field_event ONLY when ([DS:29] & 0x7f)==0x2e
```

So the trigger is **mode byte `0x2e`** in `[DS:29]`, which `asm/2423` loads from
the travel-mode byte `[DS:15]`/`[DS:18]`. `mode_table_copy` (`asm/5B71`/`asm/5C49`)
fills those from `[DS:2CB]`/`[DS:2DE]`.

### Measured at the live force-field turn

Scanning all 3000 recorded turns of `fight-20261021-castle03` for the BCD −1000 HP
signature (`[DS:51]` drops `0x10`, `[DS:52]` unchanged) found exactly **one**
event, turn 2909:

```
turn 2909: HP_hi 0x88->0x78 (=8842->7842, the -1000)  [DS:D6]=0x00 (no ring)
           [DS:15]=0x2e  [DS:18]=0x2e
```

The mode bytes are `0x2e` on the damage turn and the ring slot is 0 — the damage
branch. This is the trigger, measured, not inferred.

### Why the map byte is NOT statically resolvable (measured)

* `0x2e` is **not a grid byte**: it occurs **0 times** in `mapx00` (histogram
  measured). It is a derived travel-mode, in the same value-space as the vehicle
  board codes (`0x22` horse … `0x2e`), not a raw tile.
* The tile → mode mapping is the **indirect store that fills `DS:2CB`/`DS:2DE`**,
  which `docs/passability-findings.md` F3 already proved has **no direct writer
  anywhere in the exe** (re-confirmed: grep finds none). Static analysis cannot
  invert it, so the map byte that yields mode `0x2e` cannot be named offline.
* The live capture does not disambiguate it either: the player's own cell is
  stamped `0x78` (the player stamp), masking the terrain under it, and the damage
  fired while the player was **stationary** at (29,50) (disk byte `0x10`, a common
  byte with 122 copies in `mapx00`), so it is not a clean "step onto tile X" event
  whose byte could be read off. Guessing `0x10` or `0x2e` would be exactly the
  error the task forbids.

### The animated render

`asm/24B5` does not drive the white/blue/purple animation; it only flashes and
sounds via `L_00543e`/`L_0060f2`. The animation is a separate render path not
attributed here.

### The capture that would settle it

The backlog **four-question passability capture** already specifies the needed
reads: at the instant the mode is `0x2e`, dump `DS:2CB`/`DS:2DE` **and** the
destination tile byte (or breakpoint the indirect store that writes
`DS:2CB`/`DS:2DE`). That inverts tile → mode `0x2e` and names the force-field map
byte. No new capture type is needed — it is the same capture that resolves F3 and
the mountain-tile question.

### Files

* `asm/24B5_force_field_event.asm` (header notes updated with the measured trigger; body byte-identical)
* `docs/spice86-live-findings.md` § 12 (force-field open item narrowed)
* `docs/phase4-overnight-cp5-report.md` (this section)

`check_func.py 24B5` PASS; `bash tools/assemble_clean.sh` prints
`CLEAN REBUILD BYTE-MATCH: 37344 bytes identical`; `make -C engine test` green.

**Commit: `<pending>`.**