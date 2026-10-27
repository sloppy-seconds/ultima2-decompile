# Passability re-decode — findings

Date: 2026-10-21. Method: one contiguous linear decode of the whole passability
routine plus the walk-loop and mode-writer regions, then a raw byte scan of the
exe for writers of the mode bytes, then a re-read of every existing capture.
Supersedes the passability paragraphs in
`docs/phase4-implementation.md § CP4b` and its `RETRACTION` subsection: both
were partly right and both were missing the same piece.

Artefacts: `disasm/tile-art.tsv` (art-entry descriptions),
`tools/tile_atlas.py` (renderer), `tmp/tiles/` (PNGs, gitignored).

---

## F1 — the passability routine does not read the target tile

Decoded span: file `0x2623..0x287F` = runtime `0x2423..0x2680`, 605 bytes,
286 instructions. This is the full routine, not the `2423..242C` stub that
`asm/2423` declares.

There is exactly **one** call to `map_tile_ptr` (`call $0x52b3`) in the whole
span, at file `0x2666` (runtime `0x2466`). Its result is not tested. The
sequence around it is a **write**:

```
265A  mov [0x6a],al        ; DS:6A = x
265D  mov [0x23],al        ; map_tile_ptr x argument
2660  mov al,[0x6b]        ; DS:6B = y
2663  mov [0x24],al        ; map_tile_ptr y argument
2666  call $0x52b3         ; DS:6 -> tile cell
2669  mov al,$0x50
266F  mov [bx+si],al       ; store 0x50 into the cell
```

So the retracted claim "asm/2423 never reads a tile" was **correct about the
bytes**. The retraction was also correct that steps are rejected. Both were
right about their own evidence and neither found where the two meet.

## F2 — a second decision ladder, previously unread

At file `0x27C0..0x27F6` (runtime `0x25C0..0x25F6`), reached after the inline
BCD `-19` food drain on `DS:53..55`:

```
27C0  mov al,[0x29]
27C3  and al,$0x7f
27C5  cmp al,$0x60 ; jne 27CC
27C9      jmp $0x2877          ; mode 0x60 -> the 0x50 stamp path
27CC  cmp al,$0x00 ; je  $0x27ff   ; REJECT
27D0  cmp al,$0x08
27D2  je  $0x27ff                  ; REJECT
27D4  cmp al,$0x22 ; je $0x2804    ; ACCEPT
27D8  cmp al,$0x24 ; je $0x2804
27DC  cmp al,$0x26 ; je $0x2804
27E0  cmp al,$0x28 ; je $0x2804
27E4  cmp al,$0x2A ; je $0x2804
27E8  cmp al,$0x2C ; je $0x2804
27EC  cmp al,$0x2E ; je $0x2804
27F0  cmp al,$0x38 ; je $0x2804
27F4  cmp al,$0x16 ; jae $0x27ff   ; REJECT
27F8  jmp $0x2804                  ; ACCEPT
```

Accept target `0x2804` -> runtime `0x2604` -> `0x2664` (mask both coordinates
with `0x3F`, return 0). Reject target `0x27FF` -> runtime `0x25FF`
(`mov al,$0xff; ret`).

The ladder branches on `DS:29 & 0x7F` only. No tile value participates.

## F3 — where the mode byte comes from

The walk-loop arms load the argument at runtime `0x0962` (`mov al,[0x15]`) and
`0x09AF` (`mov al,[0x18]`), then `call 0x2423`.

Raw scan of the exe for direct writers (`mov [x],al` = `A2`, `mov [x],ax` = `A3`,
`mov byte [x],imm` = `C6 06`):

| byte | direct writers (runtime) |
| --- | --- |
| `DS:15` | `0x5B7A`, `0x5C52`, `0x6054` |
| `DS:18` | `0x5B86`, `0x5C5E` |
| `DS:29` | `0x20B7`, `0x2423`, `0x54E8`, `0x5A7A` |
| `DS:13` | ten sites, incl. `0x2699`, `0x26A2` |

The two `5Bxx/5Cxx` blocks are a table copy, runtime `0x5B71..0x5B92`:

```
mov al,[0x2df] ; mov [0x14],al
mov al,[0x2cb] ; mov [0x15],al     ; DS:15 <- DS:2CB
mov al,[0x2f3] ; mov [0x16],al
mov al,[0x2de] ; mov [0x18],al     ; DS:18 <- DS:2DE
mov al,[0x2e0] ; mov [0x17],al
mov al,[0x13]  ; mov [0x2df],al    ; DS:2DF <- DS:13
```

**`DS:2CB`, `DS:2DE`, `DS:2E0`, `DS:2F3` have no direct writers anywhere in the
exe.** They are table entries filled by an indirect store or a block read, and
that is where the tile dependence has to enter. The static route ends here:
finding an indexed writer by byte pattern alone is guesswork.

Note `DS:29` has four writers, so it is shared scratch, not a dedicated mode
slot. Calling it "the travel mode" in `state.h` is not supported.

## F4 — DS:13 is the player stamp, not terrain

`DS:13 = 0x78` in every in-world sample: `create-test-live`, `play-test-live`,
`baseline-fight`, and all 151 turns of the `vga-test` recording. In
`create-test-live` the player stood on tile `0x0C` while `DS:13 = 0x78`. So
`DS:13` is the sprite stamped into the map, not the terrain under it, and the
`0x28/0x26/0x24/0x22` arms of the first ladder are never taken on foot.

## F5 — create-test-live is a clean controlled experiment

Same session, same character, `DS:49/4A = 2/0` unchanged, `DS:13 = 0x78`
throughout. The east step onto tile `0x00` was rejected with
`--INVALID MOVE!`; five south steps onto `0x0C` were accepted, and the final
snapshot is at `(20,25)`. The only input that differed was the tile byte.
**The decision is tile-dependent and provably not `DS:13`-dependent.**

## F6 — tool defect: redecode.py swallows code as a string

`tools/redecode.py` printed 21 bytes at file `0x27D2..0x27E6` as
`STR 't+<"t,<$t(<&t$<(t <*t'`. They are real code: `74 2B 3C 22 74 2C 3C 24 ...`
is `je rel8` / `cmp al,imm8` pairs, and the `je` displacements are what produce
the accept and reject targets in F2. The printable-run heuristic fired inside a
code region.

Consequence: any `STR` line in `disasm/redecoded/*.txt` that sits inside a known
code span must be re-checked before its output is cited. This is the same class
of failure as `cfg_printed.py` reading discovered blocks — a tool returning a
plausible answer to the wrong question.

## F7 — the fight recording cannot settle this

In the 151-turn `vga-test` recording `DS:00` spans only `4..9` and `DS:01` is
constant at `11`. Those were not the overworld position during that session.
Tile under player across the whole recording is only `{0x08, 0x0C}`.

---

## F8 — the ladder is a TILE table, not a mode table (owner-confirmed, one contradiction open)

The label "travel mode" for `DS:29` was an early static guess and it is what hid
this. The ladder's accept set — `0x22,0x24,0x26,0x28,0x2A,0x2C,0x2E,0x38` plus
everything below `0x16`, with explicit rejects for `0x00` and `0x08` — is not a
plausible set of vehicle codes. It is a plausible set of tile IDs.

Read as tile bytes against `mapx20`, and combined with the owner's confirmation
that the diamond-lattice art (`0x04`) is the mountain:

| tile byte | art | meaning | ladder | cells in mapx20 |
| --- | --- | --- | --- | --- |
| `0x00` | `0x00` magenta dashes | water | REJECT | 2770 |
| `0x08` | `0x04` diamond lattice | **mountain** | **REJECT** | 582 |
| `0x0C` | `0x06` | land | accept | 461 |
| `0x10` | `0x08` arch | gate/pass | accept | 250 |
| `0x04` | `0x02` sparse dots | scrub | accept | 27 |
| `0x18/0x1C/0x20` | `0x0C/0x0E/0x10` figures | standing figures | REJECT | 1 each |
| `0x24/0x28` | `0x12/0x14` ship, rocket | boardable / enterable | accept | 1 each |

Evidence for the model, by grade:

* **observed** — diamond lattice is mountain (owner, 2026-10-21). East step from
  `(20,20)` onto tile `0x00` blocked; five south steps onto `0x0C` accepted,
  final position `(20,25)` (`create-test-live`).
* **measured** — the ladder's accept and reject sets (F2). Tile counts and
  spatial coherence: mean same-tile orthogonal neighbours is 3.62 for `0x00`,
  2.81 for `0x08`, 2.75 for `0x0C`, 1.94 for `0x10` — water and mountains form
  contiguous regions, not noise. Rendering `mapx20` under the model gives an
  archipelago with mountain ridges, and the row at `y=20` reads
  `^.....[~~~~~~~~~`, i.e. player on land with water immediately east.
* **corroborated independently** — `docs/phase4-implementation.md` recorded
  mapx30's tile ids as `{0, 4, 6, 8, 10, 16}`. Those are ART indices, and
  `map_byte >> 1` reproduces exactly that set from mapx30's raw bytes. Derived
  by a different route, on a different sector.
* **inferred** — that `DS:29` carries the destination tile byte rather than a
  mode, and therefore that the tile read happens upstream in whatever fills
  `DS:2CB`/`DS:2DE` (F3). This is the load-bearing step and it is NOT proven.

**One contradiction that must be resolved before this is called settled.**
`engine/src/core/view.h` makes two claims that cannot both hold:

1. "the fill loop computes it as `(map_byte >> 1) & 0xFE`" — implies `art = map_byte >> 2`
2. "its staging byte is `0x78` (120), which halves to art 60, a humanoid figure"
   — implies `art = map_byte >> 1`

If (1) were true the player cell's staging byte would be `0x3C`, not `0x78`.
Claim (2) is the one the owner's screenshot confirmed, and it is the one this
model needs, because the stamp `0x78` halving to art `0x3C` (a humanoid) is
exactly what the atlas shows. But (1) is recorded as a fill-loop decode and has
not been re-checked.

The model also resolves a long-standing ambiguity in favour of the table: the
kickoff called art `0x00` "water (magenta dashes)" while renders made the magenta
field look like walkable land, and T1 noted "the passability table is the
arbiter, not the label". Under this model `0x00` is rejected, so magenta is
impassable, i.e. water. That matches the owner being blocked walking east into it.

---

## F12 — ART INDEX IS `map_byte >> 2`. THE WORLD WRAPS. 2026-10-21.

Settles the `view.h` contradiction that blocked this for two sessions, and adds
a coordinate-model fact that broke an automated walk.

### The transform

Every byte that ever appears in a sector map grid is a multiple of 4, spanning
`0x00..0xFC` - exactly 64 values - and the tile atlas has exactly 64 entries.
Therefore:

    art_index = map_byte >> 2

Not `>> 1`. `engine/src/core/view.h` contains both claims and the `>>1` reading
is the wrong one. The proof is threefold and independent:

1. **Inventory.** 64 distinct grid bytes, all `≡ 0 mod 4`, matching 64 art
   entries one-for-one. `>>1` would need 128 entries.
2. **Rendered letters.** Drawing the probe map with `art = byte >> 2` puts the
   atlas A-Z glyphs (art `0x20..0x39`) exactly where map bytes `0x80..0xE4` sit.
   With `>>1` they would not line up.
3. **Named terrain.** `0x00>>2=0` water, `0x08>>2=2` grass, `0x0C>>2=3` forest,
   `0x10>>2=4` mountain - and art `0x04` is the white diamond lattice the owner
   identifies as the mountain. Consistent with F11.

This also explains the shape of the F8 error: F8 claimed the mountain was byte
`0x08` while naming art `0x04`. The art was right and the byte was wrong, which
is exactly what a `>>1` vs `>>2` slip produces. F8 is dead, F11 supersedes it.

### The `0x1A` oddity is not terrain

Earlier sweeps noticed byte `0x1A` appearing exactly once in 33 of 33 sector
maps and it was briefly treated as a rare tile. It is not in the grid at all.
Sector map files are 4224 bytes: a 4096-byte `64x64` grid plus a 128-byte tail,
and `0x1A` is the first byte of that tail in every file. It is a header marker.

### The world is toroidal

With the player parked at `x=0`, the left edge of the viewport displays map
`x=55..63` - the high bytes `0xDC..0xFC`, which render as the atlas `X Y Z`
glyphs. The viewport wraps rather than clamping at the sector edge.

Consequence for automation: any scripted walk that assumes a flat grid and
starts near `x=0` or `y=0` will desynchronise silently. Start probe walks near
the middle of the map, away from a wrap boundary.

### Lead, not a result: blocked steps may still cost food

During a monitored walk, one rejected step (into `0x00` water, position
unchanged) was accompanied by `DS:53..55` changing `04 00 00 -> 03 99 81`. If
`0x53..55` is the food field, a blocked move still drains food, which answers
open question 3 of the capture spec. **Unconfirmed:** single sample, and the
field identity was assumed from `state.h` rather than re-derived in that run.
Needs a clean before/after on a known field before it becomes a finding.

### Also observed in the same trace

`DS:26` flips `00 <-> FF` on accepted movement - consistent with its `moved`
label in `state.h`. `DS:15` flips `00 <-> 84` between two grass tiles, so it is
not a terrain type and the `mode_walk` label should be treated as unproven.
No monster or encounter appeared in the sampled window.

---

## F11 — FOUR TILE BYTES PROVEN BY WALK, WITH NAMES. 2026-10-21.

This is the first passability knowledge in the project derived from ground truth
rather than inferred from a decode. Two independent lines met in the middle.

**Owner ground truth from the live frame.** A working screenshot (needs the
patched build, see `tooling-procedures.md`) was taken with the character at
`(20,20)` in sector 20, and the owner named the terrain in four directions:
water to the right, grass above, forest below, mountain far left. Those
directions map onto `mapx20` bytes directly, because the earlier walk had
already established that up = `y-1`:

| direction | byte | owner's name |
| --- | --- | --- |
| player `(20,20)` | `0x0C` | forest |
| up `(20,19)` | `0x08` | grass |
| down `(20,21)` | `0x0C` | forest |
| right `(21,20)` | `0x00` | water |

**Byte-to-colour correlation, computed not eyeballed.** Classifying each of the
200 viewport cells by dominant colour and searching for the viewport origin that
maximises agreement gives **199/200 purity**, which is not coincidence:

| byte | colour | terrain |
| --- | --- | --- |
| `0x00` | magenta | water (wavy purple) |
| `0x08` | cyan | grass (small dots) |
| `0x0C` | cyan | forest (bigger dots) |
| `0x10` | white | mountain (diamond lattice) |

That fit also places the player at screen cell `(9,5)`, confirming the existing
`(9,5)` viewport claim. An earlier eyeball reading of "column 6-7, not centred"
was wrong and is retracted.

**The mountain, proven by walking.** Row `y=20` runs forest `x=15..20`, grass
`x=12..14`, mountain `x=11`. Walking west nine steps from `(20,20)`, same
session, same character, same key, same direction:

```
1..5   forest  0x0C  MOVED
6..8   grass   0x08  MOVED
9      MOUNTAIN 0x10  *** BLOCKED ***   destination (11,20)
```

Eight successes immediately before one failure, with the only change being the
destination byte, is a controlled comparison. So:

| byte | terrain | passability | how |
| --- | --- | --- | --- |
| `0x00` | water | **blocks** | blocked step at `(20,17)`; also the tile named water to the right |
| `0x08` | grass | passes | walked onto and across |
| `0x0C` | forest | passes | five consecutive steps |
| `0x10` | mountain | **blocks** | blocked at `(11,20)` above |

`engine/src/game/overworld.c` `u2_tile_passable()` previously accepted `0x10`
through its default-passable fallback. Now rejects it, with measurement behind
it rather than a guess.

**Two cautions.** Grass and forest are both cyan-dominant and differ only by
pattern, so any tool that reads terrain off a screenshot by colour alone will
conflate them; the byte is the only clean discriminator. And this is four bytes
out of 256 - the *rule* is still not known, only four of its instances. The
ladder at runtime `0x25C0` accepts `0x10`, which is further proof it is not the
passability gate.

---

## F10 — F8 IS REFUTED. Live measurement 2026-10-21, patched run, sector 20.

A live session settled this. Character `TEST` loaded at `(20,20)` in sector 20,
`DS:13 = 0x78` throughout, and three deliberate steps were taken, each confirmed
by reading `DS:00/DS:01` afterwards:

| step | destination tile | outcome |
| --- | --- | --- |
| (20,20) -> (20,19) | `0x08` | **moved** |
| (20,19) -> (20,18) | `0x08` | **moved** |
| (20,18) -> (20,17) | `0x00` | **blocked**, position unchanged |

Consequences, in order of importance:

1. **Tile `0x08` is passable.** The engine's original measurement was right and
   F8 was wrong. `0x08` is therefore not the mountain.
2. **`DS:29` is not the destination tile byte.** If it were, the ladder at
   runtime `0x25C0` would have rejected `0x08` twice. It did not. After the
   sequence `DS:29` read `0x1C`, a value the ladder rejects, while the character
   had just moved freely — which independently confirms F3's note that `DS:29` is
   shared scratch, not a passability input.
3. **The ladder at runtime `0x25C0..0x25F6` is not the tile passability gate.**
   It is real code and was transcribed correctly, but it decides something else.
   F2 stands as a description and dies as an explanation.
4. **Water `0x00` blocks, confirmed a third time, live, in a controlled
   comparison.** The mechanism (move, test, undo, echo) is re-confirmed working.
5. **The rule is still unknown.** Since the routine demonstrably does not read the
   tile (F1) and the tile demonstrably decides the outcome (this), the decision
   must be made by whatever fills `DS:2CB`/`DS:2DE` upstream — exactly where F3
   left it. That is now the only surviving candidate, and it is where to look.

Not settled by this run: whether a blocked step costs food. Food bytes changed
across the sequence but were not sampled immediately before and after the single
blocked step, so the change cannot be attributed. Question 3 of the capture
remains open.

Also newly established, and it changes how any future capture must be driven:
see `docs/tooling-procedures.md` — xdotool cannot deliver keys on this host
because no window manager is running, and the working input path is the
emulator's own MCP `send_keyboard_key`.

---

## F9 — CONTESTED: the engine measures tile 0x08 as passable

F8 assigns the mountain to tile `0x08`, because the ladder rejects `0x08` and
`0x08 >> 1` is art `0x04`, the diamond lattice the owner identified as mountain.
`engine/src/game/overworld.c` `u2_tile_passable()` says the opposite:

```c
if (t == 0x00) return 0;                 /* water: measured blocked */
if (t == 0x08 || t == 0x0C) return 1;    /* measured passable */
```

with the header comment "Live 2026-10-21: tile 0x00 rejected 22 times on foot;
0x08 and 0x0C stood on repeatedly" and "open: which tile id is mountain. It is
NOT 0x10".

Both cannot hold. Assessment:

* The engine's "stood on 0x08 repeatedly" traces to the `vga-test` fight turns,
  and F7 established that recording's `DS:00`/`DS:01` were NOT the overworld
  position (`x` spanned only 4..9, `y` constant at 11). Deriving a tile under the
  player from those bytes was invalid, and the engine inherited the conclusion.
* F8's `0x08` = mountain is an inference from the ladder plus the art transform,
  not an observation.
* So the conflict is between a bad dataset and an unproven inference. It is NOT a
  case of bytes contradicting a hypothesis, and it is NOT resolved by deferring
  to the existing code.

Independent evidence that F8 is at least incomplete: applying the ladder across
every `mapx*` file gives sensible aggregate behaviour for the five common tiles
(`0x00` reject over 17,403 cells, `0x08` reject over 11,748, `0x0C`/`0x10` accept)
but produces impossible geography in 12 sectors — `mapx24`, `mapx25`, `mapx34`,
`mapx35`, `mapx44`, `mapx45` come out 0.3-0.7% walkable with longest walkable run
of 1, and `mapx15`, `mapx23`, `mapx33`, `mapx70`, `mapx93` are 1.7-5.4% walkable.
Some are the known `*x4`/`*x5` different-renderer family; `mapx15`, `mapx23`,
`mapx33`, `mapx70`, `mapx93` are not. A rule that makes a real overworld sector
98% impassable is wrong or missing a case.

**Status: F8 is a hypothesis under active contradiction. Do not implement
impassable terrain from it beyond water, which is independently proven.**

---

## What is and is not safe to implement for passability

| needed | status |
| --- | --- |
| bounce mechanism | proven — move, test, inverse undo, echo; already implemented |
| water blocks on foot | proven — tile `0x00`, 22 live rejects, uncontested |
| mountain blocks on foot | CONTESTED — F8 says `0x08`, the engine says `0x08` is walkable |
| the full blocked set | unknown — `0x18/0x1C/0x20` rejects are unverified inferences |
| the rule's input | inferred, not proven — see F8 |

---

## Open: one Spice86 session answers five questions

Scoped 2026-10-21, amended 2026-10-22. All cheap, all from a single session in
sector 20 with a fresh character. Owner must do the walking; the reads are passive.

> **Why this was amended.** The original heading said "three" and listed four, and
> question 2 had already been overtaken: F10 refuted F8 live on 2026-10-21, and
> overnight T8 then killed the same premise statically. Running the old spec would
> have spent the session answering a question nobody still holds. Keep the same
> breakpoint and the same register dump — they were right — but ask the post-T8
> question.

1. **Settle the `view.h` contradiction.** Dump the staging buffer at `DS:272`
   (256 B) alongside the sector map, and compare. If `staging == map_byte` then
   claim (2) holds and `art = map_byte >> 1`. If `staging == (map_byte>>1)&0xFE`
   then claim (1) holds, `art = map_byte >> 2`, and F8's mountain assignment is
   wrong and must be re-derived.
2. **What sets the mode byte the ladder actually tests?** *(rewritten 2026-10-22)*
   It used to ask whether the ladder's input is the destination tile. That is
   settled, and the answer is no: `asm/248B→2495→24B1` reads no tile and reaches
   `asm/24B5` only when `[DS:29]&0x7f == 0x2e` (measured at fight turn 2909, where
   `[DS:15] = [DS:18] = 0x2e`). There is no tile-vs-`AL` comparison left to make.
   The live question is: **what writes `0x2e` into the mode slot, and is that write
   a function of the destination tile at all?** Break at runtime `0x2423`; dump
   `AL`, `DS:13, DS:15, DS:18, DS:29, DS:2CB, DS:2DE` and the destination cell's
   tile byte — on one ordinary step **and one step onto a force field**.
   Note the old "one accepted and one rejected step" pair may not be obtainable on
   foot at all: the CP4b re-decode found `asm/2423` never rejects an overworld foot
   step, so use ordinary-vs-field instead.
   *Success:* a reproducible mapping from the tile/sector inputs to the value in
   `DS:29`. *Failure:* if `DS:29` is identical on both steps, the mode is not
   terrain-derived and C5 must be modelled as a non-spatial hazard rather than a
   tile property — which is also a usable answer.
3. **Does a rejected step cost food?** Both inline `-19` drains sit BEFORE the
   reject test (file `0x2799` and `0x2826`), which implies walking into a mountain
   burns 19 food like a real step. Inferred from block ordering only, and the
   on-foot path enters `0x2775` which `sub_2626` also calls, so that region's
   boundary is still imperfectly linearised. Read `DS:53..55` before and after one
   deliberately blocked step.
4. **Settle F9 — walk into a mountain and read the tile byte at that cell.** This
   is the single datum that decides whether the mountain is `0x08` (F8) or
   something else (the engine's current code). It also gives the first honest
   measurement of a blocked tile other than water, which the whole model has been
   missing. Ask the owner to stand next to a visible mountain, note the screen,
   then read `DS:00`, `DS:01`, the destination cell and `AL` at the break.
5. **Attribute the indirect writers of `DS:2CB`/`DS:2DE`.** This is F3's open link
   and, since T8, the only remaining route to a C5 trigger. Static search cannot
   attribute them: the stores are indirect, no static write site names the
   destination, and `0x2e` occurs 0 times in `mapx00` — which is exactly why it is
   not statically derivable. At the same break, capture both bytes before and after
   each of: entering a sector, crossing a sector boundary, boarding and alighting a
   vehicle, and stepping onto a force field. Whichever event changes them owns the
   mapping. If the tracer can catch the instruction pointer at the moment of
   change, record it — that single address closes F3, C5 and T8 together.

---

## Next step

The static route is exhausted for the tile question. One breakpoint capture
closes it: break at runtime `0x2423`, dump `AL, DS:13, DS:15, DS:18, DS:29,
DS:2CB, DS:2DE` and the target cell tile, on one accepted and one rejected step.
If `DS:2CB`/`DS:2DE` differ between the two, the table is terrain-indexed and F3
completes. If they do not, the reject comes from the `call 0x2575` return value
and the search moves into the `DS:580` dispatch.

> **Amended 2026-10-22.** Keep the breakpoint and the dump list; the framing above
> predates F10 and T8 and is now wrong in two ways. `AL` is not a tile byte, so
> "if `AL == destination tile`" is not a live test. And an accepted-vs-rejected
> pair may not exist on foot, because the CP4b re-decode found `asm/2423` never
> rejects an overworld foot step. Use **ordinary step vs step onto a force field**
> as the discriminating pair, and read question 5 above — attributing
> `DS:2CB`/`DS:2DE` is now the whole of C5.

## F13 - the 64 art entries are not 64 terrains; A-Z are shop and sign tiles

**Grade: recalled (owner-reported), 2026-10-21.** Recorded as data, per the rule
that an owner observation outranks an agent inference.

The letters `A`-`Z` (art `0x20`-`0x39`, map bytes `0x80`-`0xE4`) are used **in
towns for signs and shops**. They are **impassable**, but `T` (talk) still works
with a shopkeeper standing on the other side of one. So an `A`-`Z` tile is a
solid fixture you transact through, not a wall you walk into and not a creature
you walk onto.

This reframes the whole table. The 64 entries split into ground, structures,
creatures, borders and the letter fixtures; only a handful are ground at all.
Measured occurrence across the 33 sector maps supports it: only `0x00`, `0x08`
and `0x0C` appear in 25 or more sectors, while 32 of the 64 values appear 50 or
fewer times in total. See `disasm/tile-art.tsv`.

**It also invalidates the first passability sweep.** All 15 tiles that run
measured were bytes `0x84`-`0xBC` - letters `B` through `P`. The run reported
`B`, `D`, `H`, `N` and `O` as passable, which F13 says is wrong. The mechanism is
a known harness defect rather than a mystery: a probe step is `Right`, `Up`,
`Down`, and if both the `Up` and the following `Down` are lost to the read-pause
race the player never leaves the corridor and the tile is recorded as passable.
Two dropped keys in a row therefore produce a false `pass`, which is exactly the
error direction observed. The sweep needs a per-step retry and re-verification
before any letter result is trusted.

**Open tension worth keeping, not smoothing over.** `0x80` (`A`) occurs 15651
times across 23 sectors, about 11.6% of all map tiles, and `0xE0` (`Y`) occurs
1050 times. Rare letters like `J`, `X` and `Z` at 4, 6 and 10 are what individual
signs would look like; `A` at that volume is not. Either town sectors are dense
with letter fixtures, or `A` and `Y` carry a second use beyond signs. This is a
question about the data, not a reason to discount the report.

**Consequence for the engine.** Passability cannot be one boolean per tile byte.
`T`-through-solid is a separate interaction predicate from walkability, and at
least the letter range needs both: not walkable, talkable-through. Any engine
model that stores only `passable(tile)` will be unable to reproduce a shop.

## F14 — THE GATE VARIABLE IS `map_byte >> 1`, AND THE RULE IS A RANGE PLUS A SHORT LIST

Found 2026-10-29 by joining two headers that had never been read together: `asm/2FAD_vehicle_board_dispatch`
(which already recorded, as RESOLVED, that `[DS:14] = map_byte >> 1`, measured on 53 of 54 walk samples:
`0x0C->0x06`, `0x5C->0x2E`, `0x70->0x38`, `0x08->0x04`) and the ladder at `asm/25C0..25F6`, which tests
`[DS:29] & 0x7F` against exactly that value space.

**This retroactively refutes F10's refutation of F8.** F10 rejected the tile interpretation because
"if DS:29 were the tile byte the ladder would have rejected 0x08 twice; it did not". But the ladder
never sees `0x08` — it sees `0x08 >> 1 = 0x04`, which is below `0x16` and therefore accepted. The
refutation, the F9 "CONTESTED" flag and F1's "does not read the target tile" all rest on assuming the
gate variable was the raw tile byte. It is the tile byte shifted once.

### The on-foot ladder, in byte order

```
al = DS:29 & 0x7F                  ; == destination map byte >> 1
if al == 0x60: -> 0x2877           ; stamp-path divert, not a verdict
if al == 0x00: REJECT              ; map 0x00  open water
if al == 0x08: REJECT              ; map 0x10  mountain
if al in {0x22,0x24,0x26,0x28,     ; map 0x44,0x48,0x4C,0x50  the four vehicle tiles
          0x2A,0x2C,0x2E,0x38}: ACCEPT
                                   ; map 0x54,0x58,0x5C(force field),0x70(town paving)
if al >= 0x16: REJECT
else:          ACCEPT              ; every map byte below 0x2C
```

So the rule is **not a per-tile table**. It is: accept everything under `0x2C` except water and
mountain, plus eight named bytes, reject the rest. That is why a hand-maintained default-deny table
keeps contradicting measurements — it is the wrong shape, not merely missing rows.

### Every live measurement in this file agrees, with no exceptions

| map byte | `>>1` | ladder | measured |
| --- | --- | --- | --- |
| `0x00` water | `0x00` | reject | 22 live rejects (F11) |
| `0x04` shallows | `0x02` | accept | re-proven live, sector 10 |
| `0x08` grass | `0x04` | accept | walked, F11 |
| `0x0C` forest | `0x06` | accept | five steps, F11 |
| `0x10` mountain | `0x08` | reject | blocked at (11,20), F11 |
| `0x5C` force field | `0x2E` | accept | g29-field, six crossings |
| `0x70` town paving | `0x38` | accept | owner, standing in town |

### Travel modes, and their separate arms

`[DS:13]` is the travel mode, and `asm/253B_food_mode_dispatch` branches on it before the ladder:

| mode | `[DS:13]` | arm | tile rule | food per step |
| --- | --- | --- | --- | --- |
| on foot | `0x78` | `asm/2575` -> `asm/2599` | the ladder above | −19 |
| horse | `0x22` | `asm/2557` -> `asm/2626` | **the same ladder as foot** | −38 |
| ship | `0x24` | `asm/2619` | `DS:29 == 0x00` or `0x80` only | 0 |
| plane | `0x26` | `asm/2604` | accepts everything **except mode `0x06`** (map `0x0C` forest) | −38 |
| rocket | `0x28` | `asm/25F8` | **accepts everything** | 0 |

**Corrected 2026-10-29 against the arm bodies, one hour after this section was first written.** The
first version said the plane "accepts everything". It does not. `asm/2604` is:

```
call L_002826          ; the mounted drain, -38
cmp $0xff,%al
je  reject             ; food underflow -> reject path
mov 0x29,%al
and $0x7f,%al
cmp $0x6,%al
je  reject             ; mode 0x06 == map 0x0C == FOREST is the only refusal
jmp L_002804           ; accept
```

So the airborne rule is "fly over anything except forest", which is a real and surprising rule that
the summary table flattened. Reading the header's one-line arm description instead of the body is
what caused it — the same mistake pattern this file already documents at F6 and F10.

`asm/2557` (horse) is a **delay loop**, not a tile rule: nested `dec %si / jne` over `0x20` and a
`%di` counter, then `jmp L_002826`. Horse therefore walks exactly where a footman walks and pays
double. That matters for the engine: horse needs travel-mode state and a food cost, not a second
passability table.

`asm/25F8` (rocket) is a single instruction, `jmp L_002804` — unconditional accept, and it never
reaches a drain, which is why the rocket is free.

Vehicle tiles, from `[DS:14] = map_byte >> 1` inverted: horse `0x44`, ship `0x48`, PLANE `0x4C`,
rocket `0x50` — arts `0x11/0x12/0x13/0x14`, corroborated three ways per the `2FAD` header.

The plane's ground/air distinction is real and is a *state*, not a tile: `asm/38B0` (`cmd_L`, LAUNCH)
tests `[DS:13]` for `0x26` and `0x28`, and landing is gated separately — `LAND PLANE.` is accepted only
on tile `0x08` grass, anything else prints `LAND--NOT HERE!!!!!` and inertial flight continues. Both
branches executed in `captures/spice86/flight-launched-live`.

### Grades, because this is a synthesis and not one measurement

- **Bytes**: the ladder's comparisons and branch targets, the mode dispatch arms, the landing gate.
- **Measured**: `[DS:14] = map_byte >> 1` (53/54 samples), every row of the agreement table above,
  the food figures, both plane-landing branches.
- **Inferred**: that the ladder is reached identically on every mode arm. The arms are separate
  routines and only the foot path was traced end to end.

### Open, and it matters before wiring

`asm/2619` (ship) reads `[DS:29]` and accepts `0x00` **and `0x80`**. `0x80` is not reachable as
`map_byte >> 1` for any byte in a mapx file, and this arm does not apply the `& 0x7F` mask the foot
ladder does. Either the ship arm sees a different quantity, or the high bit carries a second meaning.
**Do not guess it.** It needs one live sample: board a ship and read `DS:29` and the tile under the
player together.
