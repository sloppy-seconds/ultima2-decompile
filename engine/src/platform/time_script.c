/*
 * time_script.c — deterministic virtual clock for headless runs.
 *
 * A scripted playthrough must replay identically, so the tick advances by a
 * fixed step per call instead of reading the wall clock. This is also what
 * makes rand_byte (asm/5217_rand_byte.asm) reproducible under automation:
 * the original derives its roll from the live tick counters, so freezing the
 * clock freezes the dice — which is exactly what a test harness wants.
 */
#include <stdlib.h>
#include "core/ctx.h"

typedef struct script_clock {
    uint64_t tick;
    uint64_t step;
    uint64_t slept_ms;
} script_clock;

static uint64_t script_tick(u2_ctx *ctx)
{
    script_clock *sc = ctx->be_clock;
    if (!sc) return 0;
    sc->tick += sc->step;
    return sc->tick;
}

static void script_sleep_ms(u2_ctx *ctx, uint32_t ms)
{
    script_clock *sc = ctx->be_clock;
    if (sc) sc->slept_ms += ms;
}

static int script_init(u2_ctx *ctx)
{
    script_clock *sc = calloc(1, sizeof *sc);
    if (!sc) return -1;
    sc->step = 1;
    ctx->be_clock = sc;
    return 0;
}

static void script_shutdown(u2_ctx *ctx)
{
    free(ctx->be_clock);
    ctx->be_clock = NULL;
}

const u2_clock u2_clock_script = {
    .name = "script",
    .init = script_init,
    .tick = script_tick,
    .sleep_ms = script_sleep_ms,
    .shutdown = script_shutdown,
};
