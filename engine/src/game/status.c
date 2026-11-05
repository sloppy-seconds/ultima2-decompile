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

/* One status line, with the byte pair taken from the single shared definition in
 * core/state.h rather than named here. That is the whole point of the indirection:
 * the enhanced panel prints the same four fields and must not disagree. */
static void draw_field(u2_ctx *ctx, int row, const char *label, u2_bcd_field f)
{
    uint8_t msb = 0, lsb = 0;
    u2_state_bcd_pair(&ctx->state, f, &msb, &lsb);
    draw_line(ctx, row, label, msb, lsb);
}

void u2_status_draw_hp(u2_ctx *ctx)
{
    /* asm/50F9 sets the right margin to 0x28 before drawing H.P.= . */
    ctx->state.right_margin = 0x28;
    draw_field(ctx, 20, U2_S_STATUS_HP, U2_BCD_HP);
}

/* One packed-decimal byte as its two digits, the way asm/55B5 renders it. Thin
 * wrapper over the shared core definition so the classic band and the enhanced panel
 * cannot disagree about how a stored stat reads. */
static void bcd2(int v, char *out)
{
    u2_bcd2_str((uint8_t)v, out);
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
    draw_field(ctx, 21, U2_S_STATUS_FOOD, U2_BCD_FOOD);
    draw_field(ctx, 22, U2_S_STATUS_EXP,  U2_BCD_EXP);
    draw_field(ctx, 23, U2_S_STATUS_GOLD, U2_BCD_GOLD);
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
 * The list loops, asm/495B..4AA5. Each prints the name, the plural, the count as two
 * packed-decimal digits, and a space, skipping entries whose count byte is zero.
 *
 * The start index is NOT the same for all four, and that is easy to get wrong: the loop
 * heads load `mov bl,1` for weapons (f4955), armour (f49ae) and spells (f4a06), but
 * `mov bl,0` for items (f4a5e). So RING can be listed and HANDS and SKIN cannot — which
 * is what status_check asserts, and what the first version of this function got wrong.
 *
 * The item loop is also the one with a special case: index 3 already ends in S, so it
 * prints the bare dash instead of "S-" (f4a7a: cmp byte [0x1f],3).
 *
 * Read the item loop's bytes carefully, because the plural and the dash are two separate
 * prints and only the plural is conditional: name, then "S" unless index 3, then "-"
 * always, then the count. Collapsing those into one separator string is what produced
 * `RINGS01` in the first version.
 */
static void z_list(u2_ctx *ctx, int col, int row, const char *header,
                   const uint8_t *counts, int n,
                   const char *const *names, int names_n, int start, int bound,
                   const char *sep_plural, int plain_index, const char *sep_always)
{
    char line[256];
    line[0] = '\0';
    z_append(line, sizeof line, header);
    for (int i = start; i < bound && i < n; i++) {
        if (counts[i] == 0)
            continue;
        z_append(line, sizeof line,
                 (i < names_n) ? names[i] : "");
        if (i != plain_index)
            z_append(line, sizeof line, sep_plural);
        if (sep_always)
            z_append(line, sizeof line, sep_always);
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

    /* asm/4568 opens with `call L_004c1c` -- the full screen clear, not a row clear. That is
     * the whole difference between the original's Z page and this function's old behaviour:
     * the original takes the entire screen, so there is no status band on it and the item
     * lists may flow all the way down to row 24. The engine was leaving the band in place and
     * printing the page above it, so a character owning many items had its ITEMS list collide
     * with GOLD= and overwrite H.P., FOOD and EXP. Proven against the original with the same
     * maxed save: captures/spice86/z-page-maxed/readings.md -- no band anywhere on its Z page.
     * The mid-word wrapping the capture also shows is faithful and is deliberately left alone. */
    seam_clear_screen(ctx);

    /* asm/4568 sets DS:31 = 0x26 before drawing anything. That is the right margin, and
     * it matters: the default 0x1d (col 29) makes TORCHES- at column 29 overflow and
     * wrap onto the ARMOUR row, which is exactly what the first version of this function
     * did and status_check caught. 0x26 = 38 gives the page its full 40 columns. */
    const uint8_t margin_was = st->right_margin;
    st->right_margin = 0x26;

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
           (int)sizeof st->weapons_owned, Z_TBL(U2_T_WEAPONS), 1, 10,
           U2_S_Z_PLURAL_DASH, -1, NULL);
    /* The Z armour list reads the SAME array the WEAR menu and a commerce buy
     * write — armour_owned at DS:97 — indexed one below the name: armour_owned[0]
     * is CLOTH, which is name index 1. The original's loop at asm/47D0 does
     * `mov 0x96(%di),%al` with di=1..6 (DS:97..9C) and prints ARMOUR_TABLE[di];
     * z_list uses one index for both, so the counts are shifted to align here.
     * (The old code read owned_armour at DS:80, a phantom nothing writes.) */
    uint8_t armour_disp[8] = {0};
    for (int i = 1; i <= 6; i++)
        armour_disp[i] = st->armour_owned[i - 1];
    z_list(ctx, 1, 12, U2_S_Z_ARMOUR_LIST, armour_disp,
           (int)sizeof armour_disp, Z_TBL(U2_T_ARMOUR), 1, 7,
           U2_S_Z_PLURAL_DASH, -1, NULL);
    z_list(ctx, 1, 14, U2_S_Z_SPELLS_LIST, st->spell_counts,
           (int)sizeof st->spell_counts, Z_TBL(U2_T_SPELLS), 1, 10,
           U2_S_Z_PLURAL_DASH, -1, NULL);
    z_list(ctx, 1, 18, U2_S_Z_ITEMS_LIST, st->items_held,
           (int)sizeof st->items_held, Z_TBL(U2_T_ITEMS), 0, 16,
           U2_S_Z_PLURAL_S, 3, "-");

    st->right_margin = margin_was;
}

int u2_status_has_pool(void)
{
    return U2_Z_POOL;
}
