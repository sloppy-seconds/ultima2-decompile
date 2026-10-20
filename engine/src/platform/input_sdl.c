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
#include <stdlib.h>

#include "core/ctx.h"

/* From the scancode table proven in docs/phase4-implementation.md § CP4. */
#define SCAN_UP    0x48
#define SCAN_DOWN  0x50
#define SCAN_LEFT  0x4B
#define SCAN_RIGHT 0x4D

static int sdl_poll(u2_ctx *ctx, u2_key *out)
{
    SDL_Event e;
    /* --dump-screen is a one-shot proof run: once the renderer has written
     * the frame, the display is finished, which the flow reads as "the
     * player left". Without a display this is the only exit, and with one
     * it makes the flag terminate the run the same way. */
    if (ctx && ctx->dump_screen_done) return -1;
    while (SDL_PollEvent(&e)) {
        if (e.type == SDL_QUIT) {
            if (ctx) ctx->exit_code = 1;
            return -1;
        }
        /* SDL2 turns SIGTERM and friends into this event rather than dying, so a
         * backend that only watches SDL_QUIT will ignore `timeout`, a systemd
         * stop, and anything else that asks politely. Observed directly: the
         * process sat through SIGTERM until SIGKILL. */
        if (e.type == SDL_APP_TERMINATING) {
            if (ctx) ctx->exit_code = 0;
            return -1;
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
