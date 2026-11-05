/* panel.c — see panel.h. Geometry comes from core/layout.h and nowhere else. */

#include "core/panel.h"

#include <stdio.h>
#include <string.h>

#include "core/layout.h"
#include "core/font.h"
#include "core/state.h"
#include "gen_content.h"     /* the weapon and armour name pools, same as status.c */

#ifdef U2_T_WEAPONS_N
#  define P_NAME(tbl, i) (((i) >= 0 && (i) < (tbl##_N)) ? (tbl)[i] : "")
#else
   /* The pools come from the player's own executable, so a build without it has
    * blank names and correct positions. Same deliberate degradation status.c
    * documents; it is not a silent one. */
static const char *const p_no_pool[1] = { "" };
#  define P_NAME(tbl, i) p_no_pool[0]
#endif

/* ------------------------------------------------------------- colours */

static int luminance(const uint8_t e[3]) { return e[0] + e[1] + e[2]; }

/* Choose the palette entry that reads as a given hue. This exists because a v2
 * theme replaces the palette wholesale: the FM Towns table puts black at index 3,
 * which already made status text invisible once when an index was assumed rather
 * than looked up. Scanning the live table cannot go wrong that way. */
static int pick(const uint8_t pal[16][3], int (*score)(const uint8_t *), int want_max)
{
    int best = 0, best_score = score(pal[0]);
    for (int i = 1; i < 16; i++) {
        const int s = score(pal[i]);
        if ((want_max && s > best_score) || (!want_max && s < best_score)) {
            best_score = s;
            best = i;
        }
    }
    return best;
}

static int s_blue(const uint8_t *e)   { return e[2] - (e[0] + e[1]) / 2; }
static int s_red(const uint8_t *e)    { return e[0] - (e[1] + e[2]) / 2; }
static int s_dark(const uint8_t *e)   { return luminance(e); }
static int s_light(const uint8_t *e)  { return luminance(e); }

void u2_panel_pick_colours(u2_panel_colours *c, const uint8_t pal[16][3],
                           uint8_t text_fg)
{
    if (!c || !pal) return;
    c->backdrop = (uint8_t)pick(pal, s_blue, 1);
    c->box_bg   = (uint8_t)pick(pal, s_dark, 0);
    c->border   = text_fg ? text_fg : (uint8_t)pick(pal, s_light, 1);
    c->text     = text_fg ? text_fg : (uint8_t)pick(pal, s_light, 1);
    c->accent   = (uint8_t)pick(pal, s_red, 1);   /* ours, not the reference's yellow */
    c->bar      = (uint8_t)pick(pal, s_red, 1);
}

/* ---------------------------------------------------------- primitives */

/* Everything the panel draws goes through put_logical, NOT u2_frame_pixel.
 * u2_frame_pixel masks the colour to two bits because it is the CGA 2bpp path,
 * so a 16-colour index written through it silently becomes index & 3 — and in the
 * FM Towns palette index 3 is black, which is how the box borders were drawn and
 * then vanished. put_logical writes the full index and is scale-aware, which at
 * the enhanced frame's scale of 1 is a direct write. */
static void pset(u2_frame *f, int x, int y, uint8_t col)
{
    u2_frame_put_logical(f, x, y, col);
}

static void fill(u2_frame *f, int x, int y, int w, int h, uint8_t col)
{
    for (int j = y; j < y + h; j++)
        for (int i = x; i < x + w; i++)
            pset(f, i, j, col);
}

static void hline(u2_frame *f, int x, int y, int w, uint8_t col)
{
    for (int i = x; i < x + w; i++) pset(f, i, y, col);
}

static void vline(u2_frame *f, int x, int y, int h, uint8_t col)
{
    for (int j = y; j < y + h; j++) pset(f, x, j, col);
}

static void box(u2_frame *f, int x, int y, int w, int h, uint8_t bg, uint8_t border)
{
    fill(f, x, y, w, h, bg);
    hline(f, x, y, w, border);
    hline(f, x, y + h - 1, w, border);
    vline(f, x, y, h, border);
    vline(f, x + w - 1, y, h, border);
}

/* Text at a pixel position. The enhanced frame is scale 1, so a cell is exactly
 * U2_FONT_CELL_W by U2_FONT_CELL_H physical pixels and this is a division, not a
 * guess. */
static void text(u2_frame *f, int x, int y, const char *s, uint8_t fg, uint8_t bg)
{
    u2_font_draw_text(f, y / U2_FONT_CELL_H, x / U2_FONT_CELL_W, s, fg, bg);
}

/* Four BCD digits as printed by the DOS status block: the first byte carries the
 * high pair. Leading zeros are dropped so the panel reads 258 rather than 0258,
 * which is the reference's style. Invented here; the DOS block prints the zeros. */
static void bcd4(uint8_t hi, uint8_t lo, char *out, size_t n)
{
    char buf[8];
    snprintf(buf, sizeof buf, "%c%c%c%c",
             (char)('0' + ((hi >> 4) & 0x0F)), (char)('0' + (hi & 0x0F)),
             (char)('0' + ((lo >> 4) & 0x0F)), (char)('0' + (lo & 0x0F)));
    const char *p = buf;
    while (*p == '0' && p[1]) p++;
    snprintf(out, n, "%s", p);
}

/* Right-align a value in a field, the way the reference's leader column does. */
static void value_right(u2_frame *f, int right_x, int y, const char *s,
                        uint8_t fg, uint8_t bg)
{
    const int cols = (int)strlen(s);
    text(f, right_x - cols * U2_FONT_CELL_W, y, s, fg, bg);
}

/* --------------------------------------------------------------- boxes */

static void draw_box1(u2_frame *f, const u2_ctx *ctx, const u2_tiles_ega *tiles,
                      const u2_panel_colours *c, int avatar_art)
{
    const int x = U2_ENH_PANEL_X, y = U2_ENH_BOX1_Y, w = U2_ENH_PANEL_W, h = U2_ENH_BOX1_H;
    box(f, x, y, w, h, c->box_bg, c->border);

    char name[17];
    int len = 0;
    /* The name field is not guaranteed NUL-terminated in a hand-edited save, so
     * bound it by the field rather than trusting the bytes. */
    while (len < (int)sizeof ctx->state.name && ctx->state.name[len]) len++;
    if (len > (int)sizeof name - 1) len = (int)sizeof name - 1;
    memcpy(name, ctx->state.name, (size_t)len);
    name[len] = '\0';
    text(f, x + U2_ENH_BOX_PAD, y + U2_ENH_BOX_PAD, name, c->text, c->box_bg);

    char h1[8], h2[8], f1[8], g1[8];    bcd4(ctx->state.hp, ctx->state.unk_52, h1, sizeof h1);
    bcd4(ctx->state.exp_lo, ctx->state.exp_hi, h2, sizeof h2);
    bcd4(ctx->state.food_hi, ctx->state.food_lo, f1, sizeof f1);
    bcd4(ctx->state.gold_lo, ctx->state.gold_hi, g1, sizeof g1);

    /* Column arithmetic in whole text cells, because the box is 24 cells wide and
     * pixel offsets that were derived by hand were what put the E and G values off
     * the edge on the first attempt. Layout: name on row 0, then a 2x2 grid of
     * label+value pairs, then the avatar down the right-hand side. */
    const int cx = x + U2_ENH_BOX_PAD;          /* first text column, pixels */
    const int r0 = y + U2_ENH_BOX_PAD;
    const int r1 = r0 + U2_FONT_CELL_H;
    const int r2 = r1 + U2_FONT_CELL_H;
    const int c_lbl = 0, c_val = 7, c_lbl2 = 9, c_val2 = 16;
    /* Labels are ours. The reference uses bare H F E G in a 2x2 grid; keeping the
     * letters matches it closely enough to be recognised and costs nothing. */
    text(f, cx + c_lbl  * U2_FONT_CELL_W, r1, "H:", c->text, c->box_bg);
    text(f, cx + c_lbl  * U2_FONT_CELL_W, r2, "F:", c->text, c->box_bg);
    text(f, cx + c_lbl2 * U2_FONT_CELL_W, r1, "E:", c->text, c->box_bg);
    text(f, cx + c_lbl2 * U2_FONT_CELL_W, r2, "G:", c->text, c->box_bg);
    value_right(f, cx + (c_val  + 1) * U2_FONT_CELL_W, r1, h1, c->text, c->box_bg);
    value_right(f, cx + (c_val  + 1) * U2_FONT_CELL_W, r2, f1, c->text, c->box_bg);
    value_right(f, cx + (c_val2 + 1) * U2_FONT_CELL_W, r1, h2, c->text, c->box_bg);
    value_right(f, cx + (c_val2 + 1) * U2_FONT_CELL_W, r2, g1, c->text, c->box_bg);

    if (avatar_art >= 0 && tiles) {
        /* Through the theme's map, not raw: art 60 is the avatar and pool index 60
         * in a v2 theme is a capital O. That was a real bug, fixed today. */
        const int tile = u2_tiles_ega_tile(tiles, avatar_art);
        if (tile >= 0)
            u2_frame_blit_tile_ega(f, tiles, tile,
                                   x + w - U2_ENH_BOX_PAD - u2_tiles_ega_tile_w(tiles),
                                   y + (h - u2_tiles_ega_tile_h(tiles)) / 2);
    }
}

static void draw_box2(u2_frame *f, const u2_ctx *ctx, const u2_panel_colours *c)
{
    const int x = U2_ENH_PANEL_X, y = U2_ENH_BOX2_Y, w = U2_ENH_PANEL_W, h = U2_ENH_BOX2_H;
    box(f, x, y, w, h, c->box_bg, c->border);

    /* Our order and our labels, per the ruling. The reference truncates
     * INTELLIGENCE to fit its wider font; at 8px we have room for the whole word. */
    static const char *const labels[6] = {
        "STRENGTH", "AGILITY", "STAMINA", "CHARISMA", "WISDOM", "INTELLIGENCE"
    };
    const uint8_t v[6] = {
        ctx->state.stat_str, ctx->state.stat_agi, ctx->state.stat_sta,
        ctx->state.stat_cha, ctx->state.stat_wis, ctx->state.stat_int
    };
    const int right  = x + w - U2_ENH_BOX_PAD;
    for (int i = 0; i < 6; i++) {
        const int ry = y + U2_ENH_BOX_PAD + i * U2_FONT_CELL_H;
        text(f, x + U2_ENH_BOX_PAD, ry, labels[i], c->text, c->box_bg);
        /* The dotted leader the reference puts between label and value, drawn
         * rather than assumed: fill the gap the label left with dots. */
        const int dots_from = x + U2_ENH_BOX_PAD
                            + (int)strlen(labels[i]) * U2_FONT_CELL_W + U2_FONT_CELL_W;
        const int dots_to   = right - 3 * U2_FONT_CELL_W;
        for (int dx = dots_from; dx < dots_to; dx += U2_FONT_CELL_W)
            text(f, dx, ry, ".", c->text, c->box_bg);
        char num[4];
        snprintf(num, sizeof num, "%u", v[i]);
        value_right(f, right, ry, num, c->text, c->box_bg);
    }

    char line[40];
    const int ey = y + U2_ENH_BOX_PAD + 6 * U2_FONT_CELL_H;
    /* "WEA:"/"ARM:" are the reference's abbreviations and are NOT strings from
     * ultimaii.exe, which spells these WEAPON- and ARMOUR-. Invented on purpose:
     * enhanced mode is a presentation, ruled 2026-11-05. The names after them are
     * the real extracted pools. */
    snprintf(line, sizeof line, "WEA:%s", P_NAME(U2_T_WEAPONS, ctx->state.readied_weapon));
    text(f, x + U2_ENH_BOX_PAD, ey, line, c->text, c->box_bg);
    snprintf(line, sizeof line, "ARM:%s", P_NAME(U2_T_ARMOUR, ctx->state.worn_armour));
    text(f, x + U2_ENH_BOX_PAD, ey + U2_FONT_CELL_H, line, c->text, c->box_bg);
}

static void draw_box3(u2_frame *f, const u2_panel_colours *c,
                      const char *const *log, int n_log)
{
    const int x = U2_ENH_PANEL_X, y = U2_ENH_BOX3_Y, w = U2_ENH_PANEL_W, h = U2_ENH_BOX3_H;
    box(f, x, y, w, h, c->box_bg, c->border);
    if (!log) return;

    const int cols = U2_ENH_TEXT_COLS;
    const int first_row = (h - U2_ENH_BOX_PAD) / U2_FONT_CELL_H;
    /* Newest at the bottom, like a log. Lines longer than the box wrap, which is
     * a real change from the DOS 40-column grid: the panel is narrower, so a line
     * such as CMD: ATTACK--EAST--HIT!!! occupies more rows here. The reference
     * lives with 17 columns, so this is normal rather than a defect. */
    int row = first_row;
    for (int i = 0; i < n_log && row >= 0; i++) {
        const char *s = log[i];
        if (!s) continue;
        const int n = (int)strlen(s);
        for (int off = 0; off < n || off == 0; off += cols) {
            char chunk[64];
            const int take = n - off > cols ? cols : n - off;
            memcpy(chunk, s + off, (size_t)take);
            chunk[take] = '\0';
            text(f, x + U2_ENH_BOX_PAD, y + U2_ENH_BOX_PAD + row * U2_FONT_CELL_H,
                 chunk, c->text, c->box_bg);
            row--;
            if (row < 0) break;
        }
    }
}

/* ---------------------------------------------------------------- draw */

void u2_panel_draw(u2_frame *f, const u2_ctx *ctx, const u2_tiles_ega *tiles,
                   const u2_panel_colours *c, int avatar_art,
                   const char *const *log, int n_log)
{
    if (!f || !c) return;
    /* The backdrop is the field the boxes sit in, so it is painted before them. */
    fill(f, U2_ENH_PANEL_X, 0, U2_ENH_PANEL_W, U2_ENH_MAP_ROWS * 32, c->backdrop);
    draw_box1(f, ctx, tiles, c, avatar_art);
    draw_box2(f, ctx, c);
    draw_box3(f, c, log, n_log);

    /* Constant chrome in the reference: identical at H:258 and H:4922, so it is
     * not a health bar. Ruled to stay meaningless until there is a use for it. */
    box(f, U2_ENH_BAR_X, U2_ENH_BAR_Y, U2_ENH_BAR_W, U2_ENH_BAR_H,
        c->bar, c->border);
}
