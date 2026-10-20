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

int main(void)
{
    u2_ctx ctx;
    u2_frame f;
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

    printf("status_check: %s\n", fails ? "FAIL" : "PASS");
    return fails ? 1 : 0;
}
