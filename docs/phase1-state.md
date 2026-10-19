# Phase 1 State

Resume at the first non-`done` row. Update this file (and `phase1-implementation.md`) after every
checkpoint. See `phase1-plan.md` for the full work order.

| CP | Checkpoint | Status | Result / artifact paths | Updated |
| --- | --- | --- | --- | --- |
| CP0 | Environment & isolation verification (+ git init) | done | All 4 tools OK; binary 37,344 B; git repo initialised, initial commit b045523; ignore-policy verified | 2026-10-19 |
| CP1 | Entry points from runtime CFG | done | 796 code blocks -> 693 unique entries (103 dead-dropped, 0 dupes); 692/693 first-opcode match vs file (1 = known reloc fixup); 3 objdump spot-checks OK | 2026-10-19 |
| CP2 | Command jump table (26 handlers) | done* | Table found at file 0x930 (dispatcher 017D:0A1F); 26/26 plausible starts; only 7/26 in CFG — 19 handlers never executed in playthrough (gap documented, decision flagged for CP6 gate). Union seed `disasm/seed-entries.txt` = 712 | 2026-10-19 |
| CP3 | Segment map & memory-dump inventory | done | `disasm/segment-map.md`: CS=017D, DS=0x08BE, 0x0741→0x08BE fixup caveat, +0x200 map; live-ds dump 4096 B, `TEST` @ DS:0x36 confirms layout | 2026-10-19 |
| CP4 | Seeded Ghidra decompilation | todo | | |
| CP5 | Seeded Reko decompilation | done* | Exit 0; 712/712 seeds emitted + 126 discovered (839 defines); 3 per-proc rewrite failures; 1 contained SSA exception (fn 531B) — see notes; `original/` restored byte-clean | 2026-10-19 |
| CP6 | Byte-check verification 🔒 | todo | | |
| CP7 | Function inventory & sign-off 🔒 | todo | | |

Status values: `todo` / `in-progress` / `done` / `blocked`.

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

## Gate log

_(record each 🔒 gate summary and the user's decision here)_
