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
