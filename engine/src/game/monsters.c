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

int u2_monsters_spawn(u2_ctx *ctx, const u2_world *w)
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
