/*
 * game.c — main loop (CP0 skeleton).
 *
 * Structure taken from the original's command loop shape: present the screen,
 * poll for a key (seam: key_poll, asm/4F4D_key_poll.asm), dispatch, repeat.
 * The dispatch table itself is cmd_dispatch (asm/0A1F_cmd_dispatch.asm) and
 * arrives with the command handlers at CP6.
 *
 * Everything drawn here is engine-authored placeholder text. No Ultima II
 * string appears in the engine: content is extracted at build time from the
 * user's own copy (tools/extract/extractor.py, CP1) into gitignored headers.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "game/game.h"
#include "core/seam.h"
#include "debug/trace.h"

typedef struct game_ctx {
    int   frames;
    int   keys_seen;
    int   quit;
    char  last[3];
} game_ctx;

static void draw_skeleton_screen(u2_ctx *ctx)
{
    seam_str_out_at(ctx, 2, 2, "U2 ENGINE - CP0 SKELETON");
    seam_str_out_at(ctx, 2, 4, "portable C reimplementation of the Ultima II binary");
    seam_str_out_at(ctx, 2, 5, "spec: asm/ tree (byte-proven, Phase 3)");
    seam_str_out_at(ctx, 2, 7, "no game content loaded - strings arrive via the CP1 extractor");
    seam_str_out_at(ctx, 2, 9, "seams wired: char_out str_out str_out_at key_poll");
    seam_str_out_at(ctx, 2, 10, "               rand_byte timed_wait speaker_freq");
    seam_str_out_at(ctx, 2, 12, "press Q to quit");
}

static void draw_probe_line(u2_ctx *ctx, game_ctx *g)
{
    char buf[64];

    /* rand_byte probe: proves the tick mixer and the deterministic clock. */
    unsigned r1 = seam_rand_byte(ctx);
    unsigned r2 = seam_rand_byte(ctx);
    snprintf(buf, sizeof buf, "rand_byte(5217) -> %u %u   frames=%d keys=%d last=%s",
             r1, r2, g->frames, g->keys_seen, g->last);
    seam_str_out_at(ctx, 2, 14, buf);

    /* timed_wait + speaker_freq probes: the two remaining platform seams. */
    seam_wait_ms(ctx, 1);
    seam_tone(ctx, 0x0830, 5); /* divisor for ~750 Hz, asm/5CD2_speaker_freq.asm */
    snprintf(buf, sizeof buf, "timed_wait(52CA) ok   speaker_freq(5CD2) latched 0x0830");
    seam_str_out_at(ctx, 2, 16, buf);
}

int u2_game_init(u2_ctx *ctx)
{
    game_ctx *g = calloc(1, sizeof *g);
    if (!g) return -1;
    snprintf(g->last, sizeof g->last, "-");
    ctx->be_game = g;
    draw_skeleton_screen(ctx);
    seam_present(ctx);
    return 0;
}

void u2_game_run(u2_ctx *ctx)
{
    game_ctx *g = ctx->be_game;

    for (;;) {
        u2_key k;

        if (ctx->exit_code || g->quit)
            break;
        if (!seam_key_poll(ctx, &k)) {
            /* No key: in headless mode the script is exhausted, so stop; in
             * terminal mode yield and keep polling. */
            if (ctx->mode == U2_MODE_HEADLESS)
                break;
            seam_wait_ms(ctx, 10);
            continue;
        }
        g->keys_seen++;
        g->last[0] = (k.ch >= 0x20 && k.ch < 0x7F) ? (char)k.ch : '.';
        g->last[1] = '\0';
        if (k.ch == 'Q' || k.ch == 'q' || k.ch == 0x03) {
            g->quit = 1;
            continue;
        }
        g->frames++;
        draw_probe_line(ctx, g);
        seam_present(ctx);
    }
}

void u2_game_shutdown(u2_ctx *ctx)
{
    free(ctx->be_game);
    ctx->be_game = NULL;
}
