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
#define _POSIX_C_SOURCE 200809L   /* gmtime_r, strdup under -std=c11;
                                  * stated rather than assumed, as in core/save.c */

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdlib.h>
#include <string.h>
#include "core/ctx.h"
#include "core/seam.h"
#include "core/timer.h"
#include "core/state.h"
#include "core/save.h"
#include "core/rng.h"
#include "core/replay.h"
#include "debug/trace.h"
#include "debug/dump_state.h"
#include "debug/turnlog.h"
#include "game/game.h"
#include "game/overworld.h"
static void usage(const char *argv0)
{
    fprintf(stderr,
        "u2 — portable C engine (Phase 4); spec = asm/ tree\n"
        "usage: %s [--headless] [--script FILE] [--dump-state] [--selftest] [--trace[=FILE]]\n"
        "\n"
        "  --headless      null renderer + script input + deterministic clock\n"
        "  --script FILE   key script (see tests/title.keys)\n"
        "  --dump-state    print the screen grid and a JSON state dump on exit\n"
        "  --sdl           bitmap window instead of the text grid (make sdl build)\n"
        "  --play-map      enter the overworld screen directly (CP4 development entry)\n"
        "  --enhanced      enhanced fidelity: same rules and state as the original, but\n"
        "                  dead ends the original could not avoid are removed. Today that\n"
        "                  means finishing character creation enters the world instead of\n"
        "                  replaying the CP/M disk-swap restart. Default is original,\n"
        "                  which is what the CP2 byte-comparison baseline measures.\n"
        "  --auto-pass-polls N\n"
        "                  idle polls before the engine auto-PASSes. 0 = the original's\n"
        "                  fixed value, -1 = disabled for pure turn-based play, N = that\n"
        "                  many. Intended for --enhanced; the original offers no such knob.\n"
        "  --dump-map FILE render one frame of the overworld to FILE as PPM\n"
        "                  (needs --data-dir with the game files; no display needed)\n"
        "  --dump-each     print the grid after every screen change (frame log)\n"
        "  --debug cli     write turn-NNNNN.ppm and .json into --debug-path after\n"
        "                  every player turn. This is the only way to observe a\n"
        "                  running session; the dump flags are all run-then-exit.\n"
        "  --debug-path D  directory for --debug output (default /tmp; the project\n"
        "                  overrides it because /tmp is tmpfs on its own host)\n"
        "  --debug-limit N stop --debug after N turns (default 200; 0 = unlimited).\n"
        "                  An idle run auto-PASSes, and a PASS is a turn.\n"
        "  --dump-screen F  (SDL build) save the first presented frame to F as\n"
        "                    PPM and exit; with SDL_VIDEODRIVER=dummy this\n"
        "                    proves the window pixel path with no display\n"
        "  --selftest      exercise every seam once on an engine-authored screen\n"
        "  --replay-report F  write a verifiable playthrough report (digests, no game text) to F\n"
        "  --seed N          PRNG seed byte, as the 0x40:6C value the original reads\n"
        "  --rng-sequence N  print N rand_byte values and exit (test vector)\n"
        "  --cleanroom       use the engine's own independently created assets in\n"
        "                    place of the game's: substitute tiles now, and other\n"
        "                    media (sound, music) as they are added. Opt-in, and\n"
        "                    always announced — a screen drawn with substitute\n"
        "                    assets is never presented as the real thing.\n"
        "  --save-dir DIR    player-record directory, the modern default drive\n"
        "                    (default: ./saves; holds the byte-compatible PLAYER file)\n"
        "  --data-dir DIR    world content directory: mapxNN / monxNN / tlkxNN.\n"
        "                    The map is runtime data, never extracted content, so the\n"
        "                    engine reads the player's own files the way the original\n"
        "                    read them from its default drive (default: .). It is read\n"
        "                    AND written: the original rewrites its own sectors.\n"
        "\nkeys while playing:\n"
        "  Ctrl-Q  quit (the original has no quit key; 'Q' saves)\n"
        "  --mode M          reserved for CP11; only 'original' exists today\n"
        "\nkeys while playing:\n"
        "  Ctrl-Q  quit (the original has no quit key; 'Q' saves)\n"
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
#ifdef U2_HAVE_SDL
    } else if (ctx->use_sdl) {
        /* The bitmap shell. It only moves pixels the engine already composed;
         * choosing it changes nothing about what the game draws. */
        ctx->renderer = &u2_renderer_sdl;
        ctx->audio    = &u2_audio_sdl;
        ctx->clock    = &u2_clock_posix;
        ctx->input    = &u2_input_sdl;
#endif
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
    const char *report_path = NULL;
    const char *map_dump_path = NULL;
    unsigned seed = U2_RNG_DEFAULT_SEED;
    int rng_probe = 0;
    memset(&ctx, 0, sizeof ctx);
    ctx.mode = U2_MODE_TERM;

    ctx.debug_limit = U2_TURNLOG_DEFAULT_LIMIT;

    for (int i = 1; i < argc; i++) {
        const char *a = argv[i];
        if (strcmp(a, "--headless") == 0) {
            ctx.mode = U2_MODE_HEADLESS;
        } else if (strcmp(a, "--sdl") == 0) {
            ctx.use_sdl = 1;
        } else if (strcmp(a, "--play-map") == 0) {
            ctx.play_map = 1;
        } else if (strcmp(a, "--enhanced") == 0) {
            /* Same rules and state as the original; dead ends the original
             * could not avoid are removed. Default is original, which is what
             * the CP2 byte-comparison baseline is measured against. */
            ctx.fidelity = U2_FIDELITY_ENHANCED;
        } else if (strcmp(a, "--auto-pass-polls") == 0 && i + 1 < argc) {
            /* Idle auto-PASS threshold. 0 restores the faithful default, -1
             * disables it for pure turn-based play. Only meaningful in enhanced
             * mode: the original has one fixed value and no way to change it. */
            ctx.auto_pass_polls = atoi(argv[++i]);
        } else if (strcmp(a, "--script") == 0 && i + 1 < argc) {
            ctx.script_path = argv[++i];
        } else if (strcmp(a, "--save-dir") == 0 && i + 1 < argc) {
            ctx.save_dir = argv[++i];
        } else if (strcmp(a, "--cleanroom") == 0) {
            ctx.cleanroom = 1;
        } else if (strcmp(a, "--data-dir") == 0 && i + 1 < argc) {
            ctx.data_dir = argv[++i];
        } else if (strcmp(a, "--seed") == 0 && i + 1 < argc) {
            seed = (unsigned)strtoul(argv[++i], NULL, 0);
        } else if (strcmp(a, "--replay-report") == 0 && i + 1 < argc) {
            report_path = argv[++i];
        } else if (strcmp(a, "--rng-sequence") == 0 && i + 1 < argc) {
            rng_probe = (int)strtol(argv[++i], NULL, 0);
        } else if (strcmp(a, "--dump-state") == 0) {
            ctx.dump_state = 1;
        } else if (strcmp(a, "--dump-map") == 0 && i + 1 < argc) {
            map_dump_path = argv[++i];
        } else if (strcmp(a, "--dump-each") == 0) {
            ctx.dump_each = 1;
        } else if (strcmp(a, "--dump-screen") == 0 && i + 1 < argc) {
            ctx.dump_screen = argv[++i];
        } else if (strcmp(a, "--debug") == 0) {
            /* `--debug cli`, matching the existing `--trace[=FILE]` shape: the mode
             * is an argument rather than a separate flag so a bare --debug can be
             * rejected instead of silently guessing. */
            if (i + 1 < argc && argv[i + 1][0] != '-') {
                if (strcmp(argv[i + 1], "cli") != 0)
                    fprintf(stderr, "u2: --debug takes 'cli' (got '%s')\n", argv[i + 1]);
                else { ctx.debug_cli = 1; ++i; }
            } else {
                fprintf(stderr, "u2: --debug needs a mode; today that is only 'cli'\n");
            }
        } else if (strcmp(a, "--debug-path") == 0 && i + 1 < argc) {
            ctx.debug_path = argv[++i];
            ctx.debug_cli = 1;      /* naming a directory is intent enough */

        } else if (strcmp(a, "--debug-limit") == 0 && i + 1 < argc) {
            /* 0 means unlimited, and has to be asked for by name: an unattended
             * session auto-PASSes forever and wrote 288 file pairs in 45 s before
             * the cap existed. */
            char *end = NULL;
            const unsigned long v = strtoul(argv[++i], &end, 10);
            if (end == argv[i] || (end && *end != '\0'))
                fprintf(stderr, "u2: --debug-limit wants a number (got '%s')\n", argv[i]);
            else
                ctx.debug_limit = (unsigned)v;
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
    /* asm/0100_sub_0100.asm seeds the shift register once, at program launch,
     * from the BIOS keyboard flags at 0x40:6C. Nothing re-seeds it per game;
     * the only other caller of that stub is the "INSERT PROGRAM MASTER"
     * restart at asm/5400's tail. --seed overrides it so a run can be made
     * reproducible or deliberately different. */
    u2_rng_seed(&ctx, (uint8_t)seed);
    ctx.seed = seed & 0xFFu;

    if (report_path) {
        u2_replay_begin(&ctx);
        u2_replay_set_keys(&ctx, ctx.script_path);
    }

    if (rng_probe > 0) {
        for (int i = 0; i < rng_probe; i++)
            printf("%u%s", u2_rand_byte(&ctx), i + 1 == rng_probe ? "\n" : ",");
        return 0;
    }

    /* CP5: both development entries -- --play-map and --dump-map -- used to run on
     * a zeroed state, which made a scripted fight unshowable (agi 0 never lands a
     * hit) and put the player in whatever sector the zero bytes named. The title's
     * own P path loads the PLAYER record first (title.c run_play); do the same
     * here, once, so the dev entries play the save actually on disk and cannot
     * drift from the real one.
     *
     * A blank or missing record is NOT an error and the zeroed state stands: that
     * is the original's own "no character yet" condition -- DS:36 is the first byte
     * of the name, and asm/5400 tests it for zero -- and the CP4 development
     * scripts depend on it. See docs/save-format.md. */
    if (ctx.play_map || map_dump_path)
        (void)u2_save_load(&ctx);

    if (map_dump_path) {
        /* No backends, no display: this path exists so the real extracted tiles
         * can be seen, and diffed, on a machine with no screen at all. */
        const int rc = u2_overworld_dump(&ctx, map_dump_path);
        u2_trace_close(&ctx);
        return rc == 0 ? 0 : 1;
    }

    if (wire_backends(&ctx) != 0) {
        fprintf(stderr, "u2: backend initialisation failed\n");
        u2_trace_close(&ctx);
        return 1;
    }
    if (u2_game_init(&ctx) != 0) {
        fprintf(stderr, "u2: game init failed\n");
        release_backends(&ctx);
        u2_trace_close(&ctx);
        return 1;
    }

    /* One directory per launch, named by its launch time in ISO 8601, always —
     * whether the base came from --debug or --debug-path. A fixed directory is a
     * trap: turn-00001.ppm from yesterday sits next to today's and an agent
     * reading "the newest file" cannot tell which game it came from, which is the
     * stale-evidence class this feature exists to close. */
    if (ctx.debug_cli) {
        char stamp[40], full[600];
        time_t now = time(NULL);
        struct tm gm;
        gmtime_r(&now, &gm);
        strftime(stamp, sizeof stamp, "%Y-%m-%dT%H:%M:%SZ", &gm);
        snprintf(full, sizeof full, "%s/%s",
                 ctx.debug_path ? ctx.debug_path : U2_TURNLOG_DEFAULT_DIR, stamp);
        ctx.debug_path = strdup(full);
        fprintf(stderr, "u2: --debug cli writing to %s\n", full);
    }

    if (ctx.play_map) {
        /* The record is already loaded (above), so this enters the world as the
         * character on disk rather than as a blank state. The note goes to stderr
         * unconditionally: on this development entry "sector 31 ... 32 creatures"
         * is the difference between a silent no-op and a diagnosable one, and the
         * CP5 fight scripts are driven entirely by reading it back. */
        u2_overworld ow;
        const int rc = u2_overworld_init_state(&ctx, &ow);
        fprintf(stderr, "overworld: %s\n", ow.note);
        if (rc == 0)
            u2_overworld_loop(&ctx, &ow);
    } else {
        u2_game_run(&ctx);
    }
    u2_game_shutdown(&ctx);
    seam_present(&ctx);
    release_backends(&ctx);

    if (ctx.dump_state) {
        u2_dump_screen(&ctx, stdout);
        u2_dump_state_json(&ctx, stdout);
    }
    if (report_path && u2_replay_write(&ctx, report_path) != 0) {
        fprintf(stderr, "u2: cannot write replay report '%s'\n", report_path);
        ctx.exit_code = 1;
    }
    free(ctx.replay);
    ctx.replay = NULL;
    u2_trace_close(&ctx);
    return ctx.exit_code;
}
