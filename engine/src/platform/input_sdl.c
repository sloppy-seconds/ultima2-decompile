/*
 * input_sdl.c — SDL2 keyboard backend.
 *
 * SDL gives real scancodes, which matters here: the original translates the
 * arrow keys through a scancode table at CS:0x4F09 (file 0x5109) rather than
 * ASCII, so the engine carries the same scancodes instead of inventing a
 * mapping. The values below are the ones that table produces.
 */

#ifdef U2_HAVE_SDL

#include <SDL.h>
#include <signal.h>     /* mingw provides this (sig_atomic_t, signal()); what it
                         * lacks is sigaction, guarded below. */

#include "core/ctx.h"

/* From the scancode table proven in docs/phase4-implementation.md § CP4. */
#define SCAN_UP    0x48
#define SCAN_DOWN  0x50
#define SCAN_LEFT  0x4B
#define SCAN_RIGHT 0x4D

/*
 * Termination signals, handled by us rather than by SDL.
 *
 * Measured on this host (T4, 2026-10-20): a `u2-sdl` process sat through
 * SIGTERM and SIGINT until SIGKILL, and /proc/<pid>/status showed both bits
 * in SigIgn (mask 0x6), not SigCgt — the signals were ignored outright, so
 * nothing could drain them. The library doing the ignoring is
 * `sdl2-compat` (the Fedora build maps SDL2 onto SDL3), and two things fell
 * out of testing it:
 *
 *   * `SDL_HINT_NO_SIGNAL_HANDLERS` is a no-op here — the string is not even
 *     present in /usr/lib64/libSDL2-2.0.so.0, so the hint cannot be honoured.
 *   * a handler installed before `main()` loses: SDL's own disposition is
 *     still applied during init (SIGINT became catchable, SIGTERM stayed
 *     ignored). The fix therefore installs ours *after* SDL has initialised,
 *     from the first `sdl_poll`, which is guaranteed to run after every
 *     backend's `init` (main.c: renderer, input, audio all init first).
 *
 * The handler itself does exactly one async-signal-safe thing: set a flag.
 * `sdl_poll` reads the flag on every pump, so a polite `kill` or
 * `timeout -s TERM` now ends the run the same way closing the window does.
 */
static volatile sig_atomic_t g_term_signal;

#ifdef _WIN32
/* sigaction has no mingw equivalent, and console Ctrl+C on Windows terminates
 * the process outright, which is the same observable end. The flag stays so
 * sdl_poll's check compiles unchanged; nothing sets it here. */
static void install_term_handlers(void) { }
#else
static void term_handler(int sig) { (void)sig; g_term_signal = 1; }

static void install_term_handlers(void)
{
    struct sigaction sa;
    sa.sa_handler = term_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;                 /* no SA_RESTART: let blocking calls fail */
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT,  &sa, NULL);
}
#endif

static int sdl_poll(u2_ctx *ctx, u2_key *out)
{
    SDL_Event e;
    /* --dump-screen is a one-shot proof run: once the renderer has written
     * the frame, the display is finished, which the flow reads as "the
     * player left". Without a display this is the only exit, and with one
     * it makes the flag terminate the run the same way. */
    if (ctx && ctx->dump_screen_done) return -1;
    /* Re-asserted on every pump, not once: sdl2-compat re-applies its own
     * SIGTERM disposition while windows and devices are created, so a
     * one-shot install (before main, or on the first poll) is quietly
     * overwritten — measured 2026-10-20, the handler was in place right
     * after install and gone again a second later, with the bit showing up
     * in SigIgn. sigaction is a cheap syscall next to the event pump beside
     * it, and this is the only placement that survives. */
    install_term_handlers();
    if (g_term_signal) {              /* SIGTERM/SIGINT: our handler set this */
        /* Non-zero on purpose: every wait loop in the game tests
         * `if (ctx->exit_code)`, and 0 reads as "no exit requested". */
        if (ctx) ctx->exit_code = 1;
        return -1;
    }
    while (SDL_PollEvent(&e)) {
        if (e.type == SDL_QUIT) {
            if (ctx) ctx->exit_code = 1;
            return -1;
        }
        /* Kept as a belt-and-braces path: with SDL_HINT_NO_SIGNAL_HANDLERS set
         * above we own SIGTERM/SIGINT ourselves, but if the hint is ever
         * overridden this is how the event would arrive. */
        if (e.type == SDL_APP_TERMINATING) {
            if (ctx) ctx->exit_code = 0;
            return -1;
        }
        /* A resize is the one event that changes what is on screen without the
         * game having anything new to draw, and the game only presents when it
         * does. Without this the window keeps the old frame until the next
         * keypress, which is what made the picture look like it ignored the
         * window. SIZE_CHANGED rather than RESIZED: it also covers the drawable
         * changing under a HiDPI scale factor, where no resize was requested. */
        if (e.type == SDL_WINDOWEVENT &&
            e.window.event == SDL_WINDOWEVENT_SIZE_CHANGED) {
            u2_sdl_repaint(ctx);
            continue;
        }
        if (e.type != SDL_KEYDOWN) continue;

        switch (e.key.keysym.sym) {
        case SDLK_UP:     out->ch = U2_KEY_UP;    out->scan = SCAN_UP;    return 1;
        case SDLK_DOWN:   out->ch = U2_KEY_DOWN;  out->scan = SCAN_DOWN;  return 1;
        case SDLK_LEFT:   out->ch = U2_KEY_LEFT;  out->scan = SCAN_LEFT;  return 1;
        case SDLK_RIGHT:  out->ch = U2_KEY_RIGHT; out->scan = SCAN_RIGHT; return 1;
        case SDLK_ESCAPE: out->ch = 0x1B;         out->scan = 0x01;       return 1;
        case SDLK_RETURN: out->ch = 0x0D;         out->scan = 0x1C;       return 1;
        case SDLK_SPACE:  out->ch = ' ';          out->scan = 0x39;       return 1;
        default:
            /* Printable ASCII arrives with its character, as INT 16h would
             * have handed it over in AL. */
            if (e.key.keysym.sym >= 32 && e.key.keysym.sym < 127) {
                out->ch  = (uint8_t)e.key.keysym.sym;
                out->scan = (uint8_t)e.key.keysym.scancode;
                return 1;
            }
            break;
        }
    }
    return 0;
}

static int sdl_wait(u2_ctx *ctx, u2_key *out)
{
    for (;;) {
        int r = sdl_poll(ctx, out);
        if (r != 0) return r;
        SDL_Delay(10);      /* poll cadence, not a busy spin */
    }
}

static int sdl_init(u2_ctx *ctx) { (void)ctx; return SDL_InitSubSystem(SDL_INIT_VIDEO); }
static void sdl_shutdown(u2_ctx *ctx) { (void)ctx; }

const u2_input u2_input_sdl = {
    .name = "sdl",
    .init = sdl_init,
    .poll = sdl_poll,
    .wait = sdl_wait,
    .shutdown = sdl_shutdown,
};

#endif /* U2_HAVE_SDL */
