# Phase 2 Implementation Log

Running log per `docs/phase2-plan.md` §0. Newest section last.

## CP0 — Baseline verification & workspace setup (2026-10-19)

Re-verified every §1 invariant before touching anything:

| Check | Command | Result |
| --- | --- | --- |
| Binary identity | `md5sum original/ultimaii.exe` | `fe884d5117971073ac8097cc7a6aca25` ✓ |
| ASM byte-match | `./tools/verify_asm.sh` | `BYTE-MATCH: 37344 bytes identical` ✓ |
| Inventory | `wc -l disasm/functions.tsv` | 1126 (header + 1125) ✓ |
| Bytecheck corpus | `wc -l disasm/bytecheck-full.tsv` | 1126 ✓ |
| Reko procedures | `grep -c '^define fn0800_' decompiled/reko/ultimaii.c` | 1293 ✓ |
| Seeds | `wc -l disasm/seed-entries.txt` | 1125 ✓ |

Created this log and `docs/phase2-state.md`. No deviations.

## CP1 — Function boundary map (2026-10-19)

- Resolved the offset-convention question empirically first: **all disasm artifacts
  (entry-points, seed-entries, jump-table, bytecheck, functions.tsv) are SEGMENT offsets**
  (file = seg + 0x200); only `ultimaii.asm` labels are file offsets. Verified with code bytes
  (handler A seg 2B8F = file 2D8F = `e8 4d 24` call -> shared routine file 0x51DF = seg 4FDF).
- `tools/build_function_map.py`: starts = seeds (1125) ∪ asm call/lcall targets (243 call sites
  incl. forced-.byte comments) ∪ Reko defines; tile rule start->next-1; hard asserts (all seeds
  are starts, no gaps/overlaps, coverage = 0x9000).
- Result: **1299 functions**; evidence mix: seed+call+reko 66, seed+reko 1059, reko-only 106,
  call+reko 62, call-only 6. Unassigned: seg 0x0000..0x00FF (256 B, MZ relocation area) -> CP2.
- Named 27 (26 command handlers `cmd_A..Z`, `str_out` @ seg 4FDF).
- Spot-check 10 boundaries (5 seeded, 5 derived, seed 42): all show plausible code starts,
  EXCEPT **2395 has no asm label** (mid-instruction per linear decode) — corroborates the CP5
  suspicion that the Reko-failing 2395 seed is not a real boundary. Recorded, not hidden.
- Determinism: re-run -> byte-identical file (verified). Acceptance met (all four clauses).
