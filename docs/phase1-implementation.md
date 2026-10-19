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

## CP2 — Derive the command jump table   (session: phase1-run-A)
- What I did: located the 26-entry command jump table independently; wrote
  `disasm/jump-table.txt` (26 x `XXXX handler=<letter>`), `disasm/jump-table.md` (method +
  gap explanation), and `disasm/seed-entries.txt` (union of CP1 entries + jump-table targets,
  712 unique) for CP4/CP5 seeding.
- Commands run (exact):
  - python scan of all CFG `jmp` records for indirect jumps -> exactly one `FFE3|jmp near BX`,
    block 2193 @ 017D:0A1F; block asm shows `sbb al,0x41; add al,al; mov bx, cs:[si+0x0730]; jmp bx`
  - python struct.unpack of 26 LE words at file 0x930 (= cs:0x0730 + 0x200)
  - per-entry `objdump -d -b binary -m i8086 -j .data --start-address=0x<XXXX+200> ...+7`
  - membership check vs entry-points.txt; absence check vs raw CFG (block start, inside-block,
    ±0x40 proximity)
- Measured outputs:
  - Table entries monotonic 0x2B8F..0x4568. All 26 disassemble as plausible routine starts:
    24 begin `call 0x51df` (shared inline-string display routine, matches documented calling
    convention), L=38B0 and V=437E begin `mov al,abs`.
  - Cross-check: 7/26 present in entry-points.txt (E,N,P,Q,R,S,T). The other 19 are NOT in the
    CFG at all (never executed in the playthrough) — not a dead-rule artifact.
  - Union seed file: 693 cfg + 19 jump-table-only = 712 entries.
- Decisions & reasoning:
  - Kept `entry-points.txt` strictly CFG-derived per CP1's acceptance wording; the jump-table
    extras flow into decompiler seeding via `seed-entries.txt` instead. decompiling.md calls the
    table addresses "the best available seeds", so excluding them from CP4/CP5 would be worse
    than including them.
  - **Acceptance deviation (flagged):** plan's CP2 acceptance wants ≥24/26 in entry-points.txt;
    actual 7/26. Meeting it legitimately requires a new interactive re-capture (press A–Z under
    Spice86 via BIOS keyboard-buffer writes), which the plan places in Phase 2 (§6). CP2 step 4
    explicitly allows "or explain the gap", so I recorded the gap and continued. No supervisor
    channel was available in this session to ask mid-run; escalated in state file + CP6 gate
    summary for user ratification. No addresses were guessed; nothing was padded.
- Dead-ends / things that did not work:
  - First CFG scan pattern (`'%bx' in dis`) missed the dispatch because Spice86 renders it as
    `jmp near BX` (uppercase). Broadened scan found it.
- Deviations: added `disasm/seed-entries.txt` (union) as the CP4/CP5 seed input; documented above.
- Commit: `phase1: CP2 jump table located (26 handlers @ file 0x930; 7/26 CFG-covered, gap documented)`
