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
    /* Zeroed on purpose. An uninitialised view here is a real defect, not tidiness:
     * u2_view_fill sizes its clearing memset from cols*rows, so stack garbage in
     * those fields makes it write an arbitrary amount. That was latent until the
     * struct grew and shifted what garbage landed there, and it showed up as a
     * segfault in roughly a third of runs of a program with no randomness at all. */
    memset(&v, 0, sizeof v);
    uint8_t no_underlay[U2_VIEW_TILES];
    memset(no_underlay, 0xFF, sizeof no_underlay); /* matches nothing below 0x7F */

    /* The guard itself. A view whose shape is garbage must fall back rather than
     * size its clearing memset from the garbage. This is the control: remove the
     * upper-bound test in u2_view_fill and this case crashes instead of passing,
     * which is the only reason it is here rather than assumed. */
    {
        u2_view junk;
        memset(&junk, 0, sizeof junk);
        junk.cols = 0x41414141;          /* positive, absurd: the shape that crashed */
        junk.rows = 0x41414141;
        u2_view_fill(&junk, &world, 33, 23, 0xFF, no_underlay, 0);
        int c2 = 0, r2 = 0;
        u2_view_shape(&junk, &c2, &r2, NULL, NULL);
        CHECK(c2 == U2_VIEW_COLS && r2 == U2_VIEW_ROWS,
              "an absurd view shape falls back to the DOS window");
    }

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

    /* --- the world map WRAPS at the sector edge --------------------------
     * This check used to assert the opposite — "take the off-map tile, not a
     * wrap" — and it passed, because it was written from a reading of asm/5AE1
     * rather than from the running game. A test that encodes a wrong belief is
     * worse than no test: it made the seam unfixable without going red first.
     * Replaced by live capture 2026-10-27 (owner at (0,11), sector 20): staging
     * row 5 held the map's own columns 55..63 on the left of the screen.
     *
     * The mode byte is 0xFF here on purpose. asm/5AB1 branches on it, and the wrap
     * belongs to the world-map arm alone; the previous version of this test passed
     * 0x2A, an arbitrary filler, which is a site mode and must NOT wrap. */
    synth_world();
    u2_view_fill(&v, &world, 3, 3, 0xFF, no_underlay, 0);
    /* x-9 = -6 and y-5 = -2, both of which the original masks back into range. */
    int wrap_ok = 1;
    for (int c = 0; c < 9; c++)
        if (u2_view_at(&v, c, 0) !=
            u2_view_index(u2_world_tile_at(&world, (3 - 9 + c) & 63, (3 - 5) & 63)))
            wrap_ok = 0;
    CHECK(wrap_ok, "on the world map, columns left of the west edge show the wrapped columns");
    CHECK(u2_view_at(&v, 9, 0) ==
              u2_view_index(u2_world_tile_at(&world, 3, (3 - 5) & 63)),
          "on the world map the top row wraps in y as well as x");
    CHECK(u2_view_at(&v, 19, 9) == u2_view_index(u2_world_tile_at(&world, 13, 7)),
          "cells that are inside the sector still come from the map");

    /* --- a SITE sector does not wrap -------------------------------------
     * Measured 2026-11-02 standing at (31,62) and (31,63) in Port Boniface,
     * sector 31: every row past grid row 63 is one constant tile, and bitmap
     * matching it against the extracted art gives the sector's own ground byte
     * 0x08 — a real 0x08 cell in the same frame has the identical bitmap and
     * census. captures/spice86/s31-south-edge/, and asm/5ABB is the branch that
     * computes the origin without masking.
     *
     * The engine wrapped here, which pulled a town's north edge onto the bottom of
     * the screen; in Port Boniface the north edge is a sign band, and the owner
     * reported the result as water surrounding the south exit. These checks are the
     * control that stops an unconditional `& 63` coming back. */
    synth_world();
    u2_view_fill(&v, &world, 31, 62, 0x04, no_underlay, 0);
    const int ground = u2_view_index(U2_VIEW_SITE_OFFGRID);
    CHECK(u2_view_at(&v, 9, 5) == u2_view_index(u2_world_tile_at(&world, 31, 62)),
          "in a site the player's own cell still comes from the map");
    CHECK(u2_view_at(&v, 9, 6) == u2_view_index(u2_world_tile_at(&world, 31, 63)),
          "in a site the last grid row is still the last grid row");
    int filler_ok = 1, not_wrapped = 1;
    for (int r = 7; r < U2_VIEW_ROWS; r++)
        for (int c = 0; c < U2_VIEW_COLS; c++) {
            if (u2_view_at(&v, c, r) != ground) filler_ok = 0;
            /* The wrapped answer would be row (r+57)&63; if any cell equals it, the
             * wrap is back. Row 7 wrapped is map row 0, which the synthetic sector
             * makes distinguishable from the ground byte at most columns. */
            if (u2_view_at(&v, c, r) ==
                u2_view_index(u2_world_tile_at(&world, (22 + c) & 63, (57 + r) & 63)) &&
                u2_view_index(u2_world_tile_at(&world, (22 + c) & 63, (57 + r) & 63)) != ground)
                not_wrapped = 0;
        }
    CHECK(filler_ok, "in a site, every cell past the last row draws the ground byte");
    CHECK(not_wrapped, "in a site, no off-grid cell shows the wrapped far edge instead");

    /* The same rule on the other three edges, and on the axis the world map proved first. */
    synth_world();
    u2_view_fill(&v, &world, 3, 3, 0x04, no_underlay, 0);
    int west_ok = 1;
    for (int c = 0; c < 6; c++)          /* x-9 = -6..-1; col 6 is x=0, which is inside */
        if (u2_view_at(&v, c, 5) != ground) west_ok = 0;
    CHECK(west_ok, "in a site, columns left of the west edge draw the ground byte too");
    int north_ok = 1;
    for (int r = 0; r < 2; r++)          /* y-5 = -2,-1; row 2 is y=0, which is inside */
        if (u2_view_at(&v, 9, r) != ground) north_ok = 0;
    CHECK(north_ok, "in a site, rows above the north edge draw the ground byte too");
    int inside_ok = 1;
    for (int c = 6; c <= 9; c++)
        if (u2_view_at(&v, c, 5) != u2_view_index(u2_world_tile_at(&world, c - 6, 3)))
            inside_ok = 0;
    CHECK(inside_ok, "in a site, the cells that are inside the edge still come from the map");

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

    /* --- staging byte -> art record --------------------------------------
     * This is the bug that made the map unrecognisable: the staging byte was
     * used directly as an art index, doubling every tile. Grass rendered as
     * mountains, mountains as the castle, the castle as a humanoid, and water
     * alone survived because 0 doubled is still 0. */
    int in_range = 1, even_ok = 1;
    for (int mb = 0; mb <= 0xFF; mb++) {
        const int s = u2_view_index((uint8_t)mb);
        if (s & 1) even_ok = 0;
        if (u2_view_art(s) < 0 || u2_view_art(s) > 63) in_range = 0;
    }
    CHECK(even_ok, "every staging byte is even, which is what makes the halving exact");
    CHECK(in_range, "every halved art index lands inside the 64-entry table");
    CHECK(u2_view_art(u2_view_index(0x08)) == 2,
          "map byte 0x08 -> art 2 (grass), not art 4 (mountains)");
    CHECK(u2_view_art(u2_view_index(0x10)) == 4,
          "map byte 0x10 -> art 4 (mountains), not art 8 (castle)");
    CHECK(u2_view_art(u2_view_index(0x20)) == 8,
          "map byte 0x20 -> art 8 (castle), not art 16 (humanoid)");
    CHECK(u2_view_art(0x78) == 60,
          "the player's staging byte 0x78 halves to art 60, a figure — not out of range");

    /* --- robustness ------------------------------------------------------ */
    CHECK(u2_view_at(&v, -1, 0) == -1 && u2_view_at(&v, 0, 99) == -1,
          "out-of-range window coordinates give -1, never a stray read");
    u2_view_fill(&v, NULL, 33, 23, 0x12, NULL, 0);
    CHECK(u2_view_at(&v, 5, 5) == u2_view_index(0x12),
          "a missing world falls back to the off-map tile rather than inventing one");

    printf("%d checks, %d failures\n", checks, fails);
    return fails ? 1 : 0;
}
