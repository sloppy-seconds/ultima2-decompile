/*
 * font_check.c — CP4b: the engine font must put the right pixels where the
 * framebuffer contract says they go.
 *
 * The font is the display path for every string the engine draws itself
 * (status band, menu, creation). A glyph bug here is invisible in the terminal
 * build and shows up as unreadable text only in the window, so the checks are
 * pixel-exact, not "did it not crash".
 */
#include <stdio.h>
#include <string.h>

#include "core/font.h"

static int fails;
static void ok(int cond, const char *what)
{
    printf("  %s  %s\n", cond ? "ok  " : "FAIL", what);
    if (!cond) fails++;
}

static int ink_in_cell(const u2_frame *f, int row, int col, uint8_t colour)
{
    int n = 0;
    for (int y = 0; y < U2_FONT_CELL_H; y++)
        for (int x = 0; x < U2_FONT_CELL_W; x++)
            if (f->px[row * U2_FONT_CELL_H + y][col * U2_FONT_CELL_W + x] == colour) n++;
    return n;
}

int main(void)
{
    u2_frame f;
    u2_frame_init(&f, 1);   /* heap-backed store; see frame_check.c */

    /* The grid must tile the screen exactly: 40x25 cells of 8x8 = 320x200. */
    ok(U2_SCREEN_W / U2_FONT_CELL_W == 40 && U2_SCREEN_H / U2_FONT_CELL_H == 25,
       "font grid is 40x25 on a 320x200 frame");

    /* Space: every pixel is the background colour, none the foreground. */
    u2_frame_clear(&f, U2_CGA_BLACK);
    u2_font_draw_cell(&f, 3, 4, ' ', U2_CGA_WHITE, U2_CGA_BLACK);
    ok(ink_in_cell(&f, 3, 4, U2_CGA_WHITE) == 0 &&
       ink_in_cell(&f, 3, 4, U2_CGA_BLACK) == 64, "space draws all background");

    /* 'A' (font8x8 row 0 = 0x0C): bits 2 and 3 set -> pixels x=2,3 lit. */
    u2_frame_clear(&f, U2_CGA_BLACK);
    u2_font_draw_cell(&f, 0, 0, 'A', U2_CGA_WHITE, U2_CGA_BLACK);
    ok(f.px[0][2] == U2_CGA_WHITE && f.px[0][3] == U2_CGA_WHITE &&
       f.px[0][0] == U2_CGA_BLACK && f.px[0][4] == U2_CGA_BLACK,
       "glyph bits are LSB-left, row 0 at top");
    ok(ink_in_cell(&f, 0, 0, U2_CGA_WHITE) > 16, "'A' has substantial ink");

    /* A cell must not bleed into its neighbours. */
    u2_frame_clear(&f, U2_CGA_BLACK);
    u2_font_draw_cell(&f, 5, 5, 'M', U2_CGA_WHITE, U2_CGA_BLACK);
    ok(ink_in_cell(&f, 5, 6, U2_CGA_WHITE) == 0 &&
       ink_in_cell(&f, 4, 5, U2_CGA_WHITE) == 0, "glyph stays inside its cell");

    /* Text advances one cell per byte and reports the count. */
    u2_frame_clear(&f, U2_CGA_BLACK);
    int n = u2_font_draw_text(&f, 10, 2, "HI", U2_CGA_WHITE, U2_CGA_BLACK);
    ok(n == 2 && ink_in_cell(&f, 10, 2, U2_CGA_WHITE) > 0 &&
       ink_in_cell(&f, 10, 3, U2_CGA_WHITE) > 0 &&
       ink_in_cell(&f, 10, 4, U2_CGA_WHITE) == 0, "text advances one cell per byte");

    /* Control bytes render as space, never as a glyph and never as a skip:
     * a game string with an embedded 0x0d must not shift the columns. */
    u2_frame_clear(&f, U2_CGA_BLACK);
    n = u2_font_draw_text(&f, 12, 0, "A\x0d" "B", U2_CGA_WHITE, U2_CGA_BLACK);
    ok(n == 3 && ink_in_cell(&f, 12, 1, U2_CGA_WHITE) == 0 &&
       ink_in_cell(&f, 12, 2, U2_CGA_WHITE) > 0,
       "control bytes draw as space and keep the column count");

    /* Every printable glyph 33..126 has ink; the full range must be drawable
     * without touching a pixel outside the frame (clipping is by cell, and
     * 40x25 cells tile the screen exactly). */
    int empty = 0;
    for (int ch = 33; ch < 127; ch++) {
        u2_frame_clear(&f, U2_CGA_BLACK);
        u2_font_draw_cell(&f, 0, 0, (uint8_t)ch, U2_CGA_WHITE, U2_CGA_BLACK);
        if (ink_in_cell(&f, 0, 0, U2_CGA_WHITE) == 0) empty++;
    }
    ok(empty == 0, "every printable glyph 33..126 has ink");

    /* Out-of-grid cells are dropped, not wrapped. */
    u2_frame_clear(&f, U2_CGA_BLACK);
    u2_font_draw_cell(&f, 25, 0, 'X', U2_CGA_WHITE, U2_CGA_BLACK);
    u2_font_draw_cell(&f, 0, 40, 'X', U2_CGA_WHITE, U2_CGA_BLACK);
    u2_font_draw_cell(&f, -1, 0, 'X', U2_CGA_WHITE, U2_CGA_BLACK);
    int ink = 0;
    for (int y = 0; y < U2_SCREEN_H; y++)
        for (int x = 0; x < U2_SCREEN_W; x++)
            ink += f.px[y][x] != U2_CGA_BLACK;
    ok(ink == 0, "out-of-grid cells draw nothing");

    /* Determinism: the same string twice gives an identical pixel store.
     *
     * This used to declare two bare `u2_frame a, b;` and memcmp the structs. Both
     * halves were wrong: `px` is a heap pointer that only u2_frame_init sets, so
     * u2_frame_clear was writing through uninitialised memory, and memcmp over a
     * struct compares padding bytes that were never written to anything, which
     * differ between compilers and optimisation levels rather than between
     * renderings. It passed here and failed in CI on the same code — a check whose
     * verdict depends on the toolchain is not measuring the property. Compare the
     * store, and initialise what is compared. */
    u2_frame a, b;
    if (u2_frame_init(&a, 1) != 0 || u2_frame_init(&b, 1) != 0) {
        printf("  FAIL  could not allocate the determinism frames\n");
        fails++;
    } else {
        u2_frame_clear(&a, U2_CGA_BLACK);
        u2_frame_clear(&b, U2_CGA_BLACK);
        u2_font_draw_text(&a, 20, 30, "H.P.=9997", U2_CGA_WHITE, U2_CGA_BLACK);
        u2_font_draw_text(&b, 20, 30, "H.P.=9997", U2_CGA_WHITE, U2_CGA_BLACK);
        const int same = a.w == b.w && a.h == b.h
                      && memcmp(a.px, b.px, (size_t)a.h * U2_FRAME_MAX_W) == 0;
        ok(same, "text rendering is deterministic");
        u2_frame_free(&a);
        u2_frame_free(&b);
    }

    u2_frame_free(&f);
    printf("font_check: %s\n", fails ? "FAIL" : "PASS");
    return fails ? 1 : 0;
}
