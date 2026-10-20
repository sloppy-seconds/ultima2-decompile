/*
 * timer.c — tick counters and the delay seam.
 * spec: asm/52CA_timed_wait.asm, asm/0100_sub_0100.asm, clock_int1a seam sites
 */
#include "core/timer.h"

void u2_timer_pump(u2_ctx *ctx)
{
    u2_state *s = &ctx->state;
    uint64_t t = ctx->clock->tick(ctx);

    /* The original's three tick bytes are whatever the hardware timer left in
     * them; only their mixture reaches rand_byte. The engine folds the
     * monotonic tick into three bytes so the mix changes on every pump and
     * wraps like the 8-bit originals. */
    s->tick_a = (uint8_t)(t & 0xFFu);
    s->tick_b = (uint8_t)((t >> 8) & 0xFFu);
    s->tick_c = (uint8_t)((t >> 16) & 0xFFu);
}

void u2_wait_ms(u2_ctx *ctx, uint32_t ms)
{
    if (ctx->clock->sleep_ms)
        ctx->clock->sleep_ms(ctx, ms);
    u2_timer_pump(ctx);
}
