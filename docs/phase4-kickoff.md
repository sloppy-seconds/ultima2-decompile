# Phase 4 Kickoff — paste this to start a fresh engine agent

Read in this order before doing anything:
1. AGENTS.md §0 (isolation, licensing) — hard rules.
2. docs/phase4-plan.md — the full work order (CP0–CP10, gates, acceptance).
3. disasm/phase3-summary.md — the signed-off Phase 3 baseline (asm/ tree is the spec).
4. docs/phase4-state.md — resume at the first non-done checkpoint (create at CP0 if missing).
5. docs/phase4-implementation.md — the running log you must maintain.

Project root (the ONLY directory you may touch):
/var/home/paul/Projects/decompile-u2-v2/

Mission framing (do not lose this): Phase 3 produced a byte-proven asm
reconstruction. Phase 4 reimplements the game as a native portable C engine
(engine/) that runs on Linux with zero game content committed — strings and
tables are extracted at build time from the user's own copy. Every engine
module cites the asm functions it implements; the asm tree is the spec you
read, never modify. There is NO automated differential testing against the
original (owner decision) — verification is semantic review against asm/ +
scripted headless playthroughs + owner playthrough gates at milestones.

Non-negotiable guardrails:
- Never read/list/search sibling projects. Never write references/; never
  mutate original/ (md5 fe884d5117971073ac8097cc7a6aca25).
- Scratch in tmp/ or /var/tmp — never /tmp.
- Game content (strings, tables, extracted headers) is NEVER committed;
  engine/build/ and generated headers stay gitignored.
- Phase 3 invariants (check_func 1299/1299, assemble_all.sh,
  assemble_clean.sh) must stay green at every checkpoint — the engine never
  touches asm/.
- Commit only Apache-2.0-safe files; never git add -f an ignored path.
- Do NOT install system tooling (SDL2 etc. = ask the owner first).

How to work:
- Checkpoints in order per docs/phase4-plan.md; per checkpoint run steps, its
  Test, verify Acceptance objectively, update state, append an implementation-
  log section, commit phase4: CP<n> <result>.
- Be autonomous; escalate only at the three gates (CP0 architecture approval,
  CP8 full playthrough, CP10 sign-off), genuine blockers after two recovery
  attempts, scope changes, tooling installs, or game-content questions.
- Never fabricate a result. If a criterion can only be met by loosening it,
  stop and ask.

Begin now: start at CP0. Report back at the CP0 architecture gate first.
