# Phase 4 Implementation Log

Running log for `docs/phase4-plan.md`. One section per checkpoint.

---

## CP0 — Skeleton + automation substrate — done 2026-10-27 (awaiting gate)

### Baseline re-verified before touching anything

| Check | Result |
| --- | --- |
| `original/ultimaii.exe` md5 | `fe884d5117971073ac8097cc7a6aca25` ✓ (matches plan §1) |
| `bash tools/assemble_all.sh` | `REBUILD BYTE-MATCH: 37344 bytes identical` ✓ |
| `bash tools/assemble_clean.sh` | 1299/1299 cleaned files, `CLEAN REBUILD BYTE-MATCH: 37344 bytes identical` ✓ |
| `python3 tools/check_func.py <SEG> --no-compare` | sample `0100 2B8F 4FDF 363B 8DCD 5129` all green ✓ |
| `asm/` | 1300 tracked files (1299 functions + prologue), untouched by this checkpoint ✓ |

### What the asm said before any code was written

Read the seam routines themselves rather than trusting plan §1:

* `asm/51FD_str_out_core.asm` is the cursor authority:
  `mov 0x2f,%dh` / `mov 0x2e,%dl` / `mov $0x2,%ah` / `int $0x10`. INT 10h AH=02h
  takes DH=row, DL=col, BH=page, so **DS:0x2E = column and DS:0x2F = row**.
  Plan §1 records them as "cursor page/col"; the bytes disagree, and the
  `FOOD=` site confirms it (col 30, row 21 — a status line, not page 30).
  `engine/src/core/state.h` encodes the corrected meaning with the citation.
* `asm/0100_sub_0100.asm` sets `DS` from a loader-patched immediate and `SS`
  from `DS+0x310`, and reads `ES:0x6C` (BIOS keyboard flags) to seed the tick
  bytes. So the program has **two variable spaces**: the allocated DS working
  segment and statics inside the loaded image addressed with `%cs:` overrides
  (`cs:0x730` command jump table, `cs:0x2798`, `cs:0x29d0`, `cs:0x48d0..`,
  `cs:0x4f04..` scratch). The engine mirrors DS as an offset-asserted struct
  and leaves CS-side statics to their owning modules.
* `asm/5217_rand_byte.asm` has no PRNG state at all: `stc; mov 0x240,%al;
  adc 0x243,%al; adc 0x244,%al`. Entropy is the live tick counters, which is
  why a frozen virtual clock makes headless runs reproducible for free.
* `asm/5351_sub_5351.asm` loads `DS` with `0xB800` — direct video-memory pokes
  exist alongside teletype output, so the screen model needs both a teletype
  path and a positional poke path (`u2_vram_put` vs `u2_vram_poke`).

### Selfmod capture — resolved without a live dump

Plan §1 asked CP0 for a one-time capture of the runtime-patched bytes of the
`0x5120..0x5151` cluster. The project already holds 45 Spice86 runtime exports
whose blocks record the bytes the CPU actually executed, so the capture was
done as a reconciliation instead (`tools/selfmod_scan.py`,
`tools/selfmod_dump.py`, `tools/selfmod_diff.py`), and the finding is recorded
in `disasm/selfmod-capture.md`. Headline results:

* The export demonstrably reflects live memory, not the file image: exactly 2
  of 8,863 observed bytes differ from `original/ultimaii.exe`, at runtime
  `+0x0101/+0x0102` — the `mov $0x741,%ax` segment fixup, executed as
  `mov $0x08BE,...`, matching the DS value in `captures/README.md`.
* In the cluster, 44 of 50 bytes were observed as executed across all 44
  scenario captures and **none differ from the static image**. The 6 unobserved
  bytes are the inline string `FOOD=\0` at `0x5136..0x513B`.
* The executed decode is ordinary code (three calls, then the `FOOD=` label at
  row 21 col 30, then the food BCD pair at `DS:0x53/0x54`). The Phase 1/2
  "runtime-patched" verdict was a static mis-decode across that inline string.
* Consequence: CP3's `FOOD=`/`EXP=`/`GOLD=` sites lift straight from `asm/`;
  plan §5's "selfmod depends on a capture" limit is retired. `GOLD=` was never
  in the cluster — it is `asm/5175_sub_5175.asm`.

This is a correction to a plan premise, so it is flagged at the gate rather
than quietly adopted. A live DOSBox/Spice86 dump remains available if the owner
wants independent confirmation.

### What was built

```
engine/
  Makefile            cc only, C11, -Werror; goals: all run headless test test-cp0 clean sdl(help)
  README.md           build/run, seam map, two-global-store rationale, limits
  src/core/           ctx.h vram.[ch] state.[ch] rng.[ch] timer.[ch] seam.[ch]
  src/game/           game.[ch]  main loop (CP0 placeholder screen, engine-authored text)
  src/platform/       renderer_{term,null} input_{term,script} audio_{beep,null} time_{posix,script}
  src/debug/          trace.[ch] dump_state.[ch]
  src/main.c          flag parsing + backend wiring
  tests/title.keys    CP0 smoke script
  tests/run_cp0.sh    CP0 acceptance test
tools/selfmod_scan.py tools/selfmod_dump.py tools/selfmod_diff.py
disasm/selfmod-capture.md
docs/phase4-state.md  docs/phase4-implementation.md
.github/workflows/build.yml   engine job added (build + make test)
.gitignore                    engine/build/, engine/u2, disasm/selfmod-raw/
```

Design points worth recording:

* **One context, no globals.** `u2_ctx` carries the four vtable pointers, the
  vram, the state, the trace handle and one private slot per backend. The CP2
  MCP server will want several live contexts side by side, and this makes that
  ordinary instead of a refactor.
* **The seam layer is a real layer, not a typedef.** `src/core/seam.c` is the
  only place that both knows the asm name and calls a backend, so `--trace`
  output is one line per asm-visible event:
  `trace: seam=str_out_at asm=51EB col=2 row=4 len=51`.
* **Headless is a mode, not a build.** `--headless` selects null renderer +
  script input + silent audio + the virtual clock; the plan's test command is
  literally `./u2 --headless --script tests/title.keys --dump-state`.
* **Script input is a small protocol**, not raw bytes: one token per line
  (`A`, `SP CR LF TAB ESC BS NUL DEL`, `0x41`, `WAIT`, `EOF`), `#` comments.
  `WAIT` models "the player thought about it" and is what keeps a script
  honest about polls that return no key.
* **State struct with `_Static_assert` on every offset.** If a later checkpoint
  needs `DS:0x51`, it is added at its real offset or the asserts fail at
  compile time. Unlifted ranges stay in named `reserved_NN` arrays — never
  guessed.
* **BCD helpers exist but nothing converts silently**: `gold_bcd` and the
  decoded `gold` both appear in the dump so a reviewer can see the pair.
* **Audio is honestly a stub.** `audio_beep.c` records the 8253 divisor and
  rings the terminal bell; no `/dev/port`, no `KIOCSOUND` (needs root), no new
  packages. Sampled output is CP9.

### Test — the plan's CP0 command, verbatim

`make && ./u2 --headless --script tests/title.keys --dump-state` prints the
80x25 grid plus the JSON state and exits 0. `make test` (`tests/run_cp0.sh`)
checks nine things objectively:

```
  PASS  exit status 0
  PASS  screen grid rendered (banner row present)
  PASS  rand_byte seam exercised
  PASS  speaker_freq seam exercised
  PASS  state dump emitted
  PASS  JSON parses with the expected schema
  PASS  headless run is reproducible (two runs identical)
  PASS  --trace logs seam calls with asm citations
  PASS  asm/, original/, references/ untouched
CP0 TEST: PASS
```

Reproducibility is asserted by diffing two full runs, which only holds because
the headless clock is virtual — that is the design point, and the test is what
proves it rather than claims it.

### Deliberate omissions (not oversights)

* No `tools/extract/extractor.py` yet — CP1, and CP0 must not need it.
* No `tools/u2_mcp/` — CP2.
* No SDL2 target: `make sdl` prints the reason and exits 1, because installing
  system packages is an owner decision (plan §6).
* `rand_byte` returns the mixed byte of the proven prologue only; the tail past
  the reconstructed bytes is lifted with its first real caller (CP4).
* The CP0 screen is engine-authored placeholder text. No Ultima II string is
  anywhere in `engine/`.

### Gate

CP0 acceptance is "owner approves architecture". Reported and waiting; the six
decision points are listed in `docs/phase4-state.md` § Gate log. Nothing was
irreversible and no acceptance criterion was loosened.
