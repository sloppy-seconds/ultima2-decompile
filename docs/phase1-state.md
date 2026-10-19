# Phase 1 State

Resume at the first non-`done` row. Update this file (and `phase1-implementation.md`) after every
checkpoint. See `phase1-plan.md` for the full work order.

| CP | Checkpoint | Status | Result / artifact paths | Updated |
| --- | --- | --- | --- | --- |
| CP0 | Environment & isolation verification (+ git init) | done | All 4 tools OK; binary 37,344 B; git repo initialised, initial commit b045523; ignore-policy verified | 2026-10-19 |
| CP1 | Entry points from runtime CFG | done (v2) | Merged 45 CFG sources (incl. 44 owner-authorized external captures): **1113** unique entries; all byte-verified vs file (only 0100 fixup differs) | 2026-10-19 |
| CP2 | Command jump table (26 handlers) | done* | Table at file 0x930; 26/26 plausible; runtime coverage now **14/26** (was 7/26) after external merge; 12 handlers seeded from table only — flagged for gate | 2026-10-19 |
| CP3 | Segment map & memory-dump inventory | done | `disasm/segment-map.md`: CS=017D, DS=0x08BE, 0x0741→0x08BE fixup caveat, +0x200 map; live-ds dump 4096 B, `TEST` @ DS:0x36 confirms layout | 2026-10-19 |
| CP4 | Seeded Ghidra decompilation | done* | v2 (1125 seeds): 1116 rows, 497 ok = **44.5%** (bar 60% — missed; new seeds are harder fragments; flow-runaway contamination in 134/497 ok bodies flagged) | 2026-10-19 |
| CP5 | Seeded Reko decompilation | done | v2: 1125/1125 seeds + 169 discovered (1294 defines); 3 contained per-proc failures; original/ byte-clean | 2026-10-19 |
| CP6 | Byte-check verification 🔒 | **done (owner-approved 2026-10-19)** | Sample 44 + full-corpus `bytecheck-full.tsv`: zero unflagged mismatches; Reko 2 fabrications total; Ghidra fabs all flow-runaway (moot after Ghidra demotion). Owner ratified | 2026-10-19 |
| CP7 | Function inventory & sign-off 🔒 | **done (owner sign-off 2026-10-19)** | `disasm/functions.tsv` (1125 rows) + `disasm/phase1-summary.md` approved; Phase 1 complete, Phase 2 authorized | 2026-10-19 |

Status values: `todo` / `in-progress` / `done` / `blocked`.

- **2026-10-19 (owner decisions, final):** (1) handler gap **accepted** — no further playthrough
  now; targeted 5-minute captures on demand if Phase 2 hits boundary ambiguity in one of the 12
  unexecuted handlers. (3) bytecheck **ratified** — CP6 closed. With (2) above (Ghidra bar
  retired), **Phase 1 is complete and Phase 2 is authorized**.

## Open questions / blockers

- **CP2 acceptance tension:** plan requires ≥24/26 jump-table targets in `entry-points.txt`; actual
  is 7/26 because the captured playthrough never pressed the other 19 keys (verified: absent from
  CFG entirely, not a dead-rule artifact). Plan §6 defers broader re-capture to Phase 2 and CP2
  step 4 permits "explain the gap". Proceeding per step 4; `entry-points.txt` stays strictly
  CFG-derived; CP4/CP5 seed from `disasm/seed-entries.txt` (union, 712). **Must be ratified by the
  user at the CP6 gate.**

- **CP5 SSA note:** acceptance says "run completes without an SSA crash". The run completed
  (exit 0) but one procedure (`0800:531B`) hit a caught SSA-transform exception (boundless
  recursion finding `ds` definitions, logged to `analysis_99_crash.txt`); 2 more procs failed
  rewrite (2395, 50F9). This is per-procedure containment, not the whole-run shingle-heuristic
  crash the doc warns about. Flagged for CP6 gate review.

- **CP4 acceptance shortfall:** ok = 411/707 = 58.1% vs the ≥60% bar. Failures are 199
  **Night update:** after the owner-authorized external capture merge, v2 numbers are 497/1116
  = **44.5%** — the 413 new seeds are harder startup/jump-table fragments, so the rate fell
  while absolute coverage rose (411→497 ok functions). The 60% bar looks unreachable under any
  Ghidra configuration on this binary; recommend the owner either accept 44.5% (with the asm
  byte-match as the real ground truth) or formally retire the bar.
- **CP4 acceptance shortfall (original run):** ok = 411/707 = 58.1% vs the ≥60% bar. Failures are 199
  "Cannot properly adjust input varnodes" + 97 timeouts; timeout failures are mostly 1-5 byte
  functions whose decompiler flow runs away (more time won't help); RetryDecompile (3 alt
  styles × 296) recovered 0. Reaching 60% would need ~13 more recoveries — no legitimate path
  found. **User decision at CP6 gate.**

## Gate log

- **2026-10-19 (owner decision):** Ghidra ≥60% decompile bar **retired**. Quality gate for
  Phase 1+ is now: (a) asm extraction re-assembles byte-identical (`tools/verify_asm.sh`),
  (b) full-corpus pseudo-C bytecheck with zero unflagged mismatches
  (`disasm/bytecheck-full.tsv`). Reko designated primary pseudo-C engine; Ghidra retained
  only for MarkInlineData, interactive GUI use, and targeted second opinions.

_(record each 🔒 gate summary and the user's decision here)_
