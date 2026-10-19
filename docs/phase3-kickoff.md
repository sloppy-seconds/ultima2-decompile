# Phase 3 Kickoff Prompt

Paste into a fresh agent session to start (or resume) Phase 3 autonomously. Assumes the repo
layout in `AGENTS.md` and the plan in `docs/phase3-plan.md`.

---

You are executing **Phase 3** of the Ultima II decompilation project, autonomously, from a
written plan. Work the plan to completion, stopping only at the defined gates.

**Read in this order before doing anything:**
1. `AGENTS.md` §0 (isolation, licensing) — hard rules.
2. `docs/phase3-plan.md` — the full work order (CP0–CP6, acceptance criteria, tests).
3. `disasm/phase2-summary.md` — the signed-off Phase 2 baseline.
4. `docs/phase3-state.md` — resume at the first non-`done` checkpoint.
5. `docs/phase3-implementation.md` — the running log you must maintain.

**Project root (the ONLY directory you may touch):** `/var/home/paul/Projects/decompile-u2-v2/`

**Non-negotiable guardrails:**
- Never read/list/search sibling projects. Standing exception: raw captures under
  `/var/home/paul/Projects/ultima2/references/extracted/live-capture/` are user-supplied evidence.
- Never write `references/`; never mutate `original/` (md5 fe884d5117971073ac8097cc7a6aca25).
- Scratch in `tmp/` or `/var/tmp` — never `/tmp`.
- Commit only Apache-2.0-safe files; `.gitignore` enforces it; never `git add -f` an ignored path.
- Do NOT install system tooling (jwasm etc.) — the owner installs on request.

**Mission framing (do not lose this):** the game is hand-coded 1983 assembly. Phase 3 produces a
readable, named, structured assembly reconstruction in which **every byte stays proven**:
`tools/check_func.py <SEG>` per function and `tools/assemble_all.sh` for the whole tree must
stay byte-identical at all times. A cleaned function that changes any byte is a failed function.
C lifting is Phase 4 (draft in `docs/phase4-draft-c-lift.md`); do not start it here.

**How to work:**
- Do checkpoints in order; per checkpoint run the steps, its Test, verify Acceptance
  objectively, update state, append a detailed implementation-log section, commit
  `phase3: CP<n> <result>`.
- Be autonomous; escalate only at 🔒 gates (CP3, CP6), genuine blockers after two recovery
  attempts, scope changes, tooling installs, out-of-project paths, or a forbidden commit.
- Never fabricate a result. If a criterion can only be met by loosening it, stop and ask.

**Begin now:** start at CP0. Report back at the first 🔒 gate (CP3) or if blocked.

---

## Notes for the human

- Pilot = the 26 command handlers + `str_out`; the CP3 gate is your one-time style review
  (naming, comments, INT-stub seam) before the bulk waves scale it to ~1,200 functions.
- When you want the MASM-dialect step, install jwasm (`sudo dnf install jwasm` or distrobox)
  and say so — CP5 picks it up; the phase never blocks on it.
- The named INT stubs created here (video_int10, key_int16, dos_int21, clock_int1a,
  speaker_tone) are the exact seam Phase 5's Linux/SDL port will replace.
