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

typedef enum u2_fidelity {
    U2_FIDELITY_ORIGINAL = 0,   /* byte-comparison baseline behaviour */
    U2_FIDELITY_ENHANCED = 1    /* same rules; dead ends removed */
} u2_fidelity;

typedef struct u2_ctx {
    u2_mode mode;
    /* Fidelity axis — independent of `mode`, which is a renderer axis.
     *   U2_FIDELITY_ORIGINAL  reproduce the original's behaviour, including its
     *                         dead ends and its bugs (default; what the CP2
     *                         byte-comparison baseline is measured against)
     *   U2_FIDELITY_ENHANCED  same rules and state, but dead ends the original
     *                         could not avoid may be removed — the CP/M disk-swap
     *                         restart after character creation is the first one.
     * Chosen at launch with --enhanced; never switched mid-run. */
    u2_fidelity fidelity;
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
    /* --dump-frame FILE: write the last composed framebuffer to FILE as a PPM when the
     * overworld loop ends. --dump-map renders the OPENING frame and returns; this is the
     * one that can show what a scripted run ended looking at, which is what CP7's
     * wireframe gate needs — a dungeon frame only exists after ENTER and IGNITE. */
    const char *frame_dump_path;
    /* Checkpoint file for --load-ds: whitespace-separated hex bytes of the DS mirror,
     * applied after the save AND after the world/monx load, because both of those overwrite
     * fields a mid-session checkpoint carries. NULL means no checkpoint. */
    const char *load_ds_path;
    /* --trace-rolls FILE: one line per rand_byte() call, tagged with the calling function.
     * NULL when not tracing. This exists because roll COUNT alone was not the diagnosis: the
     * engine and the original consumed the same number of rolls on a turn and still ended up with
     * different creature positions, which means the rolls were spent on different decisions. Only
     * a per-site trace shows that. */
    FILE *roll_trace;
    /* Diagnostic only, never read by game logic: the count of grid cells that look occupied
     * but hold no creature, refreshed each composed frame where the world is at hand.
     * "He left a copy of him behind", made checkable. See u2_monsters_ghost_cells(). */
    int diag_ghosts;
    /* Diagnostic only: wound flashes rendered since the run began (each on+off
     * pair is one). The flash leaves the frame bit-identical to how it found it,
     * so without a counter no gate can see it happened at all — the same
     * announce-yourself rule as g_unmeasured_tiles. Wired by E1;
     * captures/spice86/wound-flash-20261102 is what it counts against. */
    unsigned diag_flashes;
    /* The mirror diagnostic: creature slots that are NOT stamped into the grid, i.e. invisible
     * monsters. diag_ghosts == 0 says nothing about this direction, which is how a town entry
     * could report a clean frame while every NPC in it was unrenderable. */
    int diag_unstamped;
    /* Latched high-water mark of diag_unstamped measured at the moment a sector becomes
     * resident, BEFORE any restamp and before the post-command creature sweep can repair
     * it. Without the latch a gate cannot distinguish "stamped on load" from "stamped by the
     * first sweep", which is exactly how a town-entry defect survived a passing test. */
    int diag_unstamped_at_load;

    /* Set by the overworld loop to a function that composites and presents a whole frame.
     * seam_key_wait calls it before blocking so a handler that printed something just before
     * waiting has it on screen WITH the map, not over a blanked one. Null outside the
     * overworld, where the text-layer flush alone is the whole screen. See seam.c. */
    void (*present_now)(struct u2_ctx *ctx);
    int dump_each;          /* --dump-each: print the grid after every present */
    const char *dump_screen;/* --dump-screen F: SDL build saves the first
                             * presented frame to F as PPM, then the run ends.
                             * With SDL_VIDEODRIVER=dummy this makes the whole
                             * cell->font->upload path testable with no display. */
    int dump_screen_done;   /* set by the renderer after the dump */
    /* --debug cli: per-turn frame + state files. See debug/turnlog.h — this is the
     * answer to "how does an agent look at a game a person is playing right now",
     * which no combination of the startup dump flags can do. */
    int debug_cli;
    const char *debug_path;   /* --debug-path DIR; NULL until parsed */
    unsigned debug_limit;     /* --debug-limit N: stop after N turns. 0 = unlimited. */
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
    /* Keep site state across a transition: write the outgoing sector's map and creature
     * table back to the content directory when leaving a town, tower or dungeon.
     * OFF by default and enhanced-only, because the original does not do it — measured
     * 2026-10-29 across several town entries and exits, where mapx31, monx31, mapx30 and
     * monx30 all came back byte-identical to pristine and only `player` was written.
     * The save path (Q) is separate and always writes a dirty sector, which asm/2305
     * supports; this knob is only about the transition. Gate: tests/site_state.py. */
    int keep_site_state;
    /* Program-flow signals set by the title flow and read by u2_game_run.
     * `restart_requested` reproduces the original's creation tail, which calls
     * the startup routine (runtime 0x0100) and so re-presents the splash; the
     * loop in game.c is the engine's equivalent of that call.
     * `enter_world` is the enhanced-mode shortcut: creation finishes and drops
     * the player straight into the overworld instead of restarting. */
    int restart_requested;
    int enter_world;
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
    int dev;                 /* --dev: development affordances, off by default.
                              * THE RULE, and it is the reason the flag exists: --dev may add
                              * observation and an exit path, and may NEVER change game
                              * behaviour -- not a damage number, not a spawn, not a message,
                              * not which tile is passable. If something would alter play, it
                              * is a fidelity question and belongs in a decision about that,
                              * not behind this flag.
                              * Deliberately independent of --play-map. Entering the world
                              * directly is not the same as accepting development keys, and
                              * implying one from the other would make every play-map test
                              * silently run under different rules.
                              * Background: cmd_Z used to quit on Escape and the overworld loop
                              * broke on Escape outright. Neither was the original -- nothing
                              * in asm/ compares against 0x1b or 0x11 -- they were dev
                              * conveniences with no sanctioned home, which is what this is. */
    int cleanroom;           /* --cleanroom: use the engine's own independently
                              * created assets instead of the game's — tiles now,
                              * sound and other media as they land. One axis, so a
                              * future asset class is a new consumer of this flag
                              * rather than a new flag.
                              * Opt-in by design: silently drawing substitute art
                              * where the player's own was expected would make the
                              * screen look finished while hiding what is absent —
                              * the failure mode this codebase refuses elsewhere
                              * (see the underlay note in game/overworld.c). Every
                              * consumer must announce the substitution. */
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
