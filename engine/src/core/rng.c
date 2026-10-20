/*
 * rng.c — tick-counter random byte.
 * spec: asm/5217_rand_byte.asm
 */
#include "core/rng.h"
#include "core/timer.h"

uint8_t u2_rand_byte(u2_ctx *ctx)
{
    u2_state *s = &ctx->state;

    /* Faithful to the byte sequence, carry chain included:
     * stc -> CF=1; adc adds operand + CF; the second adc adds the carry
     * produced by the first addition, not a fresh 1. */
    unsigned al = s->tick_a;
    unsigned t = al + (unsigned)s->tick_b + 1u;
    al = t & 0xFFu;
    unsigned cf = (t >> 8) & 1u;
    t = al + (unsigned)s->tick_c + cf;
    al = t & 0xFFu;

    u2_timer_pump(ctx);
    return (uint8_t)al;
}

void u2_rng_set_deterministic(u2_ctx *ctx, int on)
{
    ctx->clock = on ? &u2_clock_script : &u2_clock_posix;
}
