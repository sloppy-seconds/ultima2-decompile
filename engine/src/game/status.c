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

/* asm/53A5 prints a status pair as two packed-decimal bytes, low address first:
 *   call 0x55b5 (al = [lo]) ; mov ax,di (di = [hi]) ; call 0x55b5
 * and asm/55B5 emits one byte as its two nibbles each OR'd with '0', with no
 * zero suppression. So the pair is a 4-digit packed-BCD number written
 * most-significant-pair-first: [lo] holds the thousands and hundreds, [hi] the
 * tens and units. A gameplay screenshot settles the direction (owner-supplied,
 * 2026-10-27): GOLD=0038 for 38 gold. A byte-swapped display would read 3800.
 * An earlier reading in this file claimed the original printed the bytes in the
 * wrong order and that food 3 displayed as 0300; that was wrong, and the real
 * consequence is that a fresh character's 0400 is 400 gold, not 4.
 * Ceiling is 9999. */
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
    /* The status block is a fixed-region redraw, not a text stream. It writes at
     * absolute rows using the one shared cursor (DS:0x2E/0x2F), so the cursor it
     * leaves behind is an accident of whichever field was drawn last — the tail of
     * the GOLD= line — and not a position anything downstream wants.
     *
     * Callers that print after a mid-game redraw were inheriting that stray
     * cursor: the first character of a command echoed as "GOLD=0000S", and the
     * message history accumulated shifted "ASS/CMD:ASS" fragments. The initial
     * draw did not show it only because overworld_open happens to seam_goto after
     * the redraw; the redraws during play had nothing to correct it.
     *
     * Restoring here rather than at each call site means no future caller can
     * forget. This does not invent a protocol for the original: asm/087D prints
     * "CMD: " with no cursor set, so the original's echo lands immediately after
     * the prompt, which is what preserving the cursor reproduces.
     */
    const uint8_t row = ctx->state.cursor_row;
    const uint8_t col = ctx->state.cursor_col;

    u2_status_draw_hp(ctx);
    draw_line(ctx, 21, U2_S_STATUS_FOOD, ctx->state.food, ctx->state.food_hi);
    draw_line(ctx, 22, U2_S_STATUS_EXP, ctx->state.exp_lo, ctx->state.exp_hi);
    draw_line(ctx, 23, U2_S_STATUS_GOLD, ctx->state.gold_lo, ctx->state.gold_hi);
    /* The GOLD= tail restores the margin to 0x1d (file 0x5396). */
    ctx->state.right_margin = 0x1d;

    /* Through seam_goto, not by assigning the fields, so the vram cursor stays
     * in step with the state cursor the way every other writer leaves them. */
    seam_goto(ctx, col, row);
}

/* ------------------------------------------------------- the Z status screen */

/*
 * The indexed name pool is generated from the user's own copy. CI has no copy, so the
 * tables may be absent and the screen must still draw: every position, label and number
 * comes from committed strings and stays testable, and only the pool-backed names fall
 * back to empty. That is a deliberate degradation, not a silent one — the extractor warns
 * when it omits them, and status_check asserts which mode it is in.
 */
#ifdef U2_T_WEAPONS_N
#  define U2_Z_POOL 1
#  define Z_NAME(tbl, i) (((i) >= 0 && (i) < (tbl##_N)) ? (tbl)[i] : "")
#  define Z_TBL(tbl)  (tbl), (tbl##_N)
#else
#  define U2_Z_POOL 0
#  define Z_NAME(tbl, i) ""
   /* One shared empty table so the list loops keep their shape and bounds when the pool
    * was not generated. The names come out blank; the positions and counts do not. */
static const char *const z_no_pool[1] = { "" };
#  define Z_TBL(tbl)  z_no_pool, 0
#endif

/* One packed-decimal byte, the way asm/55B5 renders it, appended to `out`. */
static void z_bcd(char *out, size_t cap, uint8_t v)
{
    char d[3];
    bcd2(v, d);
    snprintf(out + strlen(out), cap - strlen(out), "%s", d);
}

static void z_append(char *out, size_t cap, const char *s)
{
    snprintf(out + strlen(out), cap - strlen(out), "%s", s);
}

/*
 * The list loops, asm/495B..4AA5. Every one of them starts at index 1 — so HANDS and SKIN
 * can never appear — skips an entry whose count byte is zero, prints the name, the plural,
 * the count as two packed-decimal digits, and a space. The item loop is the one with a
 * special case: index 3 already ends in S, so it prints the bare dash instead of "S-".
 */
static void z_list(u2_ctx *ctx, int col, int row, const char *header,
                   const uint8_t *counts, int n,
                   const char *const *names, int names_n, int bound,
                   const char *sep_plural, const char *sep_plain, int plain_index)
{
    char line[128];
    line[0] = '\0';
    z_append(line, sizeof line, header);
    for (int i = 1; i < bound && i < n; i++) {
        if (counts[i] == 0)
            continue;
        z_append(line, sizeof line,
                 (i < names_n) ? names[i] : "");
        z_append(line, sizeof line,
                 (sep_plain && i == plain_index) ? sep_plain : sep_plural);
        z_bcd(line, sizeof line, counts[i]);
        z_append(line, sizeof line, " ");
    }
    seam_str_out_at(ctx, col, row, line);
}

void u2_status_draw_full(u2_ctx *ctx)
{
    u2_state *st = &ctx->state;
    char name[17];
    char b[48];

    memcpy(name, st->name, 16);
    name[16] = '\0';

    /* asm/4568: clear, then column 1. The name prints at the current row, and the
     * 0x8d that opens "A LEVEL " is the game's newline glyph, so the header is two
     * lines and the status block starts two rows below it. */
    seam_str_out_at(ctx, 1, 0, name);

    b[0] = '\0';
    z_append(b, sizeof b, U2_S_Z_A_LEVEL);
    /* The field the original labels LEVEL is DS:56, which status.h identifies as the
     * high byte of the EXP pair. Printing it as "level" is what the binary does; the
     * relationship between the two is still the open question in § 5 and is NOT
     * resolved here — the byte is rendered, not re-derived. */
    z_bcd(b, sizeof b, st->exp_lo);
    z_append(b, sizeof b, " ");
    z_append(b, sizeof b, st->sex == 'M' ? U2_S_SEX_MALE : U2_S_SEX_FEMALE);
    z_append(b, sizeof b, " ");
    z_append(b, sizeof b, Z_NAME(U2_T_RACES, st->race));
    z_append(b, sizeof b, " ");
    z_append(b, sizeof b, Z_NAME(U2_T_CLASSES, st->pclass));
    seam_str_out_at(ctx, 1, 1, b);

    /* The three-column block. Positions are the str_out_at pairs at asm/45DA, 45FB,
     * 4620, 463C, 4660 and 467F — column into DS:2E, row into DS:2F. */
    b[0] = '\0';
    z_append(b, sizeof b, U2_S_Z_WEAPON);
    z_append(b, sizeof b, Z_NAME(U2_T_WEAPONS, st->readied_weapon));
    seam_str_out_at(ctx, 1, 3, b);
    b[0] = '\0';
    z_append(b, sizeof b, U2_S_Z_ARMOUR);
    z_append(b, sizeof b, Z_NAME(U2_T_ARMOUR, st->worn_armour));
    seam_str_out_at(ctx, 1, 4, b);

    b[0] = '\0';
    z_append(b, sizeof b, U2_S_Z_TORCHES);
    z_bcd(b, sizeof b, st->torches);
    seam_str_out_at(ctx, 29, 3, b);

    b[0] = '\0';
    z_append(b, sizeof b, U2_S_Z_KEYS);
    z_bcd(b, sizeof b, st->keys);
    seam_str_out_at(ctx, 32, 4, b);

#ifdef U2_S_Z_SPELL
    b[0] = '\0';
    z_append(b, sizeof b, U2_S_Z_SPELL);
    z_append(b, sizeof b, Z_NAME(U2_T_SPELLS, st->spell_pick));
    seam_str_out_at(ctx, 4, 5, b);
#endif

    b[0] = '\0';
    z_append(b, sizeof b, U2_S_Z_TOOLS);
    z_bcd(b, sizeof b, st->tools);
    seam_str_out_at(ctx, 31, 5, b);

    /* The six stats, in the original's own order: STR/STA/WIS down column 1-16-30 of
     * row 6 and AGI/CHA/INT down 2-15-29 of row 7. No plural on stats — they print a
     * bare dash. */
    static const struct { const char *label; uint8_t value; int col, row; } stats[6] = {
        { "STRENGTH", 0,  1, 6 }, { "AGILITY",  0,  2, 7 },
        { "STAMINA",  0, 16, 6 }, { "CHARISMA", 0, 15, 7 },
        { "WISDOM",   0, 30, 6 }, { "INTELL.",  0, 29, 7 },
    };
    const uint8_t vals[6] = { st->stat_str, st->stat_agi, st->stat_sta,
                              st->stat_cha, st->stat_wis, st->stat_int };
    for (int i = 0; i < 6; i++) {
        char s[24];
        snprintf(s, sizeof s, "%s-%c%c", stats[i].label,
                 '0' + ((vals[i] >> 4) & 0x0F), '0' + (vals[i] & 0x0F));
        seam_str_out_at(ctx, stats[i].col, stats[i].row, s);
    }

    /* The four lists. Count arrays: weapons DS:76, armour DS:80, spells DS:B6,
     * items DS:D6 — all read off the loop bodies in asm/495B..4AA5. */
    z_list(ctx, 1, 9,  U2_S_Z_WEAPONS_LIST, st->weapons_owned,
           (int)sizeof st->weapons_owned, Z_TBL(U2_T_WEAPONS), 10,
           U2_S_Z_PLURAL_DASH, NULL, -1);
    z_list(ctx, 1, 12, U2_S_Z_ARMOUR_LIST, st->owned_armour,
           (int)sizeof st->owned_armour, Z_TBL(U2_T_ARMOUR), 7,
           U2_S_Z_PLURAL_DASH, NULL, -1);
    z_list(ctx, 1, 14, U2_S_Z_SPELLS_LIST, st->spell_counts,
           (int)sizeof st->spell_counts, Z_TBL(U2_T_SPELLS), 10,
           U2_S_Z_PLURAL_DASH, NULL, -1);
    z_list(ctx, 1, 18, U2_S_Z_ITEMS_LIST, st->items_held,
           (int)sizeof st->items_held, Z_TBL(U2_T_ITEMS), 16,
           U2_S_Z_PLURAL_S, "-", 3);
}

int u2_status_has_pool(void)
{
    return U2_Z_POOL;
}
