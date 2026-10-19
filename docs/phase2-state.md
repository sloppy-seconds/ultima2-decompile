# Phase 2 State — checkpoint table

Plan: `docs/phase2-plan.md`. Log: `docs/phase2-implementation.md`.
Statuses: todo | in-progress | done | blocked | awaiting-gate

| CP | Title | Status | Notes | Date |
| --- | --- | --- | --- | --- |
| CP0 | Baseline verification & workspace setup | done | md5 ✓, asm byte-match ✓, functions.tsv 1125, bytecheck-full 1125, Reko 1293 defines, seeds 1125 | 2026-10-19 |
| CP1 | Function boundary map | done | 1299 functions, 100% coverage, deterministic; 2395 flagged mid-instruction | 2026-10-19 | | |
| CP2 | Code/data separation | done | code 8238 + derived 13350 + string 7358 + zeros 2404 + table 40 + psp 256 + unclassified 5218 = 0x9000; forced .byte 100% explained; classified asm byte-matches | 2026-10-19 | | |
| CP3 | Per-function asm slices | done | map-driven asm regen fixed 106 mis-aligned starts; 1299 slices + prologue rebuild byte-identical | 2026-10-19 | | |
| CP4 | Reko re-run on true boundaries + bytecheck v2 | done | 1299/1299 emitted; mismatch 279->199, drift 574->371; fabs 2->6 (4 new, contexts recorded for CP5) | 2026-10-19 | | |
| CP5 | Defect resolution | done | defects.md: 5/6 fabs = bytecheck FPs, 1 true (0A5F); 3 failures = nop-pads + string site | 2026-10-19 | | |
| CP6 | Byte-verification gate 🔒 | **done (owner-approved 2026-10-19)** | Function map totals + classified regions + bytecheck v2 delta + defects presented; owner approved | 2026-10-19 |
| CP7 | Sign-off & Phase 3 memo 🔒 | **done (owner sign-off 2026-10-19)** | `disasm/phase2-summary.md` + Phase 3 C-lifting decision memo; Phase 3 authorized | 2026-10-19 |

## Gate log

- **2026-10-19 (owner):** CP6 byte-verification gate **approved** (map totals, classified data,
  bytecheck v2 delta, defect verdicts). CP7 summary + Phase 3 decision memo signed off.
  **Phase 2 complete; Phase 3 (C lifting) authorized** per the memo in `phase2-summary.md`.

## Open questions / blockers

(none yet)
