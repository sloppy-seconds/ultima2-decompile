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

#include <SDL3/SDL.h>
#include <stdio.h>
#include <stdlib.h>

#include "core/ctx.h"
#include "core/font.h"
#include "core/frame.h"
#include "core/scale.h"

#define SDL_SCALE 2      /* default window size: 320x200 -> 640x400. Only the
                          * starting size; the player can resize and the frame
                          * refits by integer scale from then on. */

typedef struct sdl_video {
    SDL_Window   *win;
    SDL_Renderer *ren;
    SDL_Texture  *tex;
    uint32_t     * staging;   /* 320x200 RGBA, filled from the indexed frame */
    Uint32        pal[4];
    unsigned      frames;
    const struct u2_frame *last;  /* last frame uploaded, so a window resize can
                                   * repaint without the game drawing a new one */
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

/* One driver name per line, for --video-drivers. Does not initialise video, so it
 * works on a machine with no display at all — which is exactly where the release
 * gate needs to run it. */int u2_sdl_list_video_drivers(void)
{
    const int n = SDL_GetNumVideoDrivers();
    for (int i = 0; i < n; i++)
        printf("%s\n", SDL_GetVideoDriver(i));
    return n;
}

/* The version of the SDL actually linked, asked at runtime rather than stamped at
 * compile time, because the two can disagree: sdl2-compat reports an SDL2 version
 * number while being SDL3 underneath, and that gap is the thing
 * docs/sdl2-vs-sdl3.md is about. No SDL_Init here, so it is safe to call before
 * any subsystem exists. */
void u2_sdl_runtime_info(char *out, size_t n)
{
    if (!out || n == 0) return;
    out[0] = '\0';
    /* SDL3 returns one packed integer instead of filling a struct. The packing is
     * major*1e6 + minor*1e3 + patch, so 3004018 is 3.4.18; decoding it by hand
     * rather than with SDL_VERSIONNUM keeps this readable without pulling in the
     * version header's macro name. */
    const int v = SDL_GetVersion();
    snprintf(out, n, "%d.%d.%d", v / 1000000, (v / 1000) % 1000, v % 1000);
}

/* Why a window could not be created is usually a one-word answer ("No available
 * video device" means this binary has no display backend compiled in), and SDL
 * does not say which backends it does have. Printing the list turns "nothing
 * appeared" into something a player can act on, and it is the same line the
 * release gate greps. */
static void sdl_note_available_drivers(void)
{
    const int n = SDL_GetNumVideoDrivers();
    const char *hint = getenv("SDL_VIDEODRIVER");

    fprintf(stderr, "u2: video drivers in this binary (%d):", n);
    for (int i = 0; i < n; i++)
        fprintf(stderr, " %s", SDL_GetVideoDriver(i));
    fputc('\n', stderr);
    fprintf(stderr, "u2: SDL_VIDEODRIVER=%s\n", hint && *hint ? hint : "(unset)");
    if (n <= 2)
        fprintf(stderr, "u2: no display backend was compiled in — this binary was built"
                        " from an SDL3 configured without X11 or Wayland dev packages."
                        " It can only render headlessly.\n");
}

static int sdl_init(u2_ctx *ctx)
{
    sdl_video *v = calloc(1, sizeof *v);
    if (!v) return -1;

    /* SDL3 returns bool, where SDL2 returned 0 for success. Inverting the test
     * rather than the call is the whole change, but it is the kind of change that
     * compiles either way and silently inverts the meaning: `!= 0` on a bool would
     * have made every successful init look like a failure and every failed one
     * look fine. */
    if (!SDL_InitSubSystem(SDL_INIT_VIDEO)) {
        fprintf(stderr, "sdl: %s\n", SDL_GetError());
        free(v);
        return -1;
    }

    /* SDL3 dropped SDL_HINT_RENDER_SCALE_QUALITY and made the default LINEAR
     * filtering, so nearest-neighbour is now per-texture and must be asked for
     * explicitly after the texture exists. This is the one change on this list
     * that fails silently and beautifully: a bilinear upscale of 2bpp CGA still
     * draws, it just smears every pixel into a gradient, and a screenshot taken
     * in a hurry looks like a plausible retro blur rather than a bug. */
    v->win = SDL_CreateWindow("Ultima II (engine reconstruction)",
                              U2_SCREEN_W * SDL_SCALE, U2_SCREEN_H * SDL_SCALE,
                              SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY);
    if (!v->win) {
        fprintf(stderr, "sdl: window: %s\n", SDL_GetError());
        sdl_note_available_drivers();
        free(v);
        return -1;
    }
    fprintf(stderr, "u2: video: %s\n",
            SDL_GetCurrentVideoDriver() ? SDL_GetCurrentVideoDriver() : "(unknown)");

    /* SDL3 dropped the renderer flags: NULL means "you choose", which is what the
     * accelerated-then-software ladder used to spell out. The fallback is kept
     * because a machine with a broken GPU driver is exactly where a reconstruction
     * project still wants to run, and SDL_SOFTWARE_RENDERER is now the name rather
     * than a flag. */
    v->ren = SDL_CreateRenderer(v->win, NULL);
    if (!v->ren) v->ren = SDL_CreateRenderer(v->win, SDL_SOFTWARE_RENDERER);
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
    if (!SDL_SetTextureScaleMode(v->tex, SDL_SCALEMODE_NEAREST))
        fprintf(stderr, "u2: WARNING: nearest-neighbour scaling refused (%s);"
                        " 2bpp art will be smeared\n", SDL_GetError());
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
    /* SDL3 replaced SDL_AllocFormat with a read-only details struct, and MapRGBA
     * now takes that plus an explicit palette (NULL: RGBA8888 has none). The
     * details pointer is owned by SDL and must not be freed. */
    {
        const SDL_PixelFormatDetails *f = SDL_GetPixelFormatDetails(SDL_PIXELFORMAT_RGBA8888);
        if (!f) {
            free(v->staging); SDL_DestroyTexture(v->tex);
            SDL_DestroyRenderer(v->ren); SDL_DestroyWindow(v->win); free(v);
            return -1;
        }
        for (int i = 0; i < 4; i++)
            v->pal[i] = SDL_MapRGBA(f, NULL, pal[i][0], pal[i][1], pal[i][2], 255);
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

    /* Destination is computed, not NULL. NULL means "fill the output rect", which
     * does scale, but it stretches 320x200 to whatever aspect the window happens
     * to be and makes source pixels rectangular. The fit is integer and centred,
     * so blocks stay square and the remainder becomes letterbox bars. Queried every
     * frame rather than cached from a resize event, because the drawable size is
     * also what changes under a HiDPI scale factor with no resize at all. */
    int ow = 0, oh = 0;
    /* Renamed in SDL3, and it returns bool: a failure here leaves ow/oh at zero,
     * the fit comes back empty, and the frame is cleared to black. Checked rather
     * than ignored, because "the window went black" is otherwise undiagnosable. */
    if (!SDL_GetRenderOutputSize(v->ren, &ow, &oh)) {
        fprintf(stderr, "u2: render output size: %s\n", SDL_GetError());
        return;
    }
    u2_fit fit = u2_fit_integer(ow, oh, U2_SCREEN_W, U2_SCREEN_H);

    if (!SDL_UpdateTexture(v->tex, NULL, v->staging, U2_SCREEN_W * (int)sizeof(uint32_t))) {
        fprintf(stderr, "u2: texture upload failed: %s\n", SDL_GetError());
        return;
    }
    (void)SDL_RenderClear(v->ren);
    if (fit.w > 0 && fit.h > 0) {
        /* SDL_RenderCopy is SDL_RenderTexture in SDL3, and its rectangles are
         * floats. The fit is computed in integers in core/scale.c and widened here
         * rather than the other way round: the integer arithmetic is what the gate
         * in tests/scale_check.c can assert on, and an exact int -> float widening
         * of these magnitudes loses nothing. */
        const SDL_FRect dst_f = { (float)fit.x, (float)fit.y,
                                  (float)fit.w, (float)fit.h };
        (void)SDL_RenderTexture(v->ren, v->tex, NULL, &dst_f);
    }
    (void)SDL_RenderPresent(v->ren);
    v->frames++;
    v->last = fr;

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

/* Re-present the last frame. The window was resized and nothing else will paint
 * it: the game presents when it has something new to say, and a resize is not
 * something the game says. Called from the input backend's event pump, which is
 * the only place SDL_WINDOWEVENT is seen. No-op before the first frame exists. */
void u2_sdl_repaint(u2_ctx *ctx)
{
    sdl_video *v = ctx ? sv(ctx) : NULL;
    if (v && v->last) sdl_upload(ctx, v->last);
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
