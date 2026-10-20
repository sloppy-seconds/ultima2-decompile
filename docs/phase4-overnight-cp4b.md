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

## T1 — Passability first, then the true crossing model (gate unblocker)

Recon 2026-10-20 evening reframed this task. Proven:

- Walk loop (file 0x0B36..0x0BF1, fully re-decoded): each direction arm is
  `inc/dec [DS:00]/[DS:01]` -> str_out direction word -> `call 0x2423`
  (passability, AL = travel mode from [DS:15], stored to [DS:29]) -> if
  result != 0: undo the step, echo `--INVALID MOVE!`.
- `asm/2423` head: `[0x29]=al; if [0x4A]==0: JUMP 0x248B` (overworld path,
  file 0x268B). The edge checks at 242D/2434 and the reload at 243E run
  ONLY when DS:4A != 0 — they are the SITE-map exit path (walk off a town
  map -> restore entry pair, set site kind 0, reload the sector map).
- Overworld path (file 0x268B..0x2743, re-decoded but NOT yet understood):
  branches on travel mode ([DS:29] & 0x7F): mode 2 applies a BCD -5 to the
  HP pair (das chain at 0x2695..0x26AC) with a jump to runtime 0xE62 on
  borrow (death?); mode 0x2E checks [DS:D6] and prints a message; a check
  of [DS:26B] guards a "move only on foot" message; [DS:13] compared to
  0x28. Every one of these needs a careful read before any of it is
  implemented.
- Sector arrival machinery: [DS:6E] is `2*sector + parity` (asm/26B7
  compares [DS:6E]>>1 to [DS:49]); asm/2744 steps it by 2, masks &7, and
  looks entry (x,y) from the cs:0x2798 table (file 0x2998) indexed
  `8*[DS:49] + [DS:6E]` -> [DS:23]/[DS:24], then calls 0x52B3 (player
  stamp). Table first bytes: 1d 38 1f 38 21 38 23 38 22 08 2f 1c 24 38
  14 25 10 10 30 18 2a 18 13 34 38 34 1c 0c 21 17 14 34 12 17 32 22 34
  18 08 0b — ends ~0x29BB (36 bytes, code resumes); the index formula and
  extent must be reconciled in T1d (8*sector+dir would need 80).
- Owner recollection (2026-10-20 night): west from the start sector shows
  more map; he assumed seamless scroll into the neighbour. CONFIRMED
  DISTINCTION by owner: town/site edge = FULL transition (reload, entry
  restore — matches asm/243E exactly); overworld edge = SMOOTH continuation
  into the neighbouring sector. The smooth mechanism is what T1a must find
  in the 0x248B path or its callees; if the bytes disagree with "smooth",
  the bytes win and the disagreement gets written down. Vehicles later:
  frigate (water), plane (any) — the sector system stays relevant for them.
- Edge probe: mapx20 and mapx30 are ringed almost entirely by index-0 tiles;
  many other sectors have mixed edges (land links or impassable mountains —
  unknown until passability is decoded).

Tasks, in order:

- T1a: decode the overworld passability path at file 0x268B end to end (and
  whatever it tail-calls): where the tile under the target cell is read
  (note asm/50B3 indexes by [DS:23]/[DS:24], NOT [DS:00]/[DS:01] — find
  where 23/24 are synced from 00/01), what makes a tile passable per travel
  mode, and what happens at the wrapped edge (x=0xFF indexes where?).
  Settle the art-label question here: the kickoff calls art 0 "water
  (magenta dashes)" but renders show the magenta dotted field as walkable
  land; the passability table is the arbiter, not the label. Cite every
  blocked tile id to an address.
- T1b: implement passability in `u2_overworld_run` for travel mode on foot:
  rejected step is undone and `--INVALID MOVE!` echoed through the CMD
  window (string proven in the movement loop). This alone makes the starting
  sector fully walkable and the boundary a natural wall.
- T1b2: implement the SMOOTH overworld crossing per the T1a decode: sector
  digit steps, map reloads, position continues at the opposite edge so the
  player-centred viewport makes it seamless. Missing sector files (the
  shipped gaps) must behave per the bytes — if the bytes offer no rule for
  a missing neighbour, refuse the step and document it, never invent.
- T1c: with passability in, re-probe every `*x0` sector: can a foot traveler
  reach an edge anywhere? If yes, implement the `243E` semantics faithfully
  (entry restore, site kind 0, reload) — the bytes do NOT support a
  neighbour-digit walk-over, so do not invent one; document what reaching an
  edge does per the bytes.
- T1d: dump the `cs:0x2798` arrival table (file `0x2998`, 8 bytes per sector)
  and find the writers of `DS:6E`; write up as the vehicle/arrival contract
  for later CPs. No vehicle implementation tonight.
- Tests: passability unit checks (blocked ids refused, walkable accepted,
  echo correct); edge probe output into the implementation doc.
- Acceptance: CP4 gate is walkable — owner can walk around sector 20 fully,
  water blocks with the original's echo; crossing question answered by
  evidence and written down, not guessed.

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

## T9 — Blog post series + sailboat retro (only if T1–T8 are done or passed)

Goal: turn this stretch of work into a publishable series of blog posts plus
a lessons-learned retro framed as a **sailboat retro** (anchors = what held
us back; sails = what drove us forward; rocks = hazards we hit; currents =
conditions of the project; island = where this is heading).

Source material (all inside the project — the implementation log is the
journal):

- `docs/phase4-implementation.md` (the full CP0–CP4b narrative with every
  correction and retraction — the honest version, not the highlight reel)
- `docs/phase4-state.md` gate log (baseline moves, owner decisions)
- `git log --format='%h %s'` — the commit messages are written as
  mini-narratives and are a ready spine for the series
- `docs/phase4-overnight-cp4b.md` + its morning report (the autonomous-run
  experiment itself is one of the posts)

Suggested series arc (agent may restructure if the material says so):

1. *Byte-matching an impossible binary* — Phases 1–3, the pipeline, why
   1983 assembly resists modern decompilers (jump tables, self-patching
   filenames).
2. *The doubling bug* — every structural check passed, the render was wrong,
   a human with a screenshot caught it. Evidence vs plausibility.
3. *The byte that was two things* — DS:4A "last key" vs "sector digit": a
   plausible wrong model quietly corrupted saves until a live bug report
   became the evidence. Include the retirement of the wrong reading.
4. *Teaching a game's UI to an agent, and vice versa* — the CMD window:
   owner recollection cross-referenced against asm (0x0d as newline), the
   four-row model becoming 17 tests.
5. *The overnight contract* — prove-or-pass autonomy, why "pass with a
   reason" beats "guess with confidence", the progress-report discipline.
6. *Sailboat retro* — the lessons post. Anchors: the selfmod false premise,
   the torus misreading, heredoc traps, the sibling-directory contamination
   incident. Sails: redecode.py, tamper checks catching every baseline
   move, screenshots-as-tests, the owner-in-the-loop catches. Rocks:
   plausible-but-wrong renders, evidence that lived only in chat.

Rules: no game content or game-derived images in the drafts; cite real
addresses/commits so every claim is checkable; write drafts to
`docs/blog/` (one file per post, `NN-slug.md`), status `draft` in
frontmatter. Commit each draft separately.

Acceptance: 5–6 post drafts + the retro draft, each under ~1200 words,
each opening with a concrete story rather than a thesis.

## Explicitly NOT tonight

- No CP5+ scope beyond T2's proven tick (no combat, towns, monsters content,
  PICCAS).
- No `enhanced` mode work (CP11) beyond the policy hook already landed.
- No renaming `last_key` further, no asm/ tree edits, no git push.

## Morning report

(filled in at the end)
