# Phase 2 Summary — Boundaries, Separation, Per-Function ASM (SIGNED OFF)

Owner approved CP6 2026-10-19; CP7 artifacts signed off same day.
**Phase 2 complete; Phase 3 (C lifting) authorized with the memo below.**

## Corpus stats

| Metric | Value |
| --- | --- |
| Functions (`disasm/function-map.tsv`) | 1299, tiling 100% of the 0x9000 code segment |
| Byte kinds | code 8,238 · code-derived 13,350 · string 7,358 · zeros 2,404 · table 40 · psp 256 · unclassified 5,218 |
| Ground-truth asm | `disasm/ultimaii-mapped.asm` (per-function aligned) — re-assembles byte-identical |
| Slices | 1299 in `disasm/functions/` + `_prologue.asm`; `tools/assemble_all.sh` rebuild = byte-identical |
| Reko on true boundaries | 1299/1299 emitted + 44 discovered (`decompiled/reko-map/`) |
| Bytecheck v2 (`disasm/bytecheck-map.tsv`) | 537 verified · 199 mismatch (drift/lowering) · 563 no-claims |
| Genuine Reko fabrications | **1 in 1299** (0A5F); 5 of 6 flagged were bytecheck FPs — see `disasm/defects.md` |
| Reko failures | 3, all boundary artefacts (2395/35DD are the tail byte of an instruction the map cut in half — the `nop-pad` reading in `disasm/defects.md` was retracted 2026-10-28e; 531B string site) |

## What a row in `function-map.tsv` actually means

The filename oversells it, and an agent who reads it literally will go hunting a defect that
is not there.

`tools/build_function_map.py` does not infer routines. It collects **discovered starts**
(execution-confirmed or jump-table seeds, then `call` targets, then Reko procedure defines,
in that priority order) and then **tiles the segment**: each start ends at `next_start - 1`,
the last ends at `0x8FFF`, coverage is total by construction. A row therefore asserts two
things and only two: *this address is a discovered entry point*, and *this is the region up
to the next one*. It does not assert that the region is one routine, has one `ret`, or serves
one purpose. "Functions" in the table above is the name of the artefact, not a claim about
its rows.

That is why the fragment pathology in `docs/fragment-splits.md` is not a Phase 2 bug. A real
routine reached by a backwards branch yields several discovered starts, and the tiling
faithfully cuts it into several rows. The map is correct about starts and silent about
routines. The routine truth lives in `asm/` headers, which is where `AGENTS.md` § 3 sends
anyone looking up an address.

Two consequences worth knowing cold:

* **The map and the `asm/` file set cannot diverge.** `check_func.py` validates a file's body
  against its map row, so widening a row without joining the files fails `LENGTH MISMATCH`
  and `assemble_clean.sh` dies on that row. Tested 2026-10-28d in a throwaway worktree:
  `4AAD..4AE5` widened with the files left split gave `body assembled 11 B, map says 57 B`,
  while `asm_body_guard` stayed green throughout because it only reads `asm/`. A map-only
  correction is therefore not a cheaper substitute for merging. Merging is the only route.
* **So correcting a row means merging, and merging needs an owner ruling** (`AGENTS.md` § 3).
  Where a real span is known but unmerged, record it in the `asm/` header and leave the map
  alone. That is the sanctioned state, not a backlog item.

## Phase 2 defect fix worth remembering

Phase 1's linear disassembly mis-aligned at 106 function starts; the map-driven rebuild
(`tools/emit_map_asm.py`) fixed it and the slice rebuild proves it. Lesson recorded:
never slice a linear decode; decode from each function's own start.

## Naming conventions (start small, grow on use)

- `cmd_A..cmd_Z` — 26 command handlers (jump table 0x730).
- `str_out` — seg 0x4FDF inline-string display routine.
- `sub_<start>` — default for everything else until a Phase 3 pass names by behavior.
- Data: `data_<start>_<kind>` for classified regions when referenced.

## PHASE 3 DECISION MEMO — C-lifting strategy

> **UPDATE 2026-10-19 (owner):** roadmap reframed — the *clean byte-exact ASM reconstruction*
> became Phase 3 (`docs/phase3-plan.md`); the C-lifting strategy below is deferred to
> Phase 4 (`docs/phase4-draft-c-lift.md`). Kept verbatim as the signed-off historical memo.

**Recommendation: lift from Reko drafts, verify against asm slices per function.**

Per-function loop:
1. Start from the Reko procedure (`decompiled/reko-map/ultimaii.c`) as the draft.
2. Hand-lift to idiomatic 16-bit C (far/near pointers, sizeof(int)==2), naming locals from
   the IR's register/stack model.
3. Compile candidate back to asm (Open Watcom `-ms -1` or hand-written asm) and byte-diff
   against the function's slice; iterate until match or until only provably-equivalent
   encoding differences remain (documented per function).

Why not lift from raw asm per function: Reko's drafts are byte-honest (1 true fab/1299) and
already carry the stack/frame model; starting from asm discards that free work.
Why not trust Reko output directly: it is machine-style (Eq_ types, selector modeling) —
not the readable/portable C the project wants.

Function classes and handling:
- **Normal (verified/mismatch-drift)**: standard loop above.
- **No-claims (563)**: mostly tiny fragments; lift from asm slice directly (draft adds little).
- **Known defects**: 0A5F (ignore Reko frame math), 47BD-family (data islands — reclassify,
  don't lift), 2395/35DD (tail bytes of instructions the map cut in half — not nop-pads, see
  `disasm/defects.md`), 531B (string site — data + 3-byte stub).
- **Self-modifying cluster 0x5120–0x5151**: exclude from C lifting; document as runtime-patched.

Suggested Phase 3 order: command handlers first (26, high-value, well-understood), then
call-graph-reachable normal functions, then fragments.

## Known limits (carried, not hidden)

- 5,218 B unclassified (no positive evidence either way; includes 47BD-family islands).
- 12 unexecuted handlers' internals derived, not execution-confirmed (owner-accepted).
- Community-patch provenance of the binary (AGENTS.md §0).
- Ghidra output frozen as Phase 1 reference only.
