#ifndef U2_RNG_H
#define U2_RNG_H

/*
 * Random byte — the tick-counter mixer.
 *
 * spec: asm/5217_rand_byte.asm
 *   stc
 *   mov 0x240,%al ; adc 0x243,%al ; adc 0x244,%al ; mov %al,0x23f
 *   mov $0x4,%bx ...   (the tail past the reconstructed bytes is lifted with
 *                       the first caller that needs it — CP4; until then the
 *                       engine returns the mixed byte and says so)
 *
 * The original has no PRNG state of its own: entropy is the three live tick
 * counters, so the same wall-clock instant gives the same roll. The engine
 * keeps that property: in headless/scripted mode the counters advance from a
 * deterministic virtual tick, so a scripted playthrough replays identically;
 * in terminal mode they advance from the POSIX clock, like the original.
 */

#include <stdint.h>
#include "core/ctx.h"

/* One rand_byte() call. Returns the mixed byte (also stored to state.rand_last
 * equivalent DS:0x23F by the caller that models it). */
uint8_t u2_rand_byte(u2_ctx *ctx);

/* Deterministic mode: advance the virtual tick by `n` before mixing. */
void u2_rng_set_deterministic(u2_ctx *ctx, int on);

#endif /* U2_RNG_H */
