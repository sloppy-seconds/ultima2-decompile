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
        const uint8_t my = (uint8_t)(row + oy);
        const int y_out = (my >= U2_SECTOR_EDGE);

        for (int col = 0; col < U2_VIEW_COLS; col++) {
            const uint8_t mx = (uint8_t)(col + ox);
            const int x_out = (mx >= U2_SECTOR_EDGE);

            /* asm/5AE1: an off-sector cell takes its tile from DS:12, and does
             * not consult the map at all. */
            uint8_t map_byte = off_map;
            if (!x_out && !y_out && w && w->map_loaded)
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
