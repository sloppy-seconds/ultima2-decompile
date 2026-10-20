/*
 * status.c — the right-column status block.
 *
 * spec: asm/50F9_show_hitpoints.asm, asm/5129_sub_5129.asm,
 *       asm/5154_sub_5154.asm, asm/5175_sub_5175.asm.
 * Positions and source bytes are proven in status.h; the binary-vs-BCD question
 * is flagged there rather than guessed.
 *
 * No game text is hardcoded: the labels come from the generated content header,
 * which is extracted from the user's own copy at build time.
 */

#include <stdio.h>
#include "game/status.h"
#include "core/seam.h"
#include "gen_content.h"

/* The original loads the pair as `mov al,[lo]; mov bl,[hi]` and hands it to a
 * print helper that is not decoded yet, so the encoding is not proven. The
 * creation routine stores plain 4s, which only reads correctly as binary
 * little-endian, so that is what is used. See status.h OPEN QUESTION. */
static int pair_value(uint8_t lo, uint8_t hi)
{
    return (int)lo + ((int)hi << 8);
}

static void draw_line(u2_ctx *ctx, int row, const char *label, int value)
{
    char buf[16];
    snprintf(buf, sizeof buf, "%s%d", label, value);
    seam_str_out_at(ctx, 30, row, buf);
}

void u2_status_draw_hp(u2_ctx *ctx)
{
    /* asm/50F9 sets the right margin to 0x28 before drawing H.P.= . */
    ctx->state.right_margin = 0x28;
    draw_line(ctx, 20, U2_S_STATUS_HP,
              pair_value(ctx->state.hp, ctx->state.unk_52));
}

void u2_status_draw(u2_ctx *ctx)
{
    u2_status_draw_hp(ctx);
    draw_line(ctx, 21, U2_S_STATUS_FOOD,
              pair_value(ctx->state.food, ctx->state.food_hi));
    draw_line(ctx, 22, U2_S_STATUS_EXP,
              pair_value(ctx->state.exp_lo, ctx->state.exp_hi));
    draw_line(ctx, 23, U2_S_STATUS_GOLD,
              pair_value(ctx->state.gold_lo, ctx->state.gold_hi));
    /* The GOLD= tail restores the margin to 0x1d (file 0x5396). */
    ctx->state.right_margin = 0x1d;
}
