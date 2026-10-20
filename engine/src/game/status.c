/*
 * status.c — the right-column status block.
 *
 * spec: asm/50F9_show_hitpoints.asm, asm/5129_sub_5129.asm,
 *       asm/5154_sub_5154.asm, asm/5175_sub_5175.asm.
 * Positions and source bytes are proven in status.h; the binary-vs-BCD question
 * is flagged there rather than guessed.
 *
 * No game text is hardcoded: the labels come from the generated content header,
 * which is extracted from the user's own copy at build time.
 */

#include <stdio.h>
#include <string.h>
#include "game/status.h"
#include "core/seam.h"
#include "gen_content.h"

/* asm/53A5 prints a status pair as two packed-decimal bytes, low byte first:
 *   call 0x55b5 (al = [lo]) ; mov ax,di (di = [hi]) ; call 0x55b5
 * and asm/55B5 emits one byte as its two nibbles each OR'd with '0', with no
 * zero suppression at all. So the value is a 4-digit packed-BCD number held in a
 * little-endian word, and the original renders the bytes in the wrong order:
 * food 3 is stored 03 00 and displays "0300", not "0003". Owner-confirmed
 * against the original (2026-10-27): four digits, food 0300, gold 1200.
 * Reproduced as-is. The semantic value is the low byte (creation stores
 * `mov al,$0x4` there), so this is a display quirk, not a x100 scale. */
static void draw_line(u2_ctx *ctx, int row, const char *label, uint8_t lo, uint8_t hi)
{
    char buf[24];
    snprintf(buf, sizeof buf, "%s%c%c%c%c", label,
             (char)('0' + ((lo >> 4) & 0x0F)), (char)('0' + (lo & 0x0F)),
             (char)('0' + ((hi >> 4) & 0x0F)), (char)('0' + (hi & 0x0F)));
    seam_str_out_at(ctx, 30, row, buf);
}

void u2_status_draw_hp(u2_ctx *ctx)
{
    /* asm/50F9 sets the right margin to 0x28 before drawing H.P.= . */
    ctx->state.right_margin = 0x28;
    draw_line(ctx, 20, U2_S_STATUS_HP, ctx->state.hp, ctx->state.unk_52);
}

/* One packed-decimal byte as its two digits, the way asm/55B5 renders it. */
static void bcd2(int v, char *out)
{
    out[0] = (char)('0' + ((v >> 4) & 0x0F));
    out[1] = (char)('0' + (v & 0x0F));
    out[2] = '\0';
}

void u2_status_draw_character(u2_ctx *ctx)
{
    /* Engine-authored detail block (deviation D13). The original never prints
     * this: loading a character went straight into the world, and the status
     * block on the right is all the confirmation it gave. Until CP4 owns the
     * overworld there is nothing to load INTO, so the record is shown instead of
     * implied — visual proof that the bytes written by [S]AVE came back. */
    static const char *const RACE[4]  = { U2_S_RACE_HUMAN, U2_S_RACE_ELF,
                                          U2_S_RACE_DWARF, U2_S_RACE_HOBBIT };
    static const char *const CLASS[4] = { U2_S_CLASS_FIGHTER, U2_S_CLASS_CLERIC,
                                          U2_S_CLASS_WIZARD, U2_S_CLASS_THIEF };
    u2_state *st = &ctx->state;
    char name[17];
    char b[40];
    int i;

    memcpy(name, st->name, 16);
    name[16] = '\0';
    for (i = 0; i < 16 && name[i]; i++) {}

    seam_str_out_at(ctx, 1, 1, "[engine] character on disk");
    snprintf(b, sizeof b, "NAME   %s", name);
    seam_str_out_at(ctx, 1, 2, b);
    snprintf(b, sizeof b, "SEX %c  RACE %s", st->sex ? st->sex : '-',
             st->race < 4 ? RACE[st->race] : "?");
    seam_str_out_at(ctx, 1, 3, b);
    snprintf(b, sizeof b, "CLASS  %s", st->pclass < 4 ? CLASS[st->pclass] : "?");
    seam_str_out_at(ctx, 1, 4, b);
    /* Stats are packed decimal exactly as stored; no conversion, so what is on
     * screen is what is in the record. */
    char s1[4], s2[4], s3[4];
    bcd2(st->stat_str, s1); bcd2(st->stat_agi, s2); bcd2(st->stat_sta, s3);
    snprintf(b, sizeof b, "STR %s  AGI %s  STA %s", s1, s2, s3);
    seam_str_out_at(ctx, 1, 5, b);
    bcd2(st->stat_cha, s1); bcd2(st->stat_wis, s2); bcd2(st->stat_int, s3);
    snprintf(b, sizeof b, "CHA %s  WIS %s  INT %s", s1, s2, s3);
    seam_str_out_at(ctx, 1, 6, b);
}

void u2_status_draw(u2_ctx *ctx)
{
    u2_status_draw_hp(ctx);
    draw_line(ctx, 21, U2_S_STATUS_FOOD, ctx->state.food, ctx->state.food_hi);
    draw_line(ctx, 22, U2_S_STATUS_EXP, ctx->state.exp_lo, ctx->state.exp_hi);
    draw_line(ctx, 23, U2_S_STATUS_GOLD, ctx->state.gold_lo, ctx->state.gold_hi);
    /* The GOLD= tail restores the margin to 0x1d (file 0x5396). */
    ctx->state.right_margin = 0x1d;
}
