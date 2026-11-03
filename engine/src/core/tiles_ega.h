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
 *     same format and size, differing only in colour. None carries its own
 *     palette, so the standard EGA RGB table in core/frame.c is used for all.
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

/* The four shipped theme names. "default" is the top-level EGATILES the game
 * itself uses; the others live in EGATHEME.<NAME>/ subdirectories. */
#define U2_EGA_THEME_DEFAULT "default"

typedef enum u2_tiles_ega_result {
    U2_TILES_EGA_OK = 0,
    U2_TILES_EGA_NOT_READY,   /* no themes dir / no EGATILES found anywhere */
    U2_TILES_EGA_BAD,         /* file present but wrong size */
    U2_TILES_EGA_ERROR        /* I/O failure */
} u2_tiles_ega_result;

typedef struct u2_tiles_ega {
    uint8_t px[U2_TILE_COUNT][U2_TILE_EGA_BYTES];
    int     loaded;
    char    source[600];      /* the file we read, for diagnostics */
    char    dir[512];         /* the themes dir it was found in, so a mid-run
                               * theme cycle scans the same directory */
} u2_tiles_ega;

/* Colour index 0..15 of one EGA pixel. High nibble is the left pixel of each
 * byte, the opposite of the CGA atlas's top-two-bits convention. */
static inline int u2_tile_ega_pixel(const u2_tiles_ega *t, int tile, int x, int y)
{
    const uint8_t b = t->px[tile][y * U2_TILE_EGA_STRIDE + (x >> 1)];
    return (x & 1) ? (b & 0xF) : (b >> 4);
}

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
