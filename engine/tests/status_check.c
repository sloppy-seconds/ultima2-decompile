/*
 * status_check.c — CP4b task 1: the status band and the CMD message window.
 *
 * The owner's model of the block, cross-referenced against asm/5003..5057:
 * four rows (20..23); the bottom row always holds the live "CMD: " prompt;
 * a completed command prints its word after the prompt, the game's 0x0d is
 * a newline (col := left margin, row++, scroll at row 24), and the fresh
 * prompt lands on the blank bottom row — so history stacks upward, three
 * commands deep plus the live line. The status block sits at cols 30..39,
 * outside the scroll rect (cols 0..right_margin = 0x1d = 29), which is why
 * the GOLD= tail restores the margin to 0x1d.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "core/ctx.h"
#include "core/font.h"
#include "core/seam.h"
#include "core/state.h"
#include "core/vram.h"
#include "game/status.h"
#include "gen_content.h"

static int fails;
static void ok(int cond, const char *what)
{
    printf("  %s  %s\n", cond ? "ok  " : "FAIL", what);
    if (!cond) fails++;
}

static int cell_ink(const u2_frame *f, int row, int col)
{
    for (int y = 0; y < 8; y++)
        for (int x = 0; x < 8; x++)
            if (f->px[row * 8 + y][col * 8 + x] == U2_CGA_WHITE) return 1;
    return 0;
}

static int row_has_ink(const u2_frame *f, int row, int c0, int c1)
{
    for (int c = c0; c <= c1; c++)
        if (cell_ink(f, row, c)) return 1;
    return 0;
}

static const char *row_text(u2_ctx *ctx, int row, char *buf, int c0, int c1)
{
    int n = 0;
    for (int c = c0; c <= c1 && n < U2_COLS; c++)
        buf[n++] = (char)ctx->vram.cell[row][c].ch;
    while (n > 0 && buf[n - 1] == ' ') n--;   /* trailing blank */
    buf[n] = '\0';
    char *p = buf;
    while (*p == ' ') p++;                   /* leading blank */
    return p;
}

/* The two halves of rows 20..23: the message window (cols 0..29, the scroll
 * rect) and the status block (cols 30..39, outside it). */
#define msg_text(ctx, row, buf)    row_text((ctx), (row), (buf), 0, 29)
#define status_text(ctx, row, buf) row_text((ctx), (row), (buf), 30, 39)

/* Read exactly cols c0..c1 with no stripping. row_text strips leading blanks, which is
 * right for the message window and wrong for a position assertion: "the label starts at
 * column 29" has to mean the glyphs are physically at column 29. */
static const char *cell_span(u2_ctx *ctx, int row, int c0, int c1, char *buf)
{
    int n = 0;
    for (int c = c0; c <= c1 && n < 60; c++)
        buf[n++] = (char)ctx->vram.cell[row][c].ch;
    buf[n] = '\0';
    return buf;
}

static void z_at(u2_ctx *ctx, int row, int col, const char *want, const char *what)
{
    char buf[64], msg[180];
    const char *got = cell_span(ctx, row, col,
                                col + (int)strlen(want) - 1, buf);
    snprintf(msg, sizeof msg, "%s — row %d col %d reads \"%s\", want \"%s\"",
             what, row, col, got, want);
    ok(strcmp(got, want) == 0, msg);
}

/* Concatenate a band of rows. The list bodies wrap across several rows exactly as the
 * original's do — the transcription's item list runs from row 18 to row 22 — so a
 * substring check has to look at the whole band, not one row. */
static const char *z_band(u2_ctx *ctx, int r0, int r1, char *buf, size_t cap)
{
    size_t n = 0;
    for (int r = r0; r <= r1; r++)
        for (int c = 0; c < 40 && n + 1 < cap; c++) {
            char ch = (char)ctx->vram.cell[r][c].ch;
            if (ch == '\r' || ch == '\n') ch = ' ';
            buf[n++] = ch;
        }
    buf[n] = '\0';
    return buf;
}

static void z_checks(u2_ctx *ctx)
{
    u2_state *st = &ctx->state;

    memcpy(st->name, "G23MAX", 7);
    st->sex = 'F';
    st->race = 0; st->pclass = 0;
    st->exp_lo = 0x99; st->exp_hi = 0x00;
    st->readied_weapon = 9; st->worn_armour = 6; st->spell_pick = 0;
    st->torches = 0x50; st->keys = 0x20; st->tools = 0x20;
    st->stat_str = st->stat_agi = st->stat_sta = 0x40;
    st->stat_cha = st->stat_wis = st->stat_int = 0x40;
    for (int i = 0; i < 10; i++) st->weapons_owned[i] = 1;
    for (int i = 0; i < 6; i++)  st->armour_owned[i] = 0;
    st->armour_owned[0] = 1;   /* CLOTH owned. The Z list must show it: this is the
                                * regression guard for the DS:80-vs-DS:97 field mix-up
                                * that made owned armour invisible on the status page. */
    for (int i = 0; i < 10; i++) st->spell_counts[i] = 0;
    for (int i = 0; i < 16; i++) st->items_held[i] = 1;

    u2_vram_init(&ctx->vram);
    u2_status_draw_full(ctx);

    /* Header. The sex string is a committed label, so it is asserted unconditionally. */
    z_at(ctx, 0, 1, "G23MAX", "name");
    z_at(ctx, 1, 1, "A LEVEL ", "level label");
    z_at(ctx, 1, 9, "99", "level value (DS:56)");
    /* MALE/FEMALE are exe-only run locators (asm/5400 stores them as a byte list), so
     * the fallback build paints them empty. Assert the position only when the string is
     * actually available, rather than asserting an empty cell and calling it a pass. */
#ifdef U2_S_SEX_FEMALE
    if (U2_S_SEX_FEMALE[0])
        z_at(ctx, 1, 12, U2_S_SEX_FEMALE, "sex");
#endif

    /* The three-column block, at the columns the str_out_at pairs set. */
    z_at(ctx, 3, 1,  "  WEAPON-",  "weapon label");
    z_at(ctx, 3, 29, "TORCHES-50", "torches");
    z_at(ctx, 4, 1,  "  ARMOUR-",  "armour label");
    z_at(ctx, 4, 32, "KEYS-20",    "keys");
#ifdef U2_S_Z_SPELL
    z_at(ctx, 5, 4,  "SPELL-",     "spell label");
#endif
    z_at(ctx, 5, 31, "TOOLS-20",   "tools");

    /* The stats: the derived columns are 1/16/30 on row 6 and 2/15/29 on row 7, which
     * is NOT the even spacing the screenshot suggested. */
    z_at(ctx, 6, 1,  "STRENGTH-40", "strength");
    z_at(ctx, 6, 16, "STAMINA-40",  "stamina");
    z_at(ctx, 6, 30, "WISDOM-40",   "wisdom");
    z_at(ctx, 7, 2,  "AGILITY-40",  "agility");
    z_at(ctx, 7, 15, "CHARISMA-40", "charisma");
    z_at(ctx, 7, 29, "INTELL.-40",  "intelligence");

    /* The four list headers. */
    z_at(ctx, 9,  1, "WEAPONS: ", "weapons list header");
    z_at(ctx, 12, 1, "ARMOUR: ",  "armour list header");
    z_at(ctx, 14, 1, "SPELLS: ",  "spells list header");
    z_at(ctx, 18, 1, "ITEMS: ",   "items list header");

    if (u2_status_has_pool()) {
        /* With the pool the lists carry names, start at index 1 (so no HANDS), and the
         * item loop must not double the S on BOOTS. */
        char band[512];
        z_at(ctx, 9, 10, "DAGGERS-01", "weapons list starts at index 1");
        z_band(ctx, 9, 11, band, sizeof band);
        /* The armour list reads armour_owned (DS:97), indexed one below the name,
         * so armour_owned[0] must render as CLOTHS (name index 1), not SKIN. */
        char aband[256];
        z_band(ctx, 12, 13, aband, sizeof aband);
        ok(strstr(aband, "CLOTHS-01") != NULL,
           "owned armour (armour_owned[0]) shows on the Z page");
        ok(strstr(aband, "SKIN") == NULL,
           "SKIN (name index 0) is never listed — pins the count/name off-by-one");
        ok(strstr(band, "HANDS") == NULL,
           "HANDS is never listed (loop starts at index 1)");
        ok(strstr(band, "QUICK SWORDS-01") != NULL,
           "a two-word weapon name survives the plural");
        z_band(ctx, 18, 23, band, sizeof band);
        /* The item list wraps mid-word exactly as the original's does — the transcription
         * notes BOOTS rendering as "BOO"/"TS-01" — so a substring test has to look at the
         * band with the wrap's line breaks removed. Stripping spaces is the honest way to
         * ask "did the glyphs BOOTS-01 appear in order", which is the claim being made. */
        char flat[512];
        size_t fn = 0;
        for (size_t i = 0; band[i] && fn + 1 < sizeof flat; i++)
            if (band[i] != ' ') flat[fn++] = band[i];
        flat[fn] = '\0';
        ok(strstr(flat, "BOOTS-01") != NULL,
           "BOOTS takes the bare dash, not a doubled S");
        ok(strstr(flat, "RINGS-01") != NULL,
           "a normal item takes the plural S");
        ok(strstr(flat, "BOOTSS") == NULL, "no doubled S anywhere in the item list");
    } else {
        /* Without the pool the names are blank by design, and that must be visible in the
         * output rather than silent: each entry still renders its plural, dash and count,
         * so the layout and the loop bounds are still exercised. This is a supported
         * configuration, not a degraded one — CI builds this way. */
        char band[512];
        z_at(ctx, 9, 10, "S-01", "weapons list with no pool: counts still print");
        z_band(ctx, 18, 23, band, sizeof band);
        ok(strstr(band, "S-01") != NULL,
           "item list with no pool: plurals, dashes and counts survive");
        ok(strstr(band, "RING") == NULL && strstr(band, "BOOTS") == NULL,
           "no pool means no names, and the test proves it rather than assuming");
    }
}

int main(void)
{
    u2_ctx ctx;
    u2_frame f;
    u2_frame_init(&f, 1);   /* heap-backed store; see frame_check.c */
    char buf[64];

    memset(&ctx, 0, sizeof ctx);
    u2_vram_init(&ctx.vram);
    u2_state_init(&ctx.state);

    /* The screenshot values: H.P.=9997 FOOD=0359 EXP.=0007 GOLD=0000, as
     * packed BCD pairs, most-significant byte first (status.h). */
    ctx.state.hp      = 0x99; ctx.state.unk_52  = 0x97;
    ctx.state.food    = 0x03; ctx.state.food_hi = 0x59;
    ctx.state.exp_lo  = 0x00; ctx.state.exp_hi  = 0x07;
    ctx.state.gold_lo = 0x00; ctx.state.gold_hi = 0x00;

    u2_status_draw(&ctx);
    ok(strcmp(status_text(&ctx, 20, buf), "H.P.=9997") == 0, "H.P.= row is the BCD pair, msb first");
    ok(strcmp(status_text(&ctx, 21, buf), "FOOD=0359") == 0, "FOOD= row");
    ok(strcmp(status_text(&ctx, 22, buf), "EXP.=0007") == 0, "EXP.= row");
    ok(strcmp(status_text(&ctx, 23, buf), "GOLD=0000") == 0, "GOLD= row");

    /* The shared byte-pair definition, asserted against status.h's table. The
     * enhanced panel prints the same four fields through the same helper, so this is
     * what stops a repeat of the FOOD bug, where the panel read [0x54],[0x55] and
     * put the fractional low byte on screen -- every step then looked like it burned
     * 19 food. food_lo is set to something visible here on purpose: if it ever leaks
     * into the printed row, this goes red. */
    {
        ctx.state.food_lo = 0x11;          /* must NEVER appear in FOOD= */
        uint8_t msb = 0, lsb = 0;
        u2_state_bcd_pair(&ctx.state, U2_BCD_FOOD, &msb, &lsb);
        ok(msb == 0x03 && lsb == 0x59, "FOOD pair is [0x53],[0x54], not the fractional byte");
        u2_state_bcd_pair(&ctx.state, U2_BCD_HP, &msb, &lsb);
        ok(msb == 0x99 && lsb == 0x97, "H.P. pair is [0x51],[0x52]");
        u2_state_bcd_pair(&ctx.state, U2_BCD_EXP, &msb, &lsb);
        ok(msb == 0x00 && lsb == 0x07, "EXP pair is [0x56],[0x57]");
        u2_state_bcd_pair(&ctx.state, U2_BCD_GOLD, &msb, &lsb);
        ok(msb == 0x00 && lsb == 0x00, "GOLD pair is [0x58],[0x59]");
        u2_status_draw(&ctx);
        ok(strcmp(status_text(&ctx, 21, buf), "FOOD=0359") == 0,
           "FOOD= prints 0359 even with food_lo set: the low byte stays hidden");
    }
    ok(ctx.state.right_margin == 0x1d,
       "GOLD= tail restores the right margin to 0x1d (scroll rect stops at col 29)");

    /* Composite and check pixels: ink only in the status block, rows 20..23. */
    u2_frame_clear(&f, U2_CGA_BLACK);
    u2_font_draw_vram_rows(&f, &ctx.vram, U2_MSG_TOP, U2_ROWS - 1);
    ok(row_has_ink(&f, 20, 30, 39) && row_has_ink(&f, 23, 30, 39),
       "status block paints pixels at cols 30..39");
    ok(!row_has_ink(&f, 20, 0, 29), "message area is blank before the prompt");
    int row24 = 0;
    for (int y = 192; y < 200; y++)
        for (int x = 0; x < 320; x++)
            row24 += f.px[y][x] != U2_CGA_BLACK;
    ok(row24 == 0, "row 24 stays blank");

    /* The prompt, as the overworld prints it on entry. */
    seam_goto(&ctx, 0, U2_MSG_BOTTOM);
    seam_str_out(&ctx, U2_S_CMD_PROMPT);
    u2_frame_clear(&f, U2_CGA_BLACK);
    u2_font_draw_vram_rows(&f, &ctx.vram, U2_MSG_TOP, U2_ROWS - 1);
    ok(row_has_ink(&f, 23, 0, 4) && !row_has_ink(&f, 22, 0, 4),
       "fresh CMD: prompt paints bottom row only");

    /* One move: "NORTH" + CR + prompt. The word lands after the prompt, the
     * CR scrolls, the fresh prompt prints below. */
    seam_str_out(&ctx, U2_S_DIR_NORTH);
    seam_char_print(&ctx, '\r');
    seam_str_out(&ctx, U2_S_CMD_PROMPT);
    ok(strcmp(msg_text(&ctx, 22, buf), "CMD: NORTH") == 0,
       "completed command scrolled up as 'CMD: NORTH'");
    ok(strcmp(msg_text(&ctx, 23, buf), "CMD:") == 0,
       "bottom row is the fresh prompt again");
    ok(strcmp(status_text(&ctx, 20, buf), "H.P.=9997") == 0,
       "status block untouched by the scroll (rect stops at col 29)");

    /* Stack to the top: three commands visible plus the live prompt, the
     * oldest scrolls out of the four-row window. */
    seam_str_out(&ctx, U2_S_DIR_EAST);
    seam_char_print(&ctx, '\r');
    seam_str_out(&ctx, U2_S_CMD_PROMPT);
    seam_str_out(&ctx, U2_S_DIR_WEST);
    seam_char_print(&ctx, '\r');
    seam_str_out(&ctx, U2_S_CMD_PROMPT);
    ok(strcmp(msg_text(&ctx, 20, buf), "CMD: NORTH") == 0, "oldest command reached row 20");
    ok(strcmp(msg_text(&ctx, 21, buf), "CMD: EAST") == 0, "second command on row 21");
    ok(strcmp(msg_text(&ctx, 22, buf), "CMD: WEST") == 0, "third command on row 22");
    seam_str_out(&ctx, U2_S_DIR_SOUTH);
    seam_char_print(&ctx, '\r');
    seam_str_out(&ctx, U2_S_CMD_PROMPT);
    ok(strcmp(msg_text(&ctx, 20, buf), "CMD: EAST") == 0,
       "fourth command scrolls the oldest out of the window");
    ok(strcmp(msg_text(&ctx, 23, buf), "CMD:") == 0, "prompt still bottom");

    /* --- the Z status screen -------------------------------------------- */
    printf("  --- the Z whole-page status screen (docs/status-screen-z.md § 7) ---\n");
    z_checks(&ctx);
    printf("  %s  pool mode: %s\n", "ok",
           u2_status_has_pool() ? "name pool present" : "name pool absent (no content)");

    printf("status_check: %s\n", fails ? "FAIL" : "PASS");
    return fails ? 1 : 0;
}
