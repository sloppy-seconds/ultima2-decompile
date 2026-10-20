/*
 * tests/view_check.c — the guarantees of core/view.c.
 *
 * The viewport is where the map byte becomes something drawable, so the whole
 * CP4 render contract rests on these rules. All map bytes here are synthetic
 * filler; no game content is involved.
 *
 * Build and run by tests/run_cp4.sh.
 */

#include <stdio.h>
#include <string.h>

#include "core/view.h"
#include "core/world.h"

static int fails, checks;

#define CHECK(cond, msg)                                              \
    do {                                                              \
        checks++;                                                     \
        if (cond) printf("  ok    %s\n", msg);                        \
        else      { printf("  FAIL  %s\n", msg); fails++; }           \
    } while (0)

static u2_world world;

/* Deterministic synthetic sector: a value whose index is easy to predict. */
static void synth_world(void)
{
    memset(&world, 0, sizeof world);
    world.map_loaded = 1;
    for (int y = 0; y < U2_SECTOR_EDGE; y++)
        for (int x = 0; x < U2_SECTOR_EDGE; x++)
            world.map[y * U2_SECTOR_EDGE + x] = (uint8_t)(((x + y) & 0x1F) * 2);
}

int main(void)
{
    printf("view_check\n");
    u2_view v;
    uint8_t no_underlay[U2_VIEW_TILES];
    memset(no_underlay, 0xFF, sizeof no_underlay); /* matches nothing below 0x7F */

    /* --- the mapping itself ---------------------------------------------- */
    CHECK(u2_view_index(0x00) == 0x00, "map byte 0x00 -> tile 0");
    CHECK(u2_view_index(0x08) == 0x04, "map byte 0x08 -> tile 4");
    CHECK(u2_view_index(0x0C) == 0x06, "map byte 0x0C -> tile 6");
    CHECK(u2_view_index(0x70) == 0x38, "map byte 0x70 -> tile 0x38");
    CHECK(u2_view_index(0x0A) == 0x04, "low bit of the index is forced clear");
    CHECK(u2_view_index(0xFF) == 0x7E, "the largest index stays inside the 64-entry table");

    /* --- geometry -------------------------------------------------------- */
    synth_world();
    u2_view_fill(&v, &world, 33, 23, 0xFF, no_underlay, 0);
    CHECK(u2_view_player_col() == 9 && u2_view_player_row() == 5,
          "the player window cell is (9, 5), as the screenshots measured");

    /* The centre cell must be the tile under the player, not an offset of it. */
    CHECK(u2_view_at(&v, 9, 5) == u2_view_index(u2_world_tile_at(&world, 33, 23)),
          "window (9,5) shows the tile at the player's own position");

    /* Top-left must be (x-9, y-5). */
    CHECK(u2_view_at(&v, 0, 0) == u2_view_index(u2_world_tile_at(&world, 24, 18)),
          "window (0,0) is map cell (x-9, y-5)");
    CHECK(u2_view_at(&v, 19, 9) == u2_view_index(u2_world_tile_at(&world, 43, 27)),
          "window (19,9) is map cell (x+10, y+4)");

    int all = 1;
    for (int r = 0; r < U2_VIEW_ROWS; r++)
        for (int c = 0; c < U2_VIEW_COLS; c++)
            if (u2_view_at(&v, c, r) !=
                u2_view_index(u2_world_tile_at(&world, 24 + c, 18 + r))) all = 0;
    CHECK(all, "every one of the 200 cells matches map[(y-5+r)*64 + (x-9+c)]");
    CHECK(v.drawn == U2_VIEW_TILES, "with no suppression all 200 cells are drawable");

    /* --- off-sector cells come from DS:12, with 8-bit wrap semantics ----- */
    synth_world();
    u2_view_fill(&v, &world, 3, 3, 0x2A, no_underlay, 0);
    /* x-9 = -6 which the original computes as 0xFA, so columns 0..8 are off-map. */
    int off_ok = 1;
    for (int c = 0; c < 9; c++)
        if (u2_view_at(&v, c, 0) != u2_view_index(0x2A)) off_ok = 0;
    CHECK(off_ok, "columns left of the sector edge take the off-map tile, not a wrap");
    CHECK(u2_view_at(&v, 9, 0) == u2_view_index(0x2A),
          "the player's own row is still off-map in y at the top edge");
    CHECK(u2_view_at(&v, 19, 9) == u2_view_index(u2_world_tile_at(&world, 13, 7)),
          "cells that are inside the sector still come from the map");

    /* --- underlay suppression ------------------------------------------- */
    synth_world();
    uint8_t under[U2_VIEW_TILES];
    u2_view_fill(&v, &world, 33, 23, 0xFF, no_underlay, 0);
    memcpy(under, v.tile, sizeof under);       /* underlay == what would draw */
    u2_view_fill(&v, &world, 33, 23, 0xFF, under, 0);
    int suppressed = 0, escaped = 0;
    for (int i = 0; i < U2_VIEW_TILES; i++) {
        if (v.tile[i] & U2_VIEW_NO_DRAW) suppressed++;
        else escaped++;
    }
    CHECK(suppressed > 0, "a tile matching the underlay is suppressed with bit 7");
    CHECK(u2_view_at(&v, 3, 3) == -1, "a suppressed cell reports -1, i.e. not drawn");
    CHECK(v.drawn == escaped, "the drawn count agrees with the suppression flags");

    /* The two escapes the asm spells out. */
    synth_world();
    for (int i = 0; i < U2_VIEW_TILES; i++) under[i] = 0x00;
    u2_view_fill(&v, &world, 33, 23, 0xFF, under, 1);
    int zero_kept = 1;
    for (int i = 0; i < U2_VIEW_TILES && zero_kept; i++)
        if ((v.tile[i] & 0x7F) == 0 && (v.tile[i] & U2_VIEW_NO_DRAW)) zero_kept = 0;
    CHECK(zero_kept, "with the empty gate set, index 0 is never suppressed");

    synth_world();
    for (int i = 0; i < U2_VIEW_TILES; i++) under[i] = 0x00;
    u2_view_fill(&v, &world, 33, 23, 0xFF, under, 0);
    int zero_hidden = 0;
    for (int i = 0; i < U2_VIEW_TILES; i++)
        if ((v.tile[i] & 0x7F) == 0 && (v.tile[i] & U2_VIEW_NO_DRAW)) zero_hidden = 1;
    CHECK(zero_hidden, "with the gate clear, index 0 matching the underlay is hidden");

    synth_world();
    for (int i = 0; i < U2_VIEW_TILES; i++) under[i] = U2_VIEW_EMPTY;
    u2_view_fill(&v, &world, 33, 23, 0xFF, under, 0);
    int esc_ok = 1;
    for (int i = 0; i < U2_VIEW_TILES; i++)
        if ((v.tile[i] & 0x7F) == U2_VIEW_EMPTY &&
            (v.tile[i] & U2_VIEW_NO_DRAW)) esc_ok = 0;
    CHECK(esc_ok, "index 0x2E escapes underlay suppression, as the asm's second test says");

    /* --- robustness ------------------------------------------------------ */
    CHECK(u2_view_at(&v, -1, 0) == -1 && u2_view_at(&v, 0, 99) == -1,
          "out-of-range window coordinates give -1, never a stray read");
    u2_view_fill(&v, NULL, 33, 23, 0x12, NULL, 0);
    CHECK(u2_view_at(&v, 5, 5) == u2_view_index(0x12),
          "a missing world falls back to the off-map tile rather than inventing one");

    printf("%d checks, %d failures\n", checks, fails);
    return fails ? 1 : 0;
}
