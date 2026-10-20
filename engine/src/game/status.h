#ifndef U2_STATUS_H
#define U2_STATUS_H

/*
 * Status line — the right-column block the original draws during play.
 *
 * spec: asm/50F9_show_hitpoints.asm (H.P.=), asm/5129_sub_5129.asm (FOOD=),
 *       asm/5154_sub_5154.asm (EXP.=), asm/5175_sub_5175.asm (GOLD=).
 *
 * Every position and every source byte below is proven by the code that reads
 * it, not inferred from the label:
 *
 *   label    row  col   value bytes        cited
 *   H.P.=     20   30   [0x51],[0x52]     asm/50F9 + the load at file 0x5311
 *   FOOD=     21   30   [0x53],[0x54]     asm/5129 + the load at file 0x5340
 *   EXP.=     22   30   [0x56],[0x57]     the load at file 0x5367 (note: NOT 0x55)
 *   GOLD=     23   30   [0x58],[0x59]     asm/5175 + the load at file 0x5388
 *
 * H.P.= also sets the right margin to 0x28 (asm/50F9 first three instructions)
 * and the GOLD= tail restores it to 0x1d (file 0x5396), which is reproduced
 * here because the wrap test in char_print reads that margin.
 *
 * OPEN QUESTION, flagged rather than guessed: the display loads a byte pair and
 * hands it to a print helper that has not been decoded yet, so whether the pair
 * is binary little-endian or packed decimal is not proven. The creation routine
 * stores plain 4s (asm/5400 file 0x5BEB: `mov [0x51],$0x4`), which only reads
 * correctly as binary, so this file formats them as binary little-endian. If
 * the owner's playthrough of the original shows two-digit or BCD output, this
 * is the place that is wrong and the fix is local.
 */

#include "core/ctx.h"

/* Draw the four status lines from the current state. */
void u2_status_draw(u2_ctx *ctx);

/* Draw one value at its proven position (used by the CP3 test). */
void u2_status_draw_hp(u2_ctx *ctx);

#endif /* U2_STATUS_H */
