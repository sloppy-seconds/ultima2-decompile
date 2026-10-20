#ifndef U2_TIMER_H
#define U2_TIMER_H

/*
 * Timers — the DS tick counters and the delay seam.
 *
 * spec: asm/52CA_timed_wait.asm (delay loop; stages its AH/CX/DX arguments
 *       into the CS-side parameter block cs:0x4F04..cs:0x4F0A — that block is
 *       static scratch, not self-modifying code, see disasm/selfmod-capture.md),
 *       asm/0100_sub_0100.asm (tick seeding), clock_int1a seam sites.
 */

#include <stdint.h>
#include "core/ctx.h"

/* Refresh state.tick_a/b/c from the active clock. Called before each roll and
 * once per main-loop iteration. */
void u2_timer_pump(u2_ctx *ctx);

/* seam: timed_wait (asm/52CA). ms is an approximation — the original burned
 * CPU cycles, so real duration was machine-dependent. */
void u2_wait_ms(u2_ctx *ctx, uint32_t ms);

#endif /* U2_TIMER_H */
