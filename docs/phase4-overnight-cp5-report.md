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
| T5 | todo |
| T6 | todo |
| T7 | todo |
| T8 | todo |
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

**Commit: (pending).**
