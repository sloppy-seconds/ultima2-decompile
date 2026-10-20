# engine/ — portable C engine (Phase 4)

A native Linux reimplementation of *Ultima II*, written by reading the
byte-proven `asm/` tree. No DOSBox. Behavioural fidelity is argued from the
asm and confirmed by playthroughs; it is **not** byte-proven. The asm tree
remains the only proven artefact — see `disasm/phase3-summary.md`.

## Build and run

```sh
make                      # cc only, C11, no third-party dependencies
make test                 # CP0 acceptance test (headless smoke run)
./u2                      # interactive terminal play
./u2 --headless --script tests/title.keys --dump-state
./u2 --headless --script tests/title.keys --trace=trace.log
```

`build/`, `u2` and every generated header are gitignored.

## Zero game content

Nothing from the original binary is committed: no strings, no tables, no
extracted headers. Content is produced at build time from the user's own copy
by `tools/extract/extractor.py` (CP1) into `engine/build/gen_*.h`. That is
what keeps this directory cleanly Apache-2.0.

## Layout

```
src/core/       vram grid, DS state struct, rng, timers, the seam layer
src/game/       game logic; each module cites the asm functions it implements
src/platform/   renderer_{term,null} input_{term,script} audio_{beep,null} time_{posix,script}
src/debug/      --trace seam log, --dump-state screen + JSON
tests/          scripted playthroughs and the checkpoint test runners
tools/extract/  extractor.py (CP1)
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
| `key_poll` | `asm/4F4D_key_poll.asm` | `seam_key_poll` |
| `rand_byte` | `asm/5217_rand_byte.asm` | `seam_rand_byte` |
| `timed_wait` | `asm/52CA_timed_wait.asm` | `seam_wait_ms` |
| `speaker_freq` | `asm/5CD2_speaker_freq.asm` | `seam_tone` |
| `map_tile_ptr` | `asm/50B3_map_tile_ptr.asm` | overworld module (CP4) |
| `cmd_prompt` / `cmd_dispatch` / `cmd_done` | `asm/087D`, `asm/0A1F`, `asm/0A33` | command loop (CP6) |

## Two global stores, on purpose

The original runs with `CS` at the loaded image and `DS` pointing at a
separately allocated 64 KiB working segment (`asm/0100_sub_0100.asm`; runtime
`DS = 0x08BE`). Bare-displacement globals in the asm live in DS; a second set
of statics lives in the image segment and is addressed with a `%cs:` override.
`src/core/state.h` mirrors the DS segment as a struct with compile-time offset
assertions. CS-side statics belong to the module that owns them and are cited
in that module's header. See `disasm/selfmod-capture.md`.

## Headless is a first-class mode

`--headless` swaps in the null renderer, the script input and a deterministic
virtual clock, so a key script replays identically and stdout is
machine-readable. The scripted RNG follows from that: the original derives
`rand_byte` from live tick counters, so freezing the clock freezes the dice.

## Known limits

* Behaviour is argued from the asm and checked by playing, not differentially
  tested against the original (owner decision — see `docs/phase4-plan.md`).
* `rand_byte` is modelled from the reconstructed prologue; the tail past the
  proven bytes is lifted when the first caller needs it.
* Sound and timing feel are approximated: the beep backend is the terminal
  bell until the SDL2 target at CP9, and `timed_wait` is a wall-clock delay
  rather than a cycle burn.
* CGA glyph and colour authenticity is a CP9 decision.
