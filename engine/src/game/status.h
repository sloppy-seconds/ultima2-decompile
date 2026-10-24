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
 * '0' with no zero suppression. asm/53A5 calls it on the low address first, so
 * the pair is a 4-digit packed-BCD number written most-significant-pair-first.
 * A gameplay screenshot settles the direction: GOLD=0038 for 38 gold, so a fresh
 * character's 0400 is 400 gold, not 4. An intermediate reading in this project
 * claimed the original printed the bytes in the wrong order; that was wrong and
 * is recorded in plan § 7 so nobody re-derives it. Ceiling is 9999, not 255.
 */

#include "core/ctx.h"

/* Draw the four status lines from the current state. */
void u2_status_draw(u2_ctx *ctx);

/* Engine-authored detail block for the 'P' placeholder: name, sex, race, class
 * and the six stats as stored. Not in the original (deviation D13). */
void u2_status_draw_character(u2_ctx *ctx);

/* Draw one value at its proven position (used by the CP3 test). */
void u2_status_draw_hp(u2_ctx *ctx);

/*
 * Draw the whole-page status screen the 'Z' command shows.
 *
 * spec: asm/4568_cmd_Z and the fragments it falls through to, fully decoded in
 *       docs/status-screen-z.md § 7. Every column and row below is read off a
 *       str_out_at call (column into DS:2E, row into DS:2F), not measured off a
 *       screenshot — the earlier transcription in § 2 was wrong in three places.
 *
 * Degrades on purpose. The indexed name pool is generated from the user's own copy of the
 * game and CI has no copy, so when the tables are absent the names print blank and every
 * position, label and number still draws. That is the split this project runs on: game
 * truth is checked on a dev box, structure is checked in CI.
 */
void u2_status_draw_full(u2_ctx *ctx);

/* Non-zero when the name pool was generated into gen_content.h. The CP4 test asserts
 * which mode it is in, so a silent loss of the pool cannot pass as a green run. */
int u2_status_has_pool(void);

#endif /* U2_STATUS_H */
