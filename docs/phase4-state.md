# Phase 4 State — checkpoint table

Plan: `docs/phase4-plan.md`. Log: `docs/phase4-implementation.md`.
Kickoff: `docs/phase4-kickoff.md`.
Statuses: todo | in-progress | done | blocked | awaiting-gate

| CP | Title | Status | Notes | Date |
| --- | --- | --- | --- | --- |
| CP0 | Skeleton + automation substrate 🔒 | done (owner approved 2026-10-27) | `engine/` builds with cc only; term + null renderers, term + script input, beep + null audio, posix + script clocks; seam layer with asm-cited `--trace`; `--dump-state` screen grid + JSON; `make test` PASS incl. reproducibility; selfmod question resolved from 45 existing runtime captures (`disasm/selfmod-capture.md`) — cluster is not patched, CP3 unblocked | 2026-10-27 |
| CP1 | Extractor + title screen 🔒 | **awaiting-gate (owner eyeball vs DOSBox)** | `tools/extract/extractor.py` (exe source + asm db-line fallback + `--check`/`--emit text`); `game/title.c` = intro, title, menu, 'D' poem, CP3/CP4 stubs; `make test` = CP0 9/9 + CP1 9/9; **architecture correction: the grid is 40x25, not 80x25** (evidence in `engine/README.md`); `--selftest` keeps the CP0 substrate probe testable | 2026-10-27 |
| CP2 | Play contract + evidence 🔒 | done (owner route change 2026-10-27) | MCP wrapper replaced by the CLI contract per owner decision; `docs/playing.md` is the agent interface; in-tree SHA-256 + `--replay-report` + `tools/playlog.py verify`; committed transcript `evidence/cp2-playthrough.json` (14 keys, 23 frames) reproduces; CP2 test 12/12 | 2026-10-27 |
| CP2.5 | Re-decode tooling (scoped, owner-approved) | done 2026-10-27 | `tools/redecode.py` + `disasm/redecoded/` for the five blob functions; save path and creation flow decoded; `asm/` untouched so the byte-exact invariant is unaffected | 2026-10-27 |
| CP3 | Character creation + status line | **done, awaiting owner gate** | (a) save/disk model + byte-compatible player record. (b) creation flow + status block. (c) form rework: field-addressable with D1-D4 (Tab/arrows, editing backspace, refuse-in-place, visible cursor); rules and state unchanged. CP3 test 8/8 + 23-assertion `save_check`. **CP2 evidence baseline moved three times deliberately** — see gate log | 2026-10-27 |
| CP11 | Mod surface + original/enhanced modes (owner-scheduled, deferred from CP3) | **tabled by the owner 2026-10-28e** — not lost | two modes, sparse-diff overrides, content + rules surfaces, mandatory provenance; save-record layout non-overridable; no `.pat` reimplementation. The open input was "what do existing U2 mods actually patch"; the owner's answer was to table it until it becomes blocking, which makes it a decision rather than an oversight | 2026-10-28e |
| CP4 | Overworld + movement | **in-progress (CP4b overnight: T1,T3,T4,T6,T7,T8 done/passed; T2 half; T5 held)** | kickoff § 2 items 1 and 2 **settled from the bytes**: the name is `MAPX` + two digits self-patched into the code stream (`asm/2290`, file `0x24b7`), and a tile is **one byte** in a **64x64** sector read with `AH=27h, CX=0x1000` into `[DS:0x472]` (`asm/50B3_map_tile_ptr.asm`). New finding: `asm/2305` **writes the sector back**, so world content is mutable. EGA question answered: `original/updated/` is the Exodus Project upgrade and EGA is a **separate binary** (`U2EGA.EXE`), so the accommodation is a tile-ID seam plus data-driven naming, not a mode flag. Direction keys are **arrows**, proven via a scancode table at `CS:0x4F09`. Movement is proven: arrows via a scancode table at `CS:0x4F09`, direction codes as data at `DS:26E..271`, a rejected step is undone before `--INVALID MOVE!`, and crossing x/y >= 64 reloads the sector (`asm/242D`/`2434`/`243E`) rather than straddling. **Viewport now measured from owner screenshots**: tile = 16x16 px = 2x2 text cells, window 20x10 tiles at rows 0-19 full width, player at window tile (9,5), row 24 blank. Dungeons are first-person 3D, so the tile renderer does not cover them (CP7). **CP4b overnight (2026-10-21):** the passability premise was disproven — `asm/2423` never reads a tile, so on-foot walking is never rejected on the overworld (T1 PASSED, write-up in implementation log § CP4b); tile IDs decoded (0=water,4=land,8=plane,0x78=player); sector crossing is the `DS:6E` arrival system, not a foot step. T3/T4/T6 fixed one root-cause class (loops testing `exit_code` but not `input_exhausted`): window-close, SIGTERM, and dummy-driver `--dump-screen` all now stop cleanly. T2 shipped the proven half (PASS spends 10 food, underflow zeroes DS:51..59 = instant death; no gradual HP drain) **but its "no per-step tick — the walk loop calls no drain" is RETRACTED 2026-10-25**: all four walk arms `call 0x2423`, and `asm/2599_food_drain_walk.asm` / `asm/2626_food_drain_mounted.asm` subtract `0x19` inside it ahead of the verdict, so every step attempt costs 19 and a refusal costs it too (`captures/spice86/g2-step-food/`, `docs/needs-gameplay.md` G2/G34). The engine was charging 13, not 19, because the port passed decimal 19 where the asm's immediate `0x19` was meant. T7 screenshot differential harness landed (status-block only, poison-checked). T5 held for owner: it moves the CP2 baseline and its pre-approval flag is unresolved. Full detail: `docs/archive/phase4-overnight-cp4b.md § Morning report` | 2026-10-21 |
| CP5 | Combat | **in progress — scope ruled 2026-10-23** | Tickets C1..C7 in § CP5 below. **Owner scope ruling: the larger scope** — not just the `combat_check` spec tickets but the wiring that makes combat *reachable* in the engine (encounter, turn loop, continuous world). Status per ticket: **C1, C2, C4, C5, C6 and C7 implemented or resolved**, and **C3 implemented 2026-10-28** — the paralysis-as-movement-rejection coupling to CP4 passability. It was wiring, not mechanics, and it needed no state seam: the counter is reached the way it is reached in play, by a Daemon (type `0x34`, dispatched by `asm/0AD3`) casting it during a scripted fight, so the gate seeds the creature rather than the status byte. The CI counts are printed by `run_cp5.sh` on every run (do not copy them here; a hand-kept number goes stale, and this row's did twice). C5 is no longer "blocked on a capture" — the field turn is on record (fight turn 2909); what remains is *placement*, which belongs to passability G4, not combat. **Owner recollection on the status effects, recorded as `recalled` and treated as a pointer, not a conclusion:** legs paralysed -> can still fight but not move; arms paralysed -> the reverse; paralysis lasts "some amount of time or moves"; and **"there's not really a leaves-combat state"** — see the design note below. Two owner decisions were open there; **both are now closed (2026-10-28e)**: the acceptance bar is the plan's own *"owner wins a fight"*, kept as an eyeball gate, and C5 placement is confirmed out of CP5 scope — it was solved on 2026-10-28 and it is tile `0x5C`. | 2026-10-23 |
| CP6 | Towns + full command set | todo | | |
| CP7 | Time travel + space + dungeons | **partly informed 2026-10-21** | Dungeons are sectors, not a separate format: entering a cave moved `DS:49/4A` from `3,0` to `3,5` and loaded `mapx35`, with no video mode change (stays CGA mode 4). Rendered as a first-person wireframe. Light is a **step counter** at `DS:26`, zeroed on entry, ~150 on `I`, decremented per move, and `mapx25`/`35`/`45` are byte-identical. Command dispatch is mode-aware: `A` is ATTACK outside and ADVANCE inside. Full detail: `docs/spice86-live-findings.md` § 13. | 2026-10-21 |
| CP8 | Endgame + full playthrough 🔒 | todo | | |
| CP9 | SDL2 CGA renderer | todo — **unblocked 2026-10-28e** | owner approved installing system packages | 2026-10-28e |
| CP10 | Sign-off 🔒 | todo | | |

## Resume notes (read this first after a compaction)

- **2026-10-21 correction to the T2 closure — RESOLVED 2026-10-28d, no capture needed.** T2
  recorded "no `INT 1Ah` exists in the corpus". That was true of the decoded `asm/` tree and
  **false of the binary**: `CD 1A` occurs at file `0x8AE`, `0x8C0`, `0x8CE` and `0x8FD0`
  (runtime `0x6AE`, `0x6C0`, `0x6CE`, `0x8DD0`). The re-proof asked for was reachability, and
  the answer came out of the existing harvests rather than a new one: the first three execute
  in **136 of 136** `ExecutedInstructions` sets, the fourth in **0 of 136**. The three that run
  are one routine, now decoded and named `asm/06AC_clock_tick_wait` — a 20-tick window that
  counts busy passes into `DS:74` for what reads as machine-speed calibration (inferred).
  **T2's conclusion survives and is re-based**: the auto-PASS timeout is a poll count because
  the PASS loop's own bytes at runtime `0x8D6` say `incb DS:21 ; jne`, not because no clock is
  read. Full write-up where the claim was made: `docs/spice86-live-findings.md § Addendum`,
  corrected in the same commit. Same lesson as F6, restated because it has now bitten three
  times: a negative result from a probe over a partially decoded tree is not a negative result
  about the binary.

- **2026-10-21 passability re-decode: read `docs/passability-findings.md`.** The
  full routine (file `0x2623..0x287F`) was decoded contiguously and it contains
  **no read of the target tile** — its single `map_tile_ptr` call writes `0x50`.
  A second, previously unread ladder at runtime `0x25C0..0x25F6` decides on
  `DS:29 & 0x7F` alone. The mode chain is `DS:2CB -> DS:15` and `DS:2DE -> DS:18`
  (runtime `0x5B77/0x5B83`), and `DS:2CB`/`DS:2DE` have **no direct writers
  anywhere in the exe**, so the tile dependence enters through an indirect table
  write the static route cannot attribute. `DS:13 = 0x78` in every in-world
  sample, so it is the player stamp, not terrain — which retires the "travel
  mode" reading of `DS:13` in `state.h`. `create-test-live` is a clean controlled
  experiment proving the decision is tile-dependent. Also: `tools/redecode.py`
  mis-decodes 21 bytes of real code at file `0x27D2` as a printable string, so
  any `STR` line inside a code span in `disasm/redecoded/` must be re-checked
  before being cited. Next step is one breakpoint capture at runtime `0x2423`.

- **Entry point is `docs/handoff-2026-10-28d.md`.** The 2026-10-23 handoff named below is
  superseded; it is kept as the record of what was closed that day (G1, G8,
  G18, G20, the dungeon encoding, the price operand) and the triage of the open list of the
  time. The CP4b
  T1 finding and part of T2 were **retracted** on 2026-10-21 — see
  `docs/phase4-implementation.md § CP4b → RETRACTION` and
  `docs/spice86-live-findings.md`.

- **CP4 is mid-flight and everything is committed. To take over, read
  `docs/handoff-2026-10-23.md` for current state, then
  `docs/phase4-kickoff-cp4b.md` for the CP4 work order itself.** The headline it must not
  miss:
  the original has **two display paths** — tiles for the map and banners, and
  INT 10h teletype text (`str_out_at` runtime `0x51EB` -> `str_out_core`
  runtime `0x51FD`) for the status band, menu and creation form. There are no
  digit glyphs in the 64-record tile table (verified: zero `04 10` headers in the
  1312 bytes after the last record), so the status band must be drawn through the
  text path, not the tile path. That also explains the `CS:0x48DC` table
  alternating `B800+5k`/`BA00+5k` — character plane and attribute plane of text
  mode 0. And **the staging byte is `2 x art`**: `u2_view_at()` returns the
  staging byte, `u2_view_art()` halves it; skipping the halving doubles every
  tile, which is the bug the owner caught from a screenshot after every
  structural check had passed.
Done and green: kickoff § 2 items 1-2 (name = `MAPX` + two digits
  self-patched at file `0x24b7`; tile = **1 byte**, `y*64+x`, 64x64 sector, read
  `AH=27h CX=0x1000` into `[DS:0x472]`); the sector **write-back** (`asm/2305`) with
  the owner's decision (a) faithful in `original` mode, (b) copy-on-write for
  `enhanced`; movement and the **arrow keys** (scancode table at `CS:0x4F09`,
  direction codes as data at `DS:26E..271`, space = PASS, rejected step undone then
  `--INVALID MOVE!`); the **viewport measured** from owner screenshots (tile = 16x16
  px = 2x2 cells, window 20x10 tiles at rows 0-19 full width, player at window tile
  (9,5), row 24 blank); the **game-data inventory** as a reusable tool
  (`tools/content_inventory.py` + committed `disasm/content-inventory.tsv`); the
  **tile art found in the exe** (index at file `0x7BC0` = DS:0x5B0, 64 words, deltas
  exactly 66, `04 10` header, pixels from `0x7C42`, 16x16 2bpp —
  `tools/extract_tiles.py` proves and renders it); and **CP4(a) engine code**:
  `core/world.[ch]` + `--data-dir` + `tests/world_check.c` (42 checks) +
  `tests/run_cp4.sh`, all green under `make test`.
- **Next task, in order.** (1) Read `asm/4A74`, `asm/4D35`, `asm/4D5D` and the callers
  of `asm/4AC3` — that is the draw loop, and it also answers the map byte -> tile
  entry mapping and what the `04 10` header means (suspect: the mode-4 attribute
  byte). (2) Build the tile cache: self-bootstrapping, extracted from the user's exe
  on first run, gitignored, stamped with the source SHA-256 so a stale cache cannot
  silently survive a swapped game copy. (3) Viewport renderer behind a **tile-ID
  seam** (renderer chooses the glyph/sprite; game logic never sees a glyph), then
  movement wiring and encounter rolls. (4) Hand to the owner to walk.
- **Standing directives from the owner, recorded in plan § CP4.** Validate the engine
  against the screenshots **as a test** as it is built (SKIP with a named reason when
  the images are absent, so CI stays honest). Use **REA for engine validation, not for
  re-deriving the asm** — byte-identity is already proven better by `check_func.py`, and
  REA's provider here is Ghidra, which found fewer routine starts than the vendored
  Reko (7 vs 11 of 46). `references/u2upgrade/` is a **secondary source only** and is
  explicitly not trusted; it is an upgrade, not the original.
- **Two self-corrections to remember.** The `and $0x3f` "torus" claim was wrong (that
  mask is the rocket/plane launch auto-move; the overworld reloads the sector at
  `>= 0x40`). And "no bitmap table in the exe" was wrong twice over — my own scan
  printed `file 0x7c40` and I dismissed it as zero padding when it is two bytes from
  the tile table. A negative result from a probe not designed to detect the thing is
  not a negative result.
- **Everything is committed.** Working tree clean at the commit that folded D6-D13
  into the plan. No in-flight edits.
- **CP3 form state**: stats prefill at 10 and are a two-digit shift register (D6,
  D10), the budget may go negative and saving requires exactly 00 (D7), name is
  capped at 12 with the high bit masked (asm/5BB7, asm/5207, D8), SAVE/RESET are
  navigated to rather than hotkeys (D9), ESC abandons creation (D11) and the demo
  (D12), and `P` prints the record it read back (D13). **All thirteen deviations
  are registered in plan § 4a**, and the three evidence-backed corrections from
  this stretch are in plan § 7.
- **All suites green**: CP0 0.04s, CP1 0.12s, CP2 0.32s, CP3 4.41s (~4.9s total,
  measured 2026-10-27). CP3's cost is two `sleep 1` waits in the pty tests, which
  pace the intro-skip apart from the body because a key burst is swallowed by the
  intro's key-holds. Ctrl-Q **is** passed and **does** terminate the runs.
- **Phase 3 invariants green**: `make test` runs them (clean rebuild byte-match
  37344 B, `original/` md5, `asm/` untouched).
- **Open for the owner at the CP3 gate**:
  1. ~~Binary vs packed decimal for HP/FOOD/GOLD~~ **resolved**: packed decimal,
     4 digits, and the original prints the two bytes in the wrong order so food 3
     displays `0300`. See plan § 7 and `engine/src/game/status.h`.
  2. **CP3 polish deferred by the owner** ("good enough to move on, we can polish
     later"): nothing is recorded as broken, so if a later checkpoint exposes a CP3
     defect it goes here rather than being silently fixed in passing.
  3. Whether the CP2 evidence baseline should keep being regenerated in place or
     frozen with new files per checkpoint. It has moved six times, each
     deliberately and each recorded in the gate log.
  3. Play the form: `make play`, press `C`. Confirm Tab/arrows, re-editing, and
     that the field positions look right against the original.
- **Not yet done**: the CP11 cheap accommodations (constant registry, accessor
  reads, random-creation seam), and the branch audit as a standing gate rule is
  written in `docs/phase4-acceptance.md` but not yet applied retroactively to
  CP1/CP2.

## Next checkpoint

**This section was stale for a week and pointed at CP4 although CP5 shipped.** Rewritten
2026-10-28e. It deliberately carries no counts: every number it could name is printed by a
tool, and a hand-kept number here has gone stale before.

**Fresh agent: read `AGENTS.md`, then `docs/handoff-2026-10-28e.md`.** That handoff is the
entry point; the kickoff docs below are historical work orders, not the queue.

**CP5 — combat.** Implemented or resolved ticket by ticket (see § CP5 above and
`docs/phase4-kickoff-cp5.md` for the build order as executed). What remains is an
**owner gate**, not code. The acceptance bar was in fact set in `docs/phase4-plan.md` § CP5 —
*"owner wins a fight"* — and it stands (owner, 2026-10-28e: asked whether an eyeball gate is
needed at all, and the answer is yes, it costs two minutes and it is the only check that can catch
mechanics-correct-but-nothing-drawn). Combat entry is now observed rather than designed, so the
gate is concrete: stand beside a creature, press `A` and a direction, and read one `CMD:` line
(`ATTACK--EAST--HIT!!!` then `KILLED--GOLD+1--EXP.+02`). The second open item there — whether C5
force-field *placement* is out of CP5 scope — is resolved and no longer needs the owner:
placement was solved 2026-10-28 and it is tile `0x5C`, measured in `captures/spice86/g29-field`.

**CP6 — towns + the full command set is the next checkpoint, and its owner decision is now made.**
The engine has no command loop, and the command loop is upstream of era display, speed wiring,
towns and time travel. **Owner ruling 2026-10-28e: implement all 26 handlers**, with the twelve
that no capture has ever seen run — `C D H J M N O S T V W Y` — each carrying an in-source
`UNPROVEN:` marker, and **no checkpoint or phase may be called code-complete while any marker
stands**. The fourteen with execution evidence are `A B E F G I K L P Q R U X Z`. The rule lives in
`AGENTS.md` § 3, not only here, because a handoff gets superseded and a working rule must not.
`python3 tools/cmd_handlers.py` prints the crosswalk and its `exec` column is that evidence;
the gate fails when the jump table, the filenames and the provenance lines disagree.

**Owner-independent work that does not need the above.** In rough value order, each with the
tool that measures it rather than a number copied from a diary:

1. What each speed delay slot gates — half the slots still have no caller found
   (`asm/0711_speed_delay_lookup`).
2. Two data tables recorded with shape but no meaning: `asm/5287` and `asm/0720`. Naming them
   needs a read of `asm/4C1E`'s consumers or a capture.
3. The remaining fragment splits, which are parked deliberately
   (`disasm/fragment-splits.tsv`, `disasm/phase2-summary.md`).

**Closed 2026-10-28e, so nobody re-does it:** the forced-keep correction queue (**36 → 0**,
and three of the last five items turned out to be the checker's own desync or a wrong
disposition rather than work), the rendering-gap list (now empty — every printable `str_out`
site is rendered as data), the body guard's blindness to renames, wiring the mutation
harnesses into CI, and repointing this section.

## Gate log

- **2026-10-21 (owner-approved): T5 shipped, CP2 baseline moved 40 → 42 steps.**
  A fidelity axis was added — `ctx.fidelity` with `--enhanced`, independent of
  `u2_mode`, which is a renderer axis. The creation tail is now faithful in
  `original` mode: `asm/5400`'s tail prints `TO PLAY ULTIMA ][`, then
  `INSERT PROGRAM MASTER`, spins on `key_poll`, and calls the program startup
  routine at runtime `0x0100` — a **full restart**, which is why the owner saw
  the splash reappear and had to press `P`. The engine previously shortcut this,
  so `original` mode was wrong in a way nobody had noticed until the owner
  described the splash. `enhanced` mode skips the CP/M disk-swap dead end and
  enters the world at the created entry point. Both are asserted in CP4, plus a
  third check that an **abandoned** creation (ESC) does not run the tail —
  `u2_creation_flow` returns 0 for abandoned and 1 for completed, and treating
  any non-negative return as success made ESC-rejected creation restart the
  program. Baseline moved because the tail legitimately paints two more frames;
  re-recorded with the documented fresh-`--save-dir` command and verified to
  reproduce. Two strings added through the extractor (`U2_S_TO_PLAY`,
  `U2_S_INSERT_PROGRAM`); both are byte lists in the listing rather than quoted
  `db`, and the disassembler had mis-split `TO PLAY ULTIMA ][` into data
  fragments, so offsets came from the binary. CP1's fallback expectation moves
  64/27 → 66/29. `--auto-pass-polls` also landed, wiring the earlier
  `auto_pass_polls` knob so enhanced mode can tune or disable the idle PASS.

- **2026-10-21 (owner-approved): CP2 baseline regenerated, and CI split.**
  `engine/evidence/cp2-playthrough.json` was re-recorded. The recorded step count
  is unchanged at **40** — the apparent 40→41 drift was not a behaviour change at
  all but a **stale `--save-dir`**: the baseline had been recorded against the
  default `saves/` directory holding state from earlier runs, while
  `tools/playlog.py verify` always replays into a fresh temp save dir. Recording
  under a fresh save dir reproduces exactly. Root cause of the CI red was this
  same coupling, not the overworld changes, which turned out not to move the
  trajectory. Regenerate command, now the documented one:
  `./u2 --headless --save-dir <fresh> --script tests/play_to/reach_everything_today.keys --seed 0 --replay-report evidence/cp2-playthrough.json`.
  Verified to reproduce under both the exe header and the asm-fallback header.
  Separately, `build-and-checksum` was split into **`asm-checksum`** (the
  byte-exact proof) and **`engine-tests`** (Phase 4 WIP) with independent badges,
  because a failing engine test was making the reconstruction's badge read as
  though the proof had regressed — which is exactly the wrong signal to send.

- **2026-10-27 (owner): fidelity policy.** The engine reproduces the original's
  rules and state exactly, but may improve **interaction** where the original was
  frustrating — "spirit of the game", and these improvements live in `original`
  mode, not behind a mode flag. Hard line: UX ergonomics yes, game rules no, and
  the save-record layout never. Deviation register D1-D5 (field navigation,
  editing backspace, refuse-in-place instead of full restart, visible cursor,
  Ctrl-C quit) is in `docs/phase4-plan.md` § 4a. This also scopes what "faithful"
  may be claimed to mean: rules and state match the asm; interaction need not.
- **2026-10-27 — CP2 evidence baseline moved deliberately (owner should note).
  The approved artefact was regenerated, not silently patched.** `C` at the menu
  no longer runs the CP2 stub, so the recorded run could not reproduce; the
  tamper check is what surfaced it, which is the whole point of committing it.
  `tests/play_to/reach_everything_today.keys` now completes a real character, so
  the evidence covers the creation screens too. Digest
  `76a0b3de7556c2b1…` -> `3e5d0492c946fb5b…`, 23 steps/14 keys -> 21 steps/39
  keys. If a baseline must stay frozen instead, say so and it is one revert.
- **2026-10-27 (owner): mod surface scheduled as CP11, deferred out of CP3.**
  Two game modes (`original` hardcoded, `enhanced` customisable), sparse-diff
  overrides, content + rules surfaces, mandatory provenance, mod packs as
  directories with manifests, `key=value` not JSON. Hard constraints: the
  save-record layout is never overridable, no `.pat` reimplementation, no
  committed content. Full design in `docs/phase4-plan.md` § CP11. Also recorded
  there: the sibling `../ultima2` checkout stays off limits as a source of
  conclusions under `AGENTS.md` §0, so the "what do people actually patch"
  question comes from the owner or public research, not from that repo.
- **2026-10-27 (owner): save/disk model approved.** Engine maps the original's
  "insert a disk" onto `--save-dir` (default `./saves`) with a byte-compatible
  `PLAYER` file; missing file is seeded from the pristine blank template;
  unusable path shows the INSERT prompt rather than inventing a location;
  `(INSERT GALACTIC DISK)` is a documented deviation because content is loaded
  at startup. Quicksaves/slots deferred as a filename layer over the same
  record format. Full design in `docs/phase4-plan.md` § CP3 design.
- **2026-10-27 (owner): save-format decision, binding for CP3 onward.** Engine
  save games must be **byte-compatible with the original player record**,
  so `rng_state` (and anything else that is not in the original
  record) must **not** go into the save file. Character creation proceeds on
  that basis. If extra state ever needs persisting, the fallback is a separate
  sidecar meta file next to the save, and only once there is a strong reason —
  not by default. Correction after this decision was recorded: the record the
  game writes is **256 bytes at `DS:36..135`**, not 384 — the *file* is 384
  bytes (proven at CP2.5, three independent write/read sites). The decision is
  unaffected; only the size was wrong. Breadcrumbs to revisit are left in
  `engine/src/core/save.h` (`DEFERRED` block) and in
  `docs/phase4-state.md` § Deferred decisions.
- **2026-10-27 (owner):** CP2 route change **approved in conversation**: the CLI
  is the contract, an MCP wrapper can be added later on top of it. Also recorded:
  **no subagents for this project** — a second local model contends for the GPU;
  work stays in-process. Plan §2/CP2/acceptance-#5 amended and §7 added with
  every evidence-backed correction so far.
- **2026-10-27 — correction logged (no gate needed):** `rand_byte` is a
  six-byte feedback shift register at `DS:0x23F..0x244`, seeded once at program
  launch from the BIOS keyboard flags at `0x40:6C` — not a tick-counter sampler
  as plan §1 and the CP0 log said. Phase 3 had split the routine across
  `asm/5217`/`asm/522B`/`asm/5236`. Engine rewritten to match; `--seed` and
  `--rng-sequence` added; vectors asserted. Consequence for the plan: replay
  determinism comes from the PRNG itself, so the CP2 play-API needs no clock
  trickery, and monster spawns/encounters are reproducible by construction. The
  seed is per launch, not per new game, and is not part of the saved player
  record. Details in `docs/phase4-implementation.md`.
- **2026-10-27 — CP1 owner review round 1.** Owner feedback applied: the echoed
  choice now lands on the `CHOICE:` line (title draw order was wrong —
  `asm/0394` prints at the cursor the last title line leaves, and `CHOICE:` is
  drawn last at row 19 col 5); choice dispatch order corrected against a clean
  decode of runtime `0x389..0x3B5` (`D`→poem, `P`→`asm/0764`→poem,
  `C`→`asm/5400`→`asm/0764`→poem); the poem clears the screen first
  (`asm/03B0`→`asm/4A3E`) and sets the story flag there (`asm/03B3`). Owner
  accepted `][` as-is. Owner **declined a live DOSBox/Spice86 capture** unless a
  real decision point needs one, so the 40-column grid stands on static evidence
  (40-space row clear `asm/53A0`, margins `asm/456B`/`48A7`/`4A2F`, scroll
  window `asm/5025`, mode 4 `asm/4A3E`) — revisit if anything contradicts it.
  Added `--dump-each` (frame-by-frame grid log) so screens can be eyeballed
  without running the game, and an echo-position assertion in the CP1 test.
  CP1 test now 10/10, CP0 9/9.
- **2026-10-27 — CP1 🔒 AWAITING OWNER EYEBALL.** The plan's CP1 acceptance is
  "green test + owner eyeball vs DOSBox screenshot (one-off)". The test is
  green; the screenshot comparison is the owner's. Things worth looking at:
  1. **Grid width.** The engine draws 40x25, not the 80x25 in plan §2. The asm
     is unambiguous (40-space row clear, 0x26/0x28 margins, video mode 4 =
     320x200). If the DOSBox screenshot disagrees, this is the thing to fix.
  2. **`][` = "II".** The title strings really contain `]` `[` bytes
     (`ULTIMA ][`, `PART ][`, `...GAME OF ULTIMA ][`). No font redefinition
     exists anywhere in the binary, so this is a glyph question for CP9; the
     engine renders the bytes as extracted.
  3. **`TYPE -` at row 11 col 5** is a genuine extracted line from
     `asm/02E6`'s region; nothing in the engine fills in a value after it, and
     no code was found that does. If DOSBox shows more text there, that is a
     missing producer and CP1 needs another pass.
  4. **Intro hold durations** (1.5 s / 2 s) are a choice, not a fact; the
     original burns a cycle loop whose real duration is machine-dependent.
  5. **Not implemented yet, on purpose:** the intro's PIC picture loads (CP9),
     'P' prompt path `asm/0764` (load path ahead of us), 'C' creation
     `asm/5400` (CP3). Both stubs print engine-authored notices naming their
     checkpoint.
- **2026-10-27 (owner):** CP0 **approved** ("sure"). Seam layer as the only
  platform boundary, offset-asserted DS state, determinism by clock
  substitution, selfmod premise retired, audio stub until CP9, CI engine job.
- **2026-10-27 — CP0 🔒 AWAITING OWNER ARCHITECTURE APPROVAL.** Built and
  tested; nothing here is irreversible and no gate criterion was loosened.
  Decisions needing sign-off before CP1 builds on them:
  1. **Seam layer as the only platform boundary** — `src/core/seam.h` wraps the
     four vtables in `src/platform/platform.h`; game code never touches a
     backend directly. Every seam call traces with its asm address.
  2. **DS state as an offset-asserted struct** (`src/core/state.h`) rather than
     a bag of accessors; CS-side statics stay with their owning module.
     Reference correction found while building it: `DS:0x2E` is the **column**
     and `DS:0x2F` the **row** (`asm/51FD_str_out_core.asm` loads DL from
     0x2E, DH from 0x2F, BH=0); plan §1 lists them as "page/col".
  3. **Determinism by clock substitution** — headless swaps in a virtual clock,
     which makes `rand_byte` (tick-derived in the original) replayable. No RNG
     is invented; the unproven tail of `rand_byte` is deferred to its first
     caller.
  4. **Selfmod premise retired** — the cluster's executed bytes match the
     static image in all 45 captures; CP3 no longer depends on a live dump.
     A live DOSBox/Spice86 dump is available as extra confirmation on request.
  5. **Audio stays a stub until CP9** — terminal bell in term mode, silent in
     headless; no system package installed.
  6. **CI gains an engine job** (build + `make test`); Phase 3 jobs unchanged
     and still green.

- **2026-10-23 — CP0 asm guard restated (gate change, owner-approved direction).**
  The guard md5'd each changed `asm/` file's non-comment lines against HEAD and failed on
  **any** deletion. That was right while a rename was the only legal `asm/` edit and it made
  the G22 merges impossible: merging sixteen fragments into three routines deletes thirteen
  files, and the gate would have called legitimate maintenance vandalism. The invariant is
  now the tree's **assemblable content**, not the file boundaries —
  `engine/tests/asm_body_guard.py` concatenates every `asm/*.asm`'s non-comment lines in
  start-address order and compares against HEAD. Renames, merges and splits preserve that
  stream; any body edit, insertion, deletion or reorder breaks it. **No criterion was
  loosened — the check is strictly stronger than what it replaced**, catching whole-file
  deletion by content loss rather than by git status, and localising the first divergent
  line. Demonstrated failing first: a one-line `das`→`daa` in `asm/2052` and a removed file
  both went red with useful messages; both were reverted. `assemble_clean.sh` remains the
  end-to-end proof and still reports `37344 bytes identical` after the merges.

## Deferred decisions (with the breadcrumb location)

| decision | status | breadcrumb |
| --- | --- | --- |
| Cross-sector attacks: the original whiffs any swing that crosses a sector edge, in both directions, because the attack-target lookup adds `pos + delta` unmasked while the movement accept path masks with `0x3F` | **DECIDED by owner 2026-10-21** — **original mode reproduces the restriction, enhanced mode fixes it.** Not a fidelity question: the owner called it a defect but chose to keep `original` meaning byte-faithful, so the fix is an enhancement and belongs to that mode. Consequence for the CP2 differential: a cross-sector hit is a legitimate mismatch in `original` mode and must not be reported as an engine regression | this section; mechanism confirmed against the harvest (target lookup runtime `0x23E6` versus accept path runtime `0x2664`) |
| `PICCAS` is loaded by the demonstration (`asm/03AC`) but **is not in `original/`** — the pack ships `picout pictwn picdng picspa picmin picdra` and no `piccas`; the fan pack supplies it | **open, new finding 2026-10-27** — one of the six demo pictures cannot load from shipped content. Affects CP1's demo and CP9's picture work; recorded so it is not discovered at a gate | `docs/phase4-implementation.md` § CP4 "Game data inventory" |
| `tlkxNN` street-NPC dialogue is **high-bit-set ASCII** (Apple II convention) — masking `0x80` yields readable text | **open extractor requirement** — the extractor must mask the high bit for talk files or every string arrives as mojibake. CP6 territory, recorded now so it is not rediscovered there | same section, evidence: `tlkx03` decodes to readable `<NPC> <VERB>: <LINE>` dialogue once `0x80` is masked |
| What reads `monsters` (2176 B)? No inline FCB name in the exe matches it | **open** | same section |
| What do the `mapx` 128-byte tails hold? Byte 0 is `0x1A` in all 82 data files; for `player` and `mapx00` the rest is zero, but most map tails carry ~127 non-zero bytes the 4096-byte read never touches | **partly answered** — the CP3 "what is the `0x1A` tail" question resolves to a DOS EOF marker for `player`, but the map tails are real unread data and remain unexplained | same section |
| Does `--data-dir` get written to, given the original rewrites its own sector files? | **RESOLVED by owner 2026-10-27** — (a) faithful write-back into the player's own files in `original` mode; (b) copy-on-write is the candidate for `enhanced` mode, and belongs with CP11's content surface. Binding consequences: the content dir must be writable, a not-ready dir must fail loudly like `U2_SAVE_NOT_READY`, writes are atomic and only for dirty sectors | `docs/phase4-implementation.md` § CP4 |
| The play screenshot the CP4 viewport numbers rest on is **not in the project** — it was pasted into a chat and only the prose survived, so the tile size and the 9-left/10-right split cannot be re-measured | **CLOSED 2026-10-27** — owner supplied overworld, town, plane and dungeon screenshots; stored at `captures/screenshots/` (gitignored) and measured. Tile = 16x16 px = 2x2 cells, viewport 20x10 tiles, player at window tile (9,5), row 24 blank | `docs/phase4-implementation.md` § CP4 "Viewport: resolved" |
| Persist the PRNG seed/state for replayable saves | **rejected for the save file by owner** — engine saves stay byte-compatible with the original player record (256 bytes at `DS:36..135`), which does not store `DS:0x23F..0x244`. A sidecar meta file is the only fallback, and only with a strong reason. Revisit when CP3's save work lands | this section, and `docs/phase4-implementation.md` § CP3 |
| Exact saved span and write path of the player record | **RESOLVED at CP2.5** — FCB random read/write (AH=27h/28h) via the `asm/52CA` DOS wrapper, 256 bytes at `DS:36..135`, FCB name `PLAYER  ` | `docs/phase4-implementation.md` § CP2.5 |
| What the 128-byte tail of the 384-byte player file is (one non-zero byte, `0x1a` at offset 256) | **open question** — no write path found; do not guess | `docs/phase4-implementation.md` § CP2.5 |
| Are the status pairs (HP/FOOD/EXP/GOLD) binary little-endian or packed decimal? | **CLOSED 2026-10-27 — packed decimal, most-significant-pair-first.** `asm/55B5` emits one byte as its two nibbles each OR'd with `'0'` with no zero suppression, and `asm/53A5` calls it on the low address first, so `[lo]` holds the thousands+hundreds and `[hi]` the tens+units. A gameplay screenshot settled the direction (`GOLD=0038` for 38 gold; a byte-swapped display would read 3800), and the ceiling is 9999, not 255. Consequence worth remembering: a fresh character's `0400` is **400 gold, not 4**. This row sat here as "open, needs the owner's eyes" for a day after the question was already answered, which is the two-hand-kept-copies failure AGENTS § 3 names — the fix was to delete the claim, not reconcile it. | `engine/src/game/status.h` (the citation), `engine/src/game/status.c` `draw_line()`, `engine/src/debug/dump_state.c` prints both `gold_bcd` and the decoded `gold` so the two can no longer disagree silently |
| After creation the engine returns to the title menu, which redraws over the status block | **known gap** — the owner cannot see the status bar at the gate until CP4 gives it a permanent home, or the flow pauses on a key first | `engine/src/game/creation.c` tail |
| `][` glyph mapping ("II") | deferred to CP9 (SDL2 font decision) | `engine/README.md` § Known limits |
| PIC picture files during the intro | deferred to CP9 (no bitmap pipeline before then) | `engine/src/game/title.c` header |
| Live (non-replay) play API / MCP wrapper | optional, build only if a harness needs it; the CLI contract is the substrate | `docs/phase4-plan.md` §7 |

## Backlog

- [ ] **Improve the cleanroom substitute tile art. NO PRIORITY — deliberately parked.**
      47 of 64 tiles still fail their structural rules and sit in `PENDING_REDRAW` inside
      `tools/tile_rules.py`; running `python3 tools/tile_rules.py` prints the current list and
      the specific reason per tile, so this item needs no separate tracking list and must not
      acquire one. The set is usable and shipped; it is unfinished, and `make test` says so on
      every run.

      **The ones the owner judged worst, in case the list is long:** `06` emblem (drawn as five
      disconnected pieces, not one 4-fold-symmetric mark), `0A` signpost (four pieces), `0B`
      sea monster (water is not a stipple and the creature is not two components), `30`
      moongate (no top rule), `00`/`01` water (still chunky, wrong column parity), `03` forest
      (six components where three were asked for). The 25 letter tiles are close — they now
      carry their sign rules and fail only because the glyph touches the gutter rows.

      **If this is picked up, read `docs/cleanroom-procedure.md` first.** The redraw must be
      done by a fresh implementer working from `docs/tile-art-spec.md` alone. Whoever does it
      must not read `docs/tile-art-evidence.md` or `tools/tile_rules.py` — both are answer keys
      holding structure measured from the originals, and reading them would void the provenance
      chain that document exists to protect. Promote fixed tiles out of `PENDING_REDRAW` in the
      same commit that fixes them.

- [ ] **`docs/needs-gameplay.md` is the single tick-list for everything blocked on
      gameplay** (opened 2026-10-22, thirteen items). It carries a who-can-do-it and
      confidence verdict per item, and the standing hazards list that every capture
      session must read first. Several items previously labelled "owner must walk"
      turned out to be agent-drivable; **G0 (harden the probe so a dropped keystroke
      is never read as terrain) blocks the rejection-based items and should land
      first.** The five-question passability capture below is items G1–G5.

- [ ] **Queued for the next unattended batch — see `docs/overnight-harness.md`.**
      Build the generic binary-overlap probe (`H1`), inventory the game constants
      blocking the profile refactor (`H2`), and feed the result back into
      `docs/harness-portability.md` (`H3`). The Ultima III comparison itself (`H4`)
      is **BLOCKED on owner input**: a Ultima III DOS executable placed inside this
      project at a path the owner names. Nothing in this repo matches `*u3*`,
      `*ultima*iii*` or `*exodus*`, and `AGENTS.md` § 0 forbids going to look for
      one. The tool is calibratable offline against binaries already in `original/`,
      so only the comparison waits. Added 2026-10-22; context in
      `docs/harness-portability.md` § 8.

- [ ] **Decode the dungeon map format and reproduce the wireframe renderer.**
      **PARKED by the owner 2026-10-28: overworld and town first.** A dungeon is a
      first-person wireframe with its own byte semantics, so nothing measured there
      is evidence about the 2D world and nothing measured here may be carried in
      without re-measuring; the rule is in `AGENTS.md` § 3. This is
      the largest unexplained surface in the game and it blocks any real dungeon crawl.
      **It also owns the `original/monsters` question** — the 64×34 table at `DS:2900`
      is stroke data whose consumer is this renderer, so T9's "how do the coordinate
      pairs become shapes" cannot be answered until the renderer is decoded (see
      § Still unexplained). Not solved here on purpose; these are leads measured on
      2026-10-21 so the next session starts from evidence rather than from a blank
      page.

      **Already known, do not re-derive:**
      * Dungeons are sectors. Entering moved `DS:49/4A` from `3,0` to `3,5` and loaded
        `mapx35`. No video mode change; it stays CGA mode 4.
      * `mapx35` uses only **7 distinct bytes**, all multiples of `0x10`: `0x00` 46%,
        `0x80` 42%, `0xC0` 6%, `0xE0` 2%, and `0x40`/`0x10`/`0x20` at 15-19 cells each.
        Overworld maps use 30-50 distinct bytes. Seven aligned values is a flag or
        small-enum encoding of geometry, not an art index.
      * Only 7 of the 16 combinations a free 4-bit mask would allow actually occur, so
        it is not independent per-direction wall bits. Start from that constraint.
      * **Objects are runtime-written into the grid as small integers.** Disk vs live
        mid-visit: 32 cells differ, and every addition is a value `0x01..0x07` stamped
        into a cell that was `0x00` on disk (`0x1` x8, `0x2` x8, `0x3` x6, `0x4` x2,
        `0x5` x2, `0x6` x4, `0x7` x1). So placement is generated at load and
        representation is a tile - the same mechanism as overworld vehicles, where
        boarding stamps a cell and landing moves it. Answer to "random or tiles": both.
      * `mapx25`, `mapx35` and `mapx45` are **byte-identical** (md5 `e274897a...`). Any
        decode must explain or accept three sector numbers sharing one map, and any
        "which sector am I in" check must use the digits, not the bytes.
      * Light is a step counter at `DS:26`: zeroed on entry, ~150 on `I`, decremented
        per move, zeroed again on re-entry. `vga_ink` is a reliable dark/lit signal
        (exactly 0 when dark).
      * Command dispatch is mode-aware: `A` ATTACK outside, ADVANCE inside; `I`
        inventory outside, IGNITE TORCH inside; `K` is the rope exit; `G` looted a box.

      **Open, in the order worth attacking:**
      1. What the seven static bytes mean. The `A`-`Z` letter tiles are the foothold -
         in sectors that spell words they are legible ASCII, so a byte-to-glyph mapping
         is already known and may share the table.
      2. Which routine draws the corridor. The wireframe is mode-4 line primitives; find
         the line drawer and the table it indexes with the tile byte. `tools/vga_ring.py`
         and `tools/vga_screen.py` are the existing frame-reading tools.
      3. How the 64x64 grid maps to the crawl. The dungeon viewport is not a top-down
         window, so the (x, y) to "what is in front of you" relation is unproven.
      4. **The rope is not the tile under the player.** Climbed out at (5,5) and that
         cell is `0x80`, the same byte as 32 of 48 dungeon positions. Either it is a
         facing-relative property or a property of the entry point. Untested; do not
         write it up as a tile until measured.

      **Method that worked:** drive the owner into a known cell and dump grid plus frame,
      correlating rather than reading the listing cold. `tools/dungeon_capture.py` does
      this and re-reads the grid every sample on purpose - a cached grid produced stale
      labels and one fabricated finding. Evidence: `docs/spice86-live-findings.md` § 13
      and `captures/spice86/dungeon-entry/` (55 events, full DS + VGA each).

- [ ] **Standardised capture tooling: one recorder for gameplay, memory and CFG.**
      Today three ad-hoc probes were written in one session (`tools/turn_recorder.py`
      existed and was used; `tools/dungeon_capture.py` was written for the dungeon
      transition; two throwaway pollers went to `/var/tmp` and are now gone). Each
      re-solved the same problems and each got some of them wrong. A single tool should
      own: change-triggered sampling on a caller-supplied signature; full DS + VGA
      snapshots per event so history can be re-rendered without replaying; a
      **live** grid read every sample, never cached, because the map mutates during
      play and a cached grid caused a fabricated "vehicle depot" to be written into
      the docs and then retracted; the BIOS video mode at physical `0x449`, not
      `0x449*16`; and a VGA ink metric, which is what proved darkness was a real
      blank frame rather than a dim render. It should also subsume the CFG harvest
      and immediately cross-check `ExecutedInstructions` rather than relying on
      `tools/cfg_printed.py`, which silently dropped a genuinely executed print site
      (`LAND--NOT HERE!!!!!`, runtime `0x3B72`). Requirements: read-only against the
      emulator, output into `captures/spice86/<label>/`, and a negative control run
      per `AGENTS.md` before any result is cited. Fold in the known defects: the
      recorder's `screen` field is junk in CGA graphics mode, and `turn_recorder.py`
      logged 76 odometer anomalies in 3000 turns so single-turn boundaries in dense
      combat are not trustworthy.

- [ ] **Five-question Spice86 capture — passability, the art transform, food on a
      rejected step, the mountain tile, and the mode-byte writers.** Owner must
      walk; reads are passive. Amended 2026-10-22 after T8: question 2 was stale
      (it asked whether the ladder reads a tile, which F10 refuted live and T8
      killed statically) and a fifth question was added for the `DS:2CB`/`DS:2DE`
      attribution that is now the whole of C5. Full spec in
      `docs/passability-findings.md § Open`. In one session in sector
      20: (1) dump the staging buffer at `DS:272` against the sector map to settle
      whether `art = map_byte >> 1` or `>> 2` — `engine/src/core/view.h` currently
      claims both and they are mutually exclusive; (2) break at runtime `0x2423`
      and dump `AL, DS:13, DS:15, DS:18, DS:29, DS:2CB, DS:2DE` plus the
      destination tile on one ordinary step and one step onto a force field, to
      find what writes mode `0x2e` into `DS:29` and whether that write depends on
      the tile at all — **not** the old tile-vs-`AL` test, which is settled; (3) read
      `DS:53..55` before and after a deliberately blocked step to find out whether
      a rejected move costs 19 food, which the block ordering implies but does not
      prove; (4) **stand next to a visible mountain, walk into it, and read the
      destination tile byte** — this settles F9, where the engine currently marks
      `0x08` passable while F8 calls it the mountain, and it would be the first
      honest measurement of a blocked tile other than water; (5) capture
      `DS:2CB`/`DS:2DE` before and after sector entry, sector crossing, boarding
      and alighting, and stepping onto a field — whichever event moves them owns
      the tile→mode mapping, and the instruction pointer at the moment of change
      would close F3, C5 and T8 in one datum.

- [ ] **`tools/u2_edit.py` — save-file and live-memory editor.** Owner request,
      2026-10-21. Must do two jobs with one set of tables: edit a `player` save
      file on disk, and patch a live session through the Spice86 MCP
      (`local-mcp_write_memory`, segment/offset as decimal integers). Needs the
      lookup tables below, must handle packed BCD rather than binary, and must
      warn the user that the status band is a **cached render** — writes land in
      memory instantly but the screen only repaints on the game's own status
      draw, so "it still says 50" does not mean the write failed. Refuse to write
      an out-of-range BCD nibble (e.g. `0x9A`), which would corrupt a counter.
      Tables and offsets: `docs/spice86-live-findings.md` § 11.

- [x] **`tools/cfg_printed.py` fixed 2026-10-21.** It had two faults, both worth
      remembering. It read `CfgBlocks`, which is *discovered* blocks — Spice86
      statically expands branch successors — so it reported `MINAX IS DEAD!!`,
      `RING PROTECTS FROM FIELD!` and `FIELD CAUSES 1000 DAMAGE!` for a session
      that met none of them; it now gates on `ExecutedInstructions` in
      `spice86dumpExecutionFlow.json` (a list of `{Offset, Segment, Linear}`
      dicts, ~2400 entries) and refuses outright if that file is missing or
      empty. And messages carry `0x0D`/`0x8D` control bytes on **both** ends, so
      stripping only the leading ones silently dropped `LEGS PARALIZED!` and
      `--PARALIZED!` — the exact evidence being hunted. Address model, verified:
      the inline string sits at `runtime_offset + instr_offset + 3 + 0x200` in the
      file; do **not** add the segment base as well, which finds nothing silently.
      Validated across three harvests with a pre-fight negative control.
      Lesson kept because it generalises: a tool that confidently lies is worse
      than no tool, and a silent filter is the hardest lie to notice.

      **Follow-up, 2026-10-22 (overnight T1): the 2026-10-21 fix was still
      incomplete and dropped a real site.** It gated the *executed test* on
      `ExecutedInstructions` but still *discovered* sites by walking CFG block asm
      and still split inline bytes on the first NUL. `LAND--NOT HERE!!!!!` (runtime
      `0x3B72`) is in `ExecutedInstructions` yet was not reported: its inline bytes
      are `LAND--NOT HERE!!!!!\rCMD: \x00` — the message is terminated by `\r` and
      the next string follows before any NUL, so the NUL-split run
      `LAND--NOT HERE!!!!!\rCMD: ` failed the printable check and `extract()`
      returned `None` silently. The tool now (a) derives sites from
      `ExecutedInstructions` as the primary source (scan executed code-segment
      instructions for `E8` near-calls to str_out `0x4FDF`), with CFG blocks only a
      secondary seed for `--all`; (b) reads a message up to the first
      non-printable byte, not the first NUL; (c) fails loudly on an unrecognized
      dump shape instead of returning an empty list; and (d) carries
      `--selftest`, a positive/negative control (`LAND--NOT HERE!!!!!` present in
      `dungeon-35-live`; `MINAX CRIES: DIE FOOL!` and all combat strings absent in
      `dungeon-35-live` and `create-test-live`). Same lesson, sharper: fixing the
      *executed gate* was not enough — the *site-discovery* path and the *terminator*
      were the second and third silent filters hiding behind the first.

- [ ] **`tools/replay.py` — turn replay from the recorder snapshots.** Pure
      offline work on data already on disk, no emulator needed. Read
      `/var/tmp/u2-turns/turns/NNNNN.ds` plus `index.jsonl`, render the zoomed
      viewport or the full 64x64 map per turn, annotate each frame with detected
      events, and emit an animated sequence or a text log. Proven feasible: 151
      turns of the vga-test fight already yield the timeline, including the
      monster adjacent at turn 149 and gone at turn 150 with `+13g +4xp`. Reuse
      the glyph and monster-kind maps from `tools/map_render.py`.

- [ ] **Ordered message log.** The CFG gives the *set* of messages a session
      printed, never the order — `ExecutedInstructions` is a set of distinct
      addresses with no timestamps and no counts. So "the thief stole it, then I
      attacked" is not recoverable from a harvest. Two candidate fixes, neither
      tried: MCP `add_breakpoint` on str_out at runtime `0x4FDF` to capture an
      ordered print log (cheap, but pausing may upset game timing), or
      `tools/vga_ring.py` sampling the framebuffer continuously.

- [ ] **Run `tools/vga_ring.py` for the first time.** Written after the session
      ended; syntax-checked only. It exists because combat text is drawn and
      overwritten inside a single turn, so turn-boundary sampling provably cannot
      catch it — 151 turns of a real fight yielded zero readable framebuffer text
      while memory proved a kill.

- [ ] **Fix `tools/turn_recorder.py`'s two known flaws.** Both cosmetic, neither
      blocking, but they make the log harder to read. `DS:20` is scratch, not a
      pure invalid-move counter — the harvest shows it decremented in the walk
      loop and overwritten at `0x2BC7` — so including it in the change signature
      fabricates `[reject]` rows. And position and food update non-atomically, so
      one move can split across two samples and show as a false odometer
      anomaly. Only 12 of 151 turns classified as a clean event.

- [ ] **Screen ring for the recorder.** See `docs/spice86-live-findings.md` § 10.

### Proven from the harvests, for whoever picks this up

The CFG-plus-`ExecutedInstructions` technique settled several things without any
new capture. Executed: `ATTACK--`, `--MISS`, `--HIT!!!`, `--EXP.+`,
`KILLED--GOLD+`, `--INVALID MOVE!`, `LEGS PARALIZED!`, `--PARALIZED!`, and
`A THIEF STOLE SOMETHING!`.

**Update, 2026-10-21: the "not executed" list from that earlier pass is stale and
was removed rather than left to rot.** `RING PROTECTS FROM FIELD!`,
`FIELD CAUSES 1000 DAMAGE!`, `ARMS PARALIZED!` and `SAVED BY MAGICAL BOOTS!` have
since all been observed executing in `captures/spice86/castle-03-live`, together
with `SAVED BY MAGICAL CLOAK`, `SAVED BY IDOL!`, `MAGIC MISSILE!`, `SLEEP SPELL!`,
`-CASTLE` and a level-up. Only `MINAX IS DEAD!!` and `MINAX CRIES: DIE FOOL!` are
still unexecuted, and the sector-00 compound is now known to be a caster gauntlet
rather than the Minax fight. The `create-test-live` negative control still stands.

Two consequences worth keeping. `A THIEF STOLE SOMETHING!` is printed from the
same block that decrements `DS:D6+i`, so the theft of the staff is proven rather
than inferred. And `--PARALIZED!` lives at runtime `0x2527`, *inside* the
passability routine — so paralysis is enforced in the movement check itself and a
paralyzed step takes the same reject path as walking into a mountain. That is why
`--INVALID MOVE!` is what the owner saw while paralyzed, and it means the engine
must model paralysis as a movement rejection, not a combat overlay.

## CP5 — combat tickets (scoped 2026-10-21; mechanics landed 2026-10-22, wiring in progress)

Scope rule for this checkpoint: **no stubs.** A stub for "resist paralysis" encodes
boolean immunity, passes the tests that do not exist yet, and looks finished. Every
ticket below is either a proven behaviour with a byte citation, or an explicitly
named unknown. Where the input is unproven the ticket is `blocked`, not guessed.

Full evidence: `docs/spice86-live-findings.md` § 12, and the function headers in
`asm/` for `0AAA`, `0AD3`, `0E70`, `0EC2`, `0F12`, `0F48`, `0FCD`, `24B5`, `2FAD`.

| ID | Ticket | Status | Why |
| --- | --- | --- | --- |
| C1 | Three independent status counters as persistent state: legs `DS:26B`, arms `DS:26C`, sleep `DS:26D`, each set to `rand & 0xF` (0..15 turns) and stored in the player record | **implemented 2026-10-22** (counters); **persistence question CLOSED 2026-10-23 — they are not persisted and cannot be** | `asm/0E70`, `asm/0EC2`, `asm/0F48`. Arms and legs are separate counters with separate items, so a character can be paralysed in one and free in the other; both were observed non-zero simultaneously (9 and 8) alongside sleep 8. **Corrected 2026-10-22 (overnight T10): "stored in the player record" is not byte-proven and is probably wrong.** `DS:26B/26C/26D` are 619..621, outside the proven save record `DS:36..135` (54..309) per `docs/save-format.md`. The counters are proven to exist and to be independent; their persistence is not. `engine/tests/combat_check.c` asserts they live outside the record rather than asserting unsupported persistence. **Settled empirically 2026-10-23**: poked `07 09 08 08`, pressed `Q`, the bytes are absent from the 384-byte file and read back `00 00 00 00` on reload — `captures/spice86/cp5-g24-save/`, `docs/spice86-live-findings.md` § 17. A fourth counter `DS:26A` ticks with them. |
| C2 | Resist is a **~75% roll on a live item-array slot**, not immunity: `[DS:D9]` BOOTS, `[DS:DA]` CLOAK, `[DS:E4]` GREEN IDOL; with the item the `L_005417` roll must be `>= 0x40`, without it the effect lands with **no roll at all** | **implemented 2026-10-22** | This is the single easiest thing to get wrong, and the pre-existing docs had it wrong as a boolean gate. Needs a distribution test, not a present/absent test. |
| C3 | Paralysis is a **movement rejection**, not a combat overlay | **implemented 2026-10-28** — `overworld.c` rejects the step with `--PARALIZED!` ahead of the terrain test, gated by a Daemon fight with an Orc control | `--PARALIZED!` is at runtime `0x2527`, inside the passability routine, so a paralysed step takes the same reject path as walking into a mountain. Couples to the CP4 passability work and to the `--INVALID MOVE!` path. |
| C4 | Magic missile: **no save path exists** | **implemented 2026-10-22** | `asm/0F12` has no inventory gate and no roll, unlike the other three. Now asserted in `combat_check.c` two ways: the missile applies whatever the inventory holds, **and it consumes no random byte** (`u2_rng_rolls` unchanged) — the second is the sharp one, since a boolean-immunity impl both rolls and skips. The accumulation into `DS:20/21/22` is still **not modelled**: its BCD weight against the HP subtract is unproven and `DS:20` is separately claimed as `move_scratch` (disputed). The spec asserts the proven property and stays silent on magnitude. |ing as a named unknown. |
| C5 | Force field: ring gate `[DS:D6]`, exactly **-1000** via `stc; sbb al,0x10; das` on `[DS:51]`, and a death branch when HP < 1000 | **implemented 2026-10-22** (behaviour; placement still open) | `asm/24B5`. Damage, gate and death branch are proven and **both branches have executed** — the live force-field turn is on record (fight turn 2909: HP −1000, `[DS:D6]=0`, `[DS:15]=[DS:18]=0x2e`), and the `24B5` region executed in 2 captures. ~~blocked on a capture~~ **Reclassified 2026-10-22: the field was captured.** What remains open is only *placement*: the trigger is a **mode** byte (`[DS:29]&0x7f == 0x2e`), not a tile byte — `0x2e` occurs 0× in `mapx00` — and the tile→mode mapping is the unresolved indirect store into `DS:2CB/DS:2DE`. That belongs to the passability ticket (G4), **not to combat**. Implement the behaviour; do not wire C5 to a tile byte. **SUPERSEDED 2026-10-28 — placement is
   solved and it IS a tile: `0x5C`.** Measured in `captures/spice86/g29-field`: stepping onto a
   `0x5C` cell in sector 03 costs exactly 1000 HP with no ring, six times over, and nothing with
   the ring held; a plain `0x70` step costs nothing. The instruction above was wrong because of a
   units error — it searched `mapx00` for `0x2e`, but `0x2e` is the **mode** byte and the mode is
   `map_byte >> 1`, so the tile is `0x5C` and `0x2e` could never appear as a map byte (map bytes
   are multiples of 4). The `0x5C -> 0x2E` sample was already recorded in
   `asm/2FAD_vehicle_board_dispatch`. C5 can now be wired to tile `0x5C`. |
| C6 | Theft **deletes** from the item array; killing the thief restores nothing | **implemented 2026-10-22** — premise corrected the same day | ~~thief is monster type `0x40`~~ **wrong on two counts.** `asm/0FCD` contains exactly one `cmp $0x40` (file `0x11D1`, not `0x1244`, which is outside the span) and it compares a **random value** — a ~25% chance of attempting a theft, not a type test. The routine never reads a monster record; which monster reaches it is the caller `asm/0AD3` dispatching on the **kind index** `[DI+0x1B7]`. Mechanics to implement: roll `<0x40`; pick slot `DS:D6 + (rand & 0xF)`; if that slot is **zero, do nothing and print nothing** (a failed theft is silent); else BCD-decrement it by 1 and print `A THIEF STOLE SOMETHING!`. Measured: 8 items stolen, 0 returned, kill paid a random drop like any other. Because the C2 gates read the item array live, a flagged-but-present item would wrongly keep the resist. |
| C7 | Map byte -> vehicle code transform for BOARD | **resolved 2026-10-21** | `[DS:14] = map_byte >> 1`, measured on 53 of 54 walk samples across four terrain bytes. So vehicle tiles are `0x44` horse, `0x48` ship, `0x4C` plane, `0x50` rocket. Confirmed by the game: `B` on a `0x4C` tile set `[DS:13] = 0x26` and printed `' PLANE'`. An earlier note here claimed the plane was `0x34`; that was a `%02d`-against-hex-filenames render bug and `0x34` is art `0x0D`, a humanoid figure. ~~Still unexplained: the `y*16 + x` indexing at file `0x6AC0` against a 64-wide grid.~~ **Resolved 2026-10-22 (overnight T7):** `asm/68C0` indexes the **dungeon** grid (`word[DS:472] + [DS:25]*256 + y*16 + x`, a 16-wide paged view of the DS:1800 buffer), not the overworld sector grid; reached only from the dungeon path. See `docs/spice86-live-findings.md § 12`. |

**Combat entry is now observed, not designed (2026-10-23).** `A` + a direction attacks the
adjacent cell; the fight is drawn as one line of the world view's `CMD:` log
(`ATTACK--EAST--HIT!!!`, then `KILLED--GOLD+1--EXP.+02`) with no battle screen and no mode
switch. A creature also *blocks* movement — stepping onto one prints `EAST--INVALID MOVE!`
over a walkable tile. Full evidence and the live screenshots: `docs/spice86-live-findings.md`
§ 14, capture `captures/spice86/cp5-fight/`. Two consequences: the encounter wiring is a
command handler plus an adjacency test, not a subsystem; and the acceptance bar "a rendered
fight" is now a concrete target rather than a vibe.

**The status tick is time, not moves** — measured from the existing
`fight-20261021-castle03` recording, where `DS:26B/26C/26D` decremented while the player
never moved. The tick routine is `asm/0C33..0C53`, and it ticks a **fourth, unnamed counter
at `DS:26A`** (zero throughout that fight). So in the engine the tick belongs to the main
loop, not to `overworld` movement — which is what C3's "one movement system" needs anyway.

**The turn expires on its own, and the mechanism is a poll counter (2026-10-23, owner-ruled,
then measured, then corrected against the bytes).** Each turn has a budget; when it expires
with no action the game performs a PASS for you, and a half-typed command expires as
`ATTACK--PASS`. Observed with nothing sent at all: an empty log filled itself with `CMD: PASS`
lines, ~7.5 s apart (counted by the food a pass costs). The engine **already implements
this** — `overworld.c`'s idle auto-PASS with `U2_AUTO_PASS_POLLS 256`, because the bytes say
`incb DS:21; jne <loop>` (runtime `0x08D6`): a poll count, not a clock, and there is no
`INT 1Ah` in the corpus. So the ~7.5 s is what that count costs at `--Cycles 3000`, and it
must not be hard-coded as milliseconds — a prior session measured ~7.6 s and refused to
encode it for exactly that reason. The owner's enhanced-mode knob already exists as
`--auto-pass-polls` (`-1` = no timeout = true turn-based). Creature turns are per-creature
but **mostly no-ops**: 7% of (creature, turn) pairs moved anything, movers shift 2 cells,
and 26 of 32 slots never budged. **And the status counters do not tick per turn** — 15
decrements in ~0.7 s against exactly one PASS; `asm/0C33..0C53`'s caller is still
undiscovered, so no per-turn decrement may be wired until it is found. Evidence:
`docs/spice86-live-findings.md` § 18 and its addendum, capture
`captures/spice86/cp5-turn-timeout/`; build order in `docs/phase4-kickoff-cp5.md` W6b/W7.

**W5, W6, W6b and W9 are done (2026-10-27), and the CP5 bar is met in the scripted
sense.** `engine/src/game/ai.c` is the creature turn: the `mon_role` dispatch
(inert at 0 and at `0x81..0x85`, full pass at 1, alerted-and-moving at 2, and
deliberately nothing at 3 because `asm/1086` is unread), the unit step from
`asm/4F11` with its torus sign trick, the retreat at 14 HP, the per-species tile
rule, and the four specials behind `asm/0AAA`'s proximity-plus-1-in-8 gate.
`u2_ai_alarm()` is `asm/113A`: a landed hit inside a site sets role 1 on slots 7..0,
which is § 16's sector-wide guard response found in the static tree eight days after
it was measured. W9 is a gate that runs in CI with no game files at all —
`tests/cp5_fight_seed.py` emits a synthetic mapx, monx and PLAYER, and `run_cp5.sh`
drives `./u2` through the real input path and asserts `ATTACK--EAST--HIT!!!`,
`KILLED--GOLD+n--EXP.+m`, and that GOLD and EXP both wrapped past 9999 instead of
clamping. Its control empties the sector and requires MISS. Full write-ups:
`docs/monster-spawn.md` § 13 and § 14, `docs/sector-rulesets.md` § 6.

**W8 is done (2026-10-27), and the span was the finding.** `asm/0C62` had been left as
`sub_0c62 — behavior not yet reviewed` because each of its four fragments looks like
nothing alone. Laid end to end, `0C62..0C99` is the death handler: nine zero stores into
`DS:51..59`, a repaint, three newlines, the name from `DS:36` via `asm/507A`, then
` IS DEAD!` and a newline. Every site that can kill jumps into it — the food borrow-outs,
the force field, Minax, three dungeon-event sites and `cmd_L` — which is why the engine got
one function (`u2_death`) rather than three lines inside the food subtract. The captured
frame `captures/spice86/cp5-weak-fight/death1.png` settled two things the bytes left open:
all four status fields repaint (the routine itself calls only the H.P. line), and the
announcement sits on row 22 with the bottom row bare, because its own trailing newline
scrolls it up. `engine/tests/death_check.c` pins both, plus a control that a survivable
food spend announces nothing; the gate was mutation-tested by removing the announcement and
watching four checks go red. What the game does *after* the announcement is still unknown
and is G27 on `docs/needs-gameplay.md`, marked agent-drivable.

One design constraint that outlives the checkpoint: the original keeps **two** copies
of some item counts and one goes stale. `DS:6D` still read 1 after a thief stole the
boots, while the live gate `DS:D9` correctly went to 0. The engine needs a single
source of truth for item counts, and any resist check must read it rather than a
cached boolean.

> **`DS:6D` is disputed, 2026-10-23 — do not build on the paragraph above until this is
> resolved.** `asm/3DFA_offer_only_outdoors_earth` tests `[DS:6D]` and prints
> `ONLY ON EARTH!` when it is non-zero, which is a location gate observed live while
> pressing `Q`, not an item count (`docs/spice86-live-findings.md` § 17). The byte is
> inside the saved record and the value `1` seen after the theft is exactly what an
> on-Earth flag looks like. Either the byte is genuinely reused or the boots reading was a
> coincidence of value. The *conclusion* (one source of truth for item counts) is sound on
> its own merits and `DS:D9` is still the live gate; it is the *evidence* that is now in
> doubt. Resolving it: steal the boots, then read `DS:6D` and `DS:D9` together and check
> whether `DS:6D` also flips the save gate.

**Second design constraint, from the owner on 2026-10-23, and it is architectural.**
Asked whether paralysis survives leaving combat, the answer was *"I don't know if that
survives SAVE, but there's not really a leaves-combat state."* That is a statement about
the original's shape, not about a detail: combat is not a separate mode you enter and
exit, it is the same continuous space with a different thing happening in it. Three
consequences, all of which the scope ruling now commits us to:

* **It independently corroborates C3.** If there is no separate combat mode, then
  paralysis being a *movement rejection* rather than a combat overlay is not a quirk to
  emulate, it is the only shape that makes sense — a paralysed step takes the same reject
  path as walking into a mountain, because there is one movement system, not two.
* **It contradicts a likely engine assumption.** If the reimplementation grew a battle
  screen or a combat-mode flag, that is a deviation to surface, not a feature. Check this
  before writing the encounter wiring, because it is much cheaper to discover now.
* **It makes the SAVE question the only persistence question.** If nothing is entered and
  left, then the only way a status counter can outlive its context is by being saved — and
  C1 already says the counters sit at `DS:26B..26D`, **outside** the proven save record
  `DS:36..135`. So either they are not persisted at all, or the save record is bigger
  than `docs/save-format.md` currently proves. Both are testable headlessly: seed
  non-zero counters, save, reload, read back. Registered as a capture ticket.

The legs/arms asymmetry the owner described — **legs out means you can fight but not move,
arms out means you can move but not fight** — is consistent with C1's three independent
counters and with C2's separate item gates (`[DS:D9]` boots, `[DS:DA]` cloak), and is the
behaviour the CP5 acceptance should assert, since a single boolean "paralysed" flag cannot
reproduce it.

**C2's discrimination is now CI-enforced, not asserted.** `engine/tests/combat_check.c`
runs on every `make test` against two shipped fixture models: `combat_model_faithful.c`
(must pass) and `combat_model_boolean_wrong.c` (must fail). A third control, added
2026-10-23, runs the same harness with `CP5_SPEC_NO_TESTS=1` so it reports 0 checks,
and asserts the gate reads that as a real zero and goes red — the guard that reports
"the spec is not running" is itself now proven rather than asserted. If the spec ever
stops rejecting the boolean-immunity model, `test-cp5` goes red. Building this also exposed that
`run_cp5.sh` was exiting 0 unconditionally while `combat.c` was absent, so the gate
could not fail at all — fixed in the same commit.

## BCD counter tickets — wrap vs cap (scoped 2026-10-22, not started)

T4 proved one instance; `tools/bcd_census.py` proves it is the house style. Every
numeric field the original keeps in packed decimal behaves the same way, and the
behaviour is a property of the **storage width**, not of any individual counter.

Census (regenerate with `python3 tools/bcd_census.py --counters-only`; do not copy
these numbers, they will drift):

| op | known-counter sites | guards found |
| --- | --- | --- |
| `daa` add | 30 | 28 none, 1 branch-only, 1 clamp |
| `das` sub | 31 | 13 borrow-test, 18 none (read per chain, see below) |

The rule that falls out:

* **Additions do not guard the ceiling.** `adc`/`daa` per BCD byte with the carry out
  of the top byte discarded, so every counter wraps at its digit capacity.
* **Multi-byte subtractions test the borrow once, on the top byte.** The idiom is
  `cmc; sbb; das; cmc` — the second `cmc` deliberately re-exposes the borrow in CF so
  a following `jb` can branch on it (`asm/2599` food, `asm/2495` HP, `asm/2052`
  gold). A `cmp`/`test` search misses this entirely, which is why an earlier
  heuristic under-counted the guards.
* **Single-byte subtractions test nothing.** `torches` (`asm/37AE`), `keys`
  (`asm/435E`), `tools` (`asm/277B`) and the item slots (`asm/0FCD` theft, `asm/6999`,
  `asm/6DFD`) store the adjusted byte with no borrow test. Under BCD underflow that
  byte becomes `0x99` — **99, not 0**.

Ceilings, from the proven widths in `docs/save-format.md`:

| field | DS | width | ceiling | at ceiling, +1 | at zero, −1 |
| --- | --- | --- | --- | --- | --- |
| `str agi sta cha wis int` | `4B..50` | 1 BCD | 99 | 00 | 99 (unguarded) |
| torches / keys / tools | `64/65/66` | 1 BCD | 99 | 00 | 99 (unguarded) |
| weapons / armour / item counts | `76+i` / `96+i` / `D6+i` | 1 BCD | 99 | 00 | 99 (unguarded) |
| HP | `51..52` | 2 BCD | 9999 | 0000 | borrow-tested |
| EXP / GOLD | `56..57` / `58..59` | 2 BCD | 9999 | 0000 | borrow-tested |
| food | `53..55` | 3 BCD | 999999 | 000000 | borrow-tested |

| ID | Ticket | Status |
| --- | --- | --- |
| B1 | **Original mode reproduces the wrap.** Re-scoped 2026-10-22 after checking: the clamp this ticket was written against (`u2_bcd16_encode()`) had **zero callers** — dead code, not a live deviation. The live BCD arithmetic (`bcd_sbb()` in `engine/src/game/overworld.c`) was already faithful: it implements `das` including the AF half-borrow, tests the borrow out of the **top** byte and branches to the `asm/0C62` starvation zeroing — exactly what the census says multi-byte fields do — and was verified against a reference model (a fresh character dies on exactly the 4001st PASS). Done now: the clamping encoder is **deleted**, with a note in `core/state.c` on why it must not return. Remaining: when CP5 first adds gold/exp, write `bcd_adc()` as the deliberate mirror of `bcd_sbb()` — discard the carry, cite `asm/2DC1`/`asm/2DEE`, pin with the measured `9999 + 15 -> 14`. | **decided by owner 2026-10-22** (original mode reproduces the wrap). Trap removed; the add helper lands with CP5, its first caller |
| B2 | **Enhanced mode clamps at the ceiling and says so.** Catch the carry/borrow that original mode discards, clamp at the field's ceiling, and print a message (`NO ROOM` / `DENIED AT MAX`) in the existing message window. The same flag serves both modes, which is why honouring the BCD mechanics needs no policy layer. The message must be **enhanced-only**: the original prints nothing when gold wraps. | todo |
| B3 | **Cap override is downward-only.** The ceiling is a property of the storage width, so a value above it is unrepresentable in the save format — the save record is `DS:36..135` copied verbatim (`engine/src/core/save.c:103,129`). An override above the ceiling must be refused, not silently truncated. Raising a cap would require an enhanced-mode save format change, which is a separate and much larger decision. Follow the `auto_pass_polls` precedent in `engine/src/core/ctx.h` for the enhanced-knob shape. | todo |
| B4 | **Never normalise loaded BCD.** Invalid nibbles are reachable: BCD underflow manufactures them (`0x10-0x0B -> 0xFF`, `0x30-0x1F -> 0x0B`). A decode/encode round-trip **repairs** them — measured: `9A 99 -> 10099 -> 99 99`, and `1B 05 -> 21 05` with no clamp involved. **Downgraded from a fix to a standing rule 2026-10-22:** the only encoder that could round-trip has been deleted (see B1), and `engine/src/core/save.c` loads and writes the record by verbatim `memcpy` (lines 103/129), so no normalising path exists. Keep it that way: arithmetic mutates BCD bytes in place, never through an int round-trip. | **invariant, not a task** — held by the absence of an encoder and the note in `core/state.c` |
| B5 | **`state.h` has no names for these counters.** `engine/src/core/state.h:168` lumps `0x64..0x238` into `reserved_64[0x1D5]`, so torches, keys, tools, weapon/armour/item counts and the boots slot are all unnamed — while `docs/save-format.md` documents them as proven. Name the fields and add the `_Static_assert`s so the wrap tickets have something to attach to. | **done 2026-10-22.** Split the blob into `torches`/`keys`/`tools`/`boots_count`/`weapons_owned[10]`/`items_held[16]`, each with its asm add/sub sites cited in the comment. Two extras found while doing it: `readied_weapon` (0x61) and `worn_armour` (0x62) were proven but buried inside `reserved_5C[7]` — now named. `boots_count` carries the stale-copy warning (it kept reading 1 after theft while the live gate `DS:D9` went to 0) so nobody wires a resist to the wrong byte. **`0x96` deliberately left unnamed**: the census inference that it is an owned-armour count table rests only on three asm sites doing BCD arithmetic on `0x96(%di)` beside `0x76(%di)` — no display site, no live read/write-back. Marked CANDIDATE, NOT PROVEN. Added `sizeof(u2_state) == 0x650` as a guard so a future split cannot silently lose or gain bytes; proven to fire by perturbing one offset. |

Not yet proven, and deliberately not guessed:

* **Reachability of the single-byte underflow.** The bytes show no borrow test; they do
  not show that the game lets a counter reach zero and be decremented anyway. A
  `keys == 0` guard upstream of `asm/435E` would make `0 -> 99` unreachable. Needs a
  capture or a caller walk.
* **The `das` results are inferred from documented 8086 semantics, not observed.** The
  `daa` side I did validate against a real observation (T4). Nothing in `captures/`
  shows a BCD underflow, so `0 - 1 -> 99` is a property of the format, not a
  witnessed bug.
* **26 non-counter `daa`/`das` sites are excluded** from the census tally as unresolved
  targets or mis-decoded data (e.g. `asm/025E`, the "REVENGE" title printer, whose
  `das` is followed by the nonsense `add %al,(%bp,%di)`). Do not cite them.

---

## Invariants (checked at every checkpoint)

| Check | Command | CP0 result |
| --- | --- | --- |
| Per-function byte proof | `python3 tools/check_func.py <SEG>` | 1299/1299 green (sample re-run + CI) |
| Mechanical rebuild | `bash tools/assemble_all.sh` | byte-identical |
| Clean-tree rebuild | `bash tools/assemble_clean.sh` | 1299/1299 cleaned, 37,344 B identical |
| Original untouched | md5 `fe884d5117971073ac8097cc7a6aca25` | unchanged |
| Engine test | `make -C engine test` | CP0 11/11, CP1 9/9, CP2 12/12 PASS |

---

## TODO: internationalisation (i18n)

**Status: not started. Recorded so it is designed once, deliberately, rather than
bolted on after the text layer has hardened.**

The engine currently has no language axis at all. Text reaches the screen as
compile-time `#define` string literals in `engine/build/gen_content.h`, generated
from the original executable by the Makefile. That is simultaneously the good news
and the obstacle.

**Good news: a seam already exists.** Every string is reached through a `U2_S_*`
name (`U2_S_CMD_PROMPT`, `U2_S_STATUS_HP`, ...) rather than an inline literal at the
call site. Callers do not care where the text comes from, so replacing the macro
layer with a runtime table is a contained change, not a sweep.

**The obstacle is that those strings are game content.** They are extracted from a
copyrighted binary, they are English-only, and they are only kept out of git by being
build output. A translation catalogue cannot simply be a translation of them without
saying clearly which parts are original text and which are engine-authored.

Requirements when this is picked up:

1. **Runtime string table, not macros.** `U2_S_FOO` becomes an id resolved through a
   lookup, so the language can be chosen at launch (`--lang`) instead of at build
   time. Keep the existing names as the ids; they already describe intent.
2. **Separate the two provenances.** Strings extracted from the binary and
   engine-authored strings (e.g. `[engine] character on disk`, deviation D13) are
   different things and must be catalogued separately, or a translation project will
   inherit copyrighted text without knowing it.
3. **The text grid is fixed and narrow.** 40 columns, 8x8 cells, and several lines
   are positioned by absolute row and a right margin (`right_margin` 0x28 for the
   status block, 0x1d after it). German and Finnish will not fit where English does.
   Layout must be derived from the string, not assumed from the English width.
4. **The font is ASCII-only.** `core/font8x8_basic.h` is asserted to cover
   U+0000..U+007F. Accented Latin needs new glyphs; any non-Latin script needs a
   font and a wider cell model. This is the largest single cost and should be
   scoped before the rest.
5. **Numbers are packed BCD, not text.** HP, FOOD, EXP and GOLD are drawn from
   packed decimal bytes. Locale digit or grouping rules have nowhere to apply until
   that formatting is separated from the storage format.
6. **Do not touch the reconstruction.** The `asm/` tree holds the original inline
   strings because it is a byte-exact reconstruction; it is not the place for a
   language layer. i18n belongs entirely to the engine.

One concrete oddity worth remembering: the original map font has **no Q glyph**
(art `30`, where Q would fall, is a structural tile). Any translation that renders
through map tiles inherits that gap, so a language needing Q must route around it
rather than assume the glyph exists.

---

## TODO: VNC desktop container for remote watching

**Status: parked, and explicitly not blocking.** Recorded because it is genuinely
worth having, not because anything is waiting on it.

**Do not build this to unblock a capture.** Headless input and headless screenshots
already work through Spice86's MCP endpoint — see `tools/spice86_type.py` and
`spice86_start.sh --auto-play` in `docs/spice86-capture.md`. The idea for this
container came out of assuming a capture needed a display, and that assumption was
wrong.

**Amended 2026-10-22:** this is now *more* true, not less. `tools/spice86_screenshot.py`
captures the screen headlessly via the MCP `screenshot` tool, so an agent can see the
game without any display at all — which was the last reason this container seemed urgent.
What it does **not** provide is a human driving interactively. If the owner wants to play
and narrate, that still needs a window somewhere; but no agent task is waiting on it.

**What it is.** A podman container providing a virtual X display plus VNC, so the
owner can watch a live run from anywhere on the LAN, and so the headed-only tools
(`tools/vga_ring.py`, `tools/screenshot_diff.py`, `tools/spice86_keys.py`) become
usable from an agent shell, which currently has no `DISPLAY`, no `WAYLAND_DISPLAY`
and no `Xvfb`.

**Shape.**

| piece | plan |
| --- | --- |
| base image | `docker.io/library/ubuntu:24.04` — already present on `ai` |
| packages | `xvfb x11vnc novnc websockify x11-utils xdotool` |
| display | `Xvfb :99 -screen 0 1024x768x8`; host runs Spice86 with `DISPLAY=127.0.0.1:99` |
| networking | `--network host`, so 6099 (X), 5900 (VNC) and 6080 (noVNC web) land on the host directly |
| viewer | `x11vnc -display :99 -forever -shared -rfbauth` and `websockify 6080 localhost:5900`, browser at `http://ai.lan:6080/vnc.html` |
| X auth | X over TCP needs the server bound to `127.0.0.1` and an explicit `xhost`/`-auth` decision; do not reach for `-ac` |

**Constraints to honour when it gets built.**

1. **`sudo podman` is required on `ai`**, and passwordless sudo must be re-tested
   (`sudo -n echo SUCCESS`) rather than assumed.
2. **`0.0.0.0` exposure needs a password at minimum.** VNC auth over plain HTTP is
   weak; on a LAN it is a judgement call, so make it deliberately and record it, and
   prefer an SSH tunnel (`ssh -L 5900:localhost:5900 ai`) as the default recipe with
   the open listener as the opt-in.
3. **Never put game files in the image.** The container holds a display server only;
   the emulator and its run copy stay on the host under `tmp/`, per the usual rule
   that the game rewrites its own `player`.
4. If it becomes a long-lived service, do it as a **quadlet `.container`** — and
   remember `sudo systemctl daemon-reload` after any unit edit, then stop, `podman
   rm -f`, and start, or the old generated unit is cached and the change silently
   does nothing.
5. Keep it out of the reconstruction's gates. It is a viewing convenience; nothing in
   `make test` or `assemble_clean.sh` should ever depend on it.

## TODO: research the U1 Unity rebuild for transferable findings (opened 2026-10-23, owner-found)

**Target:** <https://u1unity.archiveofmyth.com/> — a fan project rebuilding the **1987 DOS
remake of Ultima I** in Unity, worked on in the open (a devlog with dated per-system entries,
and a GitHub repo referenced as `hoyty1/ultima-unified-engine`). It is not Ultima II, but the
overlap is real and the owner asked for a thorough pass rather than a glance.

**Second lead, unresolved (owner-reported, 2026-10-23).** A post reading *"Build 1.3.2 of the
Ultimate Ultima Engine for your testing pleasure. The last one had some bugs."* — the owner is
not sure it is the same project. Checked while logging this: the GitHub repo the U1 Unity
devlog merges from (`hoyty1/ultima-unified-engine`) returns **404** — private, renamed or
deleted — and no release numbered 1.3.2 appears in the public devlog. **First task of the
research pass: establish whether "Ultimate Ultima Engine" is this author's engine under its
repo name ("Ultima Unified Engine" — the initials match) or a different project entirely.**

**Verified in the meantime.** The same author distributes as **Ultima 1 Unity** on itch
(<https://archiveofmyth.itch.io/ultima-unity>) with a dated devlog of release notes
(<https://archiveofmyth.itch.io/ultima-unity/devlog>). Three entries are directly relevant
here and worth pulling into the research pass:

* *"Added sound effect set from Ultima II, III, and IV"* (2026-09-13) — confirms they parse
  U2 data files, so their format reading is an independent second opinion on something this
  project derived alone.
* *"Monsters will no longer despawn while chasing you around the globe"* (2026-08-09) — U1
  monster pursuit and lifecycle, the same family of question § 16 just settled for U2.
* *"Added Gameplay option for original starvation instant death"* (2026-09-21) — they
  reproduced the starvation edge case this project proved as a BCD underflow
  (`asm/0C62` zeroing, the fresh character dying on the 4001st PASS). If they modelled it as
  a mode toggle rather than a wrap, that is a useful contrast for CP11's enhanced rules.

**Why it is worth the time.** This is the same discipline as this project, applied one game
earlier: they describe pulling apart original DOS binaries, decoding tile and map formats
(**EGA row-planar tiles, nibble-packed overworld maps, column-major town data**), and
decompiling **combat formulas from the original EXE where possible**, with the guesswork
labelled as such. They also state plainly where they approximated — spawn tables "from
observed behavior since the exact original logic isn't fully understood", space behaviour as
"best guess from SPACE.EXE, close but probably not byte-exact". That candour is what makes a
sibling project usable: you can tell their facts from their guesses. They additionally import
**Ultima II art and sound effects**, so they have already decoded some U2 data structures
from the other side.

**What to look for, in priority order.**

1. **Combat formulas and turn structure.** Anything they publish on hit/miss rolls, damage
   rolls, or monster turn logic, even for U1 — the family is close and § 15/§ 16 just
   established that U2's hostility is a provoked state, so a second data point on how these
   games roll is worth having.
2. **U2 asset import paths.** If they document how they read Ultima II tiles or SFX, that is
   a second, independent reading of formats this project decoded from its own bytes — useful
   as corroboration and as a place a mistake could show up.
3. **Format techniques**: row-planar tile decoding, nibble-packed maps, column-major town
   layout. Compare against `docs/map-format.md` and the tile work; a technique that worked
   for them may explain a U2 structure that has been resisting.
4. **Their community-references page.** They credit the Ultima Dragons Discord and community
   docs for sprites, mechanics and quirks. Those sources may hold U2 material of the same
   grade as `bestiary/` — third-party, useful, and not authoritative here.
5. **The itch release notes as a changelog of their reverse-engineering.** The devlog is
   per-system and dated, so it can be mined for statements of fact about formats and
   mechanics, not just feature lists.
6. **Process ideas**: how they structure a public devlog per system, and how they mark
   best-effort reconstructions. This project's equivalent is the `# confidence:` header and
   the evidence grades; worth seeing whether their presentation makes the state easier to
   follow, since the handoff keeps having to explain where the certainty lives.

**Standing cautions, which the isolation and cleanroom rules already cover.**

* **Third-party data is a hypothesis the bytes get to veto** (`AGENTS.md` § 3). Nothing from
  this site promotes into `asm/` or into a claim about this binary without being re-derived
  from `original/` and `captures/` here. Same rule as `bestiary/`.
* **The cleanroom wall is not negotiable.** They hold Ultima II art. Anyone drawing
  substitute tiles must not read this site or anything it links — the only legal input for a
  redraw stays `docs/tile-art-spec.md`. Note this explicitly in the research write-up so the
  next agent does not treat "researched the U1 site" as harmless before an art task.
* **Different game, different binary.** U1's 1987 DOS remake is not U2's 1983 engine;
  conclusions do not transfer, methods do. That is the same boundary
  `docs/harness-portability.md` draws for generic tooling.

**Suggested shape of the deliverable:** one new document, `docs/external-u1-unity.md`, with a
table of claim → what they assert → whether this project's bytes agree → action taken. Empty
is a fine outcome; the point is a recorded pass rather than an unrecorded glance. Do it as its
own session, not as a side trip inside a checkpoint.

## TODO: headless podman container to play the SDL build over noVNC (opened 2026-10-23, owner) — **DONE 2026-10-27**

**Wanted:** the engine's SDL build (`make sdl` -> `u2-sdl`) running headless in a podman
container on `ai`, reachable from a browser over noVNC — the same shape as the Spice86
watching setup, but for *playing our engine* rather than watching the original.

**Do not duplicate the existing section.** `## TODO: VNC desktop container for remote
watching` above already works out the display plumbing (Xvfb, `x11vnc -forever -shared`,
`websockify 6080 -> 5900`, browser at `http://ai.lan:6080/vnc.html`) and the constraints that
apply to any container on this host: `sudo podman` is required and passwordless sudo must be
re-tested rather than assumed, quadlet edits need `systemctl daemon-reload` plus a stop /
`podman rm -f` / start cycle, `0.0.0.0` exposure needs a password at minimum with an SSH
tunnel as the default recipe, and **game files never go in the image** — content is mounted
read-only and passed with `--data-dir`. Read that section first; the delta here is only
"the thing inside the container is our SDL binary, not the emulator".

**What is genuinely new in this one.**

1. **The SDL path is already proven headless.** CP4 asserts
   `headless SDL: dummy driver presents a 320x200 frame` using `SDL_VIDEODRIVER=dummy`, so
   the binary runs with no display at all. That is the right mode for *tests and frame
   capture*, and the wrong mode for a human — `dummy` presents nothing to capture. The
   container therefore needs a real X server (Xvfb) and `SDL_VIDEODRIVER=x11`, with `DISPLAY`
   pointed at it, and `x11vnc` bound to that same display.
2. **Input has to come back.** Watching Spice86 is one-way; playing needs keyboard events
   delivered into the container. noVNC gives that, but it must be wired to the display the
   SDL window is on, and the engine reads keys through `src/platform/input_sdl.c`, so
   focus-follows-mouse and any window-manager surprises inside the container are live
   gameplay bugs, not cosmetics. Budget for that being the part that takes longest.
3. **Audio.** The build has `audio_beep` / `audio_null` / `audio_sdl`; a container with no
   sound server will pick `audio_null` or fail to open a device. Decide deliberately which,
   and record it — silent-by-default is fine for a remote session but should be a choice.
4. **It must stay out of the gates.** Nothing in `make test` or `assemble_clean.sh` may
   depend on the container existing. The CP4 dummy-driver assertion already covers the SDL
   path for CI; this container is a convenience for a human with a browser.
5. **Save state lives on the host.** The engine writes the `player` record into the content
   directory; if that is mounted read-only (as it should be for the original game files) the
   session needs a separate writable path for its save, or `Q` will fail in a confusing way.
   Decide the layout before building, and make the failure legible if the path is not
   writable.

**Suggested shape:** one quadlet `.container` under a project-local directory, image built
from a committed `Containerfile` (engine binary + Xvfb + x11vnc + websockify + a minimal
window manager), content mounted read-only, save path mounted read-write, ports 6080 (and
5900 only if not tunneled). Keep the `Containerfile` and the run recipe in the repo; keep the
game files out of it, per the licensing rules.

## The `--debug-path` segfault: not a code bug, a stale build

Reported and then resolved the same session, so the shape is worth keeping.

`--debug-path` on the SDL build dumped core in `snprintf` inside `main()`. Three
different builds disagreed with each other, which is what made it look like undefined
behaviour. It was not. The tree had a stale `build/gen_content.h`, and the same staleness
was separately making the container fail with `no executable and no cached tiles` — two
symptoms, one cause, and only the second one looked like a build problem.

`make clean` removed both. Clean builds at `-O0`, `-O2` and `-O2 -g` all run and write
their turn files; the container is healthy again with the feature enabled.

What is NOT explained, and is left as a fact rather than a story: the mechanism by which
the stale generated header produced a bad pointer in a `snprintf` argument. The
correlation is solid, the causal chain is not, and if it ever comes back the first thing
to do is `make clean` before believing anything else.

Two self-inflicted traps found on the way, both worth remembering:

- `make ... | head -3` sends SIGPIPE to make and kills the build partway, leaving no
  binary and a confusing `rc=127`. Filter make's output with `grep -v` or read the tail,
  never truncate the pipeline that produces the artefact.
- `gdb -batch -ex run` on an interactive engine hangs forever, because the inferior never
  exits and gdb waits for it to. Always wrap it in `timeout`.
