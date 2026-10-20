# CP4b kickoff — status band, SDL text screens, and the two display paths

Paste this to start a fresh agent on the work left in CP4. It assumes CP4(a) is
done: sector model, tile cache, viewport mapping, framebuffer, SDL window, all
committed and green.

## Read first

1. `docs/phase4-implementation.md` § CP4 — every proven fact with asm citations.
2. `docs/phase4-state.md` — resume notes and standing directives.
3. This file.

**Hard rule from `AGENTS.md`:** work only inside
`/var/home/paul/Projects/decompile-u2-v2/`. Never read sibling projects.

## The single most important thing to internalise

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

### 1. Status band (start here)

Draw `H.P.= / FOOD= / EXP.= / GOLD=` and `CMD:` in the bottom rows, via the
**text path** (`core/vram` + `seam_str_out_at`), not tiles. Values come from the
player record: `state.h` has `stat_*` and the BCD fields; the original keeps gold,
food and exp as packed BCD pairs, hundreds byte first (`u2_bcd16()`).

Reference for what it should look like: `captures/screenshots/move-after.png`
shows `H.P.=9997 FOOD=0359 EXP.=0007 GOLD=0000` and `CMD:`.

The map window occupies pixel rows 0..159; the status block is below it.

### 2. SDL text rendering

The SDL backend currently implements only `present_frame`; `cell()` is a no-op,
so title/menu/creation draw nothing in the window. To render the cell grid in
SDL, blit the **CGA ROM font** (8x8 for mode 4) into the framebuffer. The plan
already anticipated this at CP9: "Bitmap CGA font (open-licensed)". Source an
open-licensed 8x8 CGA font and add it as a build-time asset — it must not be
extracted from the game binary if a licensed substitute exists.

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
