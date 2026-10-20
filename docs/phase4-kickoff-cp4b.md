# CP4b kickoff — status band, SDL text screens, and the two display paths

> **Correction added after writing this file:** the "two display paths" claim in
> the title is **not established** — read the warning below before relying on it.
> The tile/map half is solid and verified against the original's pixels. The text
> half is not, and it gates the status band and the SDL text screens.

Paste this to start a fresh agent on the work left in CP4. It assumes CP4(a) is
done: sector model, tile cache, viewport mapping, framebuffer, SDL window, all
committed and green.

## Read first

1. `docs/phase4-implementation.md` § CP4 — every proven fact with asm citations.
2. `docs/phase4-state.md` — resume notes and standing directives.
3. This file.

**Hard rule from `AGENTS.md`:** work only inside
`/var/home/paul/Projects/decompile-u2-v2/`. Never read sibling projects.

## ⚠ The text path is NOT settled — and as of 2026-10-20 it no longer blocks us

**Owner decision: we may render text our own way.** The requirement is readable
text in the right place with the right values, not a reproduction of 1983 BIOS
plumbing. Phase 3 was the byte-matching work and it is signed off; Phase 4 is a
behavioural reconstruction, so the mechanism is an implementation choice.

This demotes "resolve the text path" from blocker to curiosity, and it removes the
font-licensing problem: see task 2, where the recommended route is an
engine-authored 8x8 bitmap font committed in the repo.

**The one distinction to keep.** Mechanism is ours; observable output is not.

- **Ours to choose:** how a string becomes pixels for the status band, menu and
  creation form.
- **Still faithfulness to content:** the site-name banners (`PORT BONIFICE`,
  `MUSEUM`) are drawn with the game's own custom A-Z tile letters (art 32-57,
  including the Q-as-vertical-bars quirk). Those are things the player sees, so
  use the real tile letters there, not our font.
- **Still required:** the 40x25 grid, the message window at rows 20-23 with its
  scrolling behaviour, and the status values as packed BCD.

### Background: why the earlier claim was wrong (kept so nobody re-derives it)

An earlier draft asserted that text goes through INT 10h teletype into text-mode
video memory. That cannot be right as stated: the game sets video mode 4
(320x200 graphics, `asm/4A3E`), and in a graphics mode there is no hardware text
path — teletype writes to text-mode memory that is not being displayed.

The more likely reading, still unverified: the 40x25 grid is the game's own
software text layer composited into the graphics framebuffer (320/8 = 40 columns,
200/8 = 25 rows), which is consistent with the row-clear loop printing 40 spaces
and the margins being 0x26/0x28.

What is actually known:

- `asm/51EB_str_out_at` saves DI/SI to `DS:0x2E/0x2F` and tail-calls
  `str_out_core` at runtime `0x51FD`. That is a fact.
- The seam map labels `str_out_core` as "INT 10h AH=02 cursor set" and `char_out`
  as "INT 10h AH=01h". **AH=01h is set-cursor-shape, not teletype, on a real
  BIOS** — so the seam labels are themselves imprecise and are not evidence of a
  mechanism.
- The 64-record tile table has A-Z (art 32-57) and **no digits**; there is no
  second tile batch (zero `04 10` headers in the 1312 bytes after the last
  record). So whatever draws digits is not in that table.
- `CS:0x48DC` alternates `B800+5k` / `BA00+5k`. In mode 4 `B800+5k` is graphics
  row k, but `BA00` = `B800:2000` = byte 8192 = row 102.4, **not row-aligned**.
  Still unexplained; the strongest sign the blit destination model is incomplete.

If anyone wants to close this out for its own sake, the probe is: trace what the
status-bar code (runtime `~0x4660`, file `0x4860`) stages for the digit `9`, via
the BCD printer at runtime `0x53B5` (not `0x55B5` — redecode prints *file*
addresses), and follow where that value resolves. Optional now.

## The text path, as previously believed (SUPERSEDED — see above)


**The original has two display paths, and they are not interchangeable.**

| path | used for | mechanism | engine equivalent |
| --- | --- | --- | --- |
| **tiles** | map, banners (`PORT BONIFICE`), figures | staging byte -> art record -> 16x16 2bpp blit | `core/view` + `core/frame` |
| **text** | status band, menu, creation form | `str_out_at` (runtime `0x51EB`) tail-calls `str_out_core` (`0x51FD`), which is **INT 10h teletype** into text-mode video memory | `core/vram` cell grid (40x25) |

Evidence for the text path: `asm/51EB_str_out_at.asm` saves DI/SI to `DS:0x2E/0x2F`
(cursor col/row) and tail-calls `str_out_core`. The seam map in
`src/platform/platform.h` already documents `str_out_core` as the INT 10h
cursor/teletype site. This also explains the long-unresolved `CS:0x48DC` table,
which alternates `B800+5k` / `BA00+5k` — the character plane and attribute plane
of **text mode 0**, both with an 80-byte row stride.

Do **not** try to render the status band from the tile table. There are no digit
glyphs in it. Verified: the tile table is exactly 64 records (index table at file
`0x7BC0`, 64 words, deltas exactly 66, `04 10` header on all 64), and the 1312
bytes after the last record contain **zero** `04 10` headers, so there is no
second batch of tiles.

## The tile table, settled

- `art = ch - 33` for `A`–`Z` (art 32–57). Confirmed glyph by glyph.
- **`Q` is drawn as vertical bars** (art 48). Not a decode error — it is how this
  font renders Q. Do not "fix" it.
- art 0 = water (magenta dashes), art 2 = grass (cyan dots), art 4 = mountains
  (white lattice), art 8 = castle (square open at the bottom), art 10 = the
  time/place sign, art 60 = player, 61–63 = armed figures, 23 = unused
  checkerboard, 29 = blank, 30 = solid white, 31/58/59 = border pieces.
- **The staging byte is `2 x art`.** `u2_view_at()` returns the staging byte
  (faithful to `DS:0x272`); `u2_view_art()` halves it. Getting this wrong doubled
  every tile — see "The doubling bug" below. Do not regress it.
- The player's staging byte is `0x78` (120), which halves to art 60. It is not
  out of range and it is not drawn by a separate sprite path.

## The doubling bug — the lesson, not just the fix

Every structural check passed: staging indices matched the game's own `DS:0x272`
buffer 199/200, the table had the right shape, the tile sheet decoded cleanly
with legible A–Z. The render looked plausible and was wrong on nearly every
tile. **The owner spotted it from a screenshot** by giving three cross-references
(grass shown as mountains, mountains as castle, castle as a humanoid), which made
the pattern `shown = 2 x correct` obvious. Water survived because `0 x 2 = 0`.

Lesson to carry forward: byte-level and structural evidence cannot validate a
*semantic* reading. When a render "looks plausible", that is not confirmation.
Get eyes on the picture early — the owner's, or a screenshot diff.

## Standing directives (owner)

- Zero game content committed. `original/`, `references/`, `captures/` are
  gitignored; the extractor reads the player's own files at run time.
- `references/u2upgrade/` is a **secondary source only** and explicitly not
  trusted — it is a fan upgrade, not the original.
- Validate against screenshots **as a test**, SKIP with a named reason when the
  images are absent.
- REA/Ghidra validate decode readings, not bytes. `asm/` is ground truth and is
  already byte-proven by `tools/check_func.py`.
- Never heredoc a non-trivial script; write a file, syntax-check, run the file.
  Never edit a file with a script — use the `edit` tool.
- Scratch files go in `/var/tmp`, never `/tmp` (`/tmp` is tmpfs = RAM here).
- `asm/` filenames are **runtime** offsets; bytes are at **file = runtime + 0x200**.
  The `L_00xxxxx` labels inside them are file offsets. Getting this backwards once
  produced a plausible-looking decode of the wrong region.

## Environment facts

- Host `ai` / `ai.lan`, Bazzite 44 (immutable ostree). `dnf install` is not the
  path for system packages.
- **SDL2 2.32.74 installed via `brew`** (`/home/linuxbrew/.linuxbrew`). Use
  `sdl2-config --cflags --libs`. `SDL_GetRendererName` is absent from these
  headers; use `SDL_GetRendererInfo`.
- SDL works from this shell only with `XDG_RUNTIME_DIR=/run/user/1000` and
  `WAYLAND_DISPLAY=wayland-0` (the session is inside tmux, so these are unset).
  Video driver resolves to `wayland`, renderer `opengl`, audio `ok`.
- The agent shell has **no** `DISPLAY`/`WAYLAND_DISPLAY` by default.
- `make` = dependency-free C11 build (`u2`). `make sdl` = `u2-sdl` with
  `-DU2_HAVE_SDL`; the `*_sdl.c` files are empty without that define so the
  default build never needs SDL2.
- Run the map: `./u2-sdl --sdl --play-map --data-dir ../original --save-dir saves`
  (arrow keys move, ESC quits). Headless still works: `make test`.

## Known defects to fix

1. **SDL build ignores SIGTERM.** `asm`-irrelevant but real: `timeout` and
   `systemd stop` escalate to SIGKILL. A first attempt to handle
   `SDL_APP_TERMINATING` in `input_sdl.c` did not take effect — the process still
   needed SIGKILL. Debug it properly; do not guess again.
2. **Sector-edge crossing is refused, not implemented.** `asm/242D` / `asm/2434` /
   `asm/243E` handle `x,y >= 0x40`, but which sector digit moves and in which
   direction is not established. `u2_overworld_run` currently refuses the step.
   Tracing these is what turns "walk around a sector" into "walk around a map".
3. **`DS:0x372` semantics still open.** It is byte-identical to the masked
   staging buffer, so it is a copy of the staged frame (previous-frame damage
   tracking), **not** the "underlay layer" originally documented. The bit-7
   suppression rule cannot be validated from the capture; `u2_view_fill` passes
   `NULL` (draw everything), which is correct for a first frame.
4. **Map byte families.** `*x0` sectors are clean tile maps (max byte `0x4C`, no
   high-bit bytes). `*x4`/`*x5` sectors (`mapx15,24,25,34,35,44,45,85`,
   `MAPG15/44/45/85`) are half high-bit bytes and produce art indices > 63, so
   they are not drawn by this path — a different map type with its own renderer.
   CP5+, not CP4.
5. **`PICCAS` missing** from the shipped pack (present in `references/u2upgrade`,
   untrusted). One of six demo pictures cannot load from shipped content.

## Tasks, in order

### 0. Text mechanism — decided, no longer a blocker

Owner decision 2026-10-20: **render text our own way.** Readable, correctly
placed, correct values. Do not spend time re-deriving the original's text
mechanism before building the status band or the SDL screens.

Recommended route (see **Font licensing decision** below for the full analysis,
the rejected sources, and what bundling a copyleft or ShareAlike font would
require):

- **Use `dhepper/font8x8` (Public Domain)** for status, menu and creation text.
  Commit `font8x8_basic.h` or the needed subset as engine data; it is already C
  headers, 8 bytes per glyph row-wise, LSB = first pixel, covering U+0000–U+007F.
  Credit the author in `THIRD-PARTY-LICENSES` even though the licence does not
  require it.
- **A-Z for in-world banners and site names: the game's own tile letters**, art
  32-57 (`art = ch - 33`), extracted at run time from the player's executable.
  Nothing committed, no third-party right involved, and it is what the original
  displays. **Q is drawn as vertical bars** — do not "correct" it.
- Blit into `u2_frame`. One rendering mechanism for the framebuffer.

Cover at least ASCII 32-126: A-Z, a-z, digits, space and `= . : + - / ! ? , ( )`.
font8x8 gives all of these already.

### 1. Status band

Draw `H.P.= / FOOD= / EXP.= / GOLD=` and `CMD:` in the bottom rows using the
engine font from task 0. Do not attempt it from the tile table — there are no
digit glyphs there and verifying that cost real time.

Values come from the player record: `state.h` has `stat_*` and the BCD fields; the
original keeps gold, food and exp as packed BCD pairs, hundreds byte first
(`u2_bcd16()`).

Reference for what it should look like: `captures/screenshots/move-after.png`
shows `H.P.=9997 FOOD=0359 EXP.=0007 GOLD=0000` and `CMD:`.

The map window occupies pixel rows 0..159; the status block is below it.

### 2. SDL text rendering

The SDL backend currently implements only `present_frame`; `cell()` is a no-op,
so title/menu/creation draw nothing in the window. Render the cell grid by
blitting the engine-authored font from task 0 into the framebuffer.

## Font licensing decision (owner, 2026-10-20)

**Decision: Px437 is a visual reference only. Do not commit any Px437 data into
this repository.** Use the game's own tile letters for A-Z and author the
remaining glyphs ourselves. The reasoning is recorded below because the analysis
is subtle and a future agent will otherwise re-litigate it — and because the
owner may revisit the call later with this in hand.

### The candidates, assessed

- **scriven** (`github.com/smithkm/scriven`, **SIL OFL 1.1**) — licence is
  compatible with Apache-2.0 and it is includable in principle. But it is an
  outline pseudo-medieval / constructed-script font (Runic, Gargish, Ophidian,
  Cirth) with no 8x8 CGA bitmap variant, so it is the wrong tool for status text.
  It may be genuinely interesting later for Ultima's runic scripts; that is a
  separate decision, not this one.
- **Px437 / The Ultimate Oldschool PC Font Pack** (int10h.org, VileR) — has exact
  IBM CGA reimplementations including the 8x8 CGA font, i.e. the correct glyphs.
  Licensed **CC-BY-SA 4.0**. Not committed here; see below for what bundling would
  actually require, because the common shorthand ("ShareAlike is viral, can't
  touch it") is **wrong** and was stated wrongly in an earlier draft of this file.

### Why Px437 could legally be shipped — the accurate reading

ShareAlike in CC-BY-SA 4.0 attaches to **Adapted Material**: work you translate,
alter, arrange, transform or build upon. Including an **unmodified** file inside a
larger work is a **collection**, and the licence expressly allows a collection to
be distributed under the distributor's own chosen terms, provided the licence
notice and attribution for the included work are kept. So bundling the TTF
unmodified does **not** relicense this project's code.

Two further facts from the pack's own readme matter:

1. The author's copyright claim is scoped to the **files**, not the glyph shapes:
   *"The **font files in this pack** (TTF and FON remakes and enhancements) are my
   own work, hereby licensed under CC-BY-SA 4.0."*
2. He explicitly disclaims the underlying data: *"I do not claim any rights to the
   **original** raster binary data charsets, which this work is based on"*, and
   states that *"the raw bitmap typefaces are not copyrightable, unlike fonts in
   specific formats such as .fon and TrueType (which qualify as software)"*.

### The trap: what would actually cause infection

The route this project would most want — extracting glyph bitmaps and committing
them as a C header of pixel data — is the **adaptation** case, not the collection
case. Converting his TTF into committed bitmap arrays is transforming his
work-product, and ShareAlike would attach to that converted data. That is the
specific move to avoid, and it is exactly the shape of "just embed the font as a
header file" that a well-meaning agent would reach for first.

### If the owner later decides to bundle it anyway

These are the conditions that keep it a collection rather than an adaptation.
Treat them as mandatory, and get a real legal read (or an email to VileR, who is
approachable and has clearly researched the question) before doing it.

1. **Ship the file unmodified** — the original `.ttf` or `.fon`, byte-for-byte, in
   its own directory. Never convert it to a header, never subset it, never
   re-encode it into project-owned data. Subsetting and re-encoding are
   adaptations.
2. **Load it at runtime, do not link it in.** Read the file from the data
   directory and rasterise it; do not compile its contents into the binary.
3. **Keep the licence text with it** — a full copy of CC-BY-SA 4.0 alongside the
   file, unaltered.
4. **Attribution, exactly as the author requests**: credit the handle **"VileR"**
   plus a link to the int10h.org home page, in a `NOTICE` or `THIRD-PARTY-LICENSES`
   file that ships with the distribution and is visible in the app's about/credits
   screen. "Appropriate credit" is a licence condition, not a courtesy; missing it
   is the most likely way to breach this.
5. **Do not describe the font as project work** anywhere in the repo, docs, or
   commit messages.
6. **Resolve the `AGENTS.md` policy question first.** The project rule is stricter
   than the law: *"anything not compatible with Apache-2.0 must never be
   committed."* The FSF lists CC-BY-SA as incompatible with Apache-2.0. So even
   where bundling is legally defensible as a collection, it may still violate the
   repo's own rule. That rule is the owner's to interpret — an agent must not
   quietly waive it.

I am not a lawyer; the above is a careful reading of the licence and the author's
own stated position, not legal advice.

### The route chosen

**Primary: `dhepper/font8x8`, Public Domain.** Commit `font8x8_basic.h` (or the
subset we need) as engine data. It is already in exactly the required shape — C
header, 8 bytes per glyph, row-wise, least significant bit = first pixel — and
`font8x8_basic.h` covers U+0000–U+007F, i.e. all of ASCII. No ShareAlike, no
attribution obligation, no collection-versus-adaptation analysis to perform.

- Author: Daniel Hepper, derived from an earlier header by Marcel Sondaar citing
  "International Business Machines (public domain VGA fonts)".
- **Credit the author anyway** in `THIRD-PARTY-LICENSES` with a note that it is
  public domain. Not required by licence; required by good practice, and it makes
  the provenance auditable instead of mysterious.
- **Caveat, stated honestly:** this is the **VGA** 8x8 glyph set, not the CGA 8x8
  set, and its provenance line repeats the same "IBM public domain" claim that
  romfont's author openly doubts. Two mitigations: US law does not treat typefaces
  as copyrightable (VileR's research point), and unlike CC-BY-SA there is no viral
  clause to trip over even if the public-domain claim proved imperfect. Worst case
  it is an unlicensed bitmap set used for UI text, not a licence infection.
- **A-Z for in-world banners and site names still come from the game's own tile
  letters** (art 32-57, `art = ch - 33`), extracted at run time from the player's
  executable. Nothing committed, no third-party right, and it is what the original
  actually displays. Remember **Q is drawn as vertical bars** and must not be
  "corrected".

### Sources assessed and rejected

- **`spacerace/romfont`** — dumps genuine ROM fonts from vintage cards, including
  IBM CGA, so it has the most authentic glyphs. **Rejected: the repository has no
  licence file at all.** Silence means all-rights-reserved by default. It also
  ships ROM dumps from proprietary hardware that the author himself questions:
  *"qemu source comment claims this is public domain. I doubt IBM would release a
  font to public domain. Does this mean qemu... use a illegal copy?"* Do not
  vendor it, and do not treat its CGA dumps as free just because they are
  published.
- **SeaBIOS (`coreboot/seabios`)** — **LGPL-3.0 / GPL-3.0** per GitHub. Copyleft;
  cannot be committed into an Apache-2.0 project. Its 8x8 font also derives from
  the same disputed public-domain VGA claim. Rejected.
- **Px437** — CC-BY-SA 4.0; reference only, per the analysis above.
- **scriven** — SIL OFL 1.1, includable but the wrong kind of font entirely.

### Fallback if none of the above is acceptable

Author the ~40 missing glyphs (digits and punctuation) by hand as engine data
under Apache-2.0, using Px437's CGA 8x8 as a **visual reference only** — look at
it, do not copy its bytes. Roughly 40 glyphs x 8 bytes = 320 bytes. Zero licence
surface, and it is a few hours of work. This is the safe option, not the preferred
one, since font8x8 is already public domain and already in the right format.

Decide and record: does the SDL build render text into the same framebuffer as
the map (one composited frame), or a separate surface? One framebuffer is closer
to the original and keeps the screenshot test meaningful.

### 3. Splash, menu, character creation in SDL

`game/title.c`, `game/creation.c` and `game/status.c` already write to the cell
grid and are content-correct from CP1/CP3. They should need no logic change —
only the display path from task 2. Verify each screen renders in the window and
that the scripted tests still pass headless.

### 4. Then the CP4 gate

Owner walks around a map. Blocked on defect 2 (sector crossing) for a full walk.

## Useful tools

- `tools/extract_tiles.py` — proves and renders the tile table.
- `tools/proto_render.py` — Python prototype of the render chain.
- `tools/content_inventory.py --check` — game-data structural invariants.
- `tools/redecode.py --range <file_start>:<file_stop>` — continuous disassembly
  of a file range. **Use this whenever an `asm/` function file looks truncated or
  its listing overruns its declared length** — several CP4 breakthroughs came from
  re-decoding a range whose per-function split had cut one loop into pieces
  (`asm/5AE1..5B6C` is the example).
- `tools/check_func.py` — byte-identity of an `asm/` slice.

## Evidence kept for the writeup

`captures/screenshots/goof-tiles-doubled.png`, `.ppm`, and
`-window.png` — the doubled-tile render, kept so the writeup can show the before
and after side by side. Gitignored (game-derived art); never commit it.

## Test counts at handoff

CP4: 42 sector + 30 tile + 29 viewport + 24 framebuffer = 125 checks, plus the
end-to-end `--dump-map` render, cache bootstrap and byte-identity checks.
CP0–CP4 all green via `make test`.
