#ifndef U2_TILES_EGA_H
#define U2_TILES_EGA_H

/*
 * EGA tile atlas — the fan pack's 16-colour redraw of the 64 overworld tiles.
 *
 * This is the art axis of `--ega` (docs/ega-graphics-plan.md). It is a SEPARATE
 * representation from the CGA `u2_tiles` in core/tiles.h, not a mode flag on it:
 * a CGA tile is 16x16 at 2bpp (64 bytes, leftmost pixel in the top two bits),
 * while an EGA tile is 16x16 at 4bpp packed (128 bytes, high nibble = left
 * pixel). Keeping the two structs apart is what lets the CGA blit stay
 * byte-for-byte untouched while EGA is added alongside it.
 *
 * What the bytes are, measured (docs/ega-graphics-plan.md § 3, spike S1b):
 *   - the file is named EGATILES and is 8320 bytes = 65 x 128, a flat array of
 *     16x16 tiles at 4bpp packed. There is NO header and NO index table — the
 *     plan's "~128-byte header" assumption was refuted by the bytes.
 *   - EGA tile N aligns 1:1 with CGA tile N for N=0..63 (proven by the A-Z letter
 *     tiles landing at indices 32..57 in both atlases). The 65th tile is an extra
 *     the CGA set lacks; the engine uses indices 0..63 and ignores it.
 *   - the pack ships four interchangeable themes (default, 10, alt, c64), all the
 *     same format and size. Two of the three alternates (`10` and `C64`) also ship
 *     a 32-byte `EGACOLOR`; `EGATHEME.ALT` ships `EGATILES` alone, so "every theme
 *     carries one" is as false as "none does".
 *   - `EGACOLOR` is NOT an RGB palette and this engine does not read it. The fan
 *     pack's `ega.drv` loads it whole (`mov cx,0x20; rep movsb`) over a built-in
 *     default table and uses it as a per-theme COLOUR-INDEX REMAP applied at draw
 *     time: entries 0..7 recolour the overlay stream, 8..15 the text attribute
 *     handed to `int 0x10/ah=0x09`, 16..19 and 20..31 feed box and pen primitives.
 *     The tile-atlas blit never consults it, so tile colour comes from the
 *     `EGATILES` bytes themselves and the standard EGA RGB table in `core/frame.c`
 *     is still what the engine draws with. Addresses and grades:
 *     `docs/ega-graphics.md` § 3.1.
 *
 * Copyright posture, identical to the CGA atlas and the pic loader: this art is
 * the player's own, read at run time from the resolved themes directory and never
 * committed. With no EGA files present the engine falls back to the CGA path (or
 * the cleanroom substitutes) and nothing about a launch changes.
 */

#include <stddef.h>
#include <stdint.h>
#include "core/ctx.h"
#include "core/tiles.h"          /* U2_TILE_COUNT, U2_TILE_W, U2_TILE_H */

#define U2_TILE_EGA_BPP    4
#define U2_TILE_EGA_STRIDE (U2_TILE_W / 2)                    /* 8 bytes/row */
#define U2_TILE_EGA_BYTES  (U2_TILE_H * U2_TILE_EGA_STRIDE)   /* 128 */
#define U2_TILE_EGA_FILE   8320                               /* 65 * 128 */

/* Format v2 bounds (docs/handoff-themes-builder.md § 4.1). A THEME.INI names a
 * tile size and a pool of tiles, and the atlas below is sized for the largest
 * one this project has evidence for; a theme that exceeds a bound is refused
 * with a reason rather than truncated. */
#define U2_TILE_EGA_MAX_SIDE   32
#define U2_TILE_EGA_MAX_TILE   (U2_TILE_EGA_MAX_SIDE * U2_TILE_EGA_MAX_SIDE / 2) /* 512 */
#define U2_TILE_EGA_MAX_TILES  128
#define U2_TILE_EGA_MAX_FRAMES 8

typedef struct u2_tiles_ega {
    /* The pool. For a v1 theme this is the EGATILES array and `art index ==
     * pool index`; for a v2 theme MAP.TSV supplies the indirection, so the pool
     * holds every frame the mapping names and an art index may point at several
     * of them. */
    uint8_t  px[U2_TILE_EGA_MAX_TILES][U2_TILE_EGA_MAX_TILE];
    int      count;                 /* tiles present in px */
    int      tile_w, tile_h;        /* 0 means the v1 default, 16x16 */
    int      stride;                /* bytes per row; 0 means tile_w/2 */
    int      bpp;                   /* 0 means 4 */
    int      scale;                 /* frame scale this theme asks for */
    int      has_palette;
    uint8_t  palette[16][3];        /* only meaningful when has_palette */
    int      has_map;
    uint16_t map[U2_TILE_COUNT][U2_TILE_EGA_MAX_FRAMES];
    uint8_t  map_n[U2_TILE_COUNT];
    int      scope_dungeon;         /* the theme claims dungeon art is mapped */
    int      scope_tower;
    int      loaded;
    char     source[760];           /* the file we read, for diagnostics; sized so
                                     * a snprintf from a path buffer cannot truncate */
    char     dir[512];              /* the themes dir it was found in, so a mid-run
                                     * theme cycle scans the same directory */
    char     name[32];              /* the theme name it was loaded as */
} u2_tiles_ega;

/* Geometry accessors with the v1 defaults behind them. A zeroed struct means
 * "the legacy 16x16 4bpp atlas", which is what every existing caller and test
 * builds by hand, and it is why these exist: the stride is not a constant any
 * more, and reading `t->stride` directly on a hand-built atlas would give 0. */
static inline int u2_tiles_ega_tile_w(const u2_tiles_ega *t)
{ return t && t->tile_w > 0 ? t->tile_w : U2_TILE_W; }
static inline int u2_tiles_ega_tile_h(const u2_tiles_ega *t)
{ return t && t->tile_h > 0 ? t->tile_h : U2_TILE_H; }
static inline int u2_tiles_ega_stride(const u2_tiles_ega *t)
{ return t && t->stride > 0 ? t->stride : u2_tiles_ega_tile_w(t) / 2; }
static inline int u2_tiles_ega_count(const u2_tiles_ega *t)
{ return t && t->count > 0 ? t->count : U2_TILE_COUNT; }

/* Which pool entry draws art index `art`. Identity when the theme carries no
 * map, which is every v1 theme by definition. Returns -1 for an art index the
 * map does not cover, and the caller must not draw rather than guess. */
static inline int u2_tiles_ega_tile(const u2_tiles_ega *t, int art)
{
    if (art < 0 || art >= U2_TILE_COUNT) return -1;
    if (!t || !t->has_map) return art;
    if (t->map_n[art] == 0) return -1;
    return t->map[art][0];
}

/* Colour index 0..15 of one EGA pixel. High nibble is the left pixel of each
 * byte, the opposite of the CGA atlas's top-two-bits convention. The stride is
 * the theme's, not a constant: a 32-wide 4bpp row is 16 bytes, not 8. */
static inline int u2_tile_ega_pixel(const u2_tiles_ega *t, int tile, int x, int y)
{
    const uint8_t b = t->px[tile][y * u2_tiles_ega_stride(t) + (x >> 1)];
    return (x & 1) ? (b & 0xF) : (b >> 4);
}

/* The four shipped theme names. "default" is the top-level EGATILES the game
 * itself uses; the others live in EGATHEME.<NAME>/ subdirectories. A format-v2
 * theme is a directory named <name>/ holding a THEME.INI, and it is discovered
 * by the same calls. */
#define U2_EGA_THEME_DEFAULT "default"

typedef enum u2_tiles_ega_result {
    U2_TILES_EGA_OK = 0,
    U2_TILES_EGA_NOT_READY,   /* no themes dir / no theme found anywhere */
    U2_TILES_EGA_BAD,         /* file present but wrong size or shape */
    U2_TILES_EGA_ERROR        /* I/O failure */
} u2_tiles_ega_result;

/*
 * Resolve the themes directory and load the chosen theme's EGATILES.
 *
 * Directory resolution order (docs/ega-graphics-plan.md § 2, [LOCKED]):
 *   ctx->ega_theme_dir, if set; else ctx->data_dir; else the built-in default
 *   candidates (references/u2upgrade where the files sit on a dev checkout). The
 *   first candidate that actually contains the theme file wins, so a data-dir
 *   without EGA art falls through to the default rather than failing.
 *
 * `theme` is one of the four names above (NULL means "default"). Returns
 * U2_TILES_EGA_OK on success; any other value means the caller should keep the
 * CGA path (and, for the top-level notice, say so once).
 */
u2_tiles_ega_result u2_tiles_ega_open(u2_ctx *ctx, u2_tiles_ega *t,
                                      const char *theme);

/* Load one theme from an EXACT directory (no resolution search), recording the
 * dir in t->dir. This is what a mid-run cycle uses: it already knows the dir the
 * current atlas came from and only needs to swap the theme within it. */
u2_tiles_ega_result u2_tiles_ega_open_in(u2_ctx *ctx, u2_tiles_ega *t,
                                         const char *dir, const char *theme);

/*
 * The next theme name after `cur` when the themes in `dir` are walked in
 * alphabetical order of their directory entries, wrapping to the first at the
 * end. The top-level EGATILES is the theme "default"; each EGATHEME.<NAME>
 * subdirectory is the theme "<NAME>" lower-cased — the same mapping
 * u2_tiles_ega_open_in understands, so the returned name can be loaded directly.
 *
 * Fills `next` and returns the number of themes found (>= 1 when the directory
 * is readable), or 0 if the directory cannot be opened. If `cur` is not among
 * the themes found (e.g. it was loaded from a different directory) the first
 * theme in the order is returned, so a cycle always makes progress.
 */
int u2_tiles_ega_next_theme(const char *dir, const char *cur,
                            char *next, size_t n);

/*
 * Fail-fast launch check for --ega (strict mode). Returns U2_TILES_EGA_OK when
 * the chosen theme's EGATILES is present and loadable in the resolved themes
 * directory; otherwise a non-OK result and, if `err` is supplied, a one-line
 * actionable reason. main() calls this and refuses to start on any non-OK, so
 * --ega never silently draws CGA because the art is missing.
 */
u2_tiles_ega_result u2_tiles_ega_validate(u2_ctx *ctx, char *err, size_t n);

const char *u2_tiles_ega_result_text(u2_tiles_ega_result r);

#endif /* U2_TILES_EGA_H */
