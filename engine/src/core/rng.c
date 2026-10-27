/*
 * rng.c — the rand_byte shift register.
 * spec: asm/5217_rand_byte.asm, asm/522B_sub_522b.asm, asm/5236_sub_5236.asm,
 *       seed at asm/0100_sub_0100.asm.
 */
#include "core/rng.h"

void u2_rng_seed(u2_ctx *ctx, uint8_t f)
{
    uint8_t *s = ctx->state.rng_state;

    /* asm/0100: six copies of the 0x40:6C byte, then incb 0x23F, incb 0x240. */
    for (int i = 0; i < 6; i++)
        s[i] = f;
    s[0] = (uint8_t)(s[0] + 1);
    s[1] = (uint8_t)(s[1] + 1);
    ctx->rng_rolls = 0;
}

void u2_rng_load(u2_ctx *ctx, const uint8_t state[6])
{
    for (int i = 0; i < 6; i++)
        ctx->state.rng_state[i] = state[i];
    ctx->rng_rolls = 0;
}

uint8_t u2_rand_byte(u2_ctx *ctx)
{
    uint8_t *s = ctx->state.rng_state;

    /* stc; mov 0x240,%al; adc 0x243,%al; adc 0x244,%al
     * The carry chain is emulated exactly: the second adc adds the carry the
     * first addition produced, not a fresh 1. */
    unsigned al = s[1];                       /* DS:0x240 */
    unsigned t = al + s[4] + 1u;              /* adc DS:0x243, CF=1 from stc */
    al = t & 0xFFu;
    unsigned cf = (t >> 8) & 1u;
    t = al + s[5] + cf;                       /* adc DS:0x244 */
    al = t & 0xFFu;

    s[0] = (uint8_t)al;                       /* mov %al,0x23f */

    /* asm/522B: bx = 4 down to 0 (jns), al = DS:0x23F(bx), DS:0x240(bx) = al. */
    for (int bx = 4; bx >= 0; bx--)
        s[1 + bx] = s[bx];

    ctx->rng_rolls++;

    return s[0];                              /* mov 0x23f,%al; or %al,%al */
}

uint32_t u2_rng_rolls(const u2_ctx *ctx)
{
    return ctx->rng_rolls;
}
