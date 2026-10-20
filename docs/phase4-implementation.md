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

---

## CP1 — Extractor + title screen — done 2026-10-27 (awaiting owner eyeball)

### Reading the asm before writing the flow

The title region is `asm/0133..03AC`. Phase 3's function boundaries cut this
region into ~60 fragments (objdump restarted at every byte that could be a
boundary), so the flow had to be reassembled from the fragments plus raw
decodes of the mis-split stretches. What came out:

* **The inline-string convention is real code, not a comment.** `str_out`
  (`asm/4FDF`) calls `str_out_core` to set the cursor, then its own body
  (`asm/4FE2..asm/5002`) `pop`s the return address — which *is* the address of
  the string bytes that follow the call — stores it to `DS:0x2B`, walks it with
  `mov %cs:(%bx,%si),%al`, calls `char_print` per byte, and pushes the advanced
  pointer back before `ret`. That is why the strings live in the image segment
  and why the extractor reads them from the exe at `runtime offset + 0x200`.
* **`char_print` is a full text printer** (`asm/5003` + `asm/500D` +
  `asm/5016` + `asm/501A` + `asm/5025` + `asm/5036` + `asm/503D` + `asm/504A` +
  `asm/5057`): mask high bit; CR returns the column to `DS:0x54F` and advances
  the row; LF advances the row; at row 24 it scrolls rows 20..23 with INT 10h
  AH=06h; otherwise INT 10h AH=09h writes char + attribute `DS:0x23E`, then the
  column advances and wraps past `DS:0x31`. `core/seam.c` reproduces that
  control flow with a citation per branch.
* **`key_poll` is bigger than its Phase 3 boundary.** `asm/4F4D..4F51` is only
  the `INT 16h AH=01h` probe; the routine continues at `4F52` (which the
  function map had handed to a neighbouring fragment): it consumes the key with
  AH=00h, maps Ctrl-E/Ctrl-N/Ctrl-W to NUL, handles the arrow table at
  `cs:4F09`, and finally upper-cases `a-z` with `and $0xdf`, returning AH=0xFF
  when a key was consumed and AH=0x00 when none was. That is what makes the
  menu loop `cmp $0xff,%ah; jne loop` read correctly, and why the engine
  upper-cases at the seam.
* **`asm/0688` is the intro hold**: a cycle loop that calls `key_poll` each
  pass and, on ESC, discards its return address and jumps to the title entry at
  `asm/0242`. So ESC anywhere in the intro or the poem lands on the title.
* **The 'D' demo is a cycle**, not a one-shot: the poem ends by jumping back to
  the intro entry (`asm/033E`), so demo = poem, intro, poem, intro ... until
  ESC. `run_demo()` models exactly that.
* **`DS:0x239` is a "story shown" flag**: cleared at startup (`asm/0133`), set
  when the poem runs (`asm/03AC`), branched on after the intro (`asm/0237`).

### Architecture correction: the grid is 40x25, not 80x25

Plan §2 specified an 80x25 VRAM grid. The bytes disagree:

| evidence | file |
| --- | --- |
| row clear prints `0x28` = 40 spaces | `asm/53A0_sub_53a0.asm` |
| printable right margin set to 0x26 / 0x28 | `asm/456B_sub_456b.asm`, `asm/48A7_sub_48a7.asm`, `asm/4A2F_sub_4a2f.asm` |
| scroll window is columns 0..`DS:0x31` | `asm/5025_sub_5025.asm` |
| video mode 4 = 320x200 = 40x25 cells of 8x8 | `asm/4A3E_sub_4a3e.asm` |
| every title string fits 40 columns at its column | `asm/0246..0375` |

`U2_COLS` is 40 and the CP0 test's schema assertion was updated to match. This
is a change to a signed-off architecture number, so it is called out at the
gate rather than slipped through; the evidence is in `engine/README.md`.

### Extractor

`engine/tools/extract/extractor.py`:

* manifest of `(symbol, asm file, locator)`; offsets and names are ours, the
  bytes are the user's;
* **exe source**: locates each string inside the containing function's byte
  range in the user's copy (search-forward from the previous hit, so repeated
  short strings stay unambiguous) and emits the exe's own bytes;
* **asm fallback** (the plan's stated fallback): the `db "...",0x00` lines of
  the byte-proven tree;
* `--check` fails on a stale header, `--emit text` gives `SYMBOL<TAB>value` for
  test scripts, and a wrong-md5 copy warns instead of failing (community-patch
  caveat from AGENTS.md);
* two title strings live inside the regions Phase 3 reconstructed as mis-decoded
  code (`asm/02A3`, `asm/02E6`) and therefore have no `db` line. They are
  manifest entries of the `("run", file_offset)` kind: exe-only. Without a copy
  the extractor yields them empty and the engine skips the line instead of
  inventing text. The test asserts 27/29 in fallback mode, so this limit is
  measured, not hidden.

`make` generates `build/gen_content.h` before compiling; `make content` and
`make content-check` exist for explicit control. The header stays gitignored.

### Engine changes

* `game/title.c` — intro (2 screens), title, choice dispatch, poem, demo cycle,
  CP3/CP4 stubs. Every drawn line cites the asm function that sets its row and
  column.
* `core/vram.c` — 40 columns, `u2_vram_scroll_window()` for the AH=06h window.
* `core/seam.c` — `char_print` semantics, `seam_clear_row`, `key_poll`
  upper-casing, `rand_last` stored like `asm/5217` stores to `DS:0x23F`.
* `core/state.h` — added `right_margin` (0x31), `story_flag` (0x239),
  `text_attr` (0x23E), `rand_last` (0x23F), `left_margin` (0x54F), each with a
  `_Static_assert` and a citation.
* `--selftest` — the CP0 substrate probe screen moved behind a flag so the CP0
  test stays runnable now that the default flow is the game. `tests/selftest.keys`
  feeds it; `tests/title.keys` drives the real flow.
* `input.poll()` now distinguishes "no key right now" (0) from "input is
  finished" (-1). Without that, a script that ran out of keys left the demo
  cycle spinning between poem and intro forever.

### Test

`make test` runs both checkpoint tests.

```
CP0 TEST: PASS   (9/9, unchanged assertions, now via --selftest)
CP1 TEST: PASS
  PASS  scripted run exits 0
  PASS  extractor produced the expected-string table
  PASS  title strings found at their asm positions        (placed=11 wrong=0)
  PASS  demonstration poem drew 7 couplet lines in row 24
  PASS  story flag set by the demo path
  PASS  scripted title run is reproducible
  PASS  asm fallback yields 27/29 strings (2 are exe-only by design)
  PASS  generated content header is gitignored
```

The position check is independent of `title.c`'s table: `run_cp1.sh` carries
its own `symbol:row:col` list read off the asm, so a mis-read in the module
shows up as a mismatch rather than being confirmed by itself.

### Phase 3 invariants after CP1

`assemble_all.sh` byte-identical, `assemble_clean.sh` 1299/1299 + 37,344 B
identical, `check_func` sample green, `original/ultimaii.exe` md5
`fe884d5117971073ac8097cc7a6aca25`, `git status` clean for `asm/ original/
references/`. The engine only reads `asm/`.

### Open questions for the owner gate

* The title strings contain a two-byte bracket sequence where the game means
  "II" (in the game title, the intro's part number and the PLAY menu line).
  Nothing in the binary redefines the font, so either DOSBox shows brackets too
  (an Apple II holdover) or the glyph mapping is subtler than the static bytes
  show. CP9 decides.
* `TYPE -` at row 11 col 5 is a real extracted line with no visible producer
  for whatever follows it. Worth a glance in DOSBox.
* Intro hold durations are chosen, not derived.

### CP1 owner review round (2026-10-27)

Owner feedback on the first CP1 report, and what each item turned into:

1. **"the character they press appears on the CHOICE: line, but only briefly"**
   — a real bug. `TITLE[]` was drawn in row order, so the cursor ended after the
   last entry (`AND ORIGIN`, row 23) and the echo printed there. The original
   draws in *code* order (`asm/0246, 025E, 0273, 0288, 02A3, 02CC, 02E6, 02F8,
   031F, 034B, 0375`), which ends with `CHOICE:` at row 19 col 5, so the echo
   from `asm/0394` lands at row 19 col 12, right after the prompt. Table
   reordered; `char_print`'s trace now carries `at=row,col` and the test
   asserts the echo position, so this cannot silently regress.
2. **Choice dispatch order corrected.** A clean decode of runtime `0x389..0x3B5`
   (the region Phase 3 had fragmented) shows: `'D'` jumps to `0x3AF` (poem);
   `'P'` calls `asm/0764` then the poem; `'C'` calls `asm/5400` (creation) then
   falls into the same `asm/0764` call; anything else jumps back to the title
   entry. My first pass had the order inverted and cited `asm/0964`, which is
   the *file* offset of runtime `0x764`. `asm/0764` turns out to be a small
   display-and-wait wrapper (echo the key, print a line at row 10 col 0, wait),
   not the play setup — the load path behind it is still ahead of us.
3. **The poem path clears the screen first** (`asm/03B0` -> `asm/4A3E`, the
   INT 10h mode set) and sets the story flag there (`asm/03B3`), so the couplets
   appear on a blank screen rather than over the title. Implemented.
4. **Grid width question.** The owner could not count columns in a CGA bitmap
   render, and declined a live DOSBox/Spice86 capture as a decision point unless
   it becomes necessary. Agreed and recorded: the 40-column conclusion rests on
   static evidence only — 40-space row clear (`asm/53A0`), margins 0x26/0x28
   (`asm/456B`, `asm/48A7`, `asm/4A2F`), scroll window 0..`DS:0x31`
   (`asm/5025`), mode 4 = 320x200 (`asm/4A3E`). If a later checkpoint shows a
   contradiction, this is the assumption to revisit.
5. **`][` accepted as-is** by the owner; CP9 still owns the glyph decision.
6. **"did we implement the splash screens?"** — the two text splash screens are
   implemented (see the frame log below); the PIC bitmap art the original loads
   during the intro is not, until CP9. To make that visible without running the
   game, the engine gained **`--dump-each`**: it prints the grid after every
   screen change, so a headless run produces a frame-by-frame visual log. That
   also happens to be the read-side primitive the CP2 MCP API needs.

Frame log from `./u2 --headless --dump-each --script <(printf 'WAIT\nWAIT\n')`:

```
frame 1: r10 ORIGIN                     r12 PROUDLY PRESENTS
frame 3: r08 PART ][     r10 OF THE #1 BEST SELLING
         r12 FANTASY ROLE-PLAYING GAME  r14 BY LORD BRITISH
frame 5: r01 ULTIMA ][  r03 REVENGE  r05 OF  THE  r07 ENCHANTRESS  r11 TYPE -
         r13 'D' ...  r15 'P' ...  r17 'C' ...  r19 CHOICE:  r22 (C)-...  r23 AND ORIGIN
```

CP1 test is now 10 assertions, all green, plus CP0's 9.
