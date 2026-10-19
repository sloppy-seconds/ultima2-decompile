# Phase 3 State — checkpoint table

Plan: `docs/phase3-plan.md`. Log: `docs/phase3-implementation.md`.
Statuses: todo | in-progress | done | blocked | awaiting-gate

| CP | Title | Status | Notes | Date |
| --- | --- | --- | --- | --- |
| CP0 | Baseline & workspace | done | md5 ✓ `fe884d...`; assemble_all REBUILD BYTE-MATCH 37344 B ✓; map 1299 functions; 1299 slices + `_prologue.asm`; jwasm v2.21 vendored and verified (`-bin -Fo` smoke test OK); state + impl log created | 2026-10-20 |
| CP1 | check_func.py harness + asm-style.md | done | harness proven on 1299/1299 mechanical slices + 3 cleaned seeds (0133 straight-line, 2B8F inline string, 0D21 far externals); style guide committed | 2026-10-20 |
| CP2 | Pilot: cmd_A..Z + str_out (27) | todo | | |
| CP3 | Style gate 🔒 | todo | | |
| CP4 | Bulk wave 1: execution-confirmed code | todo | | |
| CP5 | Bulk wave 2 + dispositions + jwasm dialect | todo | | |
| CP6 | Full-tree rebuild + sign-off 🔒 | todo | | |

## Gate log

(none yet)

## Open questions / blockers

(none yet)
