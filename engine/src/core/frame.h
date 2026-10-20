#ifndef U2_FRAME_H
#define U2_FRAME_H

/*
 * Framebuffer — the pixel side of the engine, and the seam that should have
 * existed from the start.
 *
 * Why this is a core module and not a renderer detail: the original runs the
 * whole game in video mode 4 (asm/4A3E: INT 10h AH=00h AL=04h, 320x200), and
 * it draws *everything* there, including its text — the site-name banners use
 * the custom A-Z tiles from the tile table, not the CGA ROM font. A character
 * grid is therefore a simplification of the original, not a faithful model of
 * it, and any display backend that wants to be honest needs pixels.
 *
 * So pixel generation lives here, in dependency-free C11, and a backend only
 * moves bytes to a screen: SDL2 uploads them as a texture, kitty or sixel
 * encodes them, PPM writes them to a file, the null backend counts them. That
 * split is what keeps the game portable instead of terminal-specific.
 *
 * Geometry, all proven in docs/phase4-implementation.md § CP4:
 *   - screen 320x200, one CGA row = 80 bytes at 2bpp
 *   - the map window is 20x10 tiles at rows 0..19, full width (asm/5AE1 fill
 *     loop bounds, asm/4ABB flush loop bounds, and the screenshots, three
 *     independent confirmations)
 *   - a tile is 16x16 at 2bpp, leftmost pixel in the top two bits
 *   - the original stages tile IDs then flushes to video; this mirrors that by
 *     compositing into a frame the caller then presents
 */

#include <stdint.h>
#include "core/tiles.h"
#include "core/view.h"

#define U2_SCREEN_W   320
#define U2_SCREEN_H   200
#define U2_SCREEN_ROW 80                       /* bytes per row at 2bpp */

/* The map window occupies the top 160 pixel rows; the original leaves the rest
 * for the status block and the command line, and row 24 blank. */
#define U2_MAP_PX_H   (U2_VIEW_ROWS * U2_TILE_H)   /* 160 */

/* CGA mode 4 palette indices. The engine carries indices, not RGB, so a
 * backend can honour a different palette (composite RGB, the fan pack's
 * CGACOMP.PAL, or a scaled-up 4-tone approximation) without the core knowing. */
#define U2_CGA_BLACK    0
#define U2_CGA_CYAN     1
#define U2_CGA_MAGENTA  2
#define U2_CGA_WHITE    3

typedef struct u2_frame {
    /* One byte per pixel, value 0..3. 64 KB, which is fine on any host and
     * keeps the blit trivially readable; a 2bpp packed variant is a later
     * optimisation, not a correctness requirement. */
    uint8_t  px[U2_SCREEN_H][U2_SCREEN_W];
    unsigned presents;      /* frames composited, for tests and diagnostics */
} u2_frame;

/* The four palette entries as 8-bit RGB, in CGA's canonical order. A backend
 * may substitute its own; this is the default, not an assertion about hardware. */
void u2_frame_palette(uint8_t out[4][3]);

void u2_frame_clear(u2_frame *f, uint8_t colour);

/* Blit one tile at a pixel position. Out-of-bounds pixels are clipped rather
 * than wrapped, so a partially off-screen tile cannot corrupt the frame. */
void u2_frame_blit_tile(u2_frame *f, const u2_tiles *t, int tile, int x, int y);

/*
 * Composite the map window from a filled viewport. This is the engine's
 * equivalent of asm/4ABB's flush loop: walk the 20x10 staging grid, skip the
 * cells flagged do-not-draw, and blit each tile at (col*16, row*16).
 *
 * `overlay` is the player marker drawn after the terrain, because the original
 * composites the character on top rather than baking it into the sector. It may
 * be -1 to draw no marker.
 */
void u2_frame_draw_view(u2_frame *f, const u2_view *v, const u2_tiles *t,
                        int overlay_tile, int overlay_col, int overlay_row);

/* Write the frame as a binary PPM (P6) mapped through `pal`. Uncompressed, so
 * it needs no zlib and no dependency — which is what makes "look at the real
 * tiles today" possible without SDL2. Returns 0 on success. */
int u2_frame_write_ppm(const u2_frame *f, const char *path,
                       const uint8_t pal[4][3]);

/* Same, as an uncompressed 24-bit BMP, for viewers that prefer it. */
int u2_frame_write_bmp(const u2_frame *f, const char *path,
                       const uint8_t pal[4][3]);

#endif /* U2_FRAME_H */
