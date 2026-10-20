/*
 * main.c — engine entry point and backend wiring.
 *
 * Modes (docs/phase4-plan.md §2): the headless build is a first-class mode,
 * not a debug patch. --headless selects the null renderer, the script input
 * (or piped stdin), the silent audio backend and the deterministic clock, so a
 * run is reproducible and its stdout is machine-readable.
 *
 *   ./u2                                  interactive terminal play
 *   ./u2 --headless --script k.keys       scripted playthrough
 *   ./u2 --headless --script k.keys --dump-state
 *   ./u2 --trace trace.log                seam log with asm citations
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "core/ctx.h"
#include "core/seam.h"
#include "core/timer.h"
#include "core/state.h"
#include "debug/trace.h"
#include "debug/dump_state.h"
#include "game/game.h"
static void usage(const char *argv0)
{
    fprintf(stderr,
        "u2 — portable C engine (Phase 4); spec = asm/ tree\n"
        "usage: %s [--headless] [--script FILE] [--dump-state] [--selftest] [--trace[=FILE]]\n"
        "\n"
        "  --headless      null renderer + script input + deterministic clock\n"
        "  --script FILE   key script (see tests/title.keys)\n"
        "  --dump-state    print the screen grid and a JSON state dump on exit\n"
        "  --dump-each     print the grid after every screen change (frame log)\n"
        "  --selftest      exercise every seam once on an engine-authored screen\n"
        "  --trace[=FILE]  log every seam call with its asm address\n",
        argv0);
}

static int wire_backends(u2_ctx *ctx)
{
    if (ctx->mode == U2_MODE_HEADLESS) {
        ctx->renderer = &u2_renderer_null;
        ctx->audio    = &u2_audio_null;
        ctx->clock    = &u2_clock_script;
        ctx->input    = ctx->script_path ? &u2_input_script : &u2_input_term;
    } else {
        ctx->renderer = &u2_renderer_term;
        ctx->audio    = &u2_audio_beep;
        ctx->clock    = &u2_clock_posix;
        ctx->input    = &u2_input_term;
    }

    if (ctx->clock->init && ctx->clock->init(ctx) != 0) return -1;
    if (ctx->renderer->init && ctx->renderer->init(ctx) != 0) return -1;
    if (ctx->input->init && ctx->input->init(ctx) != 0) return -1;
    if (ctx->audio->init && ctx->audio->init(ctx) != 0) return -1;
    return 0;
}

static void release_backends(u2_ctx *ctx)
{
    if (ctx->input->shutdown) ctx->input->shutdown(ctx);
    if (ctx->audio->shutdown) ctx->audio->shutdown(ctx);
    if (ctx->renderer->shutdown) ctx->renderer->shutdown(ctx);
    if (ctx->clock->shutdown) ctx->clock->shutdown(ctx);
}

int main(int argc, char **argv)
{
    u2_ctx ctx;
    const char *trace_arg = NULL;

    memset(&ctx, 0, sizeof ctx);
    ctx.mode = U2_MODE_TERM;

    for (int i = 1; i < argc; i++) {
        const char *a = argv[i];
        if (strcmp(a, "--headless") == 0) {
            ctx.mode = U2_MODE_HEADLESS;
        } else if (strcmp(a, "--script") == 0 && i + 1 < argc) {
            ctx.script_path = argv[++i];
        } else if (strcmp(a, "--dump-state") == 0) {
            ctx.dump_state = 1;
        } else if (strcmp(a, "--dump-each") == 0) {
            ctx.dump_each = 1;
        } else if (strcmp(a, "--selftest") == 0) {
            ctx.selftest = 1;
        } else if (strcmp(a, "--trace") == 0) {
            trace_arg = "-";
        } else if (strncmp(a, "--trace=", 8) == 0) {
            trace_arg = a + 8;
        } else if (strcmp(a, "--help") == 0 || strcmp(a, "-h") == 0) {
            usage(argv[0]);
            return 0;
        } else {
            fprintf(stderr, "u2: unknown argument '%s'\n", a);
            usage(argv[0]);
            return 2;
        }
    }

    if (trace_arg && u2_trace_open(&ctx, trace_arg) != 0) {
        fprintf(stderr, "u2: cannot open trace file '%s'\n", trace_arg);
        return 2;
    }

    u2_vram_init(&ctx.vram);
    u2_state_init(&ctx.state);

    if (wire_backends(&ctx) != 0) {
        fprintf(stderr, "u2: backend initialisation failed\n");
        u2_trace_close(&ctx);
        return 1;
    }
    u2_timer_pump(&ctx);

    if (u2_game_init(&ctx) != 0) {
        fprintf(stderr, "u2: game init failed\n");
        release_backends(&ctx);
        u2_trace_close(&ctx);
        return 1;
    }

    u2_game_run(&ctx);
    u2_game_shutdown(&ctx);
    seam_present(&ctx);
    release_backends(&ctx);

    if (ctx.dump_state) {
        u2_dump_screen(&ctx, stdout);
        u2_dump_state_json(&ctx, stdout);
    }
    u2_trace_close(&ctx);
    return ctx.exit_code;
}
