#ifndef U2_VIEW_H
#define U2_VIEW_H

/*
 * Viewport — the map byte to tile-ID mapping, and nothing else.
 *
 * This is the tile-ID seam the CP4 design settled on: the game logic produces a
 * grid of tile IDs, and a backend decides what an ID looks like (a terminal
 * glyph now, the extracted 16x16 art in CP9, an EGA sprite if that ever comes
 * back into scope). Nothing here knows about pixels, colours or cells, which is
 * what keeps the renderer swappable.
 *
 * Every rule is a transcription of asm/5AE1..5B6C (runtime; the per-function
 * files asm/5B4D and asm/5C25 are fragments of this one loop, which is why the
 * behaviour only appears when the range is re-decoded continuously). Proven in
 * docs/phase4-implementation.md § CP4:
 *
 *   - the window is 20 columns x 10 rows  (cmp $0x14, cmp $0xa)
 *   - the top-left map cell is (x - 9, y - 5), so the player sits at (9, 5)
 *   - the world map wraps: both origin axes get `and $0x3f` (asm/5B98). A site sector does
 *     not (asm/5ABB, deliberately), and a cell past its edge draws the ground byte instead
 *   - tile index = (map_byte >> 1) & 0xFE  (clc; rcr al,1; and al,0xfe)
 *   - a cell outside the sector takes its tile from DS:12, not from the map
 *   - a tile whose index equals the underlay byte is suppressed with bit 7 set
 *     (or al,0x80), with two exceptions: index 0 when DS:54E == 0xFF, and
 *     index 0x2E
 *
 * The flush side (asm/4ABB) honours bit 7 with `or cl,cl; js skip`, so a
 * suppressed cell is not drawn at all rather than drawn as tile 0.
 */

#include <stdint.h>
#include "core/world.h"

#define U2_VIEW_COLS      20
#define U2_VIEW_ROWS      10
#define U2_VIEW_TILES     (U2_VIEW_COLS * U2_VIEW_ROWS)   /* 200 */
#define U2_VIEW_PLAYER_COL 9
#define U2_VIEW_PLAYER_ROW 5
/* The grid is sized for the largest shape anything asks for, not for the DOS one.
 * The DOS shape above is a transcription of asm/5AE1 and stays exactly as it was;
 * the enhanced layout uses a squarer window (see core/layout.h), and a fixed
 * buffer with a runtime shape is what lets ONE fill implementation serve both.
 * Two copies of the suppression and torus rules is how they drift. */
#define U2_VIEW_MAX_CELLS 1024
#define U2_VIEW_NO_DRAW    0x80
#define U2_VIEW_EMPTY      0x2E   /* the index that escapes suppression */
/* What a site sector draws outside its own 64x64 array: the ground byte. Measured
 * 2026-11-02 in Port Boniface, where the off-grid cell and a real 0x08 cell in the
 * same frame have the identical bitmap and census. See core/view.c. */
#define U2_VIEW_SITE_OFFGRID 0x08

typedef struct u2_view {
    /* Shape of this viewport. The classic path sets the DOS 20x10 with the player
     * at (9,5), which is what asm/5AE1 compares against; enhanced sets a squarer
     * window. Everything that walks the grid reads these instead of the macros, so
     * there is no second implementation of the fill to keep honest. */
    int     cols, rows;
    int     player_col, player_row;
    /* Staging grid, the DS:0x272 analogue: low 7 bits are the tile index,
     * bit 7 means "do not draw". Only cols*rows of it are meaningful. */
    uint8_t tile[U2_VIEW_MAX_CELLS];
    /* Count of cells actually drawable, for tests and diagnostics. */
    int     drawn;
} u2_view;

/* Give a viewport its shape. Call before u2_view_fill. Passing the DOS numbers
 * reproduces the original window exactly; anything else is a presentation choice
 * and does not inherit that claim. */
void u2_view_init(u2_view *v, int cols, int rows, int player_col, int player_row);

/* The shape to draw with, falling back to the DOS window when a view was never
 * given one. A zeroed struct must not mean "draw nothing": that fails silently and
 * looks like a graphics bug, and it did exactly that to the overlay check when the
 * shape first became runtime. The fallback is the DOS 20x10, so an uninitialised
 * view draws the classic window rather than an empty frame. */
static inline void u2_view_shape(const u2_view *v, int *cols, int *rows,
                                 int *player_col, int *player_row)
{
    int c = v ? v->cols : 0, r = v ? v->rows : 0;
    int pc = v ? v->player_col : 0, pr = v ? v->player_row : 0;
    if (c <= 0 || c > U2_VIEW_MAX_CELLS) c = U2_VIEW_COLS;
    if (r <= 0 || r > U2_VIEW_MAX_CELLS) r = U2_VIEW_ROWS;
    if (pc < 0 || pc >= c) pc = U2_VIEW_PLAYER_COL < c ? U2_VIEW_PLAYER_COL : c / 2;
    if (pr < 0 || pr >= r) pr = U2_VIEW_PLAYER_ROW < r ? U2_VIEW_PLAYER_ROW : r / 2;
    if (cols) *cols = c;
    if (rows) *rows = r;
    if (player_col) *player_col = pc;
    if (player_row) *player_row = pr;
}

/* The mapping itself, exposed because the encounter and passability code needs
 * the same translation the renderer does (asm/2423 asks about the tile the
 * player is standing on). */
static inline uint8_t u2_view_index(uint8_t map_byte)
{
    return (uint8_t)((map_byte >> 1) & 0xFE);
}

/*
 * Fill the viewport.
 *
 *   px, py      player position inside the sector, the DS:00 / DS:01 pair
 *   off_map     the DS:12 byte. It carries two jobs, and asm/5AB1 is what splits them:
 *               0xFF means the world map, which is a torus and wraps on both axes; any
 *               other value means a site sector, which does not wrap, and cells past its
 *               edge draw U2_VIEW_SITE_OFFGRID. It is also the filler for the
 *               no-sector-resident case, and it is a mode byte, never a tile.
 *   underlay    the DS:0x372 analogue, U2_VIEW_TILES bytes; NULL means "no
 *               underlay layer", which suppresses nothing
 *   empty_gate  the DS:54E == 0xFF test; non-zero allows empty tiles to draw
 *
 * The underlay's producer is not yet identified in the asm, so it is an input
 * here rather than something this module invents. Passing NULL is the honest
 * default until it is found.
 */
void u2_view_fill(u2_view *v, const u2_world *w, int px, int py,
                  uint8_t off_map, const uint8_t *underlay, int empty_gate);

/* The tile index to draw at window (col, row), or -1 when the cell is
 * suppressed. Out-of-range coordinates also give -1. */
int u2_view_at(const u2_view *v, int col, int row);

/*
 * Staging byte -> art record.
 *
 * The staging byte is always even (0,2,4,...,126) because the fill loop computes
 * it as (map_byte >> 1) & 0xFE, and the art table holds exactly 64 records.
 * Those two facts only reconcile if the flush lookup halves the staging byte:
 * art = staging / 2. Assuming the table was indexed by the staging byte directly
 * doubled every tile index, which rendered as: grass shown as mountains,
 * mountains shown as the castle, the castle shown as a humanoid — and water
 * correct, because 0 is the only index where doubling is invisible.
 *
 * The player cell is the confirmation the reasoning needed: its staging byte is
 * 0x78 (120), which looked out of range against a 64-entry table, but halves to
 * art 60, a humanoid figure. The value was never out of range; the lookup was.
 */
static inline int u2_view_art(int staging)
{
    return staging >> 1;
}

/* Window coordinates of the player, always (9, 5) by construction; a function
 * so a test can assert the geometry rather than trust a constant. */
static inline int u2_view_player_col(void) { return U2_VIEW_PLAYER_COL; }
static inline int u2_view_player_row(void) { return U2_VIEW_PLAYER_ROW; }

#endif /* U2_VIEW_H */
