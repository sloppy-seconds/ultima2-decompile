/*
 * speed.h — the game speed model: DS:74, its two writers, and the rescaler.
 *
 * spec: asm/06AC_clock_tick_wait (startup seed), asm/4FA5_speed_faster_f7,
 *       asm/4F8E_speed_slower_f8, asm/4FB3_speed_rescale_call,
 *       asm/06ED_speed_rescale (the rescale loop), asm/0711_speed_delay_lookup.
 *
 * MODEL ONLY, DELIBERATELY UNWIRED. Two things are proven and one is not:
 *   proven   the variable, its bounds, the rescale arithmetic, and the 20 outputs
 *            (reproduced 20/20 against a live dump, tests/speed_check.c)
 *   NOT proven why each site chose its length. What IS known: the values are key-wait
 *            timeouts, not animation delays -- callers test the wait result with
 *            `cmp $0xff,%ah` ("no key"), which is why the measured range is 47 .. 64,581.
 *            The slot-to-caller map is in asm/0711_speed_delay_lookup's header; slots
 *            1,3,6,7,12,13,15..19 have no caller found at all.
 * So nothing here calls core/timer.c's u2_wait_ms. Wiring a slot to a timeout on the
 * strength of a guess is the exact failure this project keeps being bitten by.
 */
#ifndef U2_GAME_SPEED_H
#define U2_GAME_SPEED_H

#include <stdint.h>
#include "core/ctx.h"

/* asm/4FA5: `add $0x200,%ax ; cmp $0x3a00,%ax ; ja <skip>` */
#define U2_SPEED_STEP     0x200u
#define U2_SPEED_CEILING  0x3a00u
/* asm/06ED: `mov $0x26,%bx` down to 0 in steps of 2 -> 20 word slots */
#define U2_SPEED_SLOTS    20

/* Recompute speed_delay[] from speed, speed_baseline and speed_mult[].
 * asm/06ED_speed_rescale, all 20 iterations. Returns the number of slots that
 * would have overflowed a 16-bit DIV on the real CPU (the original would raise
 * #DE there; the engine records it instead of faulting). */
int u2_speed_rescale(u2_ctx *ctx);

/* F7 / F8. Each returns 1 if the value moved, 0 if the bound rejected it.
 * Both rescale on success, because asm/4FB3 is reached from both directions. */
int u2_speed_faster(u2_ctx *ctx);
int u2_speed_slower(u2_ctx *ctx);

/* asm/0711_speed_delay_lookup: callers pass a slot INDEX (0..19); the original
 * passes the byte offset in %bx, so index == bx/2. Returns 0 for a bad index. */
uint16_t u2_speed_delay(const u2_ctx *ctx, unsigned index);

#endif /* U2_GAME_SPEED_H */
