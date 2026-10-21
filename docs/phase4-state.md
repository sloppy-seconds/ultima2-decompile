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
| CP11 | Mod surface + original/enhanced modes (owner-scheduled, deferred from CP3) | not started | two modes, sparse-diff overrides, content + rules surfaces, mandatory provenance; save-record layout non-overridable; no `.pat` reimplementation. Needs owner input on what existing U2 mods actually patch | |
| CP4 | Overworld + movement | **in-progress (CP4b overnight: T1,T3,T4,T6,T7,T8 done/passed; T2 half; T5 held)** | kickoff § 2 items 1 and 2 **settled from the bytes**: the name is `MAPX` + two digits self-patched into the code stream (`asm/2290`, file `0x24b7`), and a tile is **one byte** in a **64x64** sector read with `AH=27h, CX=0x1000` into `[DS:0x472]` (`asm/50B3_map_tile_ptr.asm`). New finding: `asm/2305` **writes the sector back**, so world content is mutable. EGA question answered: `original/updated/` is the Exodus Project upgrade and EGA is a **separate binary** (`U2EGA.EXE`), so the accommodation is a tile-ID seam plus data-driven naming, not a mode flag. Direction keys are **arrows**, proven via a scancode table at `CS:0x4F09`. Movement is proven: arrows via a scancode table at `CS:0x4F09`, direction codes as data at `DS:26E..271`, a rejected step is undone before `--INVALID MOVE!`, and crossing x/y >= 64 reloads the sector (`asm/242D`/`2434`/`243E`) rather than straddling. **Viewport now measured from owner screenshots**: tile = 16x16 px = 2x2 text cells, window 20x10 tiles at rows 0-19 full width, player at window tile (9,5), row 24 blank. Dungeons are first-person 3D, so the tile renderer does not cover them (CP7). **CP4b overnight (2026-10-21):** the passability premise was disproven — `asm/2423` never reads a tile, so on-foot walking is never rejected on the overworld (T1 PASSED, write-up in implementation log § CP4b); tile IDs decoded (0=water,4=land,8=plane,0x78=player); sector crossing is the `DS:6E` arrival system, not a foot step. T3/T4/T6 fixed one root-cause class (loops testing `exit_code` but not `input_exhausted`): window-close, SIGTERM, and dummy-driver `--dump-screen` all now stop cleanly. T2 shipped the proven half (PASS spends 10 food, underflow zeroes DS:51..59 = instant death; no gradual HP drain, no per-step tick — the walk loop calls no drain). T7 screenshot differential harness landed (status-block only, poison-checked). T5 held for owner: it moves the CP2 baseline and its pre-approval flag is unresolved. Full detail: `docs/phase4-overnight-cp4b.md § Morning report` | 2026-10-21 |
| CP5 | Combat | **scoped, not started** | Tickets C1..C7 in § CP5 below. Evidence base is the 2026-10-21 sector-00 caster session: commits `b11bfc6`, `1d7bae3`, `341952d`, `49d8365` and `docs/spice86-live-findings.md` § 12. Nothing may be written before C1/C2, and C5 is **blocked on a capture** because a required input is still unproven. C7 is resolved. | 2026-10-21 |
| CP6 | Towns + full command set | todo | | |
| CP7 | Time travel + space + dungeons | **partly informed 2026-10-21** | Dungeons are sectors, not a separate format: entering a cave moved `DS:49/4A` from `3,0` to `3,5` and loaded `mapx35`, with no video mode change (stays CGA mode 4). Rendered as a first-person wireframe. Light is a **step counter** at `DS:26`, zeroed on entry, ~150 on `I`, decremented per move, and `mapx25`/`35`/`45` are byte-identical. Command dispatch is mode-aware: `A` is ATTACK outside and ADVANCE inside. Full detail: `docs/spice86-live-findings.md` § 13. | 2026-10-21 |
| CP8 | Endgame + full playthrough 🔒 | todo | | |
| CP9 | SDL2 CGA renderer | todo | needs owner approval for system packages | |
| CP10 | Sign-off 🔒 | todo | | |

## Resume notes (read this first after a compaction)

- **2026-10-21 correction to the T2 closure.** T2 recorded "no `INT 1Ah` exists
  in the corpus". That was true of the decoded `asm/` tree and **false of the
  binary**: `CD 1A` occurs at file `0x8AE`, `0x8C0`, `0x8CE` and `0x8FD0`
  (runtime `0x6AE`, `0x6C0`, `0x6CE`, `0x8DD0`). The auto-PASS conclusion is not
  automatically wrong — those sites still have to be shown reachable from the
  PASS path — but the evidence cited for it does not hold as written, so T2 is
  downgraded from closed to **re-open, needs re-proof**. Same lesson as F6: a
  negative result from a probe over a partially decoded tree is not a negative
  result about the binary.

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

- **Read `docs/handoff-live-capture.md` first.** Rewritten 2026-10-21 evening for
  a fresh context: running state (nothing running, tree clean, CI green, how to
  push with `GH_TOKEN`), the true T1–T9 status, what is proven and must not be
  re-derived, the tool inventory with tested-vs-untested marked, and the standing
  rules that cost time. Next step per the owner is **working through the overnight
  task results** — close T1's two named unknowns (mountain tile id, the
  `DS:15`/`DS:18` travel-mode argument), then T9. The CP4b T1 finding and part of
  T2 were **retracted** the same day — see
  `docs/phase4-implementation.md § CP4b → RETRACTION` and
  `docs/spice86-live-findings.md`.

- **CP4 is mid-flight and everything is committed. To take over, paste
  `docs/phase4-kickoff-cp4b.md` to a fresh agent — it is the current handoff and
  supersedes the notes below on what to do next.** The headline it must not miss:
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

**Overnight queue armed 2026-10-21:** `docs/phase4-overnight-cp5.md` is a
owner-independent task queue (T1..T10) and `docs/phase4-overnight-cp5-prompt.md` is the
text to paste to a fresh agent to run it. Nothing in it needs the owner; anything that
would has been left out rather than approximated. Results land in
`docs/phase4-overnight-cp5-report.md`.

**CP4 — overworld + movement.** Start a fresh session from
`docs/phase4-kickoff-cp4.md`, which records the one decision that shapes the
whole checkpoint: the map is **runtime data** (`original/mapxNN`, ~30 files of
exactly 4224 bytes each), not something the extractor pulls into code, so CP4
adds a `--data-dir` seam and reads the player's own files the way the original
 did. It also lists the four questions to settle before writing any rendering.

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
| Are the status pairs (HP/FOOD/EXP/GOLD) binary little-endian or packed decimal? | **open question, needs the owner's eyes at the CP3 gate.** `asm/5400` stores plain `4` into `[0x51]`/`[0x53]`/`[0x58]`; read as BCD-hundreds-first that is 400, read as binary it is 4. HP=400 for a fresh character is absurd, so `game/status.c` formats them as binary — but `--dump-state` still prints gold through `u2_bcd16()` and reports 400, so the two disagree until this is settled | `engine/src/game/status.h` OPEN QUESTION, `engine/src/core/state.h` gold comment |
| After creation the engine returns to the title menu, which redraws over the status block | **known gap** — the owner cannot see the status bar at the gate until CP4 gives it a permanent home, or the flow pauses on a key first | `engine/src/game/creation.c` tail |
| `][` glyph mapping ("II") | deferred to CP9 (SDL2 font decision) | `engine/README.md` § Known limits |
| PIC picture files during the intro | deferred to CP9 (no bitmap pipeline before then) | `engine/src/game/title.c` header |
| Live (non-replay) play API / MCP wrapper | optional, build only if a harness needs it; the CLI contract is the substrate | `docs/phase4-plan.md` §7 |

## Backlog

- [ ] **Decode the dungeon map format and reproduce the wireframe renderer.** This is
      the largest unexplained surface in the game and it blocks any real dungeon crawl.
      Not solved here on purpose; these are leads measured on 2026-10-21 so the next
      session starts from evidence rather than from a blank page.

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

- [ ] **Four-question Spice86 capture — passability, the art transform, food on a
      rejected step, and the mountain tile.** Owner must walk; reads are passive.
      Full spec in `docs/passability-findings.md § Open`. In one session in sector
      20: (1) dump the staging buffer at `DS:272` against the sector map to settle
      whether `art = map_byte >> 1` or `>> 2` — `engine/src/core/view.h` currently
      claims both and they are mutually exclusive; (2) break at runtime `0x2423`
      and dump `AL, DS:13, DS:15, DS:18, DS:29, DS:2CB, DS:2DE` plus the
      destination tile on one accepted and one rejected step, which proves or
      kills the F8 claim that the ladder's input is the tile byte; (3) read
      `DS:53..55` before and after a deliberately blocked step to find out whether
      a rejected move costs 19 food, which the block ordering implies but does not
      prove; (4) **stand next to a visible mountain, walk into it, and read the
      destination tile byte** — this settles F9, where the engine currently marks
      `0x08` passable while F8 calls it the mountain, and it would be the first
      honest measurement of a blocked tile other than water.

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

## CP5 — combat tickets (scoped 2026-10-21, not started)

Scope rule for this checkpoint: **no stubs.** A stub for "resist paralysis" encodes
boolean immunity, passes the tests that do not exist yet, and looks finished. Every
ticket below is either a proven behaviour with a byte citation, or an explicitly
named unknown. Where the input is unproven the ticket is `blocked`, not guessed.

Full evidence: `docs/spice86-live-findings.md` § 12, and the function headers in
`asm/` for `0AAA`, `0AD3`, `0E70`, `0EC2`, `0F12`, `0F48`, `0FCD`, `24B5`, `2FAD`.

| ID | Ticket | Status | Why |
| --- | --- | --- | --- |
| C1 | Three independent status counters as persistent state: legs `DS:26B`, arms `DS:26C`, sleep `DS:26D`, each set to `rand & 0xF` (0..15 turns) and stored in the player record | todo | `asm/0E70`, `asm/0EC2`, `asm/0F48`. Arms and legs are separate counters with separate items, so a character can be paralysed in one and free in the other; both were observed non-zero simultaneously (9 and 8) alongside sleep 8. |
| C2 | Resist is a **~75% roll on a live item-array slot**, not immunity: `[DS:D9]` BOOTS, `[DS:DA]` CLOAK, `[DS:E4]` GREEN IDOL; with the item the `L_005417` roll must be `>= 0x40`, without it the effect lands with **no roll at all** | todo | This is the single easiest thing to get wrong, and the pre-existing docs had it wrong as a boolean gate. Needs a distribution test, not a present/absent test. |
| C3 | Paralysis is a **movement rejection**, not a combat overlay | todo | `--PARALIZED!` is at runtime `0x2527`, inside the passability routine, so a paralysed step takes the same reject path as walking into a mountain. Couples to the CP4 passability work and to the `--INVALID MOVE!` path. |
| C4 | Magic missile: **no save path exists** | todo | `asm/0F12` has no inventory gate and no roll, unlike the other three. The accumulation into `DS:20/21/22` is proven (`+2, +2, +0x40` per cast) but its BCD weight against the HP subtract is **not** — model the no-save property, leave the scaling as a named unknown. |
| C5 | Force field: ring gate `[DS:D6]`, exactly **-1000** via `stc; sbb al,0x10; das` on `[DS:51]`, and a death branch when HP < 1000 | **blocked** | `asm/24B5`. Damage, gate and death branch are proven and both branches have executed. But **the tile byte that triggers the field is unknown**, and so is what drives its animated render. Cannot be wired to a tile until a capture names the byte. |
| C6 | Theft **deletes** from the item array; killing the thief restores nothing | todo | `asm/0FCD`, thief is monster type `0x40`. Measured: 8 items stolen, 0 returned, kill paid a random drop like any other. Because the C2 gates read the item array live, a flagged-but-present item would wrongly keep the resist. |
| C7 | Map byte -> vehicle code transform for BOARD | **resolved 2026-10-21** | `[DS:14] = map_byte >> 1`, measured on 53 of 54 walk samples across four terrain bytes. So vehicle tiles are `0x44` horse, `0x48` ship, `0x4C` plane, `0x50` rocket. Confirmed by the game: `B` on a `0x4C` tile set `[DS:13] = 0x26` and printed `' PLANE'`. An earlier note here claimed the plane was `0x34`; that was a `%02d`-against-hex-filenames render bug and `0x34` is art `0x0D`, a humanoid figure. ~~Still unexplained: the `y*16 + x` indexing at file `0x6AC0` against a 64-wide grid.~~ **Resolved 2026-10-22 (overnight T7):** `asm/68C0` indexes the **dungeon** grid (`word[DS:472] + [DS:25]*256 + y*16 + x`, a 16-wide paged view of the DS:1800 buffer), not the overworld sector grid; reached only from the dungeon path. See `docs/spice86-live-findings.md § 12`. |

One design constraint that outlives the checkpoint: the original keeps **two** copies
of some item counts and one goes stale. `DS:6D` still read 1 after a thief stole the
boots, while the live gate `DS:D9` correctly went to 0. The engine needs a single
source of truth for item counts, and any resist check must read it rather than a
cached boolean.

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
