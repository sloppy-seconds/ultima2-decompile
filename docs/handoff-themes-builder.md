# Handover — theme builder: slice A, slice B, and the held slice C

> **Status, read before anything below.** This is a plan with measured ground under
> it, not a piece of work in progress. **Nothing here is built yet.** The facts in § 1
> and § 2 were measured on 2026-11-04 while committing the FM Towns crosswalk, and
> one of them **refutes a claim currently sitting in `engine/src/core/tiles_ega.h`**
> (§ 2.4) — that is the most valuable paragraph in this file and it should be
> checked and fixed before any of the code is written.
>
> HEAD is `c38eda3`. `make -C engine test` CP0–CP7 green. `tools/check_all.sh` has
> **two pre-existing red gates unrelated to this work** — `cmd_provenance_derived`
> and `xref_provenance` — which were already failing and are not yours to inherit.
>
> Prerequisite reading: `AGENTS.md`, then `docs/fmtowns-graphics.md` (the FM Towns
> format, the palette, and three refutations), then `docs/ega-graphics.md` and
> `docs/ega-graphics-plan.md` § 2 (the theme resolution order, which is `[LOCKED]`).

---

## 0. What is being asked for

One tool, `tools/build_themes.py`, that takes a list of source paths and emits a
single `themes/<name>/` tree in the fan pack's own layout, so the existing
`--ega-theme-dir` can point at it and Ctrl-T cycles across art that came from
three different places.

The three sources, and **what each actually contributes** — this is not obvious
and getting it wrong wastes a morning:

| source | contributes | does NOT contribute |
| --- | --- | --- |
| `references/u2upgrade/` | `EGATILES`, `EGATHEME.{10,ALT,C64}`, `CGATILES`, `PIC*.EGA`, `PIC*.IDX` | the Galaxy maps |
| `original/updated/` | the Galaxy maps `MAPG*`/`MONG*`/`TLKG*`, and the `PIC*-E` picture set in both CGA and EGA spellings, plus a patched `ultimaii.exe` | **`EGATILES` — there is no tile atlas in here at all** |
| `references/fmtowns/` | `GRAPH/*.TIF`, the FM Towns banks | anything the current theme format can hold (§ 4) |

`original/updated/` looks like an art directory and mostly is one, but the tile
atlas only exists in `references/u2upgrade/`. Confirmed by listing: `updated/`
holds `PICCAS`, `PICCAS-E`, `picdng`, `PICDNG-E`, … `u2ega.exe`, and no
`EGATILES`.

**`themes/` is gitignored** (owner ruling, 2026-11-04). It will hold extracted art
from the player's own media, same posture as `tmp/tiles` and `bestiary/cache/`.
Add `/themes/` to `.gitignore` as part of slice A, and say why in a comment —
this repo has a history of ignoring things for a reason and needing the reason
written down.

---

## 1. Why FM Towns cannot be "just another theme"

`EGATILES` is 8320 bytes = 65 × 128, a **headerless flat array** of 16x16 tiles
at 4bpp packed, high nibble = left pixel. There is no index table, no size field,
no palette field. It can express exactly one thing: "tile N lives at N × 128".

That works for the fan pack for one reason, recorded in `tiles_ega.h`: **EGA tile
N aligns 1:1 with CGA tile N**, proven by the A–Z letter tiles landing at indices
32..57 in both atlases. FM Towns has no such alignment — that is the entire reason
`disasm/fmtowns-crosswalk.tsv` exists. Four independent blockers:

1. **Alignment.** `art 0x0C` is `ENEMY2/16`, not tile 12. A flat array cannot
   carry an indirection.
2. **Set-valued mapping.** One DOS art index maps to a *run* of FM tiles (the
   animation pair). A flat array holds one tile per index. No frame list, no
   frame period.
3. **Tile size.** FM Towns is 32x32. `U2_TILE_EGA_STRIDE` is derived from
   `U2_TILE_W` and the SDL blit assumes 16x16.
4. **Palette.** FM Towns needs its own 8-entry table, and index 3 is black — not
   an EGA fact.

So FM Towns needs a **format v2**. Squeezing it into `EGATILES` would mean
resampling 32x32 down to 16x16 and throwing away the animation, i.e. paying the
cost of a port to get a worse version of art we already have.

---

## 2. Measured facts to work from

### 2.1 The existing theme contract

`engine/src/core/tiles_ega.c`:

- `theme_relpath()` — `"default"` → `"EGATILES"`; any other name →
  `"EGATHEME.<UPPERCASED>/EGATILES"`. Names are matched case-insensitively on
  purpose, because the pack ships `EGATHEME.10` and `EGATHEME.ALT` in different
  cases.
- `entry_to_theme()` — the inverse, so anything it produces is loadable.
- `u2_tiles_ega_next_theme()` — collects theme names, **sorts them alphabetically**
  so Ctrl-T order is directory order and not `readdir` order.
- `u2_tiles_ega_validate()` — the fail-fast `--ega` launch check. `--ega` is
  strict: a missing themes dir or a missing theme is a refusal, not a silent
  fallback.
- Resolution order is `[LOCKED]` in `docs/ega-graphics-plan.md` § 2: an explicit
  `--ega-theme-dir` is authoritative with **no fall-through**, so a wrong path is
  reported rather than papered over. Keep that property in anything you build.

### 2.2 What a theme directory actually contains

Measured by listing the shipped themes:

```
EGATHEME.10/    EGATILES 8320, EGACOLOR 32, PICDNG.EGA 64000, PICSPA.EGA 64000
EGATHEME.ALT/   EGATILES 8320
EGATHEME.C64/   EGATILES 8320, EGACOLOR 32, PICDNG.EGA 64000, PICSPA.EGA 64000
```

So a theme may carry **its own pictures** as well as its own tiles. A theme
builder that only copies `EGATILES` will silently produce a theme that looks
half-recoloured: tiles from the theme, pictures from the top level.

### 2.3 The FM Towns side, already committed

- Format and palette: `docs/fmtowns-graphics.md` § 2, § 3.
- Mapping: `disasm/fmtowns-crosswalk.tsv`, 64 rows, `art_index → BANK/tile[,…]`.
- Regenerate with `python3 tools/fmtowns_xwalk.py --export
  disasm/fmtowns-owner-mapping.json <out>`; validate with `--check <tsv>`.
- **The crosswalk is exactly the v2 `MAP.TSV`.** Do not invent a second mapping
  format. It already has the set-valued structure and a `source` column.
- Scope caveat that will bite: the crosswalk covers **overworld and towns only**.
  Dungeon, tower and the whole `PLAYER` bank are unmapped. A v2 theme built today
  is an overworld theme, and should say so in its manifest.

### 2.4 REFUTED — go and check this first

`engine/src/core/tiles_ega.h` currently states:

> the pack ships four interchangeable themes (default, 10, alt, c64), all the same
> format and size, **differing only in colour. None carries its own palette**, so
> the standard EGA RGB table in `core/frame.c` is used for all.

**Two of the three alternate themes do carry a palette.** `EGATHEME.10/EGACOLOR`
and `EGATHEME.C64/EGACOLOR` exist, are 32 bytes, and differ from each other.
`EGATHEME.ALT` has no `EGACOLOR`, so the claim is true for `alt` and false for
`10` and `c64`.

**Its layout is undecoded and you must not guess it.** 32 bytes for 16 colours
means 2 bytes per entry. Reading it as little-endian RGB555 produces nonsense —
`EGATHEME.C64` decodes to mostly `#78c018`, with the raw word `0f0f` appearing 8
times out of 16, which is not a C64 palette. The raw nibble pairs look more like
an index remap than an RGB table. Treat it as an open decode:

```bash
xxd references/u2upgrade/EGATHEME.10/EGACOLOR
xxd references/u2upgrade/EGATHEME.C64/EGACOLOR
```

This matters beyond tidiness: **v2 needs a palette field anyway**, so if
`EGACOLOR` decodes, the fan pack and FM Towns share one mechanism instead of
two. Fix the comment in `tiles_ega.h` in the same commit as your first slice,
with whatever you find — a stale comment in a header that people read as
contract is how this got asserted in the first place.

---

## 3. Slice A — the build tool, no engine change

**Goal.** `tools/build_themes.py` scans source paths and emits a `themes/` tree
that `--ega-theme-dir` already understands. Nothing in `engine/` changes. The
acceptance test is the existing engine, unmodified.

**Do it in this order.**

1. **Inventory first, write second.** Emit a report of what each source path
   contains and which theme each file would land in, and **read it before you
   copy anything.** The failure mode for this tool is a plausible-looking tree
   with a missing `EGACOLOR` or a stale `PICDNG.EGA`, which renders as a
   half-recoloured game and looks like a theme bug rather than a build bug.
2. Copy **whole theme directories**, never individual files. A theme is
   `EGATILES` + optional `EGACOLOR` + optional `PIC*.EGA`, and the optionality is
   per-theme (§ 2.2). Selective copying is how you get the half-recoloured bug.
3. Emit `EGATILES` **byte-identical** to the source. Do not decode and re-encode
   the atlas in slice A. There is no reason to, and any difference becomes
   something you have to defend.
4. Also emit a `default` theme from `references/u2upgrade/EGATILES` so the
   output directory is self-contained and `--ega-theme-dir themes/` alone works.
5. Add `/themes/` to `.gitignore` with the reason.

**CLI shape.**

```bash
python3 tools/build_themes.py \
    --source references/u2upgrade \
    --source original/updated \
    --out themes/ \
    [--dry-run] [--report]
```

`--dry-run` prints the plan and writes nothing. `--report` prints the inventory
from step 1. Default should be dry-run if you want a guard rail; if you make it
write by default, refuse to write into `original/` or `references/` exactly the
way `tools/u2_mkprobe.py` does.

**Acceptance — and write the failing control first, per `AGENTS.md` § 3.**

- `./u2-sdl --ega --data-dir <dir> --ega-theme-dir themes/ --ega-theme c64`
  renders, and the built `themes/EGATHEME.C64/EGATILES` is
  `cmp`-identical to `references/u2upgrade/EGATHEME.C64/EGATILES`.
- Ctrl-T cycles the same set of theme names it cycles from the source directory.
  If the name list differs, `entry_to_theme()` and your naming have diverged.
- **Control that must go red:** build a theme with `EGACOLOR` deliberately omitted
  and confirm your own gate notices. If nothing notices, your tool has no gate —
  say so in the commit rather than claiming coverage.
- `python3 tools/check_all.sh --fast` green, plus `make -C engine test` (slice A
  touches tooling, so the suite applies).

**Slice A explicitly does not** touch the engine, does not decode `EGACOLOR`, and
does not involve FM Towns. If you find yourself editing `engine/`, stop.

---

## 4. Slice B — FM Towns as a static v2 theme

**Goal.** FM Towns art in the engine, one tile per art index, **no animation**.
This proves the v2 format and the indirection end to end at the lowest cost, and
it is the step that makes the crosswalk pay for itself.

### 4.1 The v2 format

```
themes/<name>/
  THEME.INI      manifest: tile size, bpp, palette source, mapping file, scope
  TILES          flat array, tile_w * tile_h * bpp / 8 bytes per tile
  PALETTE.RGB    optional, 16 x 3 bytes; absent means the built-in EGA table
  MAP.TSV        optional, art_index -> tile[,tile...]; absent means identity
```

`THEME.INI` at minimum:

```ini
[theme]
name = fmtowns
tile_w = 32
tile_h = 32
bpp = 4
pixel = nibble-high-left
palette = PALETTE.RGB
map = MAP.TSV
identity = no
scope = overworld,towns
source = FM Towns (1990) GRAPH banks
```

Two design points worth holding firm on:

- **`MAP.TSV` absent means identity.** That is what keeps every existing
  `EGATILES` theme valid with no changes — the fan pack themes are identity
  mappings by definition.
- **`scope` is not decoration.** The crosswalk covers overworld and towns only.
  A theme that silently substitutes something for unmapped dungeon art is worse
  than one that refuses. Load it, and refuse the mode.

### 4.2 What the builder does in slice B

Reads `disasm/fmtowns-crosswalk.tsv` plus the FM Towns banks, and emits:

- `TILES` — the 64 FM tiles, **resampled to the size the engine can blit**.
  Decide deliberately: 32x32 native (needs § 4.3 item 2) or downsample to 16x16
  (no renderer change, and you lose the detail that was the point). I would take
  32 native and accept the renderer work; downsampling is how this ends up worse
  than EGA.
- `MAP.TSV` — the crosswalk, first tile of each set only. **Record the dropped
  frames in the manifest**, not silently.
- `PALETTE.RGB` — the FM Towns in-game table from `docs/fmtowns-graphics.md` § 3.
  Index 3 is black. That is not a bug to fix.

### 4.3 What the engine needs

In rough dependency order:

1. **A size-parameterised atlas.** `u2_tiles_ega` is fixed at
   `U2_TILE_COUNT × U2_TILE_EGA_BYTES`. Either generalise it or add a third atlas
   type; do not overload the EGA struct with a size field and call it done,
   because `u2_tile_ega_pixel()` hardcodes the stride and the compiler will not
   stop you being wrong.
2. **The renderer blit.** `renderer_sdl.c` picks the palette from
   `ctx->art_mode` (`U2_ART_EGA` → `u2_frame_palette_ega`) and assumes 16x16.
   The viewport geometry is `U2_VIEW_COLS/ROWS` of `U2_TILE_W/H`, so a 32x32
   atlas changes the window's pixel size. Check what `--scale` and the frame
   buffer do before assuming the map still fits.
3. **The lookup.** `u2_view_art()` returns an art index and the renderer indexes
   the atlas with it. With `MAP.TSV` present, that becomes a table lookup. Keep
   `view.h` pure — it is the tile-ID seam and it deliberately knows nothing about
   pixels. The indirection belongs in the atlas layer.
4. **`--fmtowns`, or better: generalise `--ega-theme-dir`.** The cleanest end
   state is one theme loader that reads `THEME.INI` when present and falls back
   to the legacy `EGATILES` assumption when it is not. That avoids a third art
   mode enum value and keeps Ctrl-T working across mixed formats. If you do add
   `U2_ART_FMTOWNS`, remember `ctx.h` documents `U2_ART_EGA` as falling back to
   CGA when art is absent — preserve that property.

### 4.4 Acceptance

- `--ega-theme-dir themes/ --ega-theme fmtowns` renders the overworld with FM
  Towns art. Screenshot it and **look at it** — `AGENTS.md` § 3 requires a frame
  for any claim about visible behaviour, and this whole thread started because a
  wrong palette made the art look like noise while every byte-level check passed.
- The letters still work. `art 0x20..0x39` → `MAP2_1/38..63` is the strongest
  known-correct part of the crosswalk; if site-name banners come out as garbage,
  the mapping or the row order is wrong, not the art.
- `--ega-theme c64` from the same directory still works. Mixed v1 and v2 themes
  in one directory must not break Ctrl-T.
- `make -C engine test` green. Add a CP-level test that loads a v2 theme built by
  the tool and asserts at least the letter rows decode to the right tiles — that
  is a real gate with a known-true answer, which is the kind this project trusts.
- **Controls first:** a `MAP.TSV` with a row pointing outside the atlas, a
  `THEME.INI` with `bpp = 3`, and a theme with `scope = overworld` used in a
  dungeon. All three must fail loudly.

---

## 5. Slice C — HELD. The v2 extras that make FM Towns complete

**Do not start this.** It is written down so it is not lost, and so slice B does
not accidentally design itself into a corner that makes this harder.

C is everything the current crosswalk deliberately parked:

1. **Animation.** Frame lists and a frame clock. The stride is **1, adjacent** —
   `docs/fmtowns-graphics.md` § 7 records how the stride-2 claim got made and
   what refuted it. Needs: a per-art frame list in `MAP.TSV` (already
   set-valued), a tick source the renderer reads, and a decision about whether
   animation is wall-clock or game-tick. Game-tick is probably right, because the
   original is paused when the game is paused and a wall-clock animation would
   keep cycling in a scripted test run.
2. **The `PLAYER` bank.** Entirely unmapped. FM Towns varies the avatar by race
   and class, which is an axis the single DOS atlas does not have. This is not
   more rows in `MAP.TSV`; it needs a second key, so the mapping format grows a
   selector. Design it before you touch it.
3. **Dungeon and tower art.** `CHEST`, `DUNG1`, `DUNG2` decode and are available.
   Note `docs/art-index.md` § 5 and `docs/monster-spawn.md` § 9: dungeons do not
   stamp the grid the same way, so the dungeon appearance may not come from the
   map byte at all. Do not assume the overworld lookup applies.
4. **Horse and boat directional variants.** The owner reports facing variants;
   the crosswalk currently carries the animation pair only.
5. **`MAP2_2` planet-2 terrain.** 15 tiles differ per planet, and only `17` has
   been touched. Also unresolved: whether the per-planet band changes *meaning*
   more than once — tile 16 does (moongate vs shield) and tile 35 may.
6. **`EGACOLOR`.** If it decodes (§ 2.4), fold it into the same `PALETTE.RGB`
   mechanism rather than leaving two palette paths.
7. **Per-screen palettes.** Unproven whether title, town, dungeon or combat
   install a different FM Towns palette. The clean measurement is breaking on
   `EGB_palette` at `0x103c84` in `ENCHANT.EXP` and dumping the 512 bytes behind
   `[edi+8]`.

**The one thing to get right in slice B so C stays cheap:** keep `MAP.TSV`
set-valued end to end. If slice B collapses each set to its first tile on the way
into the engine and loses the rest, slice C has to rebuild the mapping layer.
Parse the full list, use `list[0]`, and keep the list.

---

## 6. Hazards

- **Do not hand-maintain a second copy of the crosswalk.** It is generated; the
  owner mapping JSON is the input. `--check` exists and goes red.
- **`EGACOLOR` is undecoded.** Do not ship a palette guess. A wrong palette is
  invisible to every byte-level test and obvious to a human, which is the worst
  possible combination — this exact failure already cost a session on the FM
  Towns side.
- **Half-copied themes.** § 2.2. Copy directories, not files.
- **No fall-through on an explicit theme dir.** `[LOCKED]` behaviour. A tool that
  silently searches elsewhere turns a typo into a mystery.
- **`themes/` must stay gitignored.** It is player-supplied game art. Same rule as
  `original/`, `references/`, `tmp/tiles`, `bestiary/cache/`.
- **The cleanroom wall.** `docs/tile-art-spec.md` is the only document someone
  drawing substitute art may read. A theme builder is not drawing art, but if it
  ever starts synthesising tiles rather than copying them, you are on the other
  side of that wall and must read `docs/cleanroom-procedure.md` first.
- **Two pre-existing red gates** in `check_all.sh` (§ status). Don't let them make
  you think your slice broke, and don't fix them as a drive-by.

---

## 7. What to update as you go

- Slice A done → mark it here, and add the tool to the `tools/` row of
  `AGENTS.md` § 4.
- `EGACOLOR` decoded → fix `engine/src/core/tiles_ega.h` in the same commit, and
  add a line to `docs/ega-graphics.md`.
- Slice B done → update `docs/ega-graphics.md` (it currently describes only the
  fan pack), and add the theme format spec to `docs/` rather than leaving it in
  this handover. Handovers are entry points, not contracts.
- Anything that changes how a *generic* DOS decompilation harness should be built
  → `docs/harness-portability.md` § 6, same commit. Method transfers; conclusions
  do not.
- If slice C starts, it should become its own plan doc, not an append to this one.
