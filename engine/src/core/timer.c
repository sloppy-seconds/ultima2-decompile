/*
 * timer.c — the delay seam.
 * spec: asm/52CA_timed_wait.asm (the delay loop; it stages its AH/CX/DX
 *       arguments into the CS-side scratch block cs:0x4F04..cs:0x4F0A — that is
 *       a parameter block, not self-modifying code, see disasm/selfmod-capture.md).
 *
 * There is no tick source here on purpose. The bytes at DS:0x23F..0x244 that an
 * earlier reading called "tick counters" are the rand_byte shift register
 * (see core/rng.h), so nothing in the engine derives randomness from a clock.
 * The clock exists only to make timed_wait wait.
 */
#include "core/timer.h"

void u2_wait_ms(u2_ctx *ctx, uint32_t ms)
{
    if (ctx->clock->sleep_ms)
        ctx->clock->sleep_ms(ctx, ms);
}
