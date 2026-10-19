# Phase 1 Implementation Log

A running, committed record of **how** Phase 1 was actually executed — commands run, measured
outputs, decisions and reasoning, dead-ends, and deviations from `phase1-plan.md`. Append a
section per checkpoint as you complete it. Write it contemporaneously, not from memory at the end.

Format per checkpoint:

```
## CP<n> — <name>   (date, agent/session id)
- What I did:
- Commands run (exact):
- Measured outputs (counts, sizes, verdicts):
- Decisions & reasoning:
- Dead-ends / things that did not work:
- Deviations from the plan (if any) and why:
- Commit: <git short hash + message>
```

---

## CP0 — Environment & isolation verification   (session: phase1-run-A)
- What I did: sourced `tools/env.sh`, smoke-tested all four tools, verified binary size and
  capture inputs, initialised git and made the initial commit of authored files.
- Commands run (exact):
  - `source tools/env.sh; test -x "$GHIDRA_HOME/support/analyzeHeadless" && echo ghidra-ok`
  - `dotnet "$REKO_DLL" --version`
  - `dotnet "$SPICE86_DLL" --help >/dev/null 2>&1 && echo spice86-ok`
  - `objdump --version | head -1`
  - `wc -c < original/ultimaii.exe`
  - `git init -b main; git status --ignored --short | grep -E '^!! (original|references|tools/spice86|tools/reko)/'`
  - `git add -A && git commit`
- Measured outputs:
  - ghidra-ok (Ghidra 12.1.4 at /var/home/paul/Projects/ghidra-12.1.4)
  - `Reko decompiler version 0.12.5.0 (git:418d3538ee)`
  - spice86-ok
  - `GNU objdump version 2.46.1-1.fc44`
  - `original/ultimaii.exe` = 37,344 bytes (matches plan)
  - captures present: spice86-cfg.json (333,881 B), spice86-functions.json (11,126 B), live-ds-4f4d.bin (4,096 B)
  - `ignore-policy-ok` — `original/`, `references/`, `tools/reko/`, `tools/spice86/` all ignored
- Decisions & reasoning:
  - Git identity already configured globally (Paul Czarkowski) — no local config needed.
  - Initial commit staged with `git add -A`; verified the staged list contained only authored
    files (AGENTS.md, LICENSE, .gitignore, docs/, captures/README.md, tools/env.sh,
    tools/ghidra/*.java). No ignored path was force-added.
  - §1A mentions `tools/*/README.md` but the spice86/reko READMEs live inside the gitignored
    vendored tool dirs, so they cannot be committed without `-f`. Left them out; the exclusion
    policy (whole dirs ignored) takes precedence. Noted as a benign plan inconsistency.
- Dead-ends: none.
- Deviations: none.
- Commit: b045523 `phase1: CP0 initial commit of authored files (docs, tools, policy)`

## CP1 — Extract entry points from the runtime CFG   (session: phase1-run-A)
- What I did: wrote `tools/extract_entry_points.py` implementing the plan's filter rule
  (segment 017D; drop dead blocks only when no live predecessor; dedup; sort), generated
  `disasm/entry-points.txt` (693 lines) and `disasm/entry-points.md`.
- Commands run (exact):
  - `python3 tools/extract_entry_points.py`
  - full first-opcode verification (inline python): for each entry, compare CFG first-opcode
    bytes with file bytes at `XXXX+0x200`
  - `objdump -d -b binary -m i8086 -j .data --start-address=0x<XXXX+200> --stop-address=+6 original/ultimaii.exe`
    for 3 random entries (seed=1): 0962, 5188, 06AC
  - `wc -l disasm/entry-points.txt` -> 693
- Measured outputs:
  - 845 blocks total; 796 in 017D (48 F000 + 1 0A29 dropped); 181 dead in code segment;
    78 dead kept (live pred), 103 dead dropped (all preds dead); 693 unique offsets, 0 dupes.
  - First-opcode check: 692/693 match the file. Sole mismatch = block 96 @ 0100 (runtime
    `mov ax,0x08BE` vs file `mov ax,0x0741`) — the documented MZ relocation fixup, expected.
  - All 3 objdump spot-checks decode as plausible instruction starts (see entry-points.md).
- Decisions & reasoning:
  - "Live predecessor" = pred id present in the CFG and not flagged dead. All pred ids resolved
    and no block had an empty pred list, so the rule is unambiguous on this data.
  - Count is 693, not "within a few of 796": the reduction is the plan's own dead-drop rule
    (103 blocks), not dedup. The plan's on-failure note explicitly anticipates the dead-block
    reduction and forbids padding, so I kept the rule as written and documented the arithmetic
    rather than loosening anything. Flagged for human eyes at the CP6 gate.
  - Went beyond the required 3-random spot-check with a full 693-entry first-opcode comparison
    (cheap, stronger evidence).
- Dead-ends / things that did not work:
  - **binutils 2.46 quirk:** `objdump -d -b binary -m i8086 --start-address=... file` silently
    emits zero instructions (no error). Adding `-j .data` fixes it. All later objdump commands
    in this phase must include `-j .data`. Plan's Test command amended accordingly.
- Deviations: added `-j .data` to objdump invocations (tool quirk, noted above); wrote the
  extractor as a committed script under `tools/` for reproducibility.
- Commit: (see git log, `phase1: CP1 ...`)
