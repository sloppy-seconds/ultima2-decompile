# EGA graphics — implementation plan

Status: **IMPLEMENTED (2026-11-04).** All four phases shipped and gated; `make -C engine
test` green (CP0..CP7), the new `ega_check` gate green, and the CGA path verified
byte-identical to the pre-change binary on the same input. The Phase 0 verdicts below
correct one assumption in § 1 (EGATILES has no header). The three flags are interim
scaffolding per § 10. Original plan text follows, kept as the build record.

Derived from `docs/ega-graphics.md`. Every open decision is resolved with a locked default
below (marked **[LOCKED]**) so an implementer runs the whole plan and reports at the end; the
owner reviews after it is built, not between phases. The interim flags are deliberately
provisional and get cleaned up when `docs/options-menu.md` lands.

## 0. What the code already gives us (measured this session)

- `engine/src/core/frame.h`: `u2_frame.px[200][320]` is **one byte per pixel, value 0..3**
  (a CGA palette index). This is the key fact: EGA is 0..15, so the *storage is already
  correct* — widening CGA→EGA is a palette and value-range change, not a framebuffer rewrite.
- `u2_frame_palette(uint8_t out[4][3])` returns the 4 CGA RGB entries; `renderer_sdl.c`
  builds `v->pal[4]` from it via `SDL_MapRGBA`. Both are the seams that grow to 16 entries.
- `engine/src/core/pic.c` unpacks the CGA `pic*` files (320×200 @ 2bpp, even/odd field
  interleave) straight into a `u2_frame`. Used by `title.c` for the splash screens
  (`u2_pic_can_show`, `u2_pic_blit`).
- `engine/src/core/tiles.c` extracts the **64-tile atlas** from `ultimaii.exe` at
  2bpp (16×16, 4 bytes/row). This is what draws the map, towns, etc. — the dominant visual.
- The fan pack's `original/updated/PIC*-E` are each **64000 = 320×200×1** bytes: a raw
  EGA framebuffer image (mode-D, 1 byte/pixel, paletted). Confirmed by size; layout by S1.

## 1. The tile atlas: RESOLVED (spike S2, 2026-11-04)

The EGA tile atlas is a data file named **`EGATILES`**, which `u2ega.exe` opens at runtime
via DOS block-read (INT 21h AH=27h) exactly like it opens `PLAYER` and `MONSTERS` — the
`EGATILES` string sits in the code next to those two filenames, not as an embedded table.
`Files.txt` in the pack says it plainly: `U2EGA.EXE - EGA Game Binary & tiles`.

The file is present at **`references/u2upgrade/EGATILES`** (the full Exodus "U2 Upgrade"
source package, broader than the `original/updated/` runtime dir). Measured shape: **8320
bytes = a ~128-byte header/index + 64 tiles x 128 bytes**, where a tile is 16x16 at **4bpp
packed (two 16-colour pixels per byte)** — confirmed by the byte pattern (every byte splits
into two nibbles <= 0xF, e.g. `0x99` = two pixels of colour 9). A genuine 16-colour atlas,
not a palette remap. The `Readme.txt` agrees: the upgrade redraws tiles "conforming loosely
to the Apple II colour scheme" and borrows some from U1/U4.

The pack ships **four themes** — `EGATILES`, `EGATHEME.10/EGATILES`, `EGATHEME.ALT/EGATILES`,
`EGATHEME.C64/EGATILES` (all 8320 bytes, different content) — plus `CGATILES` and
`CGACOMP.PAL`. A "switch graphic set" maps directly onto picking a theme file.

## 2. Decisions locked for autonomous execution

Each was an open question; each now has a default so the plan runs without a pause. All are
reversible and none is load-bearing on correctness — they are taste, and the owner reviews
after the build.

- **[LOCKED] `--ega` is an independent art axis, not gated on `--enhanced`.** It changes no
  rules, so it is available in both fidelity modes.
- **[LOCKED] Default theme = the top-level `EGATILES`** (the canonical set the game itself
  uses). Theme names: `default`, `10`, `alt`, `c64`.
- **[LOCKED] Themes-dir default resolution order:** `--ega-theme-dir` if given → else
  `--data-dir` → else `references/u2upgrade/` (where they sit on our disk, so dev just
  works). ~~Absent everywhere → CGA fallback, never a launch failure.~~ **SUPERSEDED
  (owner, 2026-11-04): `--ega` is now strict — it refuses to start (exit 2) when the themes
  directory does not exist or the chosen theme is not in it, rather than falling back to
  CGA.** See § 11.
- **[LOCKED] EGA palette = the standard 16 EGA RGB values** in `frame.c`, *unless* spike S1b
  finds a per-theme palette file (e.g. a `.pal`/`.drv` that the theme needs); if it does,
  load the palette from the theme dir instead. Decide from S1b's evidence, do not ask.
- **[LOCKED] CGA remains the shipped default and must not regress.** EGA is additive and
  opt-in; the cleanroom substitute tiles stay the fallback when no EGA art is present.
- **[LOCKED] If a spike refutes an assumption** (e.g. `PIC*-E` is planar, not linear), adapt
  the loader to what the bytes show and note it in the doc — do not stop for the owner.

## 3. Phase 0 — spikes (no engine change; throwaway scripts under /var/tmp)

- **S1 — confirm `PIC*-E` layout.** Read `PICOUT-E` as 320×200×1 byte, map through the EGA
  palette, write a PNG. Linear-index → trivial loader; 4-plane → planar unpack like
  `pic.c`. *Gate:* the PNG is recognisably the outdoor screen. Record the verdict here.
- **S1b — confirm the `EGATILES` header/index layout.** Parse the ~128-byte header, extract
  tile 0 (16×16 @ 4bpp packed) to a PNG. *Gate:* a recognisable tile. Also check whether a
  theme dir carries its own palette (feeds the [LOCKED] palette decision).
- **S2b — themes.** Confirm the four `EGATILES` variants share the format and differ only in
  art, so they are interchangeable graphic sets.

Run all three first, write the verdicts into this doc, then proceed. None needs the owner.

### Phase 0 verdicts (spikes run 2026-11-04, scripts under /var/tmp/ega-spike)

- **S1 — `PIC*-E` is LINEAR, one palette index per byte. Confirmed.** `PICOUT-E`,
  `PICDRA-E`, `PICMIN-E` are each exactly 64000 bytes; every byte value is <= 0x0F
  (0 values above 15 in all three), and rendering the bytes straight through the
  standard 16-colour EGA RGB table top-down produces a recognisable outdoor screen
  (trees, mountains, figures, castle), the dragon logo, and the pyramid. No planar
  decode, no interleave: the loader is a read + palette map. The dominant value is 0
  (background) at ~75-90% of pixels, consistent with a sparse sprite over black.
- **S1b — `EGATILES` has NO header. The plan's "~128-byte header/index" assumption is
  REFUTED by the bytes.** The file is 8320 = **65 x 128** bytes: a flat array of
  16x16 tiles at 4bpp packed (high nibble = left pixel), no index, no per-tile header.
  Proof of the alignment: the CGA atlas extracted from `ultimaii.exe` has its custom
  A-Z letters at tile indices 32..57 (A=32, Z=57). Decoding `EGATILES` from offset 0
  puts 'A' at tile 32 and 'Z' at tile 57, matching the CGA atlas tile-for-tile; the
  letter-Z tile carries ~83 lit pixels in CGA and ~89 at EGA offset 0, versus 46 at
  offset 128 (a half-blank tile). So **EGA tile N aligns 1:1 with CGA tile N for
  N=0..63**, and the 65th tile (offset 8192, a solid white circle) is an extra the
  CGA set does not have — the engine uses indices 0..63 and ignores it. No theme dir
  (`EGATHEME.10/ALT/C64`) carries its own palette file; the only `.pal`/`.drv` at the
  root are `CGACOMP.PAL` (a 768-byte CGA composite palette) and x86 `.drv` code files
  (`ega.drv` starts with `e9` = `jmp`), none of which is a per-theme EGA palette. So
  the [LOCKED] palette decision resolves to the **standard 16 EGA RGB values in
  `frame.c`**.
- **S2b — the four themes share the format and differ only in art. Confirmed.** All
  four `EGATILES` (default, 10, alt, c64) are 8320 bytes, decode identically as 65x128
  4bpp tiles, and are pairwise byte-different. The nibble histograms differ per theme
  (e.g. c64 is dominated by index 10, default by 0/7/15), which is the recolouring the
  README describes. They are interchangeable graphic sets.

## 4. Phase 1 — 16-colour frame + palette (the pipeline, CGA stays default)

- `frame.h`: document `px` values as 0..15 (storage unchanged); add
  `void u2_frame_palette_ega(uint8_t out[16][3])` beside the CGA one. Keep the CGA 4-entry
  function untouched so nothing that assumes 4 colours breaks.
- `frame.c`: the EGA palette table (per the [LOCKED] palette decision).
- `renderer_sdl.c`: grow `v->pal[]` to 16 and select the CGA or EGA table from the art mode
  (§ 7). The blit already reads `px[y][x]` as an index, so it works for 0..15 unchanged.
- Terminal/null renderers: map the extra indices or clamp; not the target but must not crash.
- *Gate:* a new `engine/tests/ega_check.c` renders a synthetic 16-index frame and asserts the
  palette mapping; the existing `pic_check`/CP4 CGA path stays green.

## 5. Phase 2 — `PIC*-E` loader (full-screen pictures in EGA)

- Extend `pic.c` (or add `pic_ega.c`): read `PIC*-E` from the themes/data dir as the layout
  S1 proved, into a `u2_frame` with EGA indices. Reuse `pic_open`'s case-insensitive search;
  add the `-E` name variants.
- Fallback: if a `PIC*-E` is absent, use the CGA `pic*` (existing path). Never fail a launch.
- *Gate:* with the fan pack, `--ega` shows the EGA splash; without it, the CGA splash.
  `pic_check` extended with an EGA case that skips cleanly when the file is absent.

## 6. Phase 3 — EGA tile atlas (committed: the atlas exists)

- Add a `u2_tiles` EGA variant: load `EGATILES` from the resolved themes dir, parse the
  header per S1b, decode 64 tiles at 16×16 @ 4bpp packed into 1-byte-per-pixel EGA indices.
- Have the tile blit in `frame.c` write EGA indices when the art mode is EGA; CGA path
  untouched.
- If S1b shows the header/index differs from the assumed ~128-byte layout, adapt the parser
  to the bytes (per the [LOCKED] "adapt, don't ask" rule).
- *Gate:* the map renders in 16 colours from a chosen theme, CGA intact as fallback.

## 7. Phase 4 — interim flags (`--ega`, `--ega-theme`, `--ega-theme-dir`)

- A mode on `u2_ctx` (parallel to `fidelity`): `u2_art_mode { U2_ART_CGA, U2_ART_EGA }`, plus
  a theme name and a themes-dir path, all read once at launch. Decides which palette (P1),
  pic loader (P2), and atlas (P3) the frame uses.
- `main.c`: parse the three flags; add to `usage()` marked **provisional (superseded by the
  options menu)**. Defaults per § 2: `--ega` off (CGA); `--ega-theme default`; themes-dir by
  the resolution order.
- *Gate:* `--ega` with files present → EGA in the chosen theme; ~~`--ega` without → CGA + a
  one-line notice~~ **`--ega` without the art present → refuse to start (exit 2) with a
  reason (owner override, 2026-11-04, § 11)**; no flag → CGA
  exactly as today. `--ega-theme c64` visibly swaps the tile set.

## 8. Cross-cutting rules

- **Copyright.** EGA art is loaded from the user's copy at runtime only; never committed.
  The cleanroom substitute tiles remain the shipped fallback. No new art enters the repo.
  `references/u2upgrade/` is read-only and gitignored like the other reference dirs.
- **CGA is the default and must not regress.** Every phase keeps the existing 4-colour path
  byte-for-byte; EGA is additive and opt-in.
- **Gates run in CI where they can.** `ega_check` and the extended `pic_check` skip cleanly
  when the fan pack is absent (CI has no `original/`/`references/`), and assert fully on a
  dev box that does — same pattern as `save_cross_load` and the planet-map loader.
- **Definition of done:** `make -C engine test` green; `tools/check_all.sh --fast` green
  (modulo the pre-existing `xref_provenance` red, unrelated); `--ega` visibly renders the map
  and splash in 16 colours on a dev box with the pack; CGA path byte-identical to before.

## 9. Sequencing

1. Phase 0 spikes (S1, S1b, S2b) — small; write verdicts into this doc.
2. Phase 1 (frame/palette) — the real pipeline work; medium.
3. Phase 2 (`PIC*-E` loader) — small once S1 confirms the layout.
4. Phase 3 (tile atlas) — medium; committed since the atlas exists.
5. Phase 4 (flags) — small; wire last so the flags have something to select.

Then report to the owner with a screenshot of the EGA map + splash and the spike verdicts.

## 10. Relationship to the options menu

The three flags are interim scaffolding. When `docs/options-menu.md` lands, the art mode and
theme become live-switchable menu rows (graphics is presentation, safe to change mid-run)
seeded from these flags, and the flags are removed or folded into the settings model. Building
the pipeline now is not throwaway: the menu rows drive the same `u2_art_mode` + theme fields.

## 11. Implementation record (2026-11-04)

What shipped, by phase:

- **Phase 1** — `core/frame.[ch]`: `u2_frame_palette_ega(uint8_t out[16][3])` (standard EGA
  RGB table), `u2_frame_write_ppm16` / `u2_frame_write_bmp16` (index with `& 15`), and
  `u2_frame_blit_tile_ega` / `u2_frame_draw_view_ega` (4bpp decode, high nibble = left pixel).
  The CGA four-entry functions are untouched. `renderer_sdl.c` grew `pal[]` to 16 and picks
  the CGA or EGA table from `ctx->art_mode`; the upload indexes with `& 15` (a CGA frame
  never exceeds 3, so its output is unchanged). Terminal/null renderers use the cell grid and
  never index a palette by pixel value, so they are unaffected.
- **Phase 2** — `core/pic_ega.[ch]`: `u2_pic_can_show_ega` / `u2_pic_blit_ega` read a linear
  64000-byte `PIC*-E` (or `PIC*.EGA`) into the frame as 0..15 indices, trying both spellings
  case-insensitively across the resolved dirs. `game/title.c`'s `show_pic` prefers EGA when
  `art_mode` is EGA and the file is present, else falls back to the CGA pic unchanged.
- **Phase 3** — `core/tiles_ega.[ch]`: `u2_tiles_ega_open` resolves the themes dir
  (`--ega-theme-dir` → `--data-dir` → `references/u2upgrade`) and loads the chosen theme's
  `EGATILES` (no header; first 64 of 65 tiles). `game/overworld.c` loads it on top of the CGA
  tiles when `--ega` is set, sets `ow->use_ega`, and branches the draw and the two frame-dump
  paths on it. A missing atlas prints one notice and keeps CGA.
- **Phase 4** — `core/ctx.h`: `u2_art_mode { U2_ART_CGA, U2_ART_EGA }` plus `ega_theme` and
  `ega_theme_dir`. `main.c` parses `--ega`, `--ega-theme`, `--ega-theme-dir`, all marked
  provisional in `usage()`.

**Follow-up (owner, 2026-11-04): live theme cycle.** Ctrl-T (`0x14`) in the overworld
loop advances to the next EGA theme while `--ega` is active. It is gated on the EGA art mode
and a loaded atlas, **not** on `--dev` — it is pure presentation and changes no rule, so it
lives in the loop unconditionally when EGA is on (unlike Ctrl-Q, which is a dev-only quit). It
knows its current theme (`ow->ega_theme`) and the resolved themes dir (`ow->tiles_ega.dir`),
and `u2_tiles_ega_next_theme` walks that directory's themes in alphabetical order of their
names (the top-level `EGATILES` = "default", each `EGATHEME.<X>` = "<x>"), wrapping at the
end; the next theme is reloaded in place with `u2_tiles_ega_open_in` and named on the message
line. `ega_check` grew to 23 checks covering the cycle (visits each theme once per lap, wraps
to default, and an unknown current theme still advances). Verified end-to-end by driving
`0x14` through `--script`: default → 10 → alt → c64 → default, and inert in CGA mode.

Gates: `engine/tests/ega_check.c` (20 checks: palette table incl. the CGA-vs-EGA index-1/2
difference, 4bpp blit decode, 16-entry writer, real-atlas load incl. the letter-A tile and a
theme-differs check, real `PICDRA-E` blit) wired into `run_cp4.sh`; it self-skips the
content-dependent checks when the pack is absent. `run_cp4.sh`'s `save_q_check` and
`food_check` harnesses gained `src/core/tiles_ega.c` on their link line.

Verified: `make -C engine test` green (CP0..CP7); `tools/check_all.sh --fast` green except the
pre-existing, unrelated `xref_provenance` red; the EGA map renders in 16 colours (green
forest, blue water, grey mountains) where CGA renders 4; `--ega-theme c64`/`alt` swap the set;
`--ega` with no art anywhere prints the notice and still renders CGA; and the CGA `--dump-map`
output is **byte-identical** to the pre-change binary built at HEAD on the same input.

**SDL control-key fix (2026-11-04).** Ctrl-Q and Ctrl-T did nothing in the SDL build —
they reached the command dispatcher as `q`/`t` and triggered save/transact instead. Cause:
the terminal backend delivers the raw control byte (Ctrl-Q = `0x11`) because a raw tty read
yields the control character, but SDL reports Ctrl+letter as the letter keycode with an
`SDL_KMOD_CTRL` modifier. `input_sdl.c` now masks a Ctrl+letter to its control code
(`key & 0x1F`), which is exactly what the original's INT 16h returned in AL, so both backends
agree on the byte the overworld loop tests. (SDL3 renamed `KMOD_CTRL` to `SDL_KMOD_CTRL`.)

Known limitation, out of scope: `debug/turnlog.c` (the `--debug cli` per-turn dump) still maps
frames through the 4-entry CGA palette, so an EGA frame dumped there is recoloured to 4 tones.
It is a diagnostic path only, not the window or the gated dumps, and the plan did not list it.

**Strict `--ega` (owner, 2026-11-04).** `--ega` now refuses to start (exit 2) instead of
falling back to CGA, when the themes directory does not exist or the chosen theme is not in
it. `u2_tiles_ega_validate` runs in `main.c` right after the other post-parse flag checks,
before any screen is drawn, and prints `u2: --ega refused: <reason>`. The reason distinguishes
an explicit `--ega-theme-dir` that does not exist, a themes dir present but missing the theme,
and a theme file present but the wrong size. This supersedes the § 2 / § 7 "never fail a
launch" default. The flag was also renamed `--ega-themes-dir` → `--ega-theme-dir` (and the
`ctx` field `ega_themes_dir` → `ega_theme_dir`) for consistency with `--ega-theme`.
