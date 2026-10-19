> **STATUS: deferred draft.** Became future Phase 4 (C lifting); the active Phase 3 is now the
> clean byte-exact ASM reconstruction (`docs/phase3-plan.md`). Content kept for reuse.

# Phase 4 (draft) — Pseudo-C Lifting (asm is the oracle)

Goal: produce readable, correct 16-bit pseudo-C for the game's functions, starting from the
Reko drafts, with the **byte-exact asm slices as the reference oracle**. Phase 3 delivers
understanding, not a recompilable rebuild: this binary is hand-coded 1983 assembly, so
"compile the C and byte-match the original" is not achievable with any available compiler
(verified: gcc `-m16` emits operand-size prefixes; Open Watcom/Turbo C are not installed and
even they would not reproduce hand-coded idioms). The AGENTS.md Phase-4 loop is therefore
scoped in this project to **asm-level** byte-matching (done in Phase 2) plus **semantic**
C verification.

> **To start a fresh agent:** paste `docs/phase3-kickoff.md`. Agent maintains
> `docs/phase3-state.md` + `docs/phase3-implementation.md`.

---

## 0. How to run this plan (resume protocol)

1. Read `AGENTS.md` §0 — hard rules unchanged (isolation, licensing, scratch paths).
2. Read this plan, `disasm/phase2-summary.md` (baseline + decision memo), then
   `docs/phase3-state.md` — resume at first non-`done` checkpoint.
3. Per checkpoint: run steps, run its Test, verify Acceptance objectively, update state,
   append to the implementation log, commit `phase3: CP<n> <result>`.
4. 🔒 gates: CP3 (pilot review), CP6 (sign-off). Everything else autonomous.
5. Standing owner decisions: no playthrough captures unless explicitly requested; Ghidra
   stays demoted; Reko is the draft source.

### Hard guardrails (unchanged)
Project root only; `references/` immutable; `original/` never mutated; scratch `tmp/` or
`/var/tmp`; commit policy unchanged (`src/` C we author IS committable — it is our work;
generated dumps stay gitignored).

## 1. Invariants and reference facts (from Phases 1–2 — do not re-derive)

* Binary `original/ultimaii.exe` 37,344 B md5 `fe884d5117971073ac8097cc7a6aca25`;
  **segment offsets everywhere in `disasm/`; file = seg + 0x200**.
* `disasm/function-map.tsv` — 1299 functions tiling the segment; `evidence` + `name_hint`
  columns. `disasm/functions/<SEG>.asm` — per-function asm slices; `tools/assemble_all.sh`
  proves the rebuild byte-identical.
* `decompiled/reko-map/ultimaii.c` — Reko drafts for 1299/1299 starts (1 true fabrication:
  0A5F; see `disasm/defects.md`). `disasm/bytecheck-map.tsv` — per-function verdicts
  (537 verified / 199 mismatch-drift / 563 no-claims).
* Function classes (phase2-summary §memo): normal | no-claims (lift from asm) | defect
  (0A5F, 47BD-family data islands, 2395/35DD nop-pads, 531B string site) | self-modifying
  cluster 0x5120–0x5151 (EXCLUDE from lifting).
* Naming: `cmd_A..Z` (handlers), `str_out` (0x4FDF), default `sub_<start>`.
* 16-bit rules for all C: `sizeof(int)==2`, near ptr 2 B, far ptr 4 B, `push bp; mov bp,sp`
  frames common, DS-relative globals at seg-data addresses (see `segment-map.md`), inline
  strings passed to `str_out`.
* Toolchain reality: gcc 16.2 supports `-m16` (odd encodings, not byte-matchable); no
  Open Watcom/Turbo C/jwasm/nasm installed. Do NOT install system packages without owner ask.

## 2. Inputs already available (do not regenerate)

Everything in §1 plus `captures/` and all Phase 1/2 artifacts. If a Phase 2 artifact changes,
re-run its gate (`assemble_all.sh` for anything asm-related).

## 3. Checkpoints

### CP0 — Baseline verification & workspace setup
Re-verify: binary md5, `assemble_all.sh` byte-match, map/slices/bytecheck counts, Reko-map
defines. Create `docs/phase3-state.md` + `docs/phase3-implementation.md`.
**Acceptance:** all §1 invariants re-verified true; files exist. Commit `phase3: CP0`.

### CP1 — Lifting harness + conventions doc
Write `docs/lifting-guide.md`: the C style (types `u8/u16`, near/far conventions, how globals
and inline strings are represented, register-allocation comments, per-function header comment
template: `/* sub_XXXX  evidence=...  confidence=...  notes */`), and the **verification
protocol** (below). Write `tools/lift_check.py`: for a lifted function — (a) re-assembles its
asm slice bytes unchanged (guard against slice drift), (b) checks the C file parses
(`gcc -fsyntax-only -m16` with a shared `src/u2_types.h`), (c) every referenced `sub_/data_`
symbol exists in the symbol index or is explicitly extern'd.
**Acceptance:** guide committed; `lift_check.py` passes on a hand-made example function.

### CP2 — Pilot: the 26 command handlers
Lift `cmd_A..cmd_Z` + `str_out` (27 functions) end-to-end into `src/cmd_handlers.c`
following the guide: Reko draft -> hand-lift -> symbol check -> semantic review against the
asm slice (every branch, constant, and memory access in the slice accounted for in the C).
**Acceptance:** 27/27 lifted; `lift_check.py` green; a written per-function review line in
the log (matched-semantics or documented deviation).

### CP3 — Pilot review 🔒
Owner reviews the pilot C: style, readability, comment density, confidence. This sets the
template for the bulk work. **Gate: stop and wait.**

### CP4 — Bulk wave 1: call-graph-reachable normal functions
From handlers + `str_out`, walk the call graph outward; lift every normal-class function
within depth 2 (expect ~150–300; count from the call scan). Same protocol as CP2, batched
(~30 per batch, log per batch).
**Acceptance:** all in-scope functions lifted + checked; zero unexplained slice instructions
in them (each slice byte is code-with-meaning or annotated data).

### CP5 — Bulk wave 2: remainder + defect dispositions
Remaining normal/no-claims functions outside wave 1; apply defect dispositions from
`defects.md` (reclassify 47BD-family as data, mark nop-pads, document 0A5F and 531B in
place). Emit `src/README.md` index: file -> function -> status -> confidence.
**Acceptance:** every one of the 1299 map functions is exactly one of: lifted | data |
excluded(selfmod) | deferred-with-reason — counted in the log, sums to 1299.

### CP6 — Phase 3 sign-off 🔒
`disasm/phase3-summary.md`: stats (functions lifted, LOC, confidence mix), what "verified"
means here (semantic review + slice integrity, NOT compile byte-match), residual unknowns,
Phase 4 proposal (functional emulator-level differential testing OR targeted recaptures —
owner's call). **Gate: stop and wait.**

## 4. Global acceptance criteria (Phase 3 "done")

1. `src/` contains lifted C for all liftable functions, style-checked, symbol-checked.
2. Every lifted function passed the verification protocol (CP1 §b,c + semantic review).
3. 1299/1299 map functions dispositioned (lifted/data/excluded/deferred) with counts shown.
4. Pilot + final reviews signed off by the owner at both 🔒 gates.
5. No Phase 1/2 invariant broken (rebuild still byte-identical at every checkpoint).

## 5. Testing strategy

`lift_check.py` per function (slice integrity + syntax + symbols) is mechanical truth.
Semantic equivalence is human-review truth: the reviewer reads C against the asm slice;
the log records the review line per function. No claim of "compiled byte-match" is made
anywhere — that bar is explicitly retired for C (owner ratified at CP0 of this phase by
approving this plan; revisit only if the owner installs a period compiler).

## 6. Known limits to record, not hide

- Hand-coded asm idioms (self-modifying code, overlay tricks, exact register choices) may
  resist faithful C; such functions get `confidence=low` + notes, not silent fudging.
- 5,218 B unclassified may hide small functions; wave 2 re-examines the biggest clusters.
- No functional test harness yet — semantic review is the only correctness signal until
  Phase 4 proposes more.

## 7. Definition of "stop and ask the user"

🔒 gates (CP3, CP6); any request to install system tooling; any out-of-project path; any
criterion only meetable by loosening it; blocker after two recovery attempts; scope change.
