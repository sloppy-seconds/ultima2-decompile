# CP4b overnight task list — owner-approved work queue

Drafted 2026-10-20 for overnight autonomous execution. Work through in order.
Each task commits independently; `make test` must be green at every commit.
If a task's evidence is insufficient, STOP that task, write findings into
`docs/phase4-implementation.md` § CP4b as an open question, and move on —
never guess a mechanic (the doubling-bug rule).

## Rules of engagement (standing, from AGENTS.md + kickoff)

- Project root only; no sibling directories. `asm/` + `disasm/redecoded/` are
  the evidence sources; raw-exe byte reads only to resolve a redecode
  ambiguity, and say so in the commit.
- Never heredoc a script; write file, syntax-check, run. Edit with the edit
  tool only. Scratch in `/var/tmp`.
- No subagents (GPU contention, owner directive).
- Zero game content committed; screenshots stay gitignored.
- CP2 evidence baseline: moves allowed ONLY when a change is evidence-backed,
  and each move gets a commit line + a gate-log entry naming the old and new
  digest. [OWNER: confirm this is pre-approved for overnight, or mark tasks
  that move it as hold-until-morning.]
- If everything below is done or blocked, stop and write a morning summary in
  this file under `## Morning report`. Do not invent new scope.

## T1 — Sector-edge crossing (gate blocker, highest value)

Proven already: `asm/242D/2434` test `x,y >= 0x40`; `asm/243E` restores
`[00],[01] = [5A],[5B]`, sets `[4A]=0`, calls the map read. Unknown: which
digit moves and in which direction per arrow.

- Read the callers of `asm/242D/2434/243E` (redecode the movement loop tail
  if needed), `asm/26C6` (the known `DS:49` writer), `asm/2708` + the
  (x,y)-pair table at `cs:0x2798`, and every writer of `DS:5A/5B`.
- Establish the crossing rule per direction (which digit, +/-, and what the
  entry pair becomes in the new sector).
- Implement in `u2_overworld_loop`: on crossing, update sector digits, reload
  sector via `u2_world_load`, set position from the rule. Sector files that
  do not exist (the shipped gaps) must refuse the step like an invalid move,
  not crash.
- Tests: unit checks for the digit arithmetic with synthetic sectors (extend
  `save_q_check` or new `edge_check.c`); live `--dump-map` unaffected.
- Acceptance: walking N/S/E/W across a sector boundary in the SDL window
  loads the neighbour sector; `make test` green; rule cited to asm in
  overworld.c comments.

## T2 — Creation tail: straight into the world

Original: after SAVE/confirm, sets entry pair, saves, clears, prints
"TO PLAY ULTIMA ][" prompt, `call 0x300` (enter world). Engine currently
returns to the menu.

- Extract the "PRESS ANY KEY TO PLAY ULTIMA ][" string (redecoded 5400 tail,
  file 0x5C1F region — check exact bytes/prompt).
- On confirm: same tail as the original, then `u2_overworld_init_state` +
  loop (bitmap backends only; terminal keeps current flow).
- MOVES THE CP2 BASELINE (creation flow change). [OWNER: pre-approved?]
- Acceptance: C → create → world at (20,20) sector 20; CP3 tests still pass
  or are updated with named reasons; baseline regenerated + logged.

## T3 — SIGTERM defect (kickoff defect 1)

SDL build ignores SIGTERM; `timeout`/systemd stop escalate to SIGKILL.
Earlier `SDL_APP_TERMINATING` attempt did not take.

- Debug properly: reproduce with `timeout -s TERM` under the real Wayland
  session; find whether SDL installs a handler (check `SDL_SetHint`
  `SDL_HINT_NO_SIGNAL_HANDLERS` behaviour in the brew build) or whether the
  event is queued but the loop never drains it.
- Fix in the SDL input/renderer init; verify `timeout -s TERM` exits with our
  code, not 137.
- Acceptance: documented root cause in the commit; manual proof in the
  morning report (command + exit code).

## T4 — SDL dummy-driver segfault → headless SDL test

`SDL_VIDEODRIVER=dummy ./u2-sdl --sdl` segfaults in `sdl_upload` via the
flush path (seen under gdb earlier; the -O0 rebuild attempt was interrupted).

- Root-cause it (suspect: renderer create order or texture on dummy driver —
  verify, don't guess).
- Then wire `--dump-screen` into `run_cp4.sh`: dummy-driver run of the title
  flow dumps the first presented frame; assert PPM size + ink presence.
  SKIP cleanly when `u2-sdl` is not built.
- Acceptance: `make test` proves the cell→font→upload path headlessly.

## T5 — Screenshot differential test (standing directive, first attempt)

`captures/screenshots/move-after.png` (gitignored) vs engine output.

- Python tool `tools/screenshot_diff.py`: crop the game area from the
  DOSBox screenshot, downsample to 320x200, derive the 40x25 colour-class
  grid; render the engine's status band region headlessly (known BCD values
  via a small `--dump-state-json`-style hook or reuse `--dump-screen` from
  T4); compare the status-block rows only (map region differs by sector/pos —
  out of scope tonight).
- SKIP with named reason when images or PIL are absent.
- Acceptance: runs in `make test` (PASS or SKIP), catches a deliberately
  blanked status band (prove once by hand, note in commit).

## T6 — Documentation pass (always last)

- `docs/phase4-implementation.md` § CP4b: font decision landed, CMD model
  (owner's four-row model + asm citations), P→world contract, DS:4A
  correction (last-key retired), Q save contract, sector rule from T1.
- `docs/phase4-state.md`: CP4 row status, resume notes pointing here, gate-log
  entries for any baseline moves.
- Morning report section in this file: what shipped (commit list), what is
  open, what needs an owner decision.

## Explicitly NOT tonight

- No CP5+ scope (combat, towns, monsters content, PICCAS).
- No `enhanced` mode work (CP11) beyond the policy hook already landed.
- No renaming `last_key` further, no asm/ tree edits, no git push.
