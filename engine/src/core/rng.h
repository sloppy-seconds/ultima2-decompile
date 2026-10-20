#ifndef U2_RNG_H
#define U2_RNG_H

/*
 * Random byte — the shift-register PRNG.
 *
 * spec: asm/5217_rand_byte.asm + asm/522B_sub_522b.asm + asm/5236_sub_5236.asm.
 * Phase 3 split this routine across three "function" boundaries; read together
 * (runtime 0x5217..0x523D) it is:
 *
 *   push ax; push bx
 *   stc
 *   al  = DS:0x240
 *   al += DS:0x243 + 1        (adc, carry in from stc)
 *   al += DS:0x244 + carry    (adc)
 *   DS:0x23F = al             the new value
 *   bx = 4
 * 1: al = DS:0x23F(bx)        shift the window one byte left ...
 *    DS:0x240(bx) = al        ... five times (jns runs bx = 4..0)
 *    dec bx ; jns 1b
 *   pop bx ; pop ax
 *   al = DS:0x23F
 *   or al, al                 callers branch on the zero flag
 *   ret
 *
 * So the state is the six bytes DS:0x23F..0x244 and it is rewritten on every
 * call: a feedback shift register, not a clock sampler. docs/phase4-plan.md §1
 * described those bytes as tick counters; the decode says otherwise, and
 * nothing else in the binary writes them (only asm/0100_sub_0100.asm seeds
 * them). Consequences that matter for this project:
 *
 *   - rolls are a pure function of (seed, number of rolls so far), so monster
 *     spawns, encounters and combat rolls replay exactly for the same inputs;
 *   - the original's seed is the BIOS keyboard-flag byte at 0x40:6C, which is
 *     normally zero at startup, so the shipped game is itself effectively
 *     deterministic per boot;
 *   - no wall-clock source is needed for reproducibility, and none is used.
 *
 * The engine keeps the state in the DS mirror (u2_state.rng_state) so a dump
 * shows exactly what the original's memory would have shown.
 */

#include <stdint.h>
#include "core/ctx.h"

/* One rand_byte() call: advances the register and returns the new byte. */
uint8_t u2_rand_byte(u2_ctx *ctx);

/* Seed the register the way asm/0100_sub_0100.asm does, from the 0x40:6C byte.
 * The engine calls this at startup with u2_rng_default_seed(); --seed overrides
 * it so a run can be given a different-but-still-reproducible dice sequence. */
void u2_rng_seed(u2_ctx *ctx, uint8_t bios_kbd_flags);

/* The value the original would have read at 0x40:6C on a cold boot. */
#define U2_RNG_DEFAULT_SEED 0x00

/* Number of rolls performed (diagnostics; not part of the original's state). */
uint32_t u2_rng_rolls(const u2_ctx *ctx);

#endif /* U2_RNG_H */
