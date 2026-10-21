# engine/ — portable C engine (Phase 4)

A native Linux reimplementation of *Ultima II*, written by reading the
byte-proven `asm/` tree. No DOSBox. Behavioural fidelity is argued from the
asm and confirmed by playthroughs; it is **not** byte-proven. The asm tree
remains the only proven artefact — see `disasm/phase3-summary.md`.

## Build and run

```sh
make                      # cc only, C11, no third-party dependencies
make test                 # CP0 + CP1 + CP2 acceptance tests
./u2                      # interactive terminal play
./u2 --headless --script tests/title.keys --dump-state
./u2 --headless --script tests/title.keys --dump-each   # frame-by-frame grid log
./u2 --headless --script tests/title.keys --trace=trace.log
./u2 --headless --script tests/play_to/reach_everything_today.keys --seed 0 \
     --replay-report /var/tmp/run.json                  # verifiable transcript
python3 tools/playlog.py verify /var/tmp/run.json       # REPRODUCES | DIVERGES
./u2 --headless --selftest --script tests/selftest.keys --dump-state
make content              # regenerate build/gen_content.h only
```

`--headless`, `--script`, `--dump-state`, `--dump-each`, `--trace`, `--seed` and
`--replay-report` are the agent-facing contract — see [docs/playing.md](docs/playing.md).

`build/`, `u2` and every generated header are gitignored.

## Zero game content

Nothing from the original binary is committed: no strings, no tables, no
extracted headers. `tools/extract/extractor.py` produces `build/gen_content.h`
at build time from a copy the user owns:

```sh
python3 tools/extract/extractor.py --exe ../original/ultimaii.exe   # normal
python3 tools/extract/extractor.py --source asm                     # no copy (CI)
python3 tools/extract/extractor.py --emit text                      # for tests
```

With no copy present the extractor falls back to the `db` lines of the
byte-proven `asm/` tree, as the plan specifies. Two title strings live inside
regions Phase 3 reconstructed as mis-decoded code (`asm/02A3`, `asm/02E6`), so
they have no `db` line and cannot come from the fallback; the extractor yields
them empty and the engine skips those two lines rather than inventing text.
`make content-check` fails if the header is stale.

That is what keeps this directory cleanly Apache-2.0.

## Screen model

40 columns x 25 rows, not the 80x25 the plan assumed. The row-clear loop prints
40 spaces (`asm/53A0_sub_53a0.asm`), the printable margin is 0x26/0x28
(`asm/456B_sub_456b.asm`, `asm/48A7_sub_48a7.asm`), and the game sets video
mode 4 — 320x200, exactly 40x25 cells of 8x8 (`asm/4A3E_sub_4a3e.asm`). The
text printer reproduces `char_print`'s control flow: attribute from `DS:0x23E`,
CR returns to `DS:0x54F`, wrap at `DS:0x31`, scroll of rows 20-23 at row 24.

## Layout

```
src/core/       vram grid, DS state struct, rng, timers, the seam layer
src/game/       game logic; each module cites the asm functions it implements
src/platform/   renderer_{term,null} input_{term,script} audio_{beep,null} time_{posix,script}
src/debug/      --trace seam log, --dump-state screen + JSON
tests/          scripted playthroughs and the checkpoint test runners
tools/extract/  extractor.py — the user's copy -> build/gen_content.h
tools/u2_mcp/   MCP play-API (CP2)
```

## The seam rule

Game logic talks to the outside world only through `src/core/seam.h`, which
routes to the four platform vtables in `src/platform/platform.h`. No terminal
escape, `sleep()`, `read()` or SDL call may appear under `src/game/`. Each seam
stands in for one named routine in the asm tree, and `--trace` prints the asm
address on every call, which is what makes a trace auditable against `asm/`:

| seam | asm spec | engine |
| --- | --- | --- |
| `char_out` | `asm/4A1C_char_out.asm` | `seam_char_out` |
| `char_print` | `asm/5003_char_print.asm` | `seam_char_print` |
| `char_print_wrap` | `asm/53F4_char_print_wrap.asm` | `seam_str_out` |
| `str_out` | `asm/4FDF_str_out.asm` | `seam_str_out` |
| `str_out_at` | `asm/51EB_str_out_at.asm` | `seam_str_out_at` |
| cursor set | `asm/51FD_str_out_core.asm` | `seam_goto` |
| row clear | `asm/53A0_sub_53a0.asm` | `seam_clear_row` |
| `key_poll` | `asm/4F4D_key_poll.asm` | `seam_key_poll` |
| `rand_byte` | `asm/5217_rand_byte.asm` | `seam_rand_byte` |
| `timed_wait` | `asm/52CA_timed_wait.asm` | `seam_wait_ms` |
| `speaker_freq` | `asm/5CD2_speaker_freq.asm` | `seam_tone` |
| `map_tile_ptr` | `asm/50B3_map_tile_ptr.asm` | overworld module (CP4) |
| `cmd_prompt` / `cmd_dispatch` / `cmd_done` | `asm/087D`, `asm/0A1F`, `asm/0A33` | command loop (CP6) |

`key_poll` is larger than the function boundary Phase 3 drew: it consumes the
key (INT 16h AH=00h), maps a few control bytes to NUL, and upper-cases a-z with
`and $0xdf`. The engine does the same, so everything downstream sees uppercase.

## Two global stores, on purpose

The original runs with `CS` at the loaded image and `DS` pointing at a
separately allocated 64 KiB working segment (`asm/0100_sub_0100.asm`; runtime
`DS = 0x08BE`). Bare-displacement globals in the asm live in DS; a second set
of statics lives in the image segment and is addressed with a `%cs:` override.
`src/core/state.h` mirrors the DS segment as a struct with compile-time offset
assertions. CS-side statics belong to the module that owns them and are cited
in that module's header. See `disasm/selfmod-capture.md`.

## Headless is a first-class mode

`--headless` swaps in the null renderer, the script input and a virtual clock
that does not really sleep, so a key script replays identically and stdout is
machine-readable.

## Randomness

`rand_byte` is a six-byte feedback shift register at `DS:0x23F..0x244`
(`asm/5217` + `asm/522B` + `asm/5236`, which Phase 3 had split into three
fragments). It is seeded once at program launch from the BIOS keyboard-flag
byte at `0x40:6C` (`asm/0100`) and nothing else writes those bytes. So rolls
are a pure function of seed and roll count: encounters, combat rolls and monster
spawns replay exactly for the same inputs, with no clock involved. `--seed N`
sets that byte (default 0, what a cold boot gives); `--rng-sequence N` prints
the first N values as a test vector.

## Known limits

* Behaviour is argued from the asm and checked by playing, not differentially
  tested against the original (owner decision — see `docs/phase4-plan.md`).
* The `rand_byte` vector in `tests/run_cp0.sh` is derived from a hand decode of
  the three fragments, not captured from the running game; it guards against
  regressions and documents the reading.
* The title strings contain a two-byte bracket sequence where the game means
  "II" (in the game title, the intro's part number and the PLAY menu line). The
  original never redefines the font, so this is a glyph question, not a decoding
  one; the engine renders the bytes as extracted and CP9 decides the mapping.
* The intro in the original also loads PIC picture files (the FCB names near
  file `0x419`, the sector read at `asm/535A_sub_535a.asm`). The engine has no
  bitmap pipeline until CP9, so the text screens stand alone.
* Sound and timing feel are approximated: the beep backend is the terminal
  bell until the SDL2 target at CP9, and `timed_wait` is a wall-clock delay
  rather than a cycle burn. Intro hold durations are a choice, not a fact.
* CGA glyph and colour authenticity is a CP9 decision.
