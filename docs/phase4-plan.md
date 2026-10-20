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

#### CP3 design — the save/disk model (owner-approved 2026-10-27)

The original asks the player to insert a disk to save onto. The engine cannot
hand back a physical floppy, and must not become unplayable because of one. The
model below is faithful where it can be and pragmatic where it must be.

**How the original actually works.** All disk I/O goes through the DOS wrapper
at `asm/52CA`, which takes the DOS function number in AH from its caller (which
is why a scan of every `int 21h` site shows no write function — the numbers are
dynamic). Player I/O is FCB random access: AH=27h read, AH=28h write, CX=0x100,
DX=0x36, with the FCB name `PLAYER  ` copied out of the caller's own code
stream. The wrapper validates the drive with AH=0Fh; on failure it prints its
inline `(INSERT ... DISK)` prompt, waits for ESC and retries forever. The FCB
drive byte is 0 — the **default drive** — so the game plays in whatever
directory it was launched from. There is no disk-swap API; the retry loop *is*
the disk-swap experience.

| concern | engine behaviour | why |
| --- | --- | --- |
| save location | `--save-dir DIR`, default `./saves`, created on demand | maps the original's "default drive" onto a directory |
| file name | `PLAYER`, no extension | matches the FCB name, so a real DOSBox save drops straight in |
| missing file | seed from the blank template: 384 bytes, all zero except `0x1a` at `0x100` | byte-identical to the pristine shipped disk; and `DS:36 == 0` is the original's own "generate a character" test, so faithful and pragmatic are the same path |
| what gets written | only the 256 record bytes at `DS:36..135`; the 128-byte tail is preserved | keeps saves interchangeable in both directions |
| unusable path | `U2_SAVE_NOT_READY` -> show the INSERT prompt and wait | the honest analogue of a drive that is not ready; the engine never invents a place to write |
| `(INSERT GALACTIC DISK)` | **deliberate deviation**: all world content comes from the user's extracted copy at startup, so there is no second disk to swap | documented, not faked; the prompt becomes unreachable |
| quicksaves / slots | **not now.** They are a filename layer over this same record format (`PLAYER.01`, `autosave`), so they need no format change and no migration | owner wants modern management eventually, faithfulness first |

**Consequences that are already binding:** `rng_state` stays out of the save
(owner decision, § Deferred decisions in the state file), and the 128-byte tail
whose meaning is still an open question is reproduced verbatim rather than
interpreted.

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

### CP11 — Mod surface and the two game modes (owner-directed, scheduled 2026-10-27)

**Deferred out of CP3 by owner instruction** ("do the modding stuff where it makes
sense, now or later is fine"), recorded here so it is a scheduled checkpoint and
not folklore. Motivation, from the owner: people enjoy moddable games, and
Ultima II already has a modding community that patches the **original binary**
(a `.pat` patch format plus a patcher program). That is the demand signal.

The design agreed in conversation:

* **Two modes.** `--mode original` (default) is the faithful engine with **no
  knobs at all**; `--mode enhanced` is where customisation lives. This is what
  answers the obvious objection to tweakable constants: in `original` mode a
  number cannot be edited, so the reconstruction stays provably faithful.
* **Overrides are sparse diffs, never full replacements.** Anything absent keeps
  the original value, so the file stays short, reviewable, and does not drift on
  every re-extraction.
* **Two surfaces.** *Content* (strings, tables, maps, monster/town data) and
  *rules* (budget, stat minimums, bonuses, later encounter rates). Content is
  the one the existing extractor already half-provides.
* **Precedence, explicit and boring:** built-in defaults (original values, cited
  to `asm/`) -> content extracted from the user's own copy -> mod pack ->
  personal override file. Later wins; every layer sparse.
* **Provenance is mandatory.** `--dump-config` prints each effective value with
  the layer that set it and `file:line`. Third-party packs make this a support
  requirement, not a nicety.
* **Mod packs are directories with a manifest**, so they can be shared, versioned
  and broken cleanly. No new archive format, no parser dependency.
* **Format is `key=value` with sections**, not JSON/YAML: the engine's rule is
  *cc only, zero dependencies*.

**Hard constraints, which survive the whole design:**

1. **The 256-byte save record layout is not overridable, even in enhanced mode.**
   Overrides change rules, not the record structure. Byte-compatibility with the
   original's `PLAYER` file is what makes this engine useful to anyone who
   already mods the original; enhanced-only persisted state goes in the deferred
   sidecar, never into the record.
2. **We do not reimplement `.pat`.** It is address-based over a binary we
   deliberately do not embed, and `AGENTS.md` already records that our copy may
   carry community patches — patching by address into a binary whose patch level
   cannot be determined is the failure mode we are escaping, not reproducing.
3. **No game content is committed.** Mods are user-supplied, under the same rule
   as the game copy itself.

**Cheap accommodations to land before CP11**, each of which is better code
regardless of whether enhanced mode ever ships:

* Collect the tunable binary facts into **one registry** with default + citation
  each (today they are spread through `game/creation.c`), so the later loader has
  a single thing to read.
* Route reads through an accessor with the default inline, so `original` mode has
  zero runtime difference.
* **Random character creation** is the first enhanced feature to want this. Keep
  stat *acquisition* separate from stat *validation* so a roller is additive; the
  constraint it must satisfy is small (six packed-BCD values, each >= 10, summing
  to <= 90).

**Open input needed from the owner:** whether existing U2 mods mostly patch text,
tables, or code. That answer decides which surface gets built first. It must come
from the owner or from public research — **not** from the sibling `../ultima2`
checkout, which is off limits under §0 and must not become a source of conclusions
we present as our own.

## 4a. Fidelity policy — what "faithful" permits (owner decision 2026-10-27)

The engine reproduces the original's **rules and state** exactly, and improves
its **interaction** where the original was genuinely frustrating. Owner's
framing: aim for the *spirit* of the game; small UX improvements belong in
`original` mode, not behind a mode flag.

The line, stated so it can be applied consistently:

| change | allowed in `original` mode? | why |
| --- | --- | --- |
| cursor visibility, field navigation (Tab/arrows), backspace that edits rather than wipes | **yes** | interaction only; no game state or outcome changes |
| refusing invalid input in place instead of restarting the whole form | **yes** | the original's `asm/5C66` rejection jumps back to `0x5698` and discards everything. Refusing in place changes the *pain*, not what is achievable |
| a quit key; clearer error text | **yes** | the original has no quit path at all, which is a defect rather than a design |
| stat values, bonuses, budget, minimums, encounter rates, damage, gold, XP | **no — enhanced mode** | these are the game; changing them changes play |
| the 256-byte save record layout | **never, in either mode** | byte-compatibility with the original's `PLAYER` file is what makes DOSBox saves work both ways |
| extracted content (strings, tables, maps) | **no** | content is the user's copy, surfaced by the extractor |

Two consequences worth stating:

1. **Behavioural fidelity claims must be scoped.** When this project says an
   engine module is faithful it means its *rules and state* match the asm, not
   that every interaction is identical. Interaction deviations are listed below
   with the reason.
2. **The asm is still the spec for what a change may touch.** A UX improvement may
   not silently alter what is written to `DS` or to disk. `asm/` remains ground
   truth for state; it simply stops being the spec for keystroke handling.

### Deviation register (interaction changes made deliberately)

| # | original behaviour | engine behaviour | reason |
| --- | --- | --- | --- |
| D1 | Creation is strictly sequential; no way back | Tab / Up / Down move between fields; any field can be re-edited | the form is the most-repeated input in the game and could not be corrected without restarting it |
| D2 | Backspace in the name field wipes and restarts the whole field (`asm/5BA5`) | Backspace deletes one character | matches every other input surface players know |
| D3 | A stat below the minimum, or an overspend, discards the entire generation and restarts at `asm/5698` | The entry is refused in place and the field re-asked | same outcome set, none of the lost work |
| D4 | No visible cursor during creation | Cursor shown on the active field | without it there is no indication which field is being filled |
| D5 | No quit key; `'Q'` in the command set is "QUIT OR SAVE GAME." (string at file `0x3FCA`) and it saved rather than exiting, because on a real machine you swapped disks or powered off | **Ctrl-Q quits** from any screen; **`Q` saves** once the in-game command loop exists (CP4), keeping the original's meaning | there is no disk to swap, so a clean quit is a gap rather than a deviation. Ctrl-Q rather than Ctrl-C because Ctrl-C is a signal the terminal owns and a harness cannot always deliver; note raw mode must clear `IXON` or Ctrl-Q is swallowed as XON |
| D6 | The first typed digit of a stat fills the tens place, so `5` means 50 and the field advances immediately (`asm/53B0`) | Two-digit shift register: the field shows its current value, `5` reads `05`, a following `0` reads `50`, backspace returns the stat to its minimum | a player who means 5 does not mean 50; the original's own minimum of 10 (`asm/5C69`) makes `05` an illegal transient, which is handled at completion rather than mid-keystroke |
| D7 | An overspend is impossible to see: it throws the generation away (`asm/5C66` -> `asm/5698`) | The budget is a running total that may go negative while editing; the character simply cannot be saved until it lands on exactly 00 | watching a total move is how a player budgets the remaining points; forbidding the intermediate state is what made the original punish exploration |
| D8 | Every typed byte has its high bit masked off (`asm/5207` `and al,$0x7f`) and everything else is stored, control characters included | The mask is reproduced; control characters are refused in the name | a BEL or ESC in a name renders as garbage and cannot be typed usefully. The name cap of 12 is **not** relaxed: `asm/5BB7` `cmp bl,$0xc` stops input at 12, not at the 16-byte field width, so a full name leaves the same 4 pad bytes the original writes |
| D9 | The confirm line reads `SATISFACTORY (Y/N)-` (`asm/5B6E`, in the form blob) and `N` restarts the whole generation from scratch (`asm/5BD5` -> `asm/5698`) | The line reads `[S]AVE / [R]ESET` and is a pair of fields you Tab to and press Enter on | "not satisfactory" is not an instruction a player can guess and does not say what happens next. Deliberately **not** hotkeys: as `r`/`R` shortcuts they fired the moment anyone typed the name BRITISH. This is the one place the engine overwrites an extracted game string, so it paints over row 16 rather than editing the blob |
| D10 | Every stat starts at 0 and the player builds all 90 points | Every stat starts at 10, the enforced minimum, and the player distributes the 30 left over | same solution set as "90 total, each at least 10", but an illegal value now takes deliberate effort instead of a careless keystroke |
| D11 | No way out of character creation short of finishing it | ESC abandons creation and returns to the title menu | the form is long and there was no reason to be trapped in it; nothing is written to disk until `[S]AVE` is activated |
| D12 | The demonstration, once started, cannot be left | ESC returns to the title menu, checked at block boundaries rather than mid-couplet | a wall of text with no exit is not a demonstration; the picture slideshow that gives it a natural ending is CP9 |
| D13 | Loading a character goes straight into the world and offers only the status block as confirmation | The `P` placeholder prints the record that was read back (name, sex, race, class, six stats as stored) above the CP4 notice | until there is a world to load into, the point of `P` is visual proof that the bytes `[S]AVE` wrote came back, not an implied round trip |

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
* **The fan EGA upgrade is a different binary, not a mode of ours.**
  `original/updated/` is *The Exodus Project: Ultima II Upgrade 1.1*, and
  `Files.txt` lists `U2EGA.EXE` as "EGA Game Binary & tiles". Our `ultimaii.exe`
  has no EGA register programming, no `MAPG` string and only ever sets video mode
  4, so a faithful EGA mode would be a second reconstruction pass over that
  binary, not a flag on this one. What CP4 does protect is the cheap part: the
  tile **ID** grid is mode-independent (`MAPG44` is byte-identical to `mapx44`),
  so art, naming and geometry are kept as data behind the renderer seam. Details
  and the three adopted accommodations in `docs/phase4-implementation.md` § CP4.

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
| CP3 "status pairs may be binary little-endian" (the reading `status.c` shipped with until the owner looked at the original) | HP / FOOD / EXP / GOLD are **4-digit packed decimal**, most-significant-pair-first: `asm/55B5` emits a byte as its two nibbles OR'd with `'0'` with no zero suppression, and `asm/53A5` calls it on the low address then the high address. A gameplay screenshot fixes the direction: `GOLD=0038` for 38 gold, so a fresh character's `0400` is **400 gold, not 4**. Ceiling 9999, not 255 | `asm/53A5`, `asm/55B5`, owner gameplay screenshot 2026-10-27 |
| An intermediate CP3 reading claimed the original **prints the two bytes in the wrong order**, so food 3 displayed `0300` | wrong, and worth recording because it was confidently written into `status.c` and this table. `GOLD=0038` in a real gameplay screenshot is 38 gold; a byte-swapped display would read `3800`. The display is ordinary big-endian packed BCD and there is no quirk to reproduce. The trap: `0300` read from memory was assumed to mean "3 with a bug" instead of "three hundred" | owner gameplay screenshot 2026-10-27, superseding an owner from-memory recollection the same day |
| CP3 "the remaining-point total follows `PLAYER GENERATION :`" | it does not. `asm/56C6` prints `POINTS LEFT TO DISTRIBUTE : ` and `asm/5C85` addresses the value at column 33 row 2; the heading carries no number. The string was missing from the extraction manifest entirely | `asm/56C6`, `asm/5C7D..5C89`, `asm/5C66` |
| CP3 "stats are two typed digits packed as nibbles, budget is packed BCD at `DS:29`" | correct as to the budget, but the validator is narrower than assumed: `asm/5C66` stores the stat, fails below `0x0a`, then `sub`/`das`/`jb` fails an overspend. **Minimum 10 per stat, no maximum** — the only other bounds are the 90 budget and two-digit input. Derived: since every stat is at least 10, no single stat can exceed `90 - 5*10 = 40`, so the BCD bonuses (max +15) can never overflow a byte | `asm/5C66..5C7A` |
| CP4 kickoff "4224 = 4096 + 128, candidates: 32x32 tiles x 4 bytes plus a 128-byte header, or 1056 x 4-byte entries" | neither. **One byte per tile, 64 columns, 4096 bytes = a 64x64 sector**, and the 128-byte tail is never read (same shape as the 384-byte `PLAYER` file whose record is 256). The read is `AH=27h, CX=0x1000` into `[DS:0x472]`, and the name is `MAPX` + two digits self-patched into the code stream at file `0x24bb`/`0x24bc` | `asm/50B3_map_tile_ptr.asm`, `asm/2290_sub_2290.asm` |
| §1 "`0x4A` last key" | **in doubt, not yet corrected.** `asm/2290`/`asm/22D5`/`asm/2305` read `DS:0x4A`, add `0x30` and self-patch the result into the second digit of the `MAPXFF`/`MONXFF` FCB name, which is arithmetic a key byte does not support. `asm/334D_cmd_D` meanwhile reads it as a key byte. Either the location is reused or one reading is wrong; CP4 must settle it before movement is built | `asm/2290`, `asm/334D_cmd_D` |
| §1 "`0x472` map table base" | confirmed, and larger than a base: `[DS:0x472]` is the destination of the 4096-byte sector **read** (`asm/2290`, AH=27h) *and* the source of the sector **write** (`asm/2305`, AH=28h). The original rewrites its own `mapxNN` file, so world content is mutable at runtime | `asm/2290`, `asm/2305` |
| CP4 kickoff § 2.6 "does the viewport straddle two sectors, or snap to the new sector's origin?" | **neither.** The player position is `DS:00`/`DS:01` and the delta is applied with `adc` then **`and $0x3f`**, so the 64x64 sector wraps on itself: the world is a torus per sector file and the view never crosses a file boundary. The loader stays one-sector-at-a-time | `asm/38B0_cmd_L.asm` file `0x3c9b..0x3cb2` |
| CP4 kickoff § 2 "direction messages" implied letter commands | movement is **not** in the command set: `cmd_N/E/S/W` are NEGATE TIME / ENTER / STEAL / WEAR ARMOUR. The arrows are translated by a scancode table at `CS:0x4F09` (`48->0e`, `50->19`, `4d->05`, `4b->17`) into direction codes that live as **data** at `DS:26E..271`, and `Ctrl-E/N/W` are swallowed by the key seam so only the arrows move the character | `asm/4FBE`, `asm/4FCC`, `asm/38B0_cmd_L.asm`, file `0x5109`, file `0x787E` |

Two consequences worth stating plainly:

* **Determinism is a property of the game, not of the test harness.** Because the
  PRNG is a seeded shift register and no game logic reads a clock, a key script
  plus a seed reproduces a run exactly — encounters, combat rolls and monster
  spawns included. That is what makes the CP2 report verifiable and will make
  CP8's end-to-end playthrough checkable rather than eyeballed.
* **Standing rule for the rest of Phase 4:** game logic never reads the clock;
  only presentation delays may. If that is broken, replay evidence stops being
  sound and §7 needs a new entry.
