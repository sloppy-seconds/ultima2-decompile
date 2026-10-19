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

## CP2 — Code/data separation (2026-10-19)

- `tools/classify_data.py`: byte-level classification of the whole 0x9000 code segment.
  Priority: code (executed CFG block byte ranges, computed from per-instruction hex in all
  45 captures) > psp > string (printable runs >=4) > zeros (runs >=8) > table (>=6 consecutive
  even-aligned function-map words) > code-derived (inside call/reko-evidenced function ranges)
  > unclassified. Emits `disasm/data-regions.tsv` + `disasm/ultimaii-classified.asm`
  (data bytes as `.byte` with kind comments, labels preserved).
- Byte kinds (sum = 36,864 = 0x9000 exactly): code 8,238 | code-derived 13,350 |
  string 7,358 | unclassified 5,218 | zeros 2,404 | table 40 | psp 256.
- Forced .byte explanation: 2,071/2,071 (100% >= 90% bar): data-misread 477,
  opcode-artifact 1,593 (gas-rejected real instructions incl. 683 call forms + (bad) opcodes),
  outside-seg 1 (MZ header).
- **CLASSIFIED BYTE-MATCH: OK** — classified asm re-assembles byte-identical.
- Command table detected at 0x730 (partial: 40 B of 52 — some table words fall on odd
  alignment vs my even-aligned scan; noted, not hidden; the 26 handler starts are seeds anyway).
- Sanity: exec'd handler A range = code 374/derived 276/string 102/unclass 240; unexecuted
  handler C = derived 496 (Reko flow covers it) + string 96 + code 83 + unclass 82. Plausible.
- Deviation note: plan said "db directives"; used `.byte` (GNU as equivalent) to keep the
  existing assemble pipeline unchanged.

## CP3 — Per-function asm slices (2026-10-19)

- First slice attempt exposed a real defect in the Phase 1 linear asm: **106 of 1299 function
  starts had no asm label** (linear decode mis-aligned across them; e.g. program entry file
  0x300 was swallowed by a straddling instruction at 0x2ff). Slicing the linear asm would have
  baked in wrong instruction boundaries.
- Fix: `tools/emit_map_asm.py` — map-driven regeneration: objdump decodes EACH function from
  its own start (aligned by construction), data-region bytes emitted as `.byte` with kind
  comments, MZ/PSP as blobs. New edge cases found and handled:
  * objdump truncates a row at stop-address but prints full text -> gas re-encodes PC-rel ops
    LONGER than the bytes present (stop-trunc force rule added);
  * rows straddling a function boundary -> `.byte` prefix + `straddle-trunc` so the next
    function still starts at its own label;
  * gap/tail pads for bytes no row covers.
  - `disasm/ultimaii-mapped.asm`: **MAPPED BYTE-MATCH: 37,344 bytes identical** (2,241 forced;
    +170 vs linear, all from boundary handling). All 1299 starts have labels (verified).
- `tools/make_slices.py` -> `disasm/functions/<SEG>.asm` (1299 slices + `_prologue.asm`;
  slice = function label .. next function label; gitignored, regenerable).
- `tools/assemble_all.sh` rebuilds from prologue+slices in address order:
  **REBUILD BYTE-MATCH: 37,344 bytes identical**. Acceptance met (4/4 clauses).
- Canonical asm for Phase 2+ is now `ultimaii-mapped.asm` (per-function aligned);
  `ultimaii.asm` (linear) kept as the Phase 1 artifact.

## CP4 — Reko re-run on true boundaries + bytecheck v2 (2026-10-19)

- `tools/make_reko_project.py --map` -> 1299 map starts as procedure seeds, output dir
  `decompiled/reko-map/`. Run: exit 0 (~30 s), **1299/1299 map starts emitted** + 44
  discovered (1343 defines). 1 contained internal error + known 531B rewrite failure.
  `original/` md5 unchanged; Reko's `.reko` output dir moved out of `original/` (verified clean).
- `tools/bytecheck_map.py`: claims checked against TRUE map ranges (replaces next-seed span).
- Delta vs Phase 1 full-corpus (Reko side):
  * mismatch entries 279 -> **199**; drift flags 574 -> **371** (true ranges kill boundary noise);
  * verdicts: 537 verified / 199 mismatch / 563 no-claims (of 1299);
  * fabrications 2 -> **6**: known 0A5F + 4FA5, plus NEW 47BD/4815/486D (all claim 0x739 —
    same pattern as CP6-v1's 4568/0x739 fabrication; three sibling fragments) and 6999
    (`ax |= ~0x1701` — a `not` lowering artifact miscounted as fabrication). All 4 carry
    contexts; final verdicts are CP5 work. Not hidden, not reclassified silently.

## CP5 — Defect resolution (2026-10-19)

- `disasm/defects.md`: all 9 defects adjudicated against asm slices. Headline: 5 of the 6
  "fabrications" are bytecheck literal-extraction FPs (constant folding 4FA5; negative
  displacement -0x739 x3; complement form ~0x1701). **1 genuine Reko fabrication (0A5F) in
  1299 procedures.** The 3 Reko failures are all non-functions: 2395/35DD are single-nop
  padding seeds, 531B is a str_out call + spaces string site.
- Follow-ups recorded for Phase 3 (bytecheck v3 derived-constant whitelist; data-island
  candidates 47BD/4815/486D; nop-pad kind).

## CP6/CP7 — GATES CLEARED (owner 2026-10-19)
- CP6 byte-verification gate APPROVED by owner.
- CP7 `disasm/phase2-summary.md` written (corpus stats + naming conventions + Phase 3
  C-lifting decision memo). Recommended Phase 3 strategy: lift from Reko drafts, verify each
  function against its asm slice via re-assemble byte-diff; handlers first.
- Phase 2 status: COMPLETE. All §4 global criteria met. Phase 3 authorized.
