# Phase 3 Kickoff Prompt

Paste into a fresh agent session to start (or resume) Phase 3 autonomously. Assumes the repo
layout in `AGENTS.md` and the plan in `docs/phase3-plan.md`.

---

You are executing **Phase 3** of the Ultima II decompilation project, autonomously, from a
written plan. Work the plan to completion, stopping only at the defined gates.

**Read in this order before doing anything:**
1. `AGENTS.md` §0 (isolation, licensing) — hard rules.
2. `docs/phase3-plan.md` — the full work order (CP0–CP6, acceptance criteria, tests).
3. `disasm/phase2-summary.md` — the signed-off Phase 2 baseline + Phase 3 decision memo.
4. `docs/phase3-state.md` — resume at the first non-`done` checkpoint.
5. `docs/phase3-implementation.md` — the running log you must maintain.

**Project root (the ONLY directory you may touch):** `/var/home/paul/Projects/decompile-u2-v2/`

**Non-negotiable guardrails:**
- Never read/list/search sibling projects. Standing exception: raw captures under
  `/var/home/paul/Projects/ultima2/references/extracted/live-capture/` are user-supplied evidence.
- Never write `references/`; never mutate `original/` (md5 fe884d5117971073ac8097cc7a6aca25).
- Scratch in `tmp/` or `/var/tmp` — never `/tmp`.
- Commit only Apache-2.0-safe files; `.gitignore` enforces it; never `git add -f` an ignored path.
- Do NOT install system tooling (compilers etc.) without asking the owner.

**Critical framing (do not lose this):** the binary is hand-coded 1983 assembly. "Compile the
lifted C and byte-match the original" is NOT achievable and is explicitly retired as a bar.
The asm slices (`disasm/functions/`) are the oracle; verification is (a) slice integrity,
(b) syntax + symbol checks, (c) human semantic review of C against the slice. Never claim a
compile byte-match.

**How to work:**
- `source tools/env.sh` for tool paths. Reko drafts: `decompiled/reko-map/ultimaii.c`.
- Do checkpoints in order; per checkpoint run the steps, its Test, verify Acceptance
  objectively, update state, append a detailed section to the implementation log, commit
  `phase3: CP<n> <result>`.
- Be autonomous; escalate only at 🔒 gates (CP3, CP6), genuine blockers after two recovery
  attempts, scope changes, out-of-project paths, tooling installs, or a forbidden commit.
- Never fabricate a result. If a criterion can only be met by loosening it, stop and ask.

**Begin now:** start at CP0. Report back at the first 🔒 gate (CP3) or if blocked.

---

## Notes for the human

- Phase 3 lifts Reko drafts to readable 16-bit C, verified against the byte-exact asm slices.
- Pilot is the 26 command handlers + `str_out` (CP2); the CP3 gate is your style review before
  the bulk waves — approve/reject the template there and the agent scales it out.
- If you want a real period compiler (Open Watcom) for closer C, install it yourself or ask the
  agent to request it; the plan does not assume it.
