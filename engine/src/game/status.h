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
 * RESOLVED 2026-10-27, was an open question: the pair is packed decimal and the
 * print helper is asm/55B5, which emits a byte as its two nibbles each OR'd with
 * '0' with no zero suppression. asm/53A5 calls it on the low byte then the high
 * byte, so a 4-digit BCD value held little-endian renders byte-swapped: food 3
 * (stored 03 00) displays "0300". Owner-confirmed against the original — four
 * digits, food 0300, gold 1200. Reproduced exactly, quirk included.
 */

#include "core/ctx.h"

/* Draw the four status lines from the current state. */
void u2_status_draw(u2_ctx *ctx);

/* Engine-authored detail block for the 'P' placeholder: name, sex, race, class
 * and the six stats as stored. Not in the original (deviation D13). */
void u2_status_draw_character(u2_ctx *ctx);

/* Draw one value at its proven position (used by the CP3 test). */
void u2_status_draw_hp(u2_ctx *ctx);

#endif /* U2_STATUS_H */
