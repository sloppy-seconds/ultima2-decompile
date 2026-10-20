# CP4b overnight task list — owner-approved work queue

Drafted 2026-10-20 evening, amended with the owner's time/food model.
Work through in order. Each task commits independently; `make test` must be
green at every commit. If a task's evidence is insufficient, STOP that task,
write findings into `docs/phase4-implementation.md` § CP4b as an open
question, and move on — never guess a mechanic (the doubling-bug rule).

Owner recollections are treated as design intent but must be confirmed
against `asm/` before implementation; where the bytes disagree, the bytes
win and the disagreement gets written down.

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
  digest. [OWNER: confirm pre-approval, or hold any task that moves it.]
- If everything below is done or blocked, stop and write a morning summary in
  this file under `## Morning report`. Do not invent new scope.

## T1 — Sector-edge crossing (gate blocker)

Proven already: `asm/242D/2434` test `x,y >= 0x40`; `asm/243E` restores
`[00],[01] = [5A],[5B]`, sets `[4A]=0`, calls the map read. Unknown: which
digit moves and in which direction per arrow.

- Read the callers of `asm/242D/2434/243E`, `asm/26C6` (known `DS:49`
  writer), `asm/2708` + the (x,y)-pair table at `cs:0x2798`, every writer
  of `DS:5A/5B`.
- Establish the crossing rule per direction (which digit, +/-, entry pair in
  the new sector).
- Implement in `u2_overworld_loop`: on crossing, update digits, reload via
  `u2_world_load`, set position from the rule. Missing sector files (the
  shipped gaps) refuse the step like an invalid move, never crash.
- Tests: digit arithmetic with synthetic sectors (`edge_check.c` or extend
  `save_q_check`).
- Acceptance: walking across a boundary loads the neighbour; `make test`
  green; rule cited to asm in overworld.c.

## T2 — Time passes: action tick, food drain, auto-PASS (owner unlock, 2026-10-20 night)

Owner's model: every action = one time unit; idle for a short period =
automatic PASS (the P action, which is itself an action); each action drains
a small unit of food; food at zero starts draining HP until DEATH. Save
already round-trips the whole record, so a drained food value persists
across Q/P automatically — that half needs no new work, only a test.

Recon first (recollection -> bytes):
- The main input loop (file `0x0B36..0x0BF1`): the PASS arm at `0x0B48`,
  `asm/3DBC_cmd_P`, and whether the loop times its key wait (INT 1Ah via the
  `asm/52CA` timed_wait seam) to auto-PASS on idle.
- Food/HP writers: every write to `DS:53/54` (food BCD pair) and `DS:51`
  (hp) — grep asm + redecoded ranges; find the per-action decrement and its
  size (one BCD unit? one food byte = hundred units?).
- The starvation chain: food==0 -> hp decrement site, and the death path
  (grep `db "DIED`, `DEATH`, `GAME OVER` — the fan screenshot `death.png`
  exists in captures, gitignored, as a visual cross-check).
- `asm/08ED` (called by the P path and the function-key speed control) and
  `DS:74` (adjusted ±0x200 bounded by `DS:554`/`0x3a00`) — check whether
  this is the time/speed counter.

Implementation (only what the bytes confirm):
- A tick function in the overworld loop: after each accepted action (move,
  PASS, later combat) apply the proven food decrement; at food zero apply
  the proven hp drain; on hp zero run the original's death path (or, if the
  death flow is out of scope, stop at hp==0 with a documented open
  question).
- Auto-PASS on idle: if proven, drive it from the clock seam so headless
  stays deterministic. DECISION POINT: if firing auto-PASS under the script
  clock would move the CP2 baseline via WAIT semantics, gate auto-PASS to
  real-clock backends and record the choice. If [not pre-approved], hold the
  auto-PASS sub-part and ship the action tick only.
- Tests: tick drains food by the proven amount; food 0 drains hp; drained
  food survives Q -> P (extends `save_q_check`); auto-PASS fires after the
  proven idle interval (real-clock path).
- Acceptance: walking around the map slowly eats food, visible in the status
  band; starvation works; every constant cited to an asm address.

## T3 — Window-close X ignored in the overworld (owner, confirmed)

`sdl_poll` returns -1 and sets `exit_code`; `seam_key_poll` collapses -1 to
0 and sets `input_exhausted`; the title flow checks `flow_stopped()` so X
works at the menu, while `u2_overworld_loop` checks neither and spins on.

- Fix in `u2_overworld_loop`: after a no-key poll, break when
  `ctx->exit_code || ctx->input_exhausted`. Do NOT change `seam_key_poll`'s
  return contract — callers test it with `!`, where -1 reads as "key got".
- Check the creation flow's wait loops for the same gap.
- Acceptance: X closes mid-game with exit 0; CP3 scripted tests green.

## T4 — SIGTERM defect (confirmed live 2026-10-20)

A stale `u2-sdl` process survived SIGTERM (kill) and only died on SIGKILL.

- Reproduce with `timeout -s TERM`; determine whether SDL installs the
  handler (`SDL_HINT_NO_SIGNAL_HANDLERS` behaviour in the brew build) or the
  event is queued but never drained.
- Fix in SDL init (likely: set the hint and install our own async-signal-safe
  flag handler checked in `sdl_poll`).
- Acceptance: `timeout -s TERM` exits with our code, not 137; root cause in
  the commit; proof line in the morning report.

## T5 — Creation tail: straight into the world

Original: after confirm, sets entry pair, saves, clears, prints the
"TO PLAY ULTIMA ][" prompt, `call 0x300`. Engine returns to the menu.

- Extract the prompt string (redecoded 5400 tail, file 0x5C1F region).
- On confirm: original's tail, then `u2_overworld_init_state` + loop (bitmap
  backends only; terminal keeps current flow).
- MOVES THE CP2 BASELINE. [OWNER: pre-approved?]
- Acceptance: C -> create -> world at (20,20) sector 20; CP3 green or
  updated with named reasons; baseline regenerated + logged.

## T6 — SDL dummy-driver segfault -> headless SDL test

`SDL_VIDEODRIVER=dummy ./u2-sdl --sdl` segfaults in `sdl_upload` via the
flush path.

- Root-cause (verify, don't guess: suspect renderer/texture creation order
  or the accelerated->software fallback on dummy).
- Then wire `--dump-screen` into `run_cp4.sh`: dummy run of the title flow
  dumps the first presented frame; assert PPM size + ink. SKIP when
  `u2-sdl` is not built.
- Acceptance: `make test` proves the cell->font->upload path headlessly.

## T7 — Screenshot differential test (standing directive, first attempt)

- `tools/screenshot_diff.py`: crop the DOSBox game area from
  `captures/screenshots/move-after.png`, downsample to 320x200, derive the
  40x25 colour-class grid; compare the status-block rows (20..23, cols
  30..39) against a headless engine render with the same BCD values. Map
  region out of scope tonight (sector/position differ).
- SKIP with named reason when images or PIL are absent.
- Acceptance: runs in `make test` (PASS or SKIP); proven to catch a
  deliberately blanked band (one manual poison check, noted in commit).

## T8 — Documentation pass (always last)

- `docs/phase4-implementation.md` § CP4b: font landed, CMD model, P->world
  contract, DS:4A correction, Q save contract, sector rule (T1), time/food
  model (T2) with every citation.
- `docs/phase4-state.md`: CP4 row, resume notes pointing here, gate-log
  entries for baseline moves.
- Morning report section below: shipped (commit list), open, owner decisions.

## Explicitly NOT tonight

- No CP5+ scope beyond T2's proven tick (no combat, towns, monsters content,
  PICCAS).
- No `enhanced` mode work (CP11) beyond the policy hook already landed.
- No renaming `last_key` further, no asm/ tree edits, no git push.

## Morning report

(filled in at the end)
