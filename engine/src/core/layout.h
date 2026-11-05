#ifndef U2_LAYOUT_H
#define U2_LAYOUT_H
/*
 * Enhanced-mode screen layout.
 *
 * The shape comes from the FM Towns version as photographed in
 * references/fmtowns-screens, and it is a reimplementation of a presentation, not
 * a byte-matching target: the FM Towns binary has never been disassembled here, so
 * every number below is measured from photographs of a CRT and carries that grade.
 * docs/enhanced-layout-plan.md § 1 has the measurements and § 9 the owner rulings.
 *
 * The one number that is NOT from the reference is the map size. The reference map
 * is 11 x 12 because FM Towns draws its panel text at about 16 px, and a readable
 * panel at that size costs 276 px of the 640. Our font is 8x8 and the owner ruled
 * the panel at 8 px, which buys back the columns: 14 x 14 = 196 cells, against the
 * DOS window's 200. That is the whole reason the enhanced map is square-ish and the
 * reference is not.
 */

#include "core/font.h"   /* U2_FONT_CELL_W, so text columns are whole glyphs */

/* The frame the enhanced layout is designed for. Classic mode stays at 320x200
 * (or 640x400 doubled) and is untouched by any of this.
 *
 * 1024x512 rather than a full 4:3: the width is what lets a 14-column map and a
 * readable 16px panel coexist, and the height is only what the map plus the bar
 * need, so there is no dead band under the map. Fits a 1024x768 display with room
 * to spare, which is the smallest display the owner was willing to assume. */
#define U2_ENH_W 1024
#define U2_ENH_H 512

/* The enhanced frame is a DOUBLED canvas, and that is load-bearing twice over.
 * Text drawn through the font API comes out at 16px rather than the unreadable 8px
 * of a scale-1 frame, and a v1 16px theme presents at 32px via
 * u2_tiles_ega_present(), so every theme fills the same map cell instead of a v1
 * theme occupying a quarter of the space. The cost is width: 768 rather than the
 * reference's 640, because 14 map columns and a readable panel do not both fit in
 * 640 (docs/enhanced-layout-plan.md § 9a). */
#define U2_ENH_SCALE 2
/* One glyph, in physical pixels. Panel geometry is in these, not raw pixels, so
 * text can never land half on a glyph cell. */
#define U2_ENH_TEXT_W (U2_FONT_CELL_W * U2_ENH_SCALE)
#define U2_ENH_TEXT_H (U2_FONT_CELL_H * U2_ENH_SCALE)

/* Map window: 14 x 14 tiles. The tile side comes from the theme, so a v1 16 px
 * theme draws 14 x 14 of those and simply leaves room at the right; the geometry
 * below is in pixels and does not care. */
#define U2_ENH_MAP_COLS 14
#define U2_ENH_MAP_ROWS 14
#define U2_ENH_MAP_X    0
#define U2_ENH_MAP_Y    0

/* Panel column, and the three boxes inside it. Widths are in whole text cells so
 * the text never clips mid-glyph. */
#define U2_ENH_PANEL_X     (U2_ENH_MAP_COLS * 32)          /* 448 */
#define U2_ENH_PANEL_W     (U2_ENH_W - U2_ENH_PANEL_X)     /* 320 */

/* Padding is a WHOLE text cell, not 4px. The font API snaps to the glyph grid, so
 * a sub-cell pad collapses to 0 and the first glyph lands on the box border —
 * which is what made the borders look missing on the first prototype. */
#define U2_ENH_BOX_PAD     U2_ENH_TEXT_W
#define U2_ENH_BOX_BORDER  1
#define U2_ENH_BOX_GAP     4
#define U2_ENH_TEXT_COLS   ((U2_ENH_PANEL_W - 2 * U2_ENH_BOX_PAD) / U2_ENH_TEXT_W)

#define U2_ENH_BOX1_Y      0
#define U2_ENH_BOX1_H      (5 * U2_ENH_TEXT_H)  /* name, H/E, F/G, and the avatar */
#define U2_ENH_BOX2_Y      (U2_ENH_BOX1_Y + U2_ENH_BOX1_H + U2_ENH_BOX_GAP)
#define U2_ENH_BOX2_H      (9 * U2_ENH_TEXT_H)  /* six stats with leaders, then WEA:/ARM: */
#define U2_ENH_BOX3_Y      (U2_ENH_BOX2_Y + U2_ENH_BOX2_H + U2_ENH_BOX_GAP)
#define U2_ENH_BOX3_H      (U2_ENH_MAP_Y + U2_ENH_MAP_ROWS * 32 - U2_ENH_BOX3_Y)

/* The bottom bar. Measured as constant full-width chrome in the reference (it does
 * not track HP: identical in frames at H:258 and H:4922), and ruled to stay
 * meaningless for now with "planet or area" as its candidate use.
 * Positioned from the bottom of the frame rather than a literal, so it survives a
 * change of frame height without silently overlapping the map. */
#define U2_ENH_BAR_H       16
#define U2_ENH_BAR_Y       (U2_ENH_MAP_Y + U2_ENH_MAP_ROWS * 32 + 8)
#define U2_ENH_BAR_X       8
#define U2_ENH_BAR_W       (U2_ENH_W - 2 * U2_ENH_BAR_X)

/* Where the player sits in the enhanced window. The reference centres the figure;
 * with an even count there is no exact centre, so this is the one that leaves the
 * extra row below, which is where you want the warning space. */
#define U2_ENH_PLAYER_COL  (U2_ENH_MAP_COLS / 2)
#define U2_ENH_PLAYER_ROW  (U2_ENH_MAP_ROWS / 2)

#endif /* U2_LAYOUT_H */
