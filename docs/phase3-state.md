# Phase 3 State — checkpoint table

Plan: `docs/phase3-plan.md`. Log: `docs/phase3-implementation.md`.
Statuses: todo | in-progress | done | blocked | awaiting-gate

| CP | Title | Status | Notes | Date |
| --- | --- | --- | --- | --- |
| CP0 | Baseline & workspace | done | md5 ✓ `fe884d...`; assemble_all REBUILD BYTE-MATCH 37344 B ✓; map 1299 functions; 1299 slices + `_prologue.asm`; jwasm v2.21 vendored and verified (`-bin -Fo` smoke test OK); state + impl log created | 2026-10-20 |
| CP1 | check_func.py harness + asm-style.md | done | harness proven on 1299/1299 mechanical slices + 3 cleaned seeds (0133 straight-line, 2B8F inline string, 0D21 far externals); style guide committed | 2026-10-20 |
| CP2 | Pilot: cmd_A..Z + str_out (27) | done | 27/27 check_func green; new tools preclean.py + decode_str.py (str_out-aware re-decode fixed all 5 mis-decode defects); per-function log in impl doc | 2026-10-20 |
| CP3 | Style gate 🔒 | done (owner-approved 2026-10-20) | owner: AFTER style = goal; max accurate comments; honest naming, improve in later passes | 2026-10-20 |
| CP4 | Bulk wave 1: execution-confirmed code | done | 1052/1052 green (majority-execution-confirmed cut); 42 batch commits; auto INT/port seams; verify_encodings fix | 2026-10-20 |
| CP5 | Bulk wave 2 + dispositions + jwasm dialect | in-progress | | |
| CP6 | Full-tree rebuild + sign-off 🔒 | todo | | |

## Gate log

- **2026-10-20 (owner):** CP3 **approved**. Owner verdict: AFTER style is the
  goal; directive "more comments the better, as long as they're accurate";
  naming as honest as possible (proven names only; `sub_<seg>` default;
  better names in later passes). Bulk waves proceed under these rules.
- **2026-10-20 — CP3 🔒 AWAITING OWNER REVIEW.** Pilot = 27 files in `asm/`
  (26 `cmd_*` + `str_out`), all `check_func.py` green. Decisions needing
  owner sign-off: (1) `#` comments + `db`/`dw` data dialect normalized by the
  harness (gas can't take `;` or multi-char `.byte ".."`); (2) big handlers
  keep mechanical `L_<addr>` labels as anchors, meaningful names only where
  proven; (3) mis-decode sites re-decoded via `tools/decode_str.py` with
  gas-re-encode diffs kept as `.byte # forced-kept`; (4) INT-stub seam =
  label+comment at int/port site (no hits in pilot; lands CP4/5).

## Open questions / blockers

(none yet)
