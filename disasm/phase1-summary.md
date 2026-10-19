# Phase 1 Summary — Evidence Capture (draft for sign-off)

Prepared 2026-10-19 (night). All artifacts regenerated from `original/` + runtime captures;
see §Provenance for the one owner-authorized external input.

## What was captured / produced

| Artifact | Content |
| --- | --- |
| `disasm/entry-points.txt` | 1113 execution-confirmed entry offsets (merged 45 CFG sources) |
| `disasm/jump-table.txt` | 26 command handlers, table at file 0x930, dispatcher at 017D:0A1F |
| `disasm/seed-entries.txt` | 1125 decompiler seeds (entries ∪ handlers) |
| `disasm/segment-map.md` | CS=017D, DS=0x08BE, relocation caveat, +0x200 mapping |
| `decompiled/ghidra/` | 1116 functions: 497 ok (44.5%), failures logged per row |
| `decompiled/reko/` | 1294 procedures (1125/1125 seeds + 169 discovered), 3 contained failures |
| `disasm/bytecheck-report.md` | stratified sample (44) with per-flag cause classes |
| `disasm/bytecheck-full.tsv` | full-corpus per-entry byte-validation verdicts |
| `disasm/functions.tsv` | machine-readable inventory (entry, size, statuses, confidence, source) |
| `disasm/ultimaii.asm` (on disk) | ground-truth asm of the whole file; **assembles byte-identically** (37,344 B) — verify with `tools/verify_asm.sh` |

## Coverage numbers (honest)

- Runtime evidence: 1224 unique executed code blocks across all captures (~2,400 → ~7,000+
  instruction records); 14/26 command handlers now execution-confirmed; 12 remain seeded only
  from the jump table (C D G H J K L M O R T V W X).
- Byte validation: Reko pseudo-C contradicts the binary in 2 procedures out of 1125. Ghidra
  pseudo-C is contaminated by flow-runaway bodies in 134 of 497 "ok" functions (boundary
  problem, not byte problem) — treat Ghidra bodies as drafts, the asm as truth.
- The asm extraction round-trips 100% of the file (16,411 instructions + 2,071 forced data
  bytes). This is the strongest artifact: any later claim can now be checked against a
  re-buildable, byte-exact asm listing.

## Known gaps

- Code never executed by any capture is absent from the entry list (absence ≠ non-code).
- Ghidra decompile rate 44.5% (< 60% plan bar): structural varnodes/timeout failures; every
  recovery mechanism in the plan was run to exhaustion (0 yield). Owner decision pending.
- 12 command handlers still lack runtime confirmation; a playthrough using them (with
  arguments/directions — see the command table in the implementation log) would close this.
- Community-patch provenance of the binary (AGENTS.md §0) — byte-match is against this pack.

## What Phase 2 must resolve

1. Function boundary recovery for the 134 flow-runaway Ghidra functions (use the asm slices +
   CFG block edges, not Ghidra's auto-bodies).
2. The two Reko fabrications (0x0A5F, 0x4FA5) and the 12 unexecuted handlers.
3. Inline-string/data separation (2,071 forced .byte regions are candidates).
4. Decide the C-lifting target style now that the asm ground truth exists.

## Provenance self-attestation

All entry points, addresses, and verdicts were derived from `original/ultimaii.exe` and runtime
CFG captures inside this project, **plus** 44 raw Spice86 CFG exports that the project owner
explicitly authorized by path on 2026-10-19 (`captures/external-20261019/PROVENANCE.md`;
byte-identity to `original/` verified before use). No prior analyses, symbol names, or
conclusions from any sibling project were read or imported. Nothing copyrighted or
GPL-licensed is committed; raw captures, decompiler dumps, and full asm dumps are gitignored.
