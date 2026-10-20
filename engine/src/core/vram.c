/*
 * vram.c — 80x25 character grid with teletype and direct-write semantics.
 * spec: asm/4A1C_char_out.asm (INT 10h AH=01h teletype),
 *       asm/5003_char_print.asm (CR special case),
 *       asm/51FD_str_out_core.asm (INT 10h AH=02 cursor set),
 *       asm/5351_sub_5351.asm (direct 0xB800 segment writes)
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

static void vram_scroll(u2_vram *v)
{
    memmove(&v->cell[0][0], &v->cell[1][0],
            sizeof(u2_cell) * U2_COLS * (U2_ROWS - 1));
    for (int c = 0; c < U2_COLS; c++) {
        v->cell[U2_ROWS - 1][c].ch = ' ';
        v->cell[U2_ROWS - 1][c].attr = 0x07;
    }
    v->col = 0;
    v->row = U2_ROWS - 1;
    v->dirty = 1;
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
    /* char_print (asm/5003) masks the high bit and special-cases CR. */
    ch &= 0x7F;
    if (ch == '\r') {
        v->col = 0;
        return;
    }
    if (ch == '\n') {
        v->col = 0;
        if (++v->row >= U2_ROWS)
            v->row = U2_ROWS - 1;
        return;
    }
    if (ch == '\b') {
        if (v->col > 0) v->col--;
        return;
    }
    if (ch < 0x20)
        return; /* unhandled control chars: no cell write */
    u2_vram_poke(v, v->row, v->col, ch, attr);
    if (++v->col >= U2_COLS) {
        v->col = 0;
        if (v->row < U2_ROWS - 1)
            v->row++;
        else
            vram_scroll(v);
    }
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
