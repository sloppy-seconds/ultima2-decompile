/*
 * view.c — the viewport fill, transcribed from asm/5AE1..5B6C.
 *
 * Deliberately free of I/O and of any renderer knowledge: it turns a resident
 * sector plus a position into the staging grid the flush loop would consume.
 * That boundary is what lets the whole of CP4's map logic be tested without a
 * display, and what keeps the tile-ID seam intact.
 */

#include <string.h>

#include "core/view.h"

/*
 * The original does this arithmetic in 8-bit registers, and that detail is load
 * bearing rather than incidental. DS:02 and DS:03 are computed as
 *
 *   stc ; mov al,[0x00] ; cmc ; sbb al,9      ->  al = x - 9  (mod 256)
 *
 * so a player near the left edge gets a wrapped, very large offset, and the
 * subsequent `cmp al,0x40 / jae` classifies it as off-map without any signed
 * comparison anywhere. Reproducing that with uint8_t keeps the edge behaviour
 * identical instead of inventing a "nicer" one that would diverge at x < 9.
 */
void u2_view_fill(u2_view *v, const u2_world *w, int px, int py,
                  uint8_t off_map, const uint8_t *underlay, int empty_gate)
{
    if (!v) return;
    memset(v->tile, 0, sizeof v->tile);
    v->drawn = 0;

    const uint8_t ox = (uint8_t)(px - U2_VIEW_PLAYER_COL);
    const uint8_t oy = (uint8_t)(py - U2_VIEW_PLAYER_ROW);

    /* asm/5AB1 opens `cmpb $0xff,0x12` and branches between two viewport origins that differ
     * in exactly one respect: asm/5B98 masks both axes with `and $0x3f` and asm/5ABB
     * deliberately does not. The world map is a torus. A site sector is a finite array, and a
     * cell past its edge is off the array rather than wrapped to the far side.
     *
     * Measured 2026-11-02 standing at (31,62) and (31,63) in Port Boniface, sector 31: the
     * rows past grid row 63 are one constant tile, and that tile is the sector's own ground
     * byte 0x08 -- a real 0x08 cell in the same frame has the identical bitmap and the
     * identical census (245 black + 11 cyan). captures/spice86/s31-south-edge/. The engine
     * wrapped here, which pulled the town's north sign band onto the bottom of the screen and
     * read to the owner as a wall of water. Note that no wilderness capture could have found
     * this: mapx30 rows 0, 1 and 60..63 are all 0x00, so a wrap and a filler are the same
     * pixels at both Y edges of every sector measured before that day.
     *
     * The comparison is 8-bit on purpose, as it is in the asm. An origin of py-5 below zero
     * arrives as a large unsigned value, and `>= 64` classifies it without any signed
     * comparison anywhere -- which is also what asm/5AE1's `cmp $0x40 / jae` does.
     *
     * The torus itself is measured, not inferred: live capture 2026-10-27, the owner standing
     * at (0,11) in sector 20 of the original, origin (-9,6). Staging row 5 read
     *   84 84 84 84 84 84 84 84 84 78 84 84 84 84 84 84 84 84 86 86
     * and map row 11 wrapped from column 55 produced exactly those values with bit 7 set
     * (0x08 grass -> 0x04 -> 0x84, 0x0C forest -> 0x06 -> 0x86). Column 9 is 0x78, the
     * player stamp, not a tile. Before that capture the engine blanked off-sector cells with
     * DS:12, which the owner reported as a teleport: approach the west edge and the screen
     * fills with a constant, then the real terrain arrives all at once. */
    const int torus = (off_map == 0xFF);

    for (int row = 0; row < U2_VIEW_ROWS; row++) {
        const uint8_t my8 = (uint8_t)(row + oy);
        const int my = torus ? (my8 & (U2_SECTOR_EDGE - 1)) : (int)my8;

        for (int col = 0; col < U2_VIEW_COLS; col++) {
            const uint8_t mx8 = (uint8_t)(col + ox);
            const int mx = torus ? (mx8 & (U2_SECTOR_EDGE - 1)) : (int)mx8;

            /* In torus mode every coordinate is already inside the sector, so the bounds test
             * below only ever fires in a site sector. */
            uint8_t map_byte = off_map;
            if (w && w->map_loaded)
                map_byte = (my < U2_SECTOR_EDGE && mx < U2_SECTOR_EDGE)
                               ? u2_world_tile_at(w, mx, my)
                               : U2_VIEW_SITE_OFFGRID;

            uint8_t idx = u2_view_index(map_byte);
            const int i = row * U2_VIEW_COLS + col;

            /* asm/5AE1 store path: a tile matching the underlay is hidden,
             * except the two escapes the asm spells out. */
            if (underlay && idx == underlay[i]) {
                const int keep_empty = (idx == 0 && empty_gate);
                if (!keep_empty && idx != U2_VIEW_EMPTY)
                    idx |= U2_VIEW_NO_DRAW;
            }

            v->tile[i] = idx;
            if (!(idx & U2_VIEW_NO_DRAW)) v->drawn++;
        }
    }
}

int u2_view_at(const u2_view *v, int col, int row)
{
    if (!v || col < 0 || col >= U2_VIEW_COLS || row < 0 || row >= U2_VIEW_ROWS)
        return -1;
    const uint8_t s = v->tile[row * U2_VIEW_COLS + col];
    if (s & U2_VIEW_NO_DRAW) return -1;      /* asm/4ABB: or cl,cl; js skip */
    return s & 0x7F;
}
