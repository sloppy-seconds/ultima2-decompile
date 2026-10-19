# External runtime captures (2026-10-19)

**Provenance:** raw Spice86 runtime CFG exports from
`/var/home/paul/Projects/ultima2/references/extracted/live-capture/`, copied into this project
on 2026-10-19 **with the project owner's explicit, named authorization** (the AGENTS.md §0
isolation rule was overridden by the owner for these specific files only). Nothing else in the
sibling tree was read; in particular no derived-analysis files (symbol lists, notes) were
imported. These are raw execution evidence of the same kind as `captures/spice86/`.

**Contents:** 44 harvest directories (`cfg_blocks.json` + `cfg_summary.json`), each a Spice86
block-graph export with the same schema as `captures/spice86/spice86-cfg.json`. Named
scenarios include shops (bonifice), death/death-loop, frigate, Lord British, Port Britonnish,
and a cumulative `watch-*` series (monster kills, torch, gold, level-up, form-change, death).

**Binary identity:** every block's first-opcode bytes were verified against
`original/ultimaii.exe` at `offset + 0x200` (see CP1-style check in the implementation log);
mismatches are limited to the known MZ relocation fixup site. The captures therefore describe
this project's ground-truth binary.

**Use:** merged with the in-project CFG to extend the execution-confirmed entry-point set
(428 new code offsets; 7 of the 19 previously unexecuted command handlers now covered).
