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

    for (int row = 0; row < U2_VIEW_ROWS; row++) {
        const int my = (row + oy) & (U2_SECTOR_EDGE - 1);

        for (int col = 0; col < U2_VIEW_COLS; col++) {
            const int mx = (col + ox) & (U2_SECTOR_EDGE - 1);

            /* The viewport WRAPS. The sector is a torus and the fill loop reads it
             * as one, so terrain continues past every edge instead of stopping at a
             * strip of filler. Measured, not inferred: live capture 2026-10-27, the
             * owner standing at (0,11) in sector 20 of the original, origin (-9,6).
             * Staging row 5 read
             *   84 84 84 84 84 84 84 84 84 78 84 84 84 84 84 84 84 84 86 86
             * and map row 11 wrapped from column 55 produced exactly those values
             * with bit 7 set (0x08 grass -> 0x04 -> 0x84, 0x0C forest -> 0x06 ->
             * 0x86). Column 9 is 0x78, the player stamp, not a tile.
             *
             * The previous behaviour substituted DS:12 for off-sector cells and cited
             * asm/5AE1 for it. That is the seam the owner reported as a teleport:
             * approach the west edge and the left of the screen fills with a
             * constant, then at the boundary the real terrain arrives all at once.
             * The original never blanks, so it reads as a scroll.
             *
             * off_map is no longer consulted while a sector is resident. DS:12 still
             * exists and still reads 0xFF live — the engine's tile_offsector = 4 was
             * never right either — but whatever feeds it is not this loop, and that
             * is its own ticket. */
            uint8_t map_byte = off_map;
            if (w && w->map_loaded)
                map_byte = u2_world_tile_at(w, mx, my);

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
