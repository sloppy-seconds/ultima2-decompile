# Phase 1 Kickoff Prompt

Paste the block below into a fresh agent session to start (or resume) Phase 1 autonomously.
It assumes the repo layout described in `AGENTS.md` and the plan in `docs/phase1-plan.md`.

---

You are executing **Phase 1** of the Ultima II decompilation project, autonomously, from a written
plan. Work the plan to completion, stopping only at the defined gates.

**Read in this order before doing anything:**
1. `AGENTS.md` §0 (Project Scope & Isolation, Licensing & Commit Policy) — hard rules.
2. `docs/phase1-plan.md` — the full work order (checkpoints CP0–CP7, acceptance criteria, tests).
3. `docs/phase1-state.md` — resume at the first non-`done` checkpoint.
4. `docs/phase1-implementation.md` — the running log you must maintain.

**Project root (the ONLY directory you may touch):** `/var/home/paul/Projects/decompile-u2-v2/`

**Non-negotiable guardrails:**
- Never read, list, search, or take hints from any sibling directory (`decompile-u2`, `ultima2`,
  `agents/**`, etc.). Using external *tools* (Ghidra/Reko/Spice86/objdump) by path is fine;
  importing *prior findings* (entry lists, names, conclusions) from other attempts is forbidden.
  Regenerate everything from `original/` and `captures/` inside this project.
- Never write to `references/` (pristine backup) or mutate `original/`.
- Scratch goes in `tmp/` (project-local) or `/var/tmp` — never `/tmp` (it is RAM here).
- Commit only Apache-2.0-safe files per the Licensing & Commit Policy; `.gitignore` enforces it —
  never `git add -f` an ignored path.

**How to work:**
- `source tools/env.sh` to wire the tools.
- Do checkpoints in order. For each: run the steps, run its **Test**, verify the **Acceptance
  criteria** objectively, then update `docs/phase1-state.md`, append a detailed section to
  `docs/phase1-implementation.md` (exact commands, measured outputs, decisions/reasoning,
  dead-ends, deviations), and commit (`phase1: CP<n> <result>`).
- Be autonomous. Decide routine things yourself and record the reasoning. Escalate **only** at
  🔒 gates (CP6, CP7), genuine blockers after two distinct recovery attempts, scope changes,
  out-of-project paths, or a forbidden commit. Do not over-ask; do not spin on a failing approach.
- Never fabricate a result to pass a check. If a criterion can only be met by loosening it, stop
  and ask.

**Begin now:** start at CP0. Report back when you hit the first 🔒 gate (CP6) or if anything is
blocked.

---

## Notes for the human

- The seeds for both decompilers come from the runtime CFG in `captures/spice86/spice86-cfg.json`
  (a prior Spice86 gameplay capture). The plan consumes that capture; it does not re-run Spice86
  unless CP3 finds the existing dump insufficient.
- To have the run regenerate a fresh capture first, add a "CP1.0 — (re)capture the runtime CFG via
  `docs/spice86-capture.md`" step before CP1.
- CP6 and CP7 are 🔒 gates: the agent stops for your review before byte-check sign-off and Phase 2.
