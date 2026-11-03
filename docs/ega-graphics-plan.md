# EGA graphics — implementation plan

Status: **plan, not started.** Derived from `docs/ega-graphics.md`. Phased so each step is
gated and the risky unknown (the tile atlas) is de-risked before the big pipeline work.

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
  EGA framebuffer image (mode-D, 1 byte/pixel, paletted). Confirmed by size; layout to be
  confirmed by spike S1.

## 1. The one real unknown: where do the EGA *tiles* come from?

`PIC*-E` are full-screen pictures (splash/castle/etc.), not the per-cell tile atlas. The
in-game map is drawn from the 64-tile atlas, which today is 2bpp CGA from the exe. For the
map to render in 16 colours we need a 16-colour tile atlas, and it is not yet established
where the patch keeps it. Three possibilities, in order of hopefulness:
1. The patched `original/updated/ultima2.com` embeds a 16-colour tile table (parallel to the
   CGA one at `U2_TILE_INDEX_FILE_OFF`).
2. The patch remaps the same 2bpp tiles through a richer 16-colour palette at draw time
   (i.e. no new tile data — EGA mode just uses 16 of the palette for the same 4-plane art).
3. There is no upgraded tile atlas and only the full-screen pictures gain colour.

**This decides the value of the whole feature**, so it is spike S2 and gates everything after.

## 2. Phase 0 — spikes (no engine change, throwaway scripts under /var/tmp)

- **S1 — confirm `PIC*-E` layout.** Read `PICOUT-E` as 320×200×1 byte, map through the EGA
  palette, write a PNG. If it is the overworld screen in 16 colours, the loader is trivial
  (linear index, no planar decode). If it is 4-plane, it needs a planar unpack like `pic.c`.
  *Gate:* the PNG is recognisably the outdoor screen, not noise.
- **S2 — locate the EGA tile atlas.** Grep `updated/ultima2.com` for the tile index-table
  signature `tiles.c` already knows (`U2_TILE_MAGIC_BYTE`/`MAGIC_BYTE2`, uniform stride). If
  a 16-colour (1 byte/pixel, 16×16 = 256 bytes/tile) table is present, extract one tile and
  render it. If not, conclude possibility (2) or (3) from § 1.
  *Gate:* a written verdict on which of the three cases holds. This verdict reshapes Phases
  3 and beyond.

Both spikes are cheap and neither touches the engine. Do them first and record the result in
`docs/ega-graphics.md` before writing pipeline code.

## 3. Phase 1 — 16-colour frame + palette (the pipeline, CGA stays default)

- `frame.h`: document `px` values as 0..15 (storage unchanged); add
  `void u2_frame_palette_ega(uint8_t out[16][3])` beside the CGA one. Keep the CGA 4-entry
  function untouched so nothing that assumes 4 colours breaks.
- `frame.c`: the EGA palette table (the standard 16 EGA RGB values).
- `renderer_sdl.c`: grow `v->pal[]` to 16 and select the CGA or EGA table from a mode on ctx
  (§ 6). The blit already reads `px[y][x]` as an index, so it works for 0..15 unchanged.
- Terminal/null renderers: map the extra indices or clamp; they are not the target but must
  not crash.
- *Gate:* a new `engine/tests/ega_check.c` renders a synthetic 16-index frame and asserts the
  palette mapping; the existing `pic_check`/CP4 CGA path stays green (indices 0..3, 4-palette
  path untouched).

## 4. Phase 2 — `PIC*-E` loader (full-screen pictures in EGA)

- Extend `pic.c` (or add `pic_ega.c`): read `PIC*-E` from `--data-dir` (and `./updated`) as
  the layout S1 proved, into a `u2_frame` with EGA indices. Reuse `pic_open`'s case-insensitive
  search; add the `-E` name variants.
- Fallback: if a `PIC*-E` is absent, use the CGA `pic*` (existing path). Never fail a launch
  for a missing EGA file.
- *Gate:* on a machine with the fan pack, `--ega` shows the EGA splash; without it, the CGA
  splash. `pic_check` extended with an EGA case that skips cleanly when the file is absent
  (same skip-not-fail discipline as the planet-map loader).

## 5. Phase 3 — EGA tile atlas (only if S2 says it exists)

- If S2 found a 16-colour tile table: add a `u2_tiles` EGA variant (1 byte/pixel, 256
  bytes/tile) extracted from the patched binary, and have the tile blit in `frame.c` write
  EGA indices when the mode is EGA.
- If S2 found only a palette remap (case 2): no new atlas — Phase 1's 16-colour palette
  already delivers the richer colour for the same 2bpp tiles; skip the atlas work.
- If S2 found neither (case 3): scope the feature to full-screen pictures only and say so in
  the docs; the map stays CGA.
- *Gate:* the map renders in 16 colours (or the documented reduced scope), with the CGA path
  intact as the fallback.

## 6. Phase 4 — the `--ega` flag (the interim surface)

- A mode on `u2_ctx` (parallel to `fidelity`), e.g. `u2_art_mode { U2_ART_CGA, U2_ART_EGA }`,
  read once at launch. Decides which palette (Phase 1), which pic loader (Phase 2), and which
  atlas (Phase 3) the frame uses.
- `main.c`: parse `--ega`; add to `usage()`. Default is CGA (unchanged behaviour).
- Decide (owner, from `docs/ega-graphics.md` § 6): does `--ega` require `--enhanced`, or is it
  an independent art axis? It changes no rules, so mode-independent is the cleaner default.
- *Gate:* `--ega` with the files present → EGA; `--ega` without → CGA + a one-line notice
  (consistent with the missing-planet-maps sign idea in `docs/planet-maps-galaxy-patch.md` § 5);
  no flag → CGA exactly as today.

## 7. Cross-cutting rules

- **Copyright.** EGA art is loaded from the user's copy at runtime only; never committed.
  The cleanroom substitute tiles remain the shipped fallback. No new art enters the repo.
- **CGA is the default and must not regress.** Every phase keeps the existing 4-colour path
  byte-for-byte; EGA is additive and opt-in.
- **Gates run in CI where they can.** `ega_check` and the extended `pic_check` skip cleanly
  when the fan pack is absent (CI has no `original/`), and assert fully on a dev box that
  does — same pattern as `save_cross_load` and the planet-map loader.

## 8. Sequencing and effort

1. S1 + S2 (spikes) — small, and S2's verdict is the go/no-go on Phase 3.
2. Phase 1 (frame/palette) — the real pipeline work; medium.
3. Phase 2 (`PIC*-E` loader) — small once S1 confirms the layout.
4. Phase 4 (`--ega` flag) — small; wire it after 1 and 2 so the flag has something to select.
5. Phase 3 (tiles) — only if S2 says the atlas exists; size unknown until then.

Phases 1, 2, 4 give EGA splash/picture screens behind `--ega` and are the well-understood
core. Phase 3 (the map tiles) is the high-value, high-uncertainty piece and is deliberately
gated behind spike S2 rather than assumed.

## 9. Relationship to the options menu

`--ega` is the interim launch flag. When `docs/options-menu.md` lands, the art mode becomes a
live-switchable menu row (graphics is presentation, safe to change mid-run) seeded from
`--ega`. Building the pipeline now is not throwaway: the menu row drives the same
`u2_art_mode` field.
