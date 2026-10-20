/*
 * renderer_term.c — ANSI terminal backend.
 *
 * Paints the 80x25 grid with cursor addressing; the grid itself is owned by
 * core/vram.c so this stays a pure painter (seam discipline).
 * Colour attributes are mapped to the 16 CGA palette colours when the
 * terminal is asked for them; CP0 draws plain, CP9 (SDL2 CGA) is where
 * palette authenticity lives.
 */
#include <stdio.h>
#include <stdlib.h>
#include "core/ctx.h"

static int term_init(u2_ctx *ctx)
{
    /* Clear once; from then on every flush rewrites cells in place. */
    fputs("\033[2J\033[H", stdout);
    ctx->vram.visible = 0;
    return 0;
}

static void term_cell(u2_ctx *ctx, int row, int col, uint8_t ch, uint8_t attr)
{
    (void)attr;
    printf("\033[%d;%dH%c", row + 1, col + 1, (char)ch);
}

static void term_cursor(u2_ctx *ctx, int row, int col, int visible)
{
    (void)ctx;
    printf("\033[%d;%dH", row + 1, col + 1);
    fputs(visible ? "\033[?25h" : "\033[?25l", stdout);
}

static void term_flush(u2_ctx *ctx)
{
    (void)ctx;
    fflush(stdout);
}

static void term_shutdown(u2_ctx *ctx)
{
    (void)ctx;
    fputs("\033[?25h\n", stdout);
    fflush(stdout);
}

const u2_renderer u2_renderer_term = {
    .name = "term",
    .init = term_init,
    .cell = term_cell,
    .cursor = term_cursor,
    .flush = term_flush,
    .shutdown = term_shutdown,
};
