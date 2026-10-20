/*
 * renderer_sdl.c — SDL2 bitmap backend.
 *
 * Compiled only in the `make sdl` build (-DU2_HAVE_SDL). The default build globs
 * every file under src/platform and must keep working with nothing but a C
 * compiler, so the whole file is empty unless SDL was asked for.
 *
 * This is a presentation shell and nothing more: it uploads the u2_frame the
 * engine already composed, and for cell-only flows (title, menu, creation)
 * renders the vram grid through core/font into its own text layer. All
 * rendering semantics — geometry, palette, the do-not-draw rule, clipping —
 * live in core/frame.c and core/font.c, so a backend cannot get the game
 * wrong. That is the point of the split, and it is what makes a hi-res or
 * alternative renderer a *backend* rather than a fork.
 */

#ifdef U2_HAVE_SDL

#include <SDL.h>
#include <stdio.h>
#include <stdlib.h>

#include "core/ctx.h"
#include "core/font.h"
#include "core/frame.h"

#define SDL_SCALE 2      /* 320x200 -> 640x400; integer, so pixels stay square */

typedef struct sdl_video {
    SDL_Window   *win;
    SDL_Renderer *ren;
    SDL_Texture  *tex;
    uint32_t     * staging;   /* 320x200 RGBA, filled from the indexed frame */
    Uint32        pal[4];
    unsigned      frames;
    /* Text layer for the cell-only screens (title, menu, creation). The
     * overworld composites its own text rows into the game frame, so this
     * one belongs to the renderer and only serves flows that draw through
     * renderer->cell. The grid copy exists so the cursor can be painted
     * inverse at flush time and cleanly restored when it moves. */
    u2_frame      text;
    uint8_t       grid[U2_ROWS][U2_COLS];
    int           cur_row, cur_col, cur_vis;
    int           dumped;     /* --dump-screen already written */
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
    u2_frame_clear(&v->text, U2_CGA_BLACK);
    for (int r = 0; r < U2_ROWS; r++)
        for (int c = 0; c < U2_COLS; c++)
            v->grid[r][c] = ' ';
    return 0;
}

/* Upload one composed frame and present it. Shared by the game-frame path
 * (present_frame) and the text-layer path (flush), so both screens show the
 * same palette and the same scaling and neither can drift from the other. */
static void sdl_upload(u2_ctx *ctx, const struct u2_frame *f)
{
    sdl_video *v = sv(ctx);
    const u2_frame *fr = (const u2_frame *)f;
    if (!v || !fr) return;

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

    /* --dump-screen: the frame that was just presented is the window's
     * content, so writing it out proves the cell->font->upload path without
     * a display (SDL_VIDEODRIVER=dummy). The input backend ends the run once
     * this flag is set. */
    if (ctx->dump_screen && !v->dumped) {
        uint8_t pal[4][3];
        u2_frame_palette(pal);
        if (u2_frame_write_ppm(fr, ctx->dump_screen, pal) == 0)
            ctx->dump_screen_done = 1;
        v->dumped = 1;
    }
}

static int sdl_present_frame(u2_ctx *ctx, const struct u2_frame *f)
{
    sdl_upload(ctx, f);
    return 0;
}

static void sdl_cell(u2_ctx *ctx, int row, int col, uint8_t ch, uint8_t attr)
{
    sdl_video *v = sv(ctx);
    (void)attr;   /* mode-4 text colour is white-on-black everywhere the
                   * engine prints; real attribute mapping is CP9 work. */
    if (!v || row < 0 || row >= U2_ROWS || col < 0 || col >= U2_COLS) return;
    v->grid[row][col] = ch;
    u2_font_draw_cell(&v->text, row, col, ch, U2_CGA_WHITE, U2_CGA_BLACK);
}

static void sdl_cursor(u2_ctx *ctx, int row, int col, int visible)
{
    sdl_video *v = sv(ctx);
    if (!v) return;
    v->cur_row = row; v->cur_col = col; v->cur_vis = visible;
}

static void sdl_flush(u2_ctx *ctx)
{
    sdl_video *v = sv(ctx);
    if (!v) return;
    /* The grid is the truth; the cursor is painted on top of it, inverse
     * video, and the previous cell is restored first so a moving cursor
     * cannot leave a stale block behind. */
    const uint8_t ch = v->grid[v->cur_row][v->cur_col];
    u2_font_draw_cell(&v->text, v->cur_row, v->cur_col, ch,
                      U2_CGA_WHITE, U2_CGA_BLACK);
    if (v->cur_vis)
        u2_font_draw_cell(&v->text, v->cur_row, v->cur_col, ch,
                          U2_CGA_BLACK, U2_CGA_WHITE);
    sdl_upload(ctx, &v->text);
}

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
