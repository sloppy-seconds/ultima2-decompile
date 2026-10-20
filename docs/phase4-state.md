# Phase 4 State — checkpoint table

Plan: `docs/phase4-plan.md`. Log: `docs/phase4-implementation.md`.
Kickoff: `docs/phase4-kickoff.md`.
Statuses: todo | in-progress | done | blocked | awaiting-gate

| CP | Title | Status | Notes | Date |
| --- | --- | --- | --- | --- |
| CP0 | Skeleton + automation substrate 🔒 | done (owner approved 2026-10-27) | `engine/` builds with cc only; term + null renderers, term + script input, beep + null audio, posix + script clocks; seam layer with asm-cited `--trace`; `--dump-state` screen grid + JSON; `make test` PASS incl. reproducibility; selfmod question resolved from 45 existing runtime captures (`disasm/selfmod-capture.md`) — cluster is not patched, CP3 unblocked | 2026-10-27 |
| CP1 | Extractor + title screen 🔒 | **awaiting-gate (owner eyeball vs DOSBox)** | `tools/extract/extractor.py` (exe source + asm db-line fallback + `--check`/`--emit text`); `game/title.c` = intro, title, menu, 'D' poem, CP3/CP4 stubs; `make test` = CP0 9/9 + CP1 9/9; **architecture correction: the grid is 40x25, not 80x25** (evidence in `engine/README.md`); `--selftest` keeps the CP0 substrate probe testable | 2026-10-27 |
| CP2 | MCP play-API | todo | | |
| CP3 | Character creation + status line | todo | selfmod capture dependency removed — see `disasm/selfmod-capture.md` | |
| CP4 | Overworld + movement | todo | | |
| CP5 | Combat | todo | | |
| CP6 | Towns + full command set | todo | | |
| CP7 | Time travel + space + dungeons | todo | | |
| CP8 | Endgame + full playthrough 🔒 | todo | | |
| CP9 | SDL2 CGA renderer | todo | needs owner approval for system packages | |
| CP10 | Sign-off 🔒 | todo | | |

## Gate log

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

## Invariants (checked at every checkpoint)

| Check | Command | CP0 result |
| --- | --- | --- |
| Per-function byte proof | `python3 tools/check_func.py <SEG>` | 1299/1299 green (sample re-run + CI) |
| Mechanical rebuild | `bash tools/assemble_all.sh` | byte-identical |
| Clean-tree rebuild | `bash tools/assemble_clean.sh` | 1299/1299 cleaned, 37,344 B identical |
| Original untouched | md5 `fe884d5117971073ac8097cc7a6aca25` | unchanged |
| Engine test | `make -C engine test` | CP0 9/9 PASS, CP1 10/10 PASS |
