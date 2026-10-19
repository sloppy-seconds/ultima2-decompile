# Phase 2 Plan — Function Boundaries, Code/Data Separation, Verified Per-Function ASM

Goal: turn the Phase 1 evidence base into a **structured, buildable, per-function assembly
corpus** — every byte of the file attributed to a function or a named data region, function
ranges fed back into Reko, and the bytecheck re-run against *true* boundaries. Phase 3 (C
lifting) starts from this corpus.

> **To start a fresh agent on this plan:** paste `docs/phase2-kickoff.md`. The agent maintains
> `docs/phase2-state.md` (checkpoint table) and `docs/phase2-implementation.md` (running log).

---

## 0. How to run this plan (resume protocol)

1. Read `AGENTS.md` §0 (isolation, licensing) — hard rules, unchanged.
2. Read this plan fully, then `docs/phase1-summary.md` (signed-off baseline) and
   `docs/phase2-state.md` — resume at the first non-`done` checkpoint.
3. Work checkpoints in order. Per checkpoint: run steps, run its **Test**, verify **Acceptance**
   objectively, update the state table, append a detailed section to the implementation log
   (commands, measured outputs, decisions, dead-ends, deviations), commit `phase2: CP<n> <result>`.
4. 🔒 gates (CP6, CP7): stop and wait for the owner. Everything else: decide and record.

### Hard guardrails (unchanged from Phase 1)

* Only `/var/home/paul/Projects/decompile-u2-v2/` may be read/written. No sibling projects.
  (Owner standing note: raw captures under `/var/home/paul/Projects/ultima2/references/extracted/live-capture/`
  remain authorized as user-supplied evidence, same rules as `captures/external-20261019/`.)
* Never write `references/`; never mutate `original/` (md5 `fe884d5117971073ac8097cc7a6aca25`).
* Scratch in `tmp/` or `/var/tmp` — never `/tmp`.
* Commit policy unchanged: no game blobs, no GPL tool builds, no bulky derived dumps
  (`decompiled/`, full `.asm` dumps, raw captures stay gitignored). Scripts, `.md`/`.tsv`
  analysis notes, plans, and small factual findings commit freely.

## 1. Invariants and reference facts (verified in Phase 1 — do not re-derive)

* Binary `original/ultimaii.exe`, 37,344 B (0x91E0). Code segment `017D`; **file = seg_off + 0x200**.
  Ghidra `1000:X` = Reko `0800:X` = file `X+0x200`. Relocation caveat: file 0x0741 word
  `0x0741`→runtime `0x08BE` (DS fixup); entry 0100 first-opcode mismatch is expected.
* `disasm/ultimaii.asm` — whole-file ground-truth asm (GNU `as --32` + `.code16`), re-assembles
  **byte-identical** (16,411 insns, 2,071 forced `.byte`). Verify: `./tools/verify_asm.sh`.
* `disasm/entry-points.txt` (1113), `disasm/jump-table.txt` (26 handlers A–Z, table file 0x930,
  dispatcher 017D:0A1F), `disasm/seed-entries.txt` (1125).
* `disasm/functions.tsv` — Phase 1 inventory (1125 rows). `disasm/bytecheck-full.tsv` —
  per-entry verdicts. `decompiled/reko/ultimaii.c` — 1293 procedures (primary pseudo-C).
* Runtime CFGs: `captures/spice86/` + `captures/external-20261019/` (44 dirs, PROVENANCE.md).
  Block starts are execution-confirmed boundaries; 12 handlers (C D G H J K L M O R T V W X)
  have no runtime coverage — jump-table entry only.
* Known shared routine: `0x51DF` = inline-string display (24/26 handlers `call` it first).
* Known defects to resolve: Reko fabrications at **0x0A5F** (phantom stack delta) and
  **0x4FA5** (phantom `> 0x3800` compare); Reko per-proc failures 2395, 35DD, 531B (contained).
* Tools: `source tools/env.sh` (GHIDRA_HOME, REKO_DLL). Reko ~5 min/run. Ghidra ~3.5 h/run —
  **do not** batch-run Ghidra this phase; it is for MarkInlineData, GUI spelunking, spot checks.
* `jwasm`/`nasm` are NOT installed; GNU binutils (`as`, `objcopy`, `objdump -j .data`) is the
  assembler surface. Owner may install jwasm later; do not block on it.

## 2. Inputs already available (do not regenerate)

Everything in §1. Phase 1 artifacts are frozen: if a Phase 1 artifact must change, note it in
the implementation log and re-verify its own gate (e.g. asm byte-match) after the change.

## 3. Checkpoints

### CP0 — Baseline verification & workspace setup

- Re-verify: binary md5, `./tools/verify_asm.sh` byte-match, `functions.tsv`/`bytecheck-full.tsv`
  row counts, Reko `.c` define count. Create `docs/phase2-state.md` (checkpoint table, all
  `todo`) and `docs/phase2-implementation.md` (header).
- **Acceptance:** all Phase 1 invariants in §1 re-verified true; state/log files exist.
- **Test:** commands + outputs in the log; commit `phase2: CP0 baseline verified`.

### CP1 — Function boundary map (the core algorithmic work)

Build `tools/build_function_map.py` producing `disasm/function-map.tsv`:
`start  end  len  kind  evidence  name_hint` covering the whole code segment (file 0x200..0x91DF).

Evidence sources, in priority order (record which fired per boundary):
1. **Seed entries** (`seed-entries.txt`) — execution-confirmed or jump-table-confirmed starts.
2. **CFG block starts** — execution-confirmed internal blocks (function-internal unless a
   predecessor outside the range `jmp`s in — check block preds).
3. **Call targets** — scan `ultimaii.asm` for `call` (E8 rel16, FF /2, 9A ptr) — every target
   is a function start.
4. **Jump-table targets** — scan for `mov bx,cs:[...]` / `jmp *bx` patterns and tables of
   plausible code words (the 0x930 command table is the known instance; find others).
5. **Reko procedure extents** — from `ultimaii.dis` label ranges (corroborating, not decisive).
6. **Termination heuristics** — `ret`/`retf`/`jmp`-tail ends a function; next start begins the
   next one.

Resolution rules (document deviations): a function ends at the next start; no overlaps; every
byte attributed exactly once. Bytes not covered by any function become **unassigned regions**
→ input to CP2. Dead-block addresses (dropped in CP1 v1) must NOT start functions.

- **Acceptance:** every byte in 0x200..0x91DF is in exactly one function or one unassigned
  region; all 1125 seeds are function starts; sum(function lens) + sum(unassigned) = 0x9000;
  spot-check 10 boundaries (5 seeded, 5 derived) against asm context in the log.
- **Test:** script is deterministic (re-run → identical file); commit.

### CP2 — Code/data separation of unassigned regions

Classify every unassigned region and every forced-`.byte` cluster in `ultimaii.asm`:
- **inline strings** (printable runs ≥4 chars, `$`-terminated or length-prefixed — the 0x51DF
  convention found in Phase 1), **jump/address tables** (monotonic plausible code words),
  **data tables** (map/graphics bytes, e.g. near DS-referenced clusters), **alignment padding**.
Emit `disasm/data-regions.tsv` (`start end kind note`) and a classified asm listing
`disasm/ultimaii-classified.asm` where data regions use `db` directives with kind comments.
Ghidra `MarkInlineData` output may corroborate but the bytes + CFG are the authority.

- **Acceptance:** every unassigned byte from CP1 has a kind; classified asm still assembles
  byte-identical (`tools/verify_asm.sh` variant); ≥90% of the 2,071 forced `.byte` instructions
  are explained (data misread, `(bad)` opcode, or dup-prefix — count and list the rest).
- **Test:** byte-match re-verified; region totals sum correctly; commit.

### CP3 — Per-function asm slices

Split the classified asm into `disasm/functions/<entry>.asm` (one file per function, labels
preserved, self-contained via the existing `.org`/label machinery). A rebuild script
(`tools/assemble_all.sh`) concatenates slices in address order into one source and re-verifies
the whole-file byte-match.

- **Acceptance:** one slice per function in `function-map.tsv`; `assemble_all.sh` exits 0 with
  byte-identical output; slice count matches map; commit (slices gitignored, script + map committed).
- **Test:** full rebuild from slices only (delete intermediate, rebuild, diff) passes.

### CP4 — Reko re-run on true boundaries + bytecheck v2

Feed the function map to Reko (entry list = map starts; `tools/make_reko_project.py` gains a
`--map` mode). Re-run (~5 min). Then re-run the bytecheck using **true ranges** from the map
(replacing the next-seed heuristic): `tools/bytecheck_full.py --map`. Expect: boundary-drift
(Class C) flags largely disappear; per-function verdicts become meaningful.

- **Acceptance:** Reko exit 0, all map starts emitted; bytecheck v2 report regenerated with
  per-class counts vs Phase 1 baseline (report the delta honestly, including any regressions);
  fabrication count stays ≤2 unless a new one is found and explained.
- **Test:** `decompiled/reko/` regenerated; `original/` md5 unchanged; commit report + tools.

### CP5 — Defect resolution: the two fabrications + Reko failures

Investigate 0x0A5F, 0x4FA5 against asm slices; classify each as (a) Reko bug with workaround,
(b) seed/boundary artifact fixed by CP1 map, or (c) genuine unknown — write findings into
`disasm/defects.md`. Same for 2395/35DD/531B (contained SSA/rewrite failures): document root
cause and the workaround (manual asm reading) — do not spend >2 h total here.

- **Acceptance:** each defect has a written verdict + disposition; commit.

### CP6 — Phase 2 byte-verification gate 🔒

Owner review: function map totals, classified data regions, bytecheck v2 delta report, defects.
Present: what changed vs Phase 1 baseline, any new unexplained bytes, remaining risks.

### CP7 — Sign-off & Phase 3 decision memo 🔒

Finalize `disasm/phase2-summary.md`: corpus stats (functions, avg size, data %), naming
conventions proposal (start from knowns: 0x51DF string-out, handlers A–Z), and the Phase 3
C-lifting strategy decision memo (lift-from-Reko vs lift-from-asm per function class). Owner
signs off; Phase 3 authorized.

## 4. Global acceptance criteria (Phase 2 "done")

1. `function-map.tsv` covers 100% of the code segment with no overlaps; all seeds are starts.
2. Every unassigned byte classified; forced-`.byte` regions ≥90% explained.
3. Per-function slices rebuild the original byte-for-byte (`assemble_all.sh`).
4. Reko re-run on true boundaries; bytecheck v2 regenerated with honest delta vs Phase 1.
5. The 2 fabrications + 3 Reko failures have written verdicts.
6. Zero unexplained bytes; anything unexplained is listed, not hidden.
7. `phase2-summary.md` + Phase 3 decision memo signed off at the CP7 gate.

## 5. Testing strategy

Every claim is a command + measured output in the implementation log. Byte-level claims use
`verify_asm.sh` / `assemble_all.sh` (exit code = truth). Map claims use sum/overlap checks in
`build_function_map.py` itself (fail loudly, non-zero exit). No manual eyeballing without a
recorded spot-check.

## 6. Known limits to record, not hide

- The 12 unexecuted handlers' internal boundaries are derived (call/flow), not execution-
  confirmed. If CP1/CP3 shows ambiguity there, request a targeted 5-min capture (owner
  approved this pattern) — name the exact command and scenario in the ask.
- Self-modifying code cluster (0x5120–0x5151) will resist sane boundaries; expect to carve it
  as a data/code hybrid region with an explicit note.
- Community-patch provenance: some regions may differ from the pristine 1983 release; not a
  defect to chase (AGENTS.md §0).
- Ghidra numbers will drift as its project is untouched this phase; Phase 1 Ghidra output
  remains frozen reference, not a Phase 2 gate input.

## 7. Definition of "stop and ask the user"

🔒 gates (CP6, CP7); a criterion that can only be met by loosening it; any need to touch paths
outside the project (beyond the standing live-capture authorization); any commit that might
violate the licensing policy; genuine blocker after two distinct recovery attempts; scope
change requests. Everything else: decide, record, continue.
