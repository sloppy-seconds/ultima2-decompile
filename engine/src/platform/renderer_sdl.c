/*
 * renderer_sdl.c — SDL2 bitmap backend.
 *
 * Compiled only in the `make sdl` build (-DU2_HAVE_SDL). The default build globs
 * every file under src/platform and must keep working with nothing but a C
 * compiler, so the whole file is empty unless SDL was asked for.
 *
 * This is a presentation shell and nothing more: it uploads the u2_frame the
 * engine already composed and blits it to a window. All rendering semantics —
 * geometry, palette, the do-not-draw rule, clipping — live in core/frame.c, so
 * a backend cannot get the game wrong. That is the point of the split, and it is
 * what makes a hi-res or alternative renderer a *backend* rather than a fork.
 */

#ifdef U2_HAVE_SDL

#include <SDL.h>
#include <stdio.h>
#include <stdlib.h>

#include "core/ctx.h"
#include "core/frame.h"

#define SDL_SCALE 2      /* 320x200 -> 640x400; integer, so pixels stay square */

typedef struct sdl_video {
    SDL_Window   *win;
    SDL_Renderer *ren;
    SDL_Texture  *tex;
    uint32_t     * staging;   /* 320x200 RGBA, filled from the indexed frame */
    Uint32        pal[4];
    unsigned      frames;
} sdl_video;

static sdl_video *sv(u2_ctx *ctx) { return (sdl_video *)ctx->be_render; }

static int sdl_init(u2_ctx *ctx)
{
    sdl_video *v = calloc(1, sizeof *v);
    if (!v) return -1;

    if (SDL_InitSubSystem(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr, "sdl: %s\n", SDL_GetError());
        free(v);
        return -1;
    }

    /* Nearest-neighbour before the renderer exists, so the hint applies. A
     * filtered upscale would smear 2bpp art into mush; crisp blocks are what
     * the original looks like on a real CGA monitor. */
    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "0");

    v->win = SDL_CreateWindow("Ultima II (engine reconstruction)",
                              SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                              U2_SCREEN_W * SDL_SCALE, U2_SCREEN_H * SDL_SCALE,
                              SDL_WINDOW_RESIZABLE);
    if (!v->win) {
        fprintf(stderr, "sdl: window: %s\n", SDL_GetError());
        free(v);
        return -1;
    }
    v->ren = SDL_CreateRenderer(v->win, -1, SDL_RENDERER_ACCELERATED);
    if (!v->ren) v->ren = SDL_CreateRenderer(v->win, -1, SDL_RENDERER_SOFTWARE);
    if (!v->ren) {
        fprintf(stderr, "sdl: renderer: %s\n", SDL_GetError());
        SDL_DestroyWindow(v->win);
        free(v);
        return -1;
    }
    v->tex = SDL_CreateTexture(v->ren, SDL_PIXELFORMAT_RGBA8888,
                               SDL_TEXTUREACCESS_STREAMING,
                               U2_SCREEN_W, U2_SCREEN_H);
    if (!v->tex) {
        fprintf(stderr, "sdl: texture: %s\n", SDL_GetError());
        SDL_DestroyRenderer(v->ren);
        SDL_DestroyWindow(v->win);
        free(v);
        return -1;
    }
    v->staging = malloc(sizeof(uint32_t) * U2_SCREEN_W * U2_SCREEN_H);
    if (!v->staging) {
        SDL_DestroyTexture(v->tex);
        SDL_DestroyRenderer(v->ren);
        SDL_DestroyWindow(v->win);
        free(v);
        return -1;
    }

    uint8_t pal[4][3];
    u2_frame_palette(pal);
    /* SDL_MapRGBA needs a format object; build the same one the texture uses. */
    {
        SDL_PixelFormat *f = SDL_AllocFormat(SDL_PIXELFORMAT_RGBA8888);
        if (!f) {
            free(v->staging); SDL_DestroyTexture(v->tex);
            SDL_DestroyRenderer(v->ren); SDL_DestroyWindow(v->win); free(v);
            return -1;
        }
        for (int i = 0; i < 4; i++)
            v->pal[i] = SDL_MapRGBA(f, pal[i][0], pal[i][1], pal[i][2], 255);
        SDL_FreeFormat(f);
    }

    ctx->be_render = v;
    return 0;
}

static int sdl_present_frame(u2_ctx *ctx, const struct u2_frame *f)
{
    sdl_video *v = sv(ctx);
    const u2_frame *fr = (const u2_frame *)f;
    if (!v || !fr) return 0;

    for (int y = 0; y < U2_SCREEN_H; y++) {
        const uint8_t *src = fr->px[y];
        uint32_t *dst = v->staging + (size_t)y * U2_SCREEN_W;
        for (int x = 0; x < U2_SCREEN_W; x++) dst[x] = v->pal[src[x] & 3];
    }

    SDL_UpdateTexture(v->tex, NULL, v->staging, U2_SCREEN_W * (int)sizeof(uint32_t));
    SDL_RenderClear(v->ren);
    SDL_RenderCopy(v->ren, v->tex, NULL, NULL);
    SDL_RenderPresent(v->ren);
    v->frames++;
    return 0;
}

static void sdl_cell(u2_ctx *ctx, int row, int col, uint8_t ch, uint8_t attr)
{
    /* The bitmap backend has no text grid. The original draws its text as tiles,
     * so this is not a gap in the model — it is a reminder that the cell path is
     * the approximation, and it stays silent rather than faking a glyph. */
    (void)ctx; (void)row; (void)col; (void)ch; (void)attr;
}

static void sdl_cursor(u2_ctx *ctx, int row, int col, int visible)
{
    (void)ctx; (void)row; (void)col; (void)visible;
}

static void sdl_flush(u2_ctx *ctx) { (void)ctx; }

static void sdl_shutdown(u2_ctx *ctx)
{
    sdl_video *v = sv(ctx);
    if (!v) return;
    SDL_DestroyTexture(v->tex);
    SDL_DestroyRenderer(v->ren);
    SDL_DestroyWindow(v->win);
    free(v->staging);
    free(v);
    ctx->be_render = NULL;
    SDL_QuitSubSystem(SDL_INIT_VIDEO);
}

const u2_renderer u2_renderer_sdl = {
    .name = "sdl",
    .init = sdl_init,
    .cell = sdl_cell,
    .cursor = sdl_cursor,
    .flush = sdl_flush,
    .shutdown = sdl_shutdown,
    .present_frame = sdl_present_frame,
};

#endif /* U2_HAVE_SDL */
