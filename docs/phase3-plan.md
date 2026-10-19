# Phase 3 Plan — Clean Byte-Exact ASM Reconstruction (MASM dialect)

Goal: transform the mechanical Phase 2 asm (objdump AT&T, `L_<addr>` labels, `.byte` blobs)
into a **readable, structured, named assembly reconstruction that still re-assembles
byte-identical**. For this hand-coded 1983 binary, this is the gold-standard, *verifiable*
decompilation: every cleaned function carries proof (its bytes), unlike C which can only be
argued. C lifting is deferred to Phase 4 (`docs/phase4-draft-c-lift.md`); a runnable Linux
build is Phase 5 via C+SDL — the assemblers themselves are not a portability path.

Assembler decision (owner 2026-10-19): **jwasm is the chosen dialect target** (MASM-compatible,
era-faithful, AGENTS.md §1). **INSTALLED:** JWasm v2.21 built from source, vendored at
`tools/jwasm/jwasm` (gitignored binary + README with rebuild steps; Open Watcom Public License,
same vendored-tool policy as spice86/reko). `source tools/env.sh` exports `$JWASM`. GNU `as`
remains the independent whole-tree verifier (`assemble_all.sh` must stay green regardless).

> **To start a fresh agent:** paste `docs/phase3-kickoff.md`. Agent maintains
> `docs/phase3-state.md` + `docs/phase3-implementation.md`.

---

## 0. How to run this plan (resume protocol)

1. Read `AGENTS.md` §0 — hard rules unchanged (isolation, licensing, scratch paths).
2. Read this plan, `disasm/phase2-summary.md`, then `docs/phase3-state.md` — resume at first
   non-`done` checkpoint.
3. Per checkpoint: steps, Test, objective Acceptance, state update, implementation-log section,
   commit `phase3: CP<n> <result>`.
4. 🔒 gates: CP3 (style review), CP6 (sign-off). Everything else autonomous.
5. Standing decisions: no captures unless requested; Ghidra demoted; Reko drafts may inform
   *naming* (what a function touches) but the asm slice is the sole authority for *content*.

### Hard guardrails (unchanged)
Project root only; `references/` immutable; `original/` never mutated; scratch `tmp/` or
`/var/tmp`; commit policy: clean asm we author is committable **only as curated per-function
files if small; full dumps stay gitignored** (same policy as Phase 2).

## 1. Invariants and reference facts (from Phases 1–2 — do not re-derive)

* Binary `original/ultimaii.exe` 37,344 B md5 `fe884d5117971073ac8097cc7a6aca25`;
  **segment offsets in `disasm/`; file = seg + 0x200**; code segment tiles 0x0000..0x8FFF.
* `disasm/function-map.tsv` — 1299 functions (start, end, len, evidence, name_hint).
* `disasm/functions/<SEG>.asm` — mechanical slices; `tools/assemble_all.sh` proves the whole
  rebuild byte-identical. **This is the oracle every cleaned function must keep matching.**
* `disasm/data-regions.tsv` + byte kinds (CP2): code 8,238 · code-derived 13,350 ·
  string 7,358 · zeros 2,404 · table 40 · psp 256 · unclassified 5,218.
* Defects (`disasm/defects.md`): 0A5F Reko stack bug; 47BD/4815/486D data islands;
  2395/35DD nop-pads; 531B str_out+string site; selfmod cluster 0x5120–0x5151.
* Known names: `cmd_A..Z` (26 handlers, table seg 0x730), `str_out` (seg 0x4FDF).
* System surface (thin, from Phase 2 probe): INT 10h/16h/1Ah/21h call sites + speaker ports
  0x61/0x42/0x43. Clean asm must wrap each call site in a named stub
  (`video_int10`, `key_int16`, `clock_int1a`, `dos_int21`, `speaker_tone`) — this seam is what
  Phase 5's portable port will replace.
* Toolchain: GNU `as --32` + `.code16` + `objcopy` (works, byte-matches) AND `$JWASM` v2.21
  (installed 2026-10-19; `-bin -Fo<out>` output, case-sensitive options; error log lands in a
  `<name>.err` file — keep invocations inside `tmp/`). No system installs needed.

## 2. Inputs already available (do not regenerate)

Everything in §1. If any Phase 2 artifact changes, re-run `tools/assemble_all.sh` (must stay green).

## 3. Checkpoints

### CP0 — Baseline & workspace
Re-verify §1 (md5, assemble_all byte-match, map/slice counts). Create `docs/phase3-state.md` +
`docs/phase3-implementation.md`. Record jwasm availability status.
**Acceptance:** invariants true; files exist. Commit.

### CP1 — Per-function verification harness + style guide
The keystone tool: `tools/check_func.py <SEG>` — assembles ONE cleaned function in isolation
(wrapped with the standard prologue context + `.org` to its true origin + extern `.org` label
stubs for out-of-function branch targets) and byte-diffs its own range against `original/`.
Exit 0 = that function is proven.
Write `docs/asm-style.md`: file layout (`asm/<SEG>_<name>.asm` per function), naming rules
(`cmd_*`, `str_out`, `sub_<seg>` default, `data_<seg>_<kind>`), data directives (`db`/`dw` with
kind comments for strings/tables/zeros instead of `.byte` blobs), comment header template per
function (evidence, confidence, notes), INT-stub naming seam (see §1), and the rule:
**no cleaned function may change any byte; `check_func.py` green is mandatory before commit.**
**Acceptance:** harness proven on 3 seeded examples (one straight-line, one with inline string,
one with far-out branch targets); style guide committed.

### CP2 — Pilot: 26 handlers + str_out
Clean `cmd_A..Z` + `str_out` (27 functions) per the style guide: meaningful local labels
(`.Lcmd_cast_retry`), inline strings as `db "text",0` with the `str_out` call annotated,
data islands as `db` blobs with kind comments. Each passes `check_func.py`.
**Acceptance:** 27/27 green; per-function log line (what was cleaned, anything left mechanical).

### CP3 — Style gate 🔒
Owner reviews pilot asm: naming feel, comment density, dialect choices, INT-stub seam.
Sets the template for bulk work. **Stop and wait.**

### CP4 — Bulk wave 1: execution-confirmed code
All functions whose ranges are predominantly `code` kind (execution-confirmed). Expected
several hundred. Batch ~25 per commit-batch; every function `check_func.py` green; log per batch.
**Acceptance:** all wave-1 functions green; `assemble_all.sh` still byte-identical.

### CP5 — Bulk wave 2 + dispositions + (jwasm if installed)
Remaining `code-derived`/`no-claims` functions; apply defect dispositions (47BD-family → data
files; nop-pads marked; 531B documented; selfmod cluster 0x5120–0x5151 reconstructed as-is
with loud comments). Every one of the 1299 map functions ends as: **clean | data | excluded
(selfmod) | deferred-with-reason** — counts must sum to 1299.
jwasm is installed: add `tools/dialect_masm.py` converting the cleaned
tree to MASM syntax and verify dual-assembly byte-match (GNU as + jwasm) on a 50-function
sample; report honestly if jwasm quirks force deviations.
**Acceptance:** 1299 dispositioned with counted sum; jwasm sub-task done or explicitly
skipped (owner not yet installed — not a blocker).

### CP6 — Full-tree rebuild + sign-off 🔒
`tools/assemble_clean.sh`: rebuild the ENTIRE binary from the cleaned tree only (cleaned
functions + data files + mechanical remainder), byte-diff vs original — must be identical.
Write `disasm/phase3-summary.md`: stats (clean/data/excluded/deferred counts, % mechanical
remaining), the verifiability statement (every cleaned byte proven; deferred bytes listed),
and Phase 4/5 handoff notes. **Stop and wait for owner sign-off.**

## 4. Global acceptance criteria (Phase 3 "done")

1. Full-tree rebuild from the cleaned source is byte-identical (`assemble_clean.sh`).
2. 1299/1299 functions dispositioned (clean | data | excluded | deferred) with counts shown.
3. Every `clean` function individually proven by `check_func.py`.
4. Pilot + final style gates signed off by owner (CP3, CP6).
5. No Phase 1/2 invariant broken at any checkpoint (assemble_all green throughout).

## 5. Testing strategy

Mechanical truth: `check_func.py` (per function) + `assemble_all.sh` (whole tree) — exit codes,
not opinions. Style truth: owner at CP3. Deferred/mechanical bytes are listed, counted, and
never hidden inside "clean" claims.

## 6. Known limits to record, not hide

- Byte-identical reconstruction ≠ recovered original source: names/comments/macros of the
  1983 listing are unrecoverable; this is a faithful reconstruction, stated as such everywhere.
- 5,218 B unclassified may hide small functions; wave 2 re-examines the largest clusters.
- Self-modifying cluster cannot be made "readable" — reconstructed as-is with documentation.
- jwasm is installed (v2.21, vendored); the dialect conversion rides on it from the start.

## 7. Definition of "stop and ask the user"

🔒 gates (CP3, CP6); tooling installs; out-of-project paths; any criterion only meetable by
loosening it; blocker after two recovery attempts; scope change.
