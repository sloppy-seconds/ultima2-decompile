# Phase 2 Kickoff Prompt

Paste the block below into a fresh agent session to start (or resume) Phase 2 autonomously.
It assumes the repo layout in `AGENTS.md` and the plan in `docs/phase2-plan.md`.

---

You are executing **Phase 2** of the Ultima II decompilation project, autonomously, from a
written plan. Work the plan to completion, stopping only at the defined gates.

**Read in this order before doing anything:**
1. `AGENTS.md` §0 (Project Scope & Isolation, Licensing & Commit Policy) — hard rules.
2. `docs/phase2-plan.md` — the full work order (checkpoints CP0–CP7, acceptance criteria, tests).
3. `docs/phase1-summary.md` — the signed-off Phase 1 baseline you are building on.
4. `docs/phase2-state.md` — resume at the first non-`done` checkpoint.
5. `docs/phase2-implementation.md` — the running log you must maintain.

**Project root (the ONLY directory you may touch):** `/var/home/paul/Projects/decompile-u2-v2/`

**Non-negotiable guardrails:**
- Never read, list, search, or take hints from any sibling directory. Exception (standing owner
  authorization): raw captures under
  `/var/home/paul/Projects/ultima2/references/extracted/live-capture/` are user-supplied evidence.
- Never write to `references/`; never mutate `original/`.
- Scratch goes in `tmp/` (project-local) or `/var/tmp` — never `/tmp` (it is RAM here).
- Commit only Apache-2.0-safe files; `.gitignore` enforces it — never `git add -f` an ignored path.

**How to work:**
- `source tools/env.sh` to wire the tools. Reko is the primary decompiler (~5 min/run);
  do NOT batch-run Ghidra (~3.5 h, demoted by owner decision).
- Do checkpoints in order. For each: run the steps, run its **Test**, verify **Acceptance**
  objectively, then update `docs/phase2-state.md`, append a detailed section to
  `docs/phase2-implementation.md`, and commit (`phase2: CP<n> <result>`).
- Be autonomous. Decide routine things yourself and record the reasoning. Escalate **only** at
  🔒 gates (CP6, CP7), genuine blockers after two distinct recovery attempts, scope changes,
  out-of-project paths, or a forbidden commit.
- Never fabricate a result to pass a check. If a criterion can only be met by loosening it, stop
  and ask.

**Begin now:** start at CP0. Report back when you hit the first 🔒 gate (CP6) or if anything is
blocked.

---

## Notes for the human

- Phase 1 ended with a byte-exact whole-file asm (`disasm/ultimaii.asm`, verify via
  `tools/verify_asm.sh`). Phase 2 turns that into a per-function corpus: boundary map (CP1),
  code/data separation (CP2), slices + rebuild (CP3), Reko re-run on true boundaries (CP4),
  defect verdicts (CP5).
- If a handler boundary (of the 12 unexecuted ones) proves genuinely ambiguous in CP1/CP3, the
  approved remedy is a targeted 5-minute Spice86 capture of that one command — the agent will
  name the exact command/scenario in the ask.
- CP6 and CP7 are 🔒 gates: stop for owner review before sign-off and Phase 3.
