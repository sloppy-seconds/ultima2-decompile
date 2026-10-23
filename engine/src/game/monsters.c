/*
 * monsters.c — CP5 W1: the monx block <-> the creature arrays in the state block.
 *
 * No combat rules and no AI live here on purpose. Every byte movement in this file
 * is a copy between two buffers whose layout is measured, not guessed:
 *
 *   monxNN offset -> DS field   (docs/monster-spawn.md § 6, matched live on four sectors)
 *        0..31     -> mon_x   (DS:137)
 *       32..63     -> mon_y   (DS:157)
 *       64..95     -> mon_hp  (DS:177)
 *       96..127    -> mon_type(DS:197)
 *      128..159    -> mon_kind(DS:1B7)
 *      160..191    -> mon_role(DS:1D7)
 *
 * asm/22D5 reads 256 bytes (CX=0x100) for six 32-byte arrays totalling 192, so
 * the tail of the buffer is unread by anything found so far and is left alone on
 * a store round trip.
 */
#include "game/monsters.h"

#include <string.h>

#include "core/ctx.h"

/* monx offset of each array. Kept as one table so a future re-measurement is a
 * single edit, and so the store path cannot drift from the load path. */
#define MON_OFF_X    0
#define MON_OFF_Y    32
#define MON_OFF_HP   64
#define MON_OFF_TYPE 96
#define MON_OFF_KIND 128
#define MON_OFF_ROLE 160

int u2_monsters_spawn(u2_ctx *ctx, u2_world *w)
{
    if (ctx == NULL || w == NULL || !w->mon_loaded)
        return 0;

    u2_state *s = &ctx->state;
    memcpy(s->mon_x,    w->mon + MON_OFF_X,    U2_MON_SLOTS);
    memcpy(s->mon_y,    w->mon + MON_OFF_Y,    U2_MON_SLOTS);
    memcpy(s->mon_hp,   w->mon + MON_OFF_HP,   U2_MON_SLOTS);
    memcpy(s->mon_type, w->mon + MON_OFF_TYPE, U2_MON_SLOTS);
    memcpy(s->mon_kind, w->mon + MON_OFF_KIND, U2_MON_SLOTS);
    memcpy(s->mon_role, w->mon + MON_OFF_ROLE, U2_MON_SLOTS);

    int occupied = 0;
    for (int i = 0; i < U2_MON_SLOTS; i++) {
        if (s->mon_x[i] || s->mon_y[i])
            occupied++;
    }

    /* CP5 W2: the stamp.
     *
     * The renderer does not read the monster record. docs/art-index.md settled
     * that on the only slot in the corpus where the two fields disagree — grid
     * 0x38 versus type 0x34 — where the drawn pixels matched 0x38>>2 at 256/256
     * and 0x34>>2 at 171/256. So the original stamps the type byte into the
     * in-memory sector map at spawn and the view draws the map, which is what
     * this loop reproduces.
     *
     * Stamping the one grid rather than keeping a second is deliberate: the same
     * cell is what passability reads, so a creature blocks movement the way the
     * original does it — by not being a walkable tile — with no extra check
     * anywhere. One grid, one truth.
     *
     * The empty-slot test is the module's own (x||y), not hp, so a slot the
     * spawner left alone is never stamped. On a kill, asm/2E3D file 0x30F4 writes
     * 0x80 over the cell, which is the view's "do not draw" bit rather than a
     * restoration of the terrain beneath; whether the original ever puts terrain
     * back is not established, so the kill path writes what the bytes show.
     *
     * INFERRED, and it is the line to suspect first if a creature ever draws in
     * the wrong cell: that the stamp lands at y*64+x with the sector's own stride
     * is assumed from the grid geometry, not read off the stamping site.
     *
     * The layout this stamps was re-confirmed live on 2026-10-23 against sector 31
     * with G23MAX loaded: mon_hp, mon_type and mon_role matched monx31 at 32/32
     * each, mon_kind 30/32, and x/y under-matched only because creatures walk.
     * That is a fourth independent capture agreeing with docs/monster-spawn.md § 2,
     * which is also the capture that disproved a false alarm raised against this
     * same file the same day — see § 10 there before doubting these offsets. */

    for (int i = 0; i < U2_MON_SLOTS; i++) {
        if (!(s->mon_x[i] || s->mon_y[i]))
            continue;
        const int cell = (int)s->mon_y[i] * U2_SECTOR_EDGE + (int)s->mon_x[i];
        if (cell < 0 || cell >= U2_SECTOR_TILES)
            continue;
        w->map[cell] = s->mon_type[i];
    }
    return occupied;
}

void u2_monsters_store(u2_ctx *ctx, u2_world *w)
{
    if (ctx == NULL || w == NULL || !w->mon_loaded)
        return;

    const u2_state *s = &ctx->state;
    memcpy(w->mon + MON_OFF_X,    s->mon_x,    U2_MON_SLOTS);
    memcpy(w->mon + MON_OFF_Y,    s->mon_y,    U2_MON_SLOTS);
    memcpy(w->mon + MON_OFF_HP,   s->mon_hp,   U2_MON_SLOTS);
    memcpy(w->mon + MON_OFF_TYPE, s->mon_type, U2_MON_SLOTS);
    memcpy(w->mon + MON_OFF_KIND, s->mon_kind, U2_MON_SLOTS);
    memcpy(w->mon + MON_OFF_ROLE, s->mon_role, U2_MON_SLOTS);
    w->mon_dirty = 1;
}

int u2_monsters_at(const u2_ctx *ctx, int x, int y)
{
    if (ctx == NULL)
        return -1;
    for (int i = 0; i < U2_MON_SLOTS; i++) {
        if ((ctx->state.mon_x[i] || ctx->state.mon_y[i]) &&
            ctx->state.mon_x[i] == (uint8_t)x &&
            ctx->state.mon_y[i] == (uint8_t)y)
            return i;
    }
    return -1;
}

int u2_monsters_nearest(const u2_ctx *ctx, int x, int y)
{
    if (ctx == NULL)
        return -1;

    int best = -1, best_d = 1 << 30;
    for (int i = 0; i < U2_MON_SLOTS; i++) {
        if (!(ctx->state.mon_x[i] || ctx->state.mon_y[i]))
            continue;
        int dx = (int)ctx->state.mon_x[i] - x;
        int dy = (int)ctx->state.mon_y[i] - y;
        int d  = (dx < 0 ? -dx : dx) + (dy < 0 ? -dy : dy);
        if (d < best_d) {
            best_d = d;
            best = i;
        }
    }
    return best;
}
