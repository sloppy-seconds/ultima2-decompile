# Phase 4 Plan — Portable C Engine Reimplementation (asm/ tree is the spec)

Goal: reimplement Ultima II as a **native, portable C engine** that runs on Linux
(no DOSBox), built by reading the byte-proven `asm/` tree. The engine ships
**zero game content**: strings/tables are extracted at build time from the
user's own `ultimaii.exe` (ScummVM posture), keeping `engine/` cleanly Apache-2.0.

Owner decisions baked in (2026-10-20):
* **Language: C** (Rust rewrite remains possible later — engine core stays data +
  pure functions by design).
* **Engine route, not per-function model-C lifting.** Understanding is shared;
  output is a fresh architecture, not 1983's.
* **No differential harness against the original** (Spice86 replay determinism
  judged too costly — RNG reads tick counters, wall-clock animation).
* **Automation designed in from CP0**: headless mode, scripted input, state
  dump; a documented **CLI play contract** on top (CP2) so agents can produce
  playthrough evidence before owner playthroughs.
  *(Amended 2026-10-27: the owner replaced the planned MCP wrapper with the CLI
  contract itself — "we can always implement the mcp any time if we have a good
  contract from the cli". See `engine/docs/playing.md` and §7.)*
* Verification = semantic review against `asm/` + scripted playthroughs +
  **owner playthrough gates at milestones** (the CP6 acceptance model).

> **To start a fresh agent:** paste `docs/phase4-kickoff.md`. Agent maintains
> `docs/phase4-state.md` + `docs/phase4-implementation.md`.

## 0. How to run this plan (resume protocol)

1. Read `AGENTS.md` §0 — hard rules unchanged (isolation, licensing, scratch paths).
2. Read this plan, `disasm/phase3-summary.md`, then `docs/phase4-state.md`.
3. Per checkpoint: steps, Test, objective Acceptance, state update, log section,
   commit `phase4: CP<n> <result>`.
4. Gates (owner stop-and-wait): CP0 (architecture), CP8 (full playthrough),
   CP10 (sign-off).
5. Never commit game content: the extractor reads the user's copy; generated
   headers land in a gitignored `engine/build/` path.

## 1. Reference facts (do not re-derive)

* `asm/` tree: 1299 functions, byte-proven (`tools/check_func.py`), 109 named
  with `# name-evidence:`; `disasm/function-map.tsv` ranges; file = seg + 0x200.
* Seams (the platform API surface): `char_out`, `char_print(_wrap)`, `str_out`,
  `str_out_at`, `str_out_core`, `key_poll`, `cmd_prompt`, `cmd_dispatch`,
  `cmd_done`, `rand_byte`, `timed_wait`, `map_tile_ptr`, `speaker_freq`.
* Known DS globals (from cleaned headers): 0x23/0x24 player x/y, 0x2E/0x2F
  cursor page/col, 0x4A last key, 0x58/0x59 gold BCD pair, 0x63 spell pick,
  0x240/0x243/0x244 tick counters, 0x472 map table base.
* Selfmod cluster seg 0x5120-0x5151: static bytes are NOT the executed logic —
  CP0 includes a one-time capture of the patched bytes (single DOSBox/Spice86
  memory dump, human-assisted; evidence, not a test harness).
* Invariants that stay green throughout: `assemble_all.sh`, `assemble_clean.sh`,
  `check_func` 1299/1299 (the engine never touches these; CI enforces).

## 2. Architecture (CP0 skeleton, then frozen)

```
engine/
  src/core/      vram grid (80x25 char+attr), game state struct, rng, timers
  src/game/      logic modules; each cites its spec: /* spec: asm/15E1 tavern_menu */
  src/platform/  renderer_{term,null,sdl}.c (sdl later), input_{term,script}.c,
                 audio_beep.c, time_posix.c
  src/debug/     --dump-state json, --trace (seam calls + asm address cited)
  tools/extract/ extractor.py: user's ultimaii.exe -> engine/build/gen_*.h
  tools/playlog.py  verify/show/digest a --replay-report transcript
  docs/playing.md   the CLI play contract agents use (replaces the MCP wrapper)
  Makefile       cc only (C11, no deps) for terminal build; SDL2 optional target
```

Hard rules:
* Game logic talks ONLY to `platform/` (renderer/input/audio/time) — never a
  terminal escape or SDL call directly. The seam discipline, carried over.
* Headless (null renderer + script input + stdout screen/state) is a
  first-class build mode from CP0, not a later patch.
* Every logic module header names the asm functions it implements; behavior
  questions are resolved by reading the C next to `asm/<SEG>_*.asm`.
* 16-bit fidelity: state fields `uint8_t/uint16_t`; wraparound matches asm
  (mask where the asm relies on it); BCD counters stay BCD.

## 3. Checkpoints

### CP0 — Skeleton + automation substrate (GATE: architecture)
Platform abstraction with terminal + headless renderers, interactive + script
input, `--dump-state` JSON, `--trace`. Makefile (cc only). One-time selfmod
patched-bytes capture, recorded as a curated note under `disasm/` (raw dump
gitignored).
**Test:** `make && ./u2 --headless --script tests/title.keys --dump-state`
prints a screen grid + JSON, exit 0.
**Acceptance:** owner approves architecture. Commit.

### CP1 — Extractor + title screen
`extractor.py` pulls inline strings + tables from the user's copy (fallback:
parse our own `asm/` db lines) into generated headers. Title/menu flow
(ORIGIN / PROUDLY PRESENTS / ULTIMA II / REVENGE OF THE ENCHANTRESS / 'P' PLAY
/ 'C' CREATE / 'D' DEMO / CHOICE:) driven by extracted strings only.
**Test:** scripted keys reach menu; screen text matches `asm/014B..0375` strings.
**Acceptance:** green test + owner eyeball vs DOSBox screenshot (one-off).

### CP2 — Play contract + evidence (route amended by owner)
Originally "MCP play-API". The owner redirected: the CLI is the contract, and an
MCP wrapper can be added later on top of it if a harness needs one. Substance of
the checkpoint is unchanged — an agent drives the game through a documented
interface only and produces re-verifiable evidence.

`engine/docs/playing.md` documents the contract: `--headless`, `--script`,
`--dump-state`, `--dump-each`, `--trace`, `--seed`, `--replay-report`.
`--replay-report` writes a commit-safe transcript (seed, keys, per-frame
screen/state digests, roll counts, final state — no game text) and
`tools/playlog.py verify` re-runs it and compares every digest.
**Acceptance:** agent-produced playthrough transcript committed under
`engine/evidence/`, and `playlog.py verify` prints REPRODUCES.

### CP3 — Character creation + status line
Stats, sex (`print_sex_*`), `show_hitpoints`, `status_*` lines, food/exp/gold
display (selfmod-adjacent `FOOD=`/`EXP=`/`GOLD=` sites: use CP0 capture).
**Gate:** owner playthrough: create character, correct status bar.

### CP4 — Overworld + movement
`map_tile_ptr` sector model, direction messages, `invalid_move_msg`,
`move_only_on_foot`, terrain encounter rolls (`rand_byte` semantics).
**Gate:** owner walks around a map.

### CP5 — Combat
Combat entry, attack flow (`combat_attack_flow`, hit/miss/kill/exp/gold),
spells (magic missile/sleep), paralysis events, Minax guard text.
**Gate:** owner wins a fight.

### CP6 — Towns + full command set
All 26 `cmd_*` handlers + street NPCs (`street_*`), shops (`shop_header_*`),
tavern (`tavern_*`), cleric (`cleric_*`), `cast_spell_flow`, `offer_*`,
`steal_attempt`, `illegal_command_msg`.
**Gate:** owner plays a full town session.

### CP7 — Time travel + space + dungeons
`show_year_1990/2112` gates, `hyperwarp_flow`, `space_status`,
`space_collision`, `dungeon_darkness`, `dungeon_events`, `plane_landing_site`.
**Gate:** owner reaches 2112 and space.

### CP8 — Endgame + full playthrough (GATE)
Minax arc, `character_dead_msg`, victory. A scripted `play_to` script (grown
from CP2-7 evidence) reaches the end headless; owner then plays a full session.
**Acceptance:** end-to-end completion, agent transcript + owner confirm.

### CP9 — SDL2 CGA renderer
Bitmap CGA font (open-licensed), 16-color palette, 640x200 window; terminal
backend retained. `speaker_freq` -> SDL audio beeps. 0x8d-glyph mapping decided
here.
**Gate:** owner compares vs DOSBox look (one-off eyeball).

### CP10 — Sign-off (GATE)
`disasm/phase4-summary.md`: coverage (asm functions implemented vs engine
modules), honest limits (unverified corners, selfmod interpretation), tag
`v4-engine`. **Stop and wait.**

## 4. Global acceptance

1. `engine/` builds with cc on Linux; zero game content committed.
2. Full game completable natively (owner-confirmed) + via scripted playthrough.
3. Every engine module cites its asm spec; review lines logged per milestone.
4. Phase 3 invariants still green at every checkpoint (CI).
5. Play contract used as evidence at CP2 and CP8 (MCP wrapper optional, added
   only if a harness needs it).

## 5. Known limits to record, not hide

* Behavioral fidelity is argued + played, not byte-proven; the asm tree remains
  the only proven artifact. Stated in the engine README.
* Selfmod cluster semantics depend on a one-time runtime capture; if the
  capture is wrong, that subsystem is wrong (flagged in code).
* CGA authenticity (glyphs, colors) is best-effort from open fonts.
* Sound/timing feel (speaker beeps, delays) approximated.

## 6. Stop-and-ask

Gates (CP0, CP8, CP10); any need for new system packages (SDL2 install = ask);
game-content questions (anything that would commit extracted strings/tables);
blockers after two recovery attempts; scope changes.

## 7. Amendments during execution (evidence-backed corrections to this plan)

Facts stated in §1/§2 that later reading proved wrong, with the evidence that
settled each one. Kept here so a fresh agent does not re-derive or re-trust them.

| plan claim | what the bytes say | evidence |
| --- | --- | --- |
| §1 selfmod cluster `0x5120..0x5151` is runtime-patched; CP0 must capture patched bytes | not patched: 44 of 50 bytes observed as executed across 44 runtime captures, zero differing from the static image; the 6 unobserved are the inline string at `0x5136`. The Phase 1/2 verdict was a static mis-decode | `disasm/selfmod-capture.md`, `tools/selfmod_scan.py` |
| §1 `DS:0x2E/0x2F` = "cursor page/col" | `0x2E` = **column**, `0x2F` = **row** (`mov 0x2f,%dh` / `mov 0x2e,%dl`, BH=0 before INT 10h AH=02h) | `asm/51FD_str_out_core.asm` |
| §2 "vram grid (80x25 char+attr)" | the text grid is **40x25**: row clear prints 40 spaces, margins 0x26/0x28, scroll window 0..margin, video mode 4 = 320x200 | `asm/53A0`, `asm/456B`, `asm/48A7`, `asm/4A2F`, `asm/5025`, `asm/4A3E` |
| §1 `key_poll` is a non-blocking probe | it probes **and consumes** (INT 16h AH=01h then AH=00h), folds control bytes, and upper-cases `a-z`; AH=0xFF means "a key was consumed" | `asm/4F4D..4FDE` (Phase 3 split it mid-routine) |
| §1 `0x240/0x243/0x244` are "tick counters" feeding `rand_byte` | they are a six-byte **feedback shift register** at `DS:0x23F..0x244`, seeded once at launch from BIOS `0x40:6C`; nothing else writes them and no clock is involved | `asm/5217` + `asm/522B` + `asm/5236` read whole, `asm/0100_sub_0100.asm`, vectors in `engine/tests/run_cp0.sh` |
| §2/CP2 "MCP play-API (python)" | the CLI is the contract; an MCP wrapper is optional sugar added later only if a harness needs one | owner decision 2026-10-27, `engine/docs/playing.md` |

Two consequences worth stating plainly:

* **Determinism is a property of the game, not of the test harness.** Because the
  PRNG is a seeded shift register and no game logic reads a clock, a key script
  plus a seed reproduces a run exactly — encounters, combat rolls and monster
  spawns included. That is what makes the CP2 report verifiable and will make
  CP8's end-to-end playthrough checkable rather than eyeballed.
* **Standing rule for the rest of Phase 4:** game logic never reads the clock;
  only presentation delays may. If that is broken, replay evidence stops being
  sound and §7 needs a new entry.
