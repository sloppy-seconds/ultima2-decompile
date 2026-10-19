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
