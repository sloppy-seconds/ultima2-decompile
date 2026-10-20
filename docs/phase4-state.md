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
| CP4 | Overworld + movement | todo | | |
| CP5 | Combat | todo | | |
| CP6 | Towns + full command set | todo | | |
| CP7 | Time travel + space + dungeons | todo | | |
| CP8 | Endgame + full playthrough 🔒 | todo | | |
| CP9 | SDL2 CGA renderer | todo | needs owner approval for system packages | |
| CP10 | Sign-off 🔒 | todo | | |

## Resume notes (read this first after a compaction)

- **Everything is committed.** Working tree clean at `de68eb9`. No in-flight edits.
- **All suites green**: CP0 0.04s, CP1 0.12s, CP2 0.32s, CP3 4.41s (~4.9s total,
  measured 2026-10-27). CP3's cost is two `sleep 1` waits in the pty tests, which
  pace the intro-skip apart from the body because a key burst is swallowed by the
  intro's key-holds. Ctrl-Q **is** passed and **does** terminate the runs.
- **Phase 3 invariants green**: `make test` runs them (clean rebuild byte-match
  37344 B, `original/` md5, `asm/` untouched).
- **Open for the owner at the CP3 gate**:
  1. Whether HP/FOOD/GOLD are binary or packed decimal — `status.c` says binary,
     `--dump-state` says BCD and reports gold 400. They disagree; flagged, not
     guessed. See `engine/src/game/status.h` OPEN QUESTION.
  2. Whether the CP2 evidence baseline should keep being regenerated in place or
     frozen with new files per checkpoint. It has moved three times, each
     deliberately and each recorded in the gate log.
  3. Play the form: `make play`, press `C`. Confirm Tab/arrows, re-editing, and
     that the field positions look right against the original.
- **Not yet done**: the CP11 cheap accommodations (constant registry, accessor
  reads, random-creation seam), and the branch audit as a standing gate rule is
  written in `docs/phase4-acceptance.md` but not yet applied retroactively to
  CP1/CP2.

## Gate log

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
| Persist the PRNG seed/state for replayable saves | **rejected for the save file by owner** — engine saves stay byte-compatible with the original player record (256 bytes at `DS:36..135`), which does not store `DS:0x23F..0x244`. A sidecar meta file is the only fallback, and only with a strong reason. Revisit when CP3's save work lands | this section, and `docs/phase4-implementation.md` § CP3 |
| Exact saved span and write path of the player record | **RESOLVED at CP2.5** — FCB random read/write (AH=27h/28h) via the `asm/52CA` DOS wrapper, 256 bytes at `DS:36..135`, FCB name `PLAYER  ` | `docs/phase4-implementation.md` § CP2.5 |
| What the 128-byte tail of the 384-byte player file is (one non-zero byte, `0x1a` at offset 256) | **open question** — no write path found; do not guess | `docs/phase4-implementation.md` § CP2.5 |
| Are the status pairs (HP/FOOD/EXP/GOLD) binary little-endian or packed decimal? | **open question, needs the owner's eyes at the CP3 gate.** `asm/5400` stores plain `4` into `[0x51]`/`[0x53]`/`[0x58]`; read as BCD-hundreds-first that is 400, read as binary it is 4. HP=400 for a fresh character is absurd, so `game/status.c` formats them as binary — but `--dump-state` still prints gold through `u2_bcd16()` and reports 400, so the two disagree until this is settled | `engine/src/game/status.h` OPEN QUESTION, `engine/src/core/state.h` gold comment |
| After creation the engine returns to the title menu, which redraws over the status block | **known gap** — the owner cannot see the status bar at the gate until CP4 gives it a permanent home, or the flow pauses on a key first | `engine/src/game/creation.c` tail |
| `][` glyph mapping ("II") | deferred to CP9 (SDL2 font decision) | `engine/README.md` § Known limits |
| PIC picture files during the intro | deferred to CP9 (no bitmap pipeline before then) | `engine/src/game/title.c` header |
| Live (non-replay) play API / MCP wrapper | optional, build only if a harness needs it; the CLI contract is the substrate | `docs/phase4-plan.md` §7 |

## Invariants (checked at every checkpoint)

| Check | Command | CP0 result |
| --- | --- | --- |
| Per-function byte proof | `python3 tools/check_func.py <SEG>` | 1299/1299 green (sample re-run + CI) |
| Mechanical rebuild | `bash tools/assemble_all.sh` | byte-identical |
| Clean-tree rebuild | `bash tools/assemble_clean.sh` | 1299/1299 cleaned, 37,344 B identical |
| Original untouched | md5 `fe884d5117971073ac8097cc7a6aca25` | unchanged |
| Engine test | `make -C engine test` | CP0 11/11, CP1 9/9, CP2 12/12 PASS |
