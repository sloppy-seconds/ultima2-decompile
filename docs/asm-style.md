# Phase 3 ASM Style Guide

Rules for the cleaned tree in `asm/`. The oracle is unchanged: every cleaned
function must re-assemble **byte-identical** to its `original/` range, proven by
`python3 tools/check_func.py <SEG>` (exit 0) before any commit. A cleaned
function that changes any byte is a failed function — revert it.

## 1. Dialect

* Canonical source: GNU `as` syntax with `.code16` (the verified toolchain,
  same as Phase 2). `check_func.py` / `assemble_all.sh` assemble this.
* jwasm (MASM dialect) is the era-faithful *target*: CP5 adds
  `tools/dialect_masm.py` to transpile the cleaned tree and dual-verify.
  Stay transpilable: prefer `db`/`dw` for data (the harness normalises them to
  `.byte`/`.word` for gas; CP5 keeps the same rule), plain instructions,
  labels; avoid gas-only pseudo-ops in cleaned bodies (the harness itself
  supplies `.code16`/`.org` scaffolding — never write them in a function file).
* AT&T operand order (objdump style) is canonical: `mov $0x0, %al`.
* Comments are `#` (gas line comment). **Never `;`** — gas x86 treats `;` as a
  statement separator, not a comment. The CP5 transpiler maps `#` to `;`.

## 2. File layout

* One file per function: `asm/<SEG>_<name>.asm`, `<SEG>` = 4 uppercase hex
  digits of the function START (the `function-map.tsv` key), `<name>` = final
  name (see 3). Example: `asm/2B8F_cmd_A.asm`.
* `check_func.py <SEG>` picks `asm/<SEG>_*.asm` automatically; with no cleaned
  file it falls back to the mechanical slice (so mechanical slices always pass).
* Data-only regions that are NOT inside any map function get their own file
  `asm/<SEG>_data_<kind>.asm` (kind: `string|table|zeros|mixed`) — CP5.

## 3. Naming

* Keep known names: `cmd_A`..`cmd_Z` (26 jump-table handlers), `str_out`.
* Default for everything else: `sub_<seg>` (lowercase hex, e.g. `sub_0d21`).
  Rename to a meaningful `snake_case` name once behavior is clear; the rename
  goes in the filename too (re-run `check_func.py` after any rename).
* Local labels: `.L<seg>_<meaning>` (e.g. `.L0d21_try_east`,
  `.Lcmd_cast_retry`). Never leave a mid-function branch target unlabeled.
* Out-of-function targets: keep the mechanical form `L_<6hex>` = **file** offset
  (segment + 0x200), lowercase. `check_func.py` auto-stubs every undefined
  `L_` label at its true address; these are also the grep-able cross-reference
  seams between functions.
* Data symbols: `data_<seg>_<kind>` when a region needs a name.

## 4. File header template

```asm
# <name> — one-line what-it-does (or "unknown, mechanical-clean only")
# func <SEG>..<end>  len <NNN> B  evidence: <from function-map.tsv>
# confidence: high|medium|low   (behavioral reading, not byte-proof — bytes are
# always proven by check_func.py)
# notes: <defects, selfmod, oddities, open questions; delete if none>
```

## 5. Data inside code (inline strings, tables, pads)

* Inline string after `call str_out`: emit as `db "text",0` with a comment,
  and annotate the call:
  ```asm
  call L_0051df          # str_out — prints the inline string below
  db "ATTACK--",0        # string
  ```
  Escape `"` as `\"` and `\` as `\\`; bytes with the high bit set or
  non-printables stay as numeric `db 0x80,0x01,...` items.
* Tables: `dw` lists (one row per line where it aids reading) + `# table` comment.
* Zero pads: `db 0,0,0,...` + `# zeros` comment (keep exact count).
* Never drop a `# <kind>` comment on a data blob — the kind came from CP2
  classification and is part of the evidence trail.

## 6. Forced `.byte` lines

Mechanical slices force some instructions to `.byte ... # forced: <text>`.
If the instruction is a normal encoding, restore the instruction (e.g.
`add %al,%al` for `02 c0`) — `check_func.py` proves it. If forcing was due to a
real ambiguity (straddle, stop-trunc, mis-decode), keep `.byte` and say why in
a comment. (`db`/`.byte` are interchangeable in cleaned files; the harness
normalises.)

## 7. System-call seams (Phase 5 hooks)

Every OS/hardware entry point gets a **zero-byte-cost** seam: a label + comment
at the `int`/port instruction site. Names: `video_int10`, `key_int16`,
`clock_int1a`, `dos_int21`, `speaker_tone` (ports 0x61/0x42/0x43).
Multiple sites in one function: suffix with the local offset, e.g.
`video_int10_2:`.

```
        int $0x10         # video_int10 seam
```

Phase 5 replaces these seams with portable calls; nothing else may be assumed
replaceable.

## 8. Comments

* Trailing `#` comments for intent; keep objdump's raw text when it is already
  right. Comment density goal: a reader can follow control flow without
  decoding hex. Do not narrate every register move.
* Keep the `# func ...` map line out of cleaned files — the header template
  carries that info.
* **Never write an uppercase `L_<hex>` token in a header comment.** `check_func.py`
  collects label references from the file text and requires every target inside the
  function's own range to be defined there — and it does not stop at `#` lines. Measured
  2026-10-28: a header sentence quoting `"what L_005CB1 does"` made the proof fail with
  `L_005CB1 targets inside the function range but is not defined in asm/5AB1_....asm`,
  even though the body defines the lowercase `L_005cb1` the callers actually use. Labels in
  this tree are lowercase hex; quote them that way, or name the address as `0x5CB1` instead
  of a label.

## 9. Hard rules (recap)

1. No cleaned function may change any byte. `check_func.py <SEG>` green is
   mandatory before commit; CI of one = the exit code.
2. Body length must equal the map range (harness enforces; last function
   8DCD is clamped to EOF by the harness).
3. `tools/assemble_all.sh` (mechanical tree) must stay green at all times —
   Phase 1/2 invariant.
4. Curated per-function files are committable (Apache-2.0, our prose); full
   dumps stay gitignored.
