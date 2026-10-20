#ifndef U2_TIMER_H
#define U2_TIMER_H

/*
 * Timers — the delay seam only. See core/timer.c for why there is no tick
 * source, and core/rng.h for what the DS:0x23F..0x244 bytes really are.
 */

#include <stdint.h>
#include "core/ctx.h"

/* seam: timed_wait (asm/52CA_timed_wait.asm). ms is an approximation — the
 * original burned CPU cycles, so real duration was machine-dependent. */
void u2_wait_ms(u2_ctx *ctx, uint32_t ms);

#endif /* U2_TIMER_H */
