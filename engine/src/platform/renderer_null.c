/*
 * renderer_null.c — headless backend: accepts every cell, draws nothing.
 *
 * This is a first-class mode, not a stub: the scripted playthroughs and the
 * CP2 MCP play-API read the grid out of core/vram.c via --dump-state, so the
 * renderer only has to be a sink.
 */
#include "core/ctx.h"

static int null_init(u2_ctx *ctx)
{
    (void)ctx;
    return 0;
}

static void null_cell(u2_ctx *ctx, int row, int col, uint8_t ch, uint8_t attr)
{
    (void)ctx; (void)row; (void)col; (void)ch; (void)attr;
}

static void null_cursor(u2_ctx *ctx, int row, int col, int visible)
{
    (void)ctx; (void)row; (void)col; (void)visible;
}

static void null_flush(u2_ctx *ctx) { (void)ctx; }
static void null_shutdown(u2_ctx *ctx) { (void)ctx; }

const u2_renderer u2_renderer_null = {
    .name = "null",
    .init = null_init,
    .cell = null_cell,
    .cursor = null_cursor,
    .flush = null_flush,
    .shutdown = null_shutdown,
};
