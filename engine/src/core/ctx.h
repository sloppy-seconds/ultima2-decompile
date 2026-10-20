#ifndef U2_CTX_H
#define U2_CTX_H

/*
 * Engine context — one struct, passed everywhere. No globals in the engine:
 * a headless playthrough must be able to run several contexts side by side
 * (the MCP play-API at CP2 depends on that).
 */

#include <stdio.h>
#include "platform/platform.h"
#include "core/vram.h"
#include "core/state.h"

typedef enum u2_mode {
    U2_MODE_TERM = 0,   /* interactive terminal */
    U2_MODE_HEADLESS = 1/* null renderer, scripted or piped input */
} u2_mode;

typedef struct u2_ctx {
    u2_mode mode;
    const u2_renderer *renderer;
    const u2_input    *input;
    const u2_audio    *audio;
    const u2_clock    *clock;

    u2_vram  vram;
    u2_state state;

    struct {
        int   enabled;      /* --trace */
        FILE *out;          /* stderr by default */
    } trace;

    int dump_state;         /* --dump-state */
    int dump_each;          /* --dump-each: print the grid after every present */
    int selftest;           /* --selftest: draw the seam probe screen and stop */
    uint32_t rng_rolls;     /* rolls served, for dumps and tests */
    int rng_probe;          /* --rng-sequence N: print N rolls and exit */
    int input_exhausted;    /* set by the script backend when the keys run out;
                               the flow treats it as "the player left" */
    const char *content_source; /* set by the game layer from the generated header */
    const char *script_path;/* --script PATH (input_script backend input) */
    int exit_code;          /* set by game code / backends to force termination */

    /* Per-backend private state, one slot each so backends stay independent
     * and a context can be torn down without backend-specific knowledge. */
    void *be_render;
    void *be_input;
    void *be_audio;
    void *be_clock;
    void *be_game;          /* game layer state (game/game.c) */
} u2_ctx;

#endif /* U2_CTX_H */
