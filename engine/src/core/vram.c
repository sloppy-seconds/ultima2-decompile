/*
 * vram.c — 40x25 character grid: primitives only.
 * spec: asm/4A1C_char_out.asm (teletype), asm/5025_sub_5025.asm (INT 10h
 *       AH=06h window scroll), asm/51FD_str_out_core.asm (cursor),
 *       asm/53A0_sub_53a0.asm (40-column row clear)
 * The margin/attribute/wrap policy lives in core/seam.c, next to the asm that
 * implements it; this file is the hardware-shaped storage underneath.
 */
#include <string.h>
#include "core/vram.h"
#include "core/ctx.h"

void u2_vram_init(u2_vram *v)
{
    memset(v, 0, sizeof *v);
    u2_vram_clear(v, 0x07);
}

void u2_vram_clear(u2_vram *v, uint8_t attr)
{
    for (int r = 0; r < U2_ROWS; r++)
        for (int c = 0; c < U2_COLS; c++) {
            v->cell[r][c].ch = ' ';
            v->cell[r][c].attr = attr;
        }
    v->row = 0;
    v->col = 0;
    v->dirty = 1;
}

void u2_vram_goto(u2_vram *v, int row, int col)
{
    if (row < 0) row = 0;
    if (row >= U2_ROWS) row = U2_ROWS - 1;
    if (col < 0) col = 0;
    if (col >= U2_COLS) col = U2_COLS - 1;
    v->row = row;
    v->col = col;
}

void u2_vram_poke(u2_vram *v, int row, int col, uint8_t ch, uint8_t attr)
{
    if (row < 0 || row >= U2_ROWS || col < 0 || col >= U2_COLS)
        return;
    if (v->cell[row][col].ch != ch || v->cell[row][col].attr != attr)
        v->dirty = 1;
    v->cell[row][col].ch = ch;
    v->cell[row][col].attr = attr;
    v->writes++;
}

void u2_vram_put(u2_vram *v, uint8_t ch, uint8_t attr)
{
    /* char_out (asm/4A1C) is a bare INT 10h AH=01h teletype: no CR handling,
     * no attribute of its own. Callers that want the game's text printer
     * semantics use char_print instead (see core/seam.c). */
    ch &= 0x7F;
    if (ch < 0x20)
        return;
    u2_vram_poke(v, v->row, v->col, ch, attr);
    if (++v->col >= U2_COLS) {
        v->col = 0;
        if (v->row < U2_ROWS - 1)
            v->row++;
        else
            u2_vram_scroll_window(v, 0, U2_ROWS - 1, 0, U2_COLS - 1, attr);
    }
}

void u2_vram_scroll_window(u2_vram *v, int top, int bottom, int left, int right,
                           uint8_t attr)
{
    if (top < 0 || bottom >= U2_ROWS || top >= bottom)
        return;
    if (right >= U2_COLS) right = U2_COLS - 1;
    if (left < 0) left = 0;
    for (int r = top; r < bottom; r++)
        for (int c = left; c <= right; c++)
            u2_vram_poke(v, r, c, v->cell[r + 1][c].ch, v->cell[r + 1][c].attr);
    for (int c = left; c <= right; c++)
        u2_vram_poke(v, bottom, c, ' ', attr);
    v->dirty = 1;
}

void u2_vram_flush(u2_vram *v, u2_ctx *ctx)
{
    if (!v->dirty || !ctx || !ctx->renderer || !ctx->renderer->cell)
        return;
    for (int r = 0; r < U2_ROWS; r++)
        for (int c = 0; c < U2_COLS; c++)
            ctx->renderer->cell(ctx, r, c, v->cell[r][c].ch, v->cell[r][c].attr);
    if (ctx->renderer->cursor)
        ctx->renderer->cursor(ctx, v->row, v->col, v->visible);
    if (ctx->renderer->flush)
        ctx->renderer->flush(ctx);
    v->dirty = 0;
}

int u2_vram_row_text(const u2_vram *v, int row, char *out, int outsz)
{
    if (row < 0 || row >= U2_ROWS || outsz <= 0) {
        if (outsz > 0) out[0] = '\0';
        return 0;
    }
    int n = U2_COLS;
    while (n > 0 && v->cell[row][n - 1].ch == ' ')
        n--;
    int i = 0;
    for (; i < n && i < outsz - 1; i++)
        out[i] = (char)v->cell[row][i].ch;
    out[i] = '\0';
    return i;
}
