# Phase 1 State

Resume at the first non-`done` row. Update this file (and `phase1-implementation.md`) after every
checkpoint. See `phase1-plan.md` for the full work order.

| CP | Checkpoint | Status | Result / artifact paths | Updated |
| --- | --- | --- | --- | --- |
| CP0 | Environment & isolation verification (+ git init) | done | All 4 tools OK; binary 37,344 B; git repo initialised, initial commit b045523; ignore-policy verified | 2026-10-19 |
| CP1 | Entry points from runtime CFG | done | 796 code blocks -> 693 unique entries (103 dead-dropped, 0 dupes); 692/693 first-opcode match vs file (1 = known reloc fixup); 3 objdump spot-checks OK | 2026-10-19 |
| CP2 | Command jump table (26 handlers) | todo | | |
| CP3 | Segment map & memory-dump inventory | todo | | |
| CP4 | Seeded Ghidra decompilation | todo | | |
| CP5 | Seeded Reko decompilation | todo | | |
| CP6 | Byte-check verification 🔒 | todo | | |
| CP7 | Function inventory & sign-off 🔒 | todo | | |

Status values: `todo` / `in-progress` / `done` / `blocked`.

## Open questions / blockers

_(none yet)_

## Gate log

_(record each 🔒 gate summary and the user's decision here)_
