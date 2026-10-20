#ifndef U2_FONT_H
#define U2_FONT_H

/*
 * Engine text font — 8x8 bitmap glyphs blitted into the framebuffer.
 *
 * Owner decision 2026-10-20 (docs/phase4-kickoff-cp4b.md): the text
 * *mechanism* is ours to choose — readable text in the right place with the
 * right values, not a reproduction of the original's BIOS plumbing. The data
 * is dhepper/font8x8 (Public Domain), vendored in font8x8_basic.h; see
 * THIRD-PARTY-LICENSES. Px437 was assessed and is a visual reference only.
 *
 * What stays the game's own: A-Z for in-world site-name banners uses the
 * extracted tile letters (art 32-57, core/tiles.h), not this font. This
 * module is for the status band, menu and creation text only.
 *
 * Geometry: the grid is 40x25 cells of 8x8 px, which is exactly the 320x200
 * mode-4 screen (platform.h), so a cell (row, col) maps to pixel origin
 * (col*8, row*8) with no scaling and no fractional cells.
 *
 * Bit order (font8x8 convention): one byte per pixel row, LSB = leftmost
 * pixel, row 0 at the top.
 */

#include <stdint.h>
#include "core/frame.h"

#define U2_FONT_CELL_W 8
#define U2_FONT_CELL_H 8

/* Draw one glyph at cell (row, col). ch >= 128 draws as ch & 0x7F; the
 * engine's own pseudo-key codes (U2_KEY_*) must never reach a renderer —
 * callers pass printable text. Pixels outside the frame are clipped. */
void u2_font_draw_cell(u2_frame *f, int row, int col, uint8_t ch,
                       uint8_t fg, uint8_t bg);

/* Draw a NUL-terminated string starting at cell (row, col), advancing one
 * cell per byte. Characters outside 32..126 are drawn as space so control
 * bytes can never corrupt a screen. Returns the number of cells consumed. */
int u2_font_draw_text(u2_frame *f, int row, int col, const char *s,
                      uint8_t fg, uint8_t bg);

#endif /* U2_FONT_H */
