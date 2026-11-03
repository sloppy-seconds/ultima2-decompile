/*
 * frame.c — the framebuffer and the tile blit.
 *
 * Dependency-free by design. Everything a display backend needs to be thin is
 * decided here: geometry, the palette mapping, clipping, and the do-not-draw
 * rule from asm/4ABB. A backend that only moves bytes cannot get the game's
 * rendering semantics wrong, which is the point of the split.
 */

#include <stdio.h>
#include <string.h>

#include "core/frame.h"

void u2_frame_palette(uint8_t out[4][3])
{
    /* CGA's four mode-4 colours. High intensity is used for cyan and magenta
     * because that is what the composite output reads as on a modern display;
     * a backend wanting the true 0xAA values can build its own table, which is
     * exactly why the core carries indices and not RGB. */
    static const uint8_t pal[4][3] = {
        {   0,   0,   0 },   /* 0 black   */
        {   0, 170, 170 },   /* 1 cyan    */
        { 170,   0, 170 },   /* 2 magenta */
        { 255, 255, 255 }    /* 3 white   */
    };
    memcpy(out, pal, sizeof pal);
}

void u2_frame_palette_ega(uint8_t out[16][3])
{
    /* The standard EGA palette. These are the 0xAA-scaled RGB values the EGA
     * adapter drives (the six levels are 0x00/0xAA/0xFF), which is what the fan
     * pack's EGA art was authored to look right on. The first four entries are
     * deliberately NOT the CGA table's values: EGA's index 1 is blue and 2 is
     * red, where CGA mode 4 uses cyan and magenta. A CGA frame rendered through
     * this table would show blue grass and red walls, which is why the art mode
     * picks the table and the two are never mixed (docs/ega-graphics-plan.md § 4). */
    static const uint8_t pal[16][3] = {
        {   0,   0,   0 },   /*  0 black        */
        {   0,   0, 170 },   /*  1 blue         */
        {   0, 170,   0 },   /*  2 green        */
        {   0, 170, 170 },   /*  3 cyan         */
        { 170,   0,   0 },   /*  4 red          */
        { 170,   0, 170 },   /*  5 magenta      */
        { 170,  85,   0 },   /*  6 brown        */
        { 170, 170, 170 },   /*  7 light grey   */
        {  85,  85,  85 },   /*  8 grey         */
        {  85,  85, 255 },   /*  9 light blue   */
        {  85, 255,   0 },   /* 10 light green  */
        {  85, 255, 255 },   /* 11 light cyan   */
        { 255,  85,  85 },   /* 12 light red    */
        { 255,  85, 255 },   /* 13 light magenta*/
        { 255, 255,  85 },   /* 14 yellow       */
        { 255, 255, 255 }    /* 15 white        */
    };
    memcpy(out, pal, sizeof pal);
}

void u2_frame_clear(u2_frame *f, uint8_t colour)
{
    if (!f) return;
    const uint8_t c = (uint8_t)(colour & 3);
    for (int y = 0; y < U2_SCREEN_H; y++)
        memset(f->px[y], c, U2_SCREEN_W);
    f->presents = 0;
}

void u2_frame_blit_tile(u2_frame *f, const u2_tiles *t, int tile, int x, int y)
{
    if (!f || !t) return;
    if (tile < 0 || tile >= U2_TILE_COUNT) return;

    for (int row = 0; row < U2_TILE_H; row++) {
        const int dy = y + row;
        if (dy < 0 || dy >= U2_SCREEN_H) continue;         /* clipped */
        const uint8_t *src = t->px[tile] + row * U2_TILE_STRIDE;
        for (int col = 0; col < U2_TILE_W; col++) {
            const int dx = x + col;
            if (dx < 0 || dx >= U2_SCREEN_W) continue;     /* clipped */
            const uint8_t b = src[col >> 2];
            f->px[dy][dx] = (uint8_t)((b >> (6 - 2 * (col & 3))) & 3);
        }
    }
}

void u2_frame_blit_tile_ega(u2_frame *f, const u2_tiles_ega *t, int tile, int x, int y)
{
    if (!f || !t) return;
    if (tile < 0 || tile >= U2_TILE_COUNT) return;

    for (int row = 0; row < U2_TILE_H; row++) {
        const int dy = y + row;
        if (dy < 0 || dy >= U2_SCREEN_H) continue;         /* clipped */
        const uint8_t *src = t->px[tile] + row * U2_TILE_EGA_STRIDE;
        for (int col = 0; col < U2_TILE_W; col++) {
            const int dx = x + col;
            if (dx < 0 || dx >= U2_SCREEN_W) continue;     /* clipped */
            const uint8_t b = src[col >> 1];
            f->px[dy][dx] = (uint8_t)((col & 1) ? (b & 0xF) : (b >> 4));
        }
    }
}

void u2_frame_pixel(u2_frame *f, int x, int y, uint8_t colour)
{
    if (!f) return;
    if (x < 0 || x >= U2_SCREEN_W || y < 0 || y >= U2_SCREEN_H) return;
    f->px[y][x] = (uint8_t)(colour & 3);
}

void u2_frame_line(u2_frame *f, int x0, int y0, int x1, int y1, uint8_t colour)
{
    if (!f) return;
    int dx = x1 - x0, dy = y1 - y0;
    if (dx < 0) dx = -dx;
    if (dy < 0) dy = -dy;
    const int sx = x1 > x0 ? 1 : -1;
    const int sy = y1 > y0 ? 1 : -1;

    /* Same branch test as asm/67B3's `cmp 0x484,%al ; jae`: whichever delta is
     * not the major axis carries the error term. */
    int err;
    if (dx >= dy) {
        err = -dx;
        for (int x = x0, y = y0;; x += sx) {
            u2_frame_pixel(f, x, y, colour);
            if (x == x1) break;
            err += 2 * dy;
            if (err >= 0) { y += sy; err -= 2 * dx; }
        }
    } else {
        err = -dy;
        for (int x = x0, y = y0;; y += sy) {
            u2_frame_pixel(f, x, y, colour);
            if (y == y1) break;
            err += 2 * dx;
            if (err >= 0) { x += sx; err -= 2 * dy; }
        }
    }
}

void u2_frame_draw_view(u2_frame *f, const u2_view *v, const u2_tiles *t,
                        int overlay_tile, int overlay_col, int overlay_row)
{
    if (!f || !v || !t) return;

    for (int row = 0; row < U2_VIEW_ROWS; row++) {
        for (int col = 0; col < U2_VIEW_COLS; col++) {
            /* asm/4ABB: `or cl,cl; js skip`. A suppressed cell keeps whatever
             * was already in the frame, which is why the caller clears first.
             * The staging byte halves to reach the art record — see
             * u2_view_art(); skipping that step doubles every tile index. */
            const int staging = u2_view_at(v, col, row);
            if (staging < 0) continue;
            u2_frame_blit_tile(f, t, u2_view_art(staging),
                               col * U2_TILE_W, row * U2_TILE_H);
        }
    }

    if (overlay_tile >= 0 && overlay_col >= 0 && overlay_row >= 0 &&
        overlay_col < U2_VIEW_COLS && overlay_row < U2_VIEW_ROWS) {
        u2_frame_blit_tile(f, t, overlay_tile,
                           overlay_col * U2_TILE_W, overlay_row * U2_TILE_H);
    }
    f->presents++;
}

void u2_frame_draw_view_ega(u2_frame *f, const u2_view *v, const u2_tiles_ega *t,
                            int overlay_tile, int overlay_col, int overlay_row)
{
    if (!f || !v || !t) return;

    for (int row = 0; row < U2_VIEW_ROWS; row++) {
        for (int col = 0; col < U2_VIEW_COLS; col++) {
            /* Same staging->art mapping as the CGA composite (see above); only
             * the atlas and the blit differ, so the two paths cannot drift on
             * which tile a cell selects. */
            const int staging = u2_view_at(v, col, row);
            if (staging < 0) continue;
            u2_frame_blit_tile_ega(f, t, u2_view_art(staging),
                                   col * U2_TILE_W, row * U2_TILE_H);
        }
    }

    if (overlay_tile >= 0 && overlay_col >= 0 && overlay_row >= 0 &&
        overlay_col < U2_VIEW_COLS && overlay_row < U2_VIEW_ROWS) {
        u2_frame_blit_tile_ega(f, t, overlay_tile,
                               overlay_col * U2_TILE_W, overlay_row * U2_TILE_H);
    }
    f->presents++;
}

/* Big-endian-ish 16/32-bit writers for the two container formats. */
static void put16le(FILE *f, unsigned v)
{
    fputc((int)(v & 0xff), f);
    fputc((int)((v >> 8) & 0xff), f);
}

static void put32le(FILE *f, unsigned long v)
{
    fputc((int)(v & 0xff), f);
    fputc((int)((v >> 8) & 0xff), f);
    fputc((int)((v >> 16) & 0xff), f);
    fputc((int)((v >> 24) & 0xff), f);
}

int u2_frame_write_ppm(const u2_frame *f, const char *path,
                       const uint8_t pal[4][3])
{
    if (!f || !path || !pal) return -1;
    FILE *fp = fopen(path, "wb");
    if (!fp) return -1;

    fprintf(fp, "P6\n%d %d\n255\n", U2_SCREEN_W, U2_SCREEN_H);
    for (int y = 0; y < U2_SCREEN_H; y++) {
        for (int x = 0; x < U2_SCREEN_W; x++) {
            const uint8_t *rgb = pal[f->px[y][x] & 3];
            fputc(rgb[0], fp); fputc(rgb[1], fp); fputc(rgb[2], fp);
        }
    }
    const int err = ferror(fp);
    if (fclose(fp) != 0 || err) return -1;
    return 0;
}

int u2_frame_write_ppm16(const u2_frame *f, const char *path,
                         const uint8_t pal[16][3])
{
    if (!f || !path || !pal) return -1;
    FILE *fp = fopen(path, "wb");
    if (!fp) return -1;

    fprintf(fp, "P6\n%d %d\n255\n", U2_SCREEN_W, U2_SCREEN_H);
    for (int y = 0; y < U2_SCREEN_H; y++) {
        for (int x = 0; x < U2_SCREEN_W; x++) {
            const uint8_t *rgb = pal[f->px[y][x] & 15];
            fputc(rgb[0], fp); fputc(rgb[1], fp); fputc(rgb[2], fp);
        }
    }
    const int err = ferror(fp);
    if (fclose(fp) != 0 || err) return -1;
    return 0;
}

int u2_frame_write_bmp(const u2_frame *f, const char *path,
                       const uint8_t pal[4][3])
{
    if (!f || !path || !pal) return -1;

    const unsigned row_bytes = U2_SCREEN_W * 3;      /* 960, already padded */
    const unsigned pixels = row_bytes * U2_SCREEN_H;
    FILE *fp = fopen(path, "wb");
    if (!fp) return -1;

    fputc('B', fp); fputc('M', fp);
    put32le(fp, 14 + 40 + pixels);
    put32le(fp, 0);
    put32le(fp, 14 + 40);
    put32le(fp, 40);
    put32le(fp, U2_SCREEN_W);
    put32le(fp, U2_SCREEN_H);
    put16le(fp, 1);
    put16le(fp, 24);
    put32le(fp, 0);                 /* BI_RGB, uncompressed */
    put32le(fp, pixels);
    put32le(fp, 2835);              /* 72 dpi */
    put32le(fp, 2835);
    put32le(fp, 0);
    put32le(fp, 0);

    for (int y = U2_SCREEN_H - 1; y >= 0; y--) {      /* BMP is bottom-up */
        for (int x = 0; x < U2_SCREEN_W; x++) {
            const uint8_t *rgb = pal[f->px[y][x] & 3];
            fputc(rgb[2], fp); fputc(rgb[1], fp); fputc(rgb[0], fp);  /* BGR */
        }
    }
    const int err = ferror(fp);
    if (fclose(fp) != 0 || err) return -1;
    return 0;
}

int u2_frame_write_bmp16(const u2_frame *f, const char *path,
                         const uint8_t pal[16][3])
{
    if (!f || !path || !pal) return -1;

    const unsigned row_bytes = U2_SCREEN_W * 3;      /* 960, already padded */
    const unsigned pixels = row_bytes * U2_SCREEN_H;
    FILE *fp = fopen(path, "wb");
    if (!fp) return -1;

    fputc('B', fp); fputc('M', fp);
    put32le(fp, 14 + 40 + pixels);
    put32le(fp, 0);
    put32le(fp, 14 + 40);
    put32le(fp, 40);
    put32le(fp, U2_SCREEN_W);
    put32le(fp, U2_SCREEN_H);
    put16le(fp, 1);
    put16le(fp, 24);
    put32le(fp, 0);                 /* BI_RGB, uncompressed */
    put32le(fp, pixels);
    put32le(fp, 2835);              /* 72 dpi */
    put32le(fp, 2835);
    put32le(fp, 0);
    put32le(fp, 0);

    for (int y = U2_SCREEN_H - 1; y >= 0; y--) {      /* BMP is bottom-up */
        for (int x = 0; x < U2_SCREEN_W; x++) {
            const uint8_t *rgb = pal[f->px[y][x] & 15];
            fputc(rgb[2], fp); fputc(rgb[1], fp); fputc(rgb[0], fp);  /* BGR */
        }
    }
    const int err = ferror(fp);
    if (fclose(fp) != 0 || err) return -1;
    return 0;
}
