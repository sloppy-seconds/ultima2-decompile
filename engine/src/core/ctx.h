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

    /* The framebuffer a bitmap backend presents, owned by whoever allocates it
     * (the overworld screen today) and NULL for cell-only flows. Kept as a
     * pointer so a text-only run pays nothing for pixel support. */
    struct u2_frame *frame;

    struct {
        int   enabled;      /* --trace */
        FILE *out;          /* stderr by default */
    } trace;

    int dump_state;         /* --dump-state */
    int dump_each;          /* --dump-each: print the grid after every present */
    const char *dump_screen;/* --dump-screen F: SDL build saves the first
                             * presented frame to F as PPM, then the run ends.
                             * With SDL_VIDEODRIVER=dummy this makes the whole
                             * cell->font->upload path testable with no display. */
    int dump_screen_done;   /* set by the renderer after the dump */
    int selftest;           /* --selftest: draw the seam probe screen and stop */
    uint32_t rng_rolls;     /* rolls served, for dumps and tests */
    unsigned seed;          /* PRNG seed byte, i.e. the 0x40:6C value (core/rng.h) */
    int keys_consumed;      /* script tokens consumed so far (input_script sets it) */
    void *replay;           /* u2_replay* when --replay-report is active */
    int rng_probe;          /* --rng-sequence N: print N rolls and exit */
    /* Idle auto-PASS threshold, in polls of the overworld input loop.
     *   0  = not configured, use U2_AUTO_PASS_POLLS (the faithful default)
     *  -1  = disabled, for pure turn-based play
     *  >0  = explicit poll count
     * Reserved for the enhanced-mode knob: the original has one fixed value and
     * offers no way to change it, so `original` mode always uses the default and
     * only `enhanced` should ever set this. There is no fidelity-mode axis in the
     * engine yet (u2_mode is a renderer axis), so nothing sets it today. */
    int auto_pass_polls;
    int input_exhausted;    /* set by the script backend when the keys run out;
                               the flow treats it as "the player left" */
    const char *content_source; /* set by the game layer from the generated header */
    const char *script_path;/* --script PATH (input_script backend input) */
    const char *save_dir;    /* --save-dir PATH; "saves" when unset (core/save.h) */
    const char *data_dir;    /* --data-dir PATH; "." when unset — the original's
                                default drive, holding mapxNN / monxNN / tlkxNN.
                                Never created; see core/world.h. */
    int save_seeded;         /* set when the blank PLAYER file was created here */
    int use_sdl;             /* --sdl: bitmap backends (make sdl build only) */
    int play_map;            /* --play-map: enter the CP4 overworld directly */
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
