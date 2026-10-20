# Playing the engine as an agent — the CLI contract

CP2 replaced the planned MCP wrapper with this document. The reason: everything a
play-API would expose is already a stable command-line contract, and an agent
with a shell can use it directly. If an MCP harness is wanted later it wraps
these four commands and adds nothing the engine does not already guarantee.

Everything below is the engine's own contract, not a script's. `engine/u2` is
built by `make` in `engine/`.

## The four commands

```sh
# 1. Play a key script and see where it ends up
./u2 --headless --script keys.txt --dump-state

# 2. Every frame the script produced, in order (what the player saw)
./u2 --headless --script keys.txt --dump-each

# 3. The seam log: one line per asm-visible call, with the asm address
./u2 --headless --script keys.txt --trace=/var/tmp/trace.log

# 4. A verifiable playthrough report (digests, no game text)
./u2 --headless --script keys.txt --seed 0 --replay-report /var/tmp/run.json
```

`--headless` is always what you want for automation: null renderer, scripted
input, silent audio, and a clock that does not really sleep.

## Key script grammar

One token per line. `#` starts a comment, blank lines are skipped.

| token | meaning |
| --- | --- |
| `A` | any single printable character |
| `SP CR LF TAB ESC BS NUL DEL` | named control key |
| `0x41` | explicit byte |
| `WAIT` | poll once, no key arrives (models a player thinking) |
| `EOF` | stop feeding keys here |

When the script runs out, input is *finished*: the flow treats it as "the
player walked away" and returns instead of spinning. `WAIT` is not the same as
running out — a `WAIT` leaves the input open.

Keys are consumed by the same routine the original used (`asm/4F4D`), which
means they arrive **upper-cased** and control bytes are folded the way the
original folds them. `key_poll` consumes; it does not peek.

## What the output means

`--dump-state` prints the 40x25 grid between `+---+` borders, then one JSON
object:

```json
{"engine":"0.1-cp2","mode":"headless",
 "platform":{"renderer":"null","input":"script","audio":"null","clock":"script"},
 "screen":{"cols":40,"rows":25,"cells_written":592,"cursor":{"row":19,"col":12,"visible":0}},
 "state":{"player_x":0,"player_y":0,"cursor":{"row":19,"col":5},
          "margins":{"left":0,"right":40},"text_attr":15,"story_flag":1,"last_key":68,
          "gold_bcd":[0,0],"gold":0,"spell_pick":0,
          "rng":{"state":[2,2,1,0,0,0],"rolls":1},"map_base":0},
 "content":"exe:original/ultimaii.exe md5=fe88..."}
```

`state` mirrors the original's DS working segment, so every field is a real
address in the binary (see `src/core/state.h` for the citations). `rng.state`
is the six-byte shift register at `DS:0x23F..0x244` and `rolls` counts how many
times it has been turned.

`--trace` lines look like:

```
trace: seam=str_out_at asm=51EB col=5 row=19 len=7
trace: seam=key_poll asm=4F4D ready=1 ch=0x44
trace: seam=rand_byte asm=5217 value=2 zero=0 rolls=1
```

Read them next to `asm/<ADDR>_*.asm` to check behaviour against the spec.

## Determinism — what you can rely on

A run is a pure function of **(seed, key script, engine build, extracted
content)**. Nothing in the game logic reads a wall clock; `rand_byte` is a
shift register seeded once at launch from the value the original read from BIOS
`0x40:6C` (`src/core/rng.h`). So:

- same seed + same keys ⇒ byte-identical output, every time;
- `--seed N` changes the dice (encounters, combat rolls, monster spawns) while
  keeping the run reproducible;
- standing rule for future checkpoints: **game logic never reads the clock; only
  presentation delays do.** If that ever breaks, replays stop being exact and
  this document is wrong.

The seed is per program launch, not per new game, and the original does not
save it — the 384-byte player record does not include `DS:0x23F..0x244`.

## Transcripts: prove it, don't assume it

`--replay-report FILE` writes a report that is safe to commit — digests and
numbers, no game text:

```json
{"report":"u2-playthrough","version":1,
 "engine_version":"0.1-cp2","content_source":"exe:original/ultimaii.exe md5=...",
 "seed":0,"keys":["ESC","D","WAIT"],
 "steps":[{"at_key":1,"screen":"<sha256>","state":"<sha256>","rolls":0}, ...],
 "final_state":{...}}
```

One step per frame the engine actually painted. Verify a transcript later with:

```sh
python3 tools/playlog.py verify evidence/cp2-playthrough.json   # REPRODUCES | DIVERGES
python3 tools/playlog.py show   evidence/cp2-playthrough.json
python3 tools/playlog.py digest evidence/cp2-playthrough.json   # one hash of the whole run
```

`verify` re-runs the engine with the report's own seed and keys and compares
every recorded digest. That is the check CP8's end-to-end playthrough will rest
on.

## Committed scripts

`tests/play_to/*.keys` are the reusable routes. Run one with:

```sh
./u2 --headless --script tests/play_to/title_menu.keys --dump-each
```

## What exists today

Implemented: presentation intro, title screen, menu dispatch, the `'D'`
demonstration poem (`src/game/title.c`). `'P'` and `'C'` reach engine-authored
stubs — character creation is CP3, the overworld CP4, combat CP5, towns CP6.
There is no game text in this repository: strings are extracted at build time
from the user's own copy into `build/gen_content.h`.
