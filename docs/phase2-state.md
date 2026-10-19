# Phase 2 State — checkpoint table

Plan: `docs/phase2-plan.md`. Log: `docs/phase2-implementation.md`.
Statuses: todo | in-progress | done | blocked | awaiting-gate

| CP | Title | Status | Notes | Date |
| --- | --- | --- | --- | --- |
| CP0 | Baseline verification & workspace setup | done | md5 ✓, asm byte-match ✓, functions.tsv 1125, bytecheck-full 1125, Reko 1293 defines, seeds 1125 | 2026-10-19 |
| CP1 | Function boundary map | done | 1299 functions, 100% coverage, deterministic; 2395 flagged mid-instruction | 2026-10-19 | | |
| CP2 | Code/data separation | done | code 8238 + derived 13350 + string 7358 + zeros 2404 + table 40 + psp 256 + unclassified 5218 = 0x9000; forced .byte 100% explained; classified asm byte-matches | 2026-10-19 | | |
| CP3 | Per-function asm slices | todo | | |
| CP4 | Reko re-run on true boundaries + bytecheck v2 | todo | | |
| CP5 | Defect resolution (2 fabrications, 3 Reko failures) | todo | | |
| CP6 | Byte-verification gate 🔒 | todo | | |
| CP7 | Sign-off & Phase 3 memo 🔒 | todo | | |

## Gate log

(none yet)

## Open questions / blockers

(none yet)
