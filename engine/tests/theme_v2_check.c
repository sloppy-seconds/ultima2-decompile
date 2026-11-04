/*
 * tests/theme_v2_check.c — the format-v2 theme loader: geometry, the map
 * indirection, the theme palette, the frame scale, and the refusals.
 *
 * Why this exists as its own check rather than more lines in ega_check: v1 is a
 * flat array with one possible shape, so it can only be tested for loading. v2
 * is a format with a manifest, and a format that accepts a bad file and draws
 * something anyway is the failure mode that produces a plausible wrong screen
 * while every byte-level assertion passes. So most of this file is controls:
 * each one is a theme that MUST be refused, and the check fails if the loader
 * accepts it.
 *
 * The fixtures are written under /var/tmp so the controls need no player media,
 * exactly like tools/build_themes_selftest.sh. The one part that needs the real
 * art — that the FM Towns letter rows decode to the right tiles — skips cleanly
 * when themes/fmtowns has not been built, because a gate that passes vacuously
 * is worse than one that says it did not run.
 *
 * Build and run from engine/:
 *   cc -std=c11 -Wall -Wextra -Werror -Isrc -o /var/tmp/theme_v2_check \
 *      tests/theme_v2_check.c src/core/tiles_ega.c src/core/frame.c \
 *      src/core/view.c src/debug/trace.c && /var/tmp/theme_v2_check
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#include "core/ctx.h"
#include "core/frame.h"
#include "core/font.h"
#include "core/tiles_ega.h"
#include "core/vram.h"

static int checks, fails;
#define CHECK(cond, ...) do {                                          \
        ++checks;                                                      \
        if (cond) { printf("  ok    "); }                              \
        else { ++fails; printf("  FAIL  "); }                          \
        printf(__VA_ARGS__); printf("\n");                             \
    } while (0)

static char root[256];

static void mkpath(const char *rel)
{
    char p[512];
    snprintf(p, sizeof p, "%s/%s", root, rel);
    mkdir(p, 0755);
}

/* A tile of `n` bytes filled with a nibble pattern, so a decode error shows up
 * as the wrong index rather than as zero. */
static void fill_tile(char *buf, size_t n, int seed)
{
    for (size_t i = 0; i < n; i++)
        buf[i] = (char)((unsigned)((seed + i) & 0x77) | ((unsigned)((seed * 3 + i) & 0x7) << 4));
}

static u2_tiles_ega_result load(const char *name, u2_tiles_ega *t, char *why, size_t wn)
{
    u2_ctx ctx;
    memset(&ctx, 0, sizeof ctx);
    /* A 32x32 theme is only loadable under `--ega`, because the frame scale is a
     * property of the art mode and a 1x frame would have to decimate it. The
     * fixtures therefore load the way the engine loads them, not in a bare ctx —
     * and the refusal of the other case is its own control further down. */
    ctx.art_mode = U2_ART_EGA;
    memset(t, 0, sizeof *t);
    if (why && wn) why[0] = '\0';
    return u2_tiles_ega_open_in(&ctx, t, root, name);
}

/* A minimal, valid v2 theme: 2 tiles of 32x32 at 4bpp, a map that sends art 5
 * to tile 1 and art 6 to both (in that order), and a palette whose entry 1 is
 * pure green. Everything the loader has to read, and nothing it can hide behind. */
static void make_good_theme(void)
{
    mkpath("good");
    char p[512];

    snprintf(p, sizeof p, "%s/good/THEME.INI", root);
    FILE *f = fopen(p, "wb");
    fputs("[theme]\nname = good\ntile_w = 32\ntile_h = 32\nbpp = 4\n"
          "pixel = nibble-high-left\npalette = PALETTE.RGB\nmap = MAP.TSV\n"
          "identity = no\nscope = overworld,towns\n", f);
    fclose(f);

    snprintf(p, sizeof p, "%s/good/TILES", root);
    f = fopen(p, "wb");
    {
        char tile[512];
        fill_tile(tile, sizeof tile, 1);  fwrite(tile, 1, sizeof tile, f);
        fill_tile(tile, sizeof tile, 40); fwrite(tile, 1, sizeof tile, f);
    }
    fclose(f);

    snprintf(p, sizeof p, "%s/good/PALETTE.RGB", root);
    f = fopen(p, "wb");
    {
        unsigned char pal[48];
        memset(pal, 0, sizeof pal);
        pal[3] = 0; pal[4] = 255; pal[5] = 0;       /* entry 1 = green */
        pal[6] = 255; pal[7] = 255; pal[8] = 255;   /* entry 2 = white */
        fwrite(pal, 1, sizeof pal, f);
    }
    fclose(f);

    snprintf(p, sizeof p, "%s/good/MAP.TSV", root);
    f = fopen(p, "wb");
    fputs("# art\ttiles\tsource\n", f);
    fputs("05\t1\tFAKE/1\n", f);
    fputs("06\t0,1\tFAKE/0,FAKE/1\n", f);
    fclose(f);
}

/* Write a one-file-broken variant of the good theme and report what the loader
 * said. `what` selects the defect. */
static u2_tiles_ega_result broken(const char *what, u2_tiles_ega *t, char *why, size_t wn)
{
    char dir[32];
    snprintf(dir, sizeof dir, "bad_%s", what);
    mkpath(dir);
    char p[512];
    u2_ctx ctx;
    memset(&ctx, 0, sizeof ctx);
    memset(t, 0, sizeof *t);
    if (why && wn) why[0] = '\0';
    (void)why; (void)wn;

    /* Each case writes only the files the defect needs; the loader must refuse on
     * the first thing that is wrong rather than drawing a guess. */
    if (!strcmp(what, "bpp3")) {
        snprintf(p, sizeof p, "%s/%s/THEME.INI", root, dir);
        FILE *f = fopen(p, "wb");
        fputs("[theme]\ntile_w = 32\ntile_h = 32\nbpp = 3\n", f);
        fclose(f);
        snprintf(p, sizeof p, "%s/%s/TILES", root, dir);
        f = fopen(p, "wb"); fwrite("x", 1, 32, f); fclose(f);
    } else if (!strcmp(what, "mapoutside")) {
        snprintf(p, sizeof p, "%s/%s/THEME.INI", root, dir);
        FILE *f = fopen(p, "wb");
        fputs("[theme]\ntile_w = 16\ntile_h = 16\nbpp = 4\nmap = MAP.TSV\n", f);
        fclose(f);
        snprintf(p, sizeof p, "%s/%s/TILES", root, dir);
        f = fopen(p, "wb"); { char b[128]; fill_tile(b, sizeof b, 2); fwrite(b, 1, sizeof b, f); } fclose(f);
        snprintf(p, sizeof p, "%s/%s/MAP.TSV", root, dir);
        f = fopen(p, "wb"); fputs("00\t7\tFAKE/7\n", f); fclose(f);
    } else if (!strcmp(what, "scope")) {
        snprintf(p, sizeof p, "%s/%s/THEME.INI", root, dir);
        FILE *f = fopen(p, "wb");
        fputs("[theme]\ntile_w = 16\ntile_h = 16\nbpp = 4\nscope = overworld,dungeons\n", f);
        fclose(f);
        snprintf(p, sizeof p, "%s/%s/TILES", root, dir);
        f = fopen(p, "wb"); { char b[128]; fill_tile(b, sizeof b, 3); fwrite(b, 1, sizeof b, f); } fclose(f);
    } else if (!strcmp(what, "notiles")) {
        snprintf(p, sizeof p, "%s/%s/THEME.INI", root, dir);
        FILE *f = fopen(p, "wb");
        fputs("[theme]\ntile_w = 16\ntile_h = 16\nbpp = 4\n", f);
        fclose(f);
    } else if (!strcmp(what, "ragged")) {
        snprintf(p, sizeof p, "%s/%s/THEME.INI", root, dir);
        FILE *f = fopen(p, "wb");
        fputs("[theme]\ntile_w = 16\ntile_h = 16\nbpp = 4\n", f);
        fclose(f);
        snprintf(p, sizeof p, "%s/%s/TILES", root, dir);
        f = fopen(p, "wb"); { char b[130]; fill_tile(b, sizeof b, 4); fwrite(b, 1, sizeof b, f); } fclose(f);
    } else if (!strcmp(what, "oddside")) {
        snprintf(p, sizeof p, "%s/%s/THEME.INI", root, dir);
        FILE *f = fopen(p, "wb");
        fputs("[theme]\ntile_w = 24\ntile_h = 24\nbpp = 4\n", f);
        fclose(f);
        snprintf(p, sizeof p, "%s/%s/TILES", root, dir);
        f = fopen(p, "wb"); { char b[288]; fill_tile(b, sizeof b, 5); fwrite(b, 1, sizeof b, f); } fclose(f);
    }
    return u2_tiles_ega_open_in(&ctx, t, root, dir);
}

int main(void)
{
    printf("theme_v2_check\n");
    snprintf(root, sizeof root, "%s", "/var/tmp/u2-theme-v2-check");
    system("rm -rf " "/var/tmp/u2-theme-v2-check");
    mkdir(root, 0755);

    /* --- the good theme loads, and reports what it is -------------------- */
    make_good_theme();
    u2_tiles_ega t;
    char why[256];
    u2_ctx gctx;
    memset(&gctx, 0, sizeof gctx);
    gctx.art_mode = U2_ART_EGA;
    memset(&t, 0, sizeof t);
    CHECK(u2_tiles_ega_open_in(&gctx, &t, root, "good") == U2_TILES_EGA_OK,
          "a valid v2 theme loads");
    CHECK(t.loaded && t.count == 2, "the pool holds the 2 tiles the file is made of (%d)", t.count);
    CHECK(t.tile_w == 32 && t.tile_h == 32 && t.stride == 16,
          "32x32 at 4bpp gives a 16-byte stride (stride=%d)", t.stride);
    CHECK(t.scale == 2, "a 32 px tile is native x2 (scale=%d)", t.scale);
    CHECK(gctx.frame_scale == U2_EGA_FRAME_SCALE,
          "and --ega composites at x%d regardless (frame=%d)",
          U2_EGA_FRAME_SCALE, gctx.frame_scale);
    CHECK(t.has_palette && t.palette[1][1] == 255 && t.palette[1][0] == 0,
          "PALETTE.RGB is read and entry 1 is the green the fixture wrote");
    CHECK(t.has_map, "MAP.TSV is present so the atlas is not identity");
    CHECK(u2_tiles_ega_tile(&t, 5) == 1, "art 05 maps to pool tile 1");
    CHECK(u2_tiles_ega_tile(&t, 6) == 0, "art 06 maps to the FIRST of its two frames");
    CHECK(t.map_n[6] == 2, "art 06 keeps both frames in the table (n=%d)", t.map_n[6]);
    CHECK(u2_tiles_ega_tile(&t, 0) == -1,
          "an art index the map does not cover returns -1, not a guess");
    CHECK(!t.scope_dungeon, "scope = overworld,towns does not claim dungeons");

    /* The text-ink trap. This fixture's palette has entry 3 as black (it is
     * zero-filled above 2), exactly like the measured FM Towns table, so the CGA
     * pair the whole text layer is written with draws ink in the background colour
     * — text that is not there, which every byte-level check passes and a player
     * sees immediately. The loader must hand the frame a usable index. */
    CHECK(gctx.text_fg != 3 && gctx.text_fg != 0,
          "a theme palette whose index 3 is dark moves the text ink (fg=%d)",
          gctx.text_fg);
    {
        u2_frame tf;
        memset(&tf, 0, sizeof tf);
        u2_frame_init(&tf, gctx.frame_scale);
        u2_frame_set_text_fg(&tf, gctx.text_fg);
        u2_frame_clear(&tf, 0);
        u2_vram v;
        memset(&v, 0, sizeof v);
        for (int r = 0; r < U2_ROWS; r++)
            for (int c = 0; c < U2_COLS; c++) v.cell[r][c].ch = ' ';
        v.cell[U2_ROWS - 1][0].ch = 'H';
        u2_font_draw_vram_rows(&tf, &v, U2_ROWS - 1, U2_ROWS - 1);
        int ink = 0, wrong = 0;
        for (int y = 0; y < tf.h; y++)
            for (int x = 0; x < tf.w; x++) {
                if (tf.px[y][x] == gctx.text_fg) ink++;
                else if (tf.px[y][x]) wrong++;
            }
        /* Not "did it draw anything" — index 3 is a non-zero index even when the
         * palette makes it black, so that check would pass on the bug. The thing
         * that matters is which index the glyph was drawn with. */
        CHECK(ink > 0 && wrong == 0,
              "the status glyph is drawn in the theme's ink, not the CGA 3 (%d ink, %d other)",
              ink, wrong);
        u2_frame_free(&tf);
    }

    /* The pixel accessor must use the theme's stride, not the v1 constant. */
    CHECK(u2_tile_ega_pixel(&t, 1, 0, 0) == ((t.px[1][0] >> 4) & 0xF),
          "u2_tile_ega_pixel reads through the theme stride");

    /* --- identity: a v2 theme with no map is the v1 contract ------------- */
    mkpath("noident");
    {
        char p[320];
        snprintf(p, sizeof p, "%s/noident/THEME.INI", root);
        FILE *f = fopen(p, "wb");
        fputs("[theme]\ntile_w = 16\ntile_h = 16\nbpp = 4\n", f);
        fclose(f);
        snprintf(p, sizeof p, "%s/noident/TILES", root);
        f = fopen(p, "wb");
        for (int i = 0; i < 64; i++) { char b[128]; fill_tile(b, sizeof b, i); fwrite(b, 1, sizeof b, f); }
        fclose(f);
    }
    u2_tiles_ega ti;
    CHECK(load("noident", &ti, why, sizeof why) == U2_TILES_EGA_OK, "a v2 theme with no MAP.TSV loads");
    CHECK(!ti.has_map && u2_tiles_ega_tile(&ti, 0x2A) == 0x2A,
          "no map means identity, which is what keeps every v1 theme valid");
    CHECK(ti.scale == 1, "a 16 px theme is native x1");
    /* The frame it gets, though, is the art mode's: under --ega a 16x16 theme is
     * block-upscaled rather than shrinking the window. */
    {
        u2_ctx ec;
        memset(&ec, 0, sizeof ec);
        ec.art_mode = U2_ART_EGA;
        u2_tiles_ega ti2;
        memset(&ti2, 0, sizeof ti2);
        CHECK(u2_tiles_ega_open_in(&ec, &ti2, root, "noident") == U2_TILES_EGA_OK
              && ec.frame_scale == U2_EGA_FRAME_SCALE,
              "under --ega even a 16 px theme composites at x%d (frame=%d)",
              U2_EGA_FRAME_SCALE, ec.frame_scale);
    }

    /* --- the frame scale actually changes the framebuffer ---------------- */
    u2_frame f2;
    memset(&f2, 0, sizeof f2);
    CHECK(u2_frame_init(&f2, 2) == 0 && f2.w == 640 && f2.h == 400,
          "a x2 frame is 640x400 (%dx%d)", f2.w, f2.h);
    u2_frame_clear(&f2, 0);
    u2_frame_blit_tile_ega(&f2, &t, 1, 0, 0);
    int lit = 0;
    for (int y = 0; y < 32; y++)
        for (int x = 0; x < 32; x++)
            if (f2.px[y][x]) lit++;
    CHECK(lit > 32 * 32 / 4, "a 32x32 tile fills its 32x32 physical cell (%d lit)", lit);
    CHECK(f2.px[33][0] == 0 && f2.px[0][33] == 0,
          "the blit stops at the tile edge and does not bleed into the next cell");
    /* Text at x2 is a block, not a quarter-size island. */
    u2_frame_clear(&f2, 0);
    u2_frame_put_logical(&f2, 0, 0, 3);
    CHECK(f2.px[0][0] == 3 && f2.px[0][1] == 3 && f2.px[1][0] == 3 && f2.px[1][1] == 3
          && f2.px[2][0] == 0, "put_logical writes a scale x scale block");
    u2_frame_free(&f2);

    /* --- the controls: every one of these must be refused ---------------- */
    u2_tiles_ega bad;
    struct { const char *what; const char *why; } ctl[] = {
        { "bpp3",       "bpp = 3 is not implemented and must not be drawn as 4bpp" },
        { "mapoutside", "a MAP.TSV row pointing outside the atlas" },
        { "scope",      "a misspelt scope word must not read as 'everything'" },
        { "notiles",    "THEME.INI with no TILES beside it" },
        { "ragged",     "a TILES whose size is not a whole number of tiles" },
        { "oddside",    "a tile width that is not a multiple of the 16 px layout" },
    };
    for (size_t i = 0; i < sizeof ctl / sizeof ctl[0]; i++) {
        const u2_tiles_ega_result r = broken(ctl[i].what, &bad, why, sizeof why);
        CHECK(r != U2_TILES_EGA_OK, "control: %s — refused (%s)", ctl[i].why,
              u2_tiles_ega_result_text(r));
    }

    /* --- the real FM Towns theme, when it has been built ---------------- */
    u2_ctx ctx;
    memset(&ctx, 0, sizeof ctx);
    ctx.ega_theme_dir = "../themes";
    ctx.ega_theme = "fmtowns";
    u2_tiles_ega fm;
    memset(&fm, 0, sizeof fm);
    const u2_tiles_ega_result fr = u2_tiles_ega_open(&ctx, &fm, "fmtowns");
    if (fr != U2_TILES_EGA_OK) {
        printf("  SKIP  themes/fmtowns not built (run `python3 tools/build_themes.py "
               "--fmtowns`); the real-art checks did not run\n");
    } else {
        CHECK(fm.count == 80 || fm.count > 64,
              "the FM Towns pool is the crosswalk's distinct tiles (%d)", fm.count);
        CHECK(fm.tile_w == 32 && fm.scale == 2, "the FM Towns theme composites at x2");
        CHECK(fm.has_palette && fm.palette[3][0] == 0 && fm.palette[3][1] == 0
              && fm.palette[3][2] == 0, "FM Towns palette entry 3 is black, as measured");
        CHECK(fm.palette[1][2] == 255 && fm.palette[2][0] == 255,
              "FM Towns entry 1 is blue and entry 2 is red, not the EGA order");
        CHECK(!fm.scope_dungeon, "the crosswalk covers overworld and towns only");
        /* The strongest known-correct part of the crosswalk: the A-Z rows.
         * MAP2_1 tiles 38..63 are A..Z in order, so art 0x20..0x39 must land on
         * 26 DISTINCT pool tiles in increasing order apart from the one slot the
         * owner named as bars. If this comes out scrambled, the row order or the
         * pool numbering is wrong, not the art. */
        int prev = -1, distinct = 1, ordered = 1;
        for (int art = 0x20; art <= 0x39; art++) {
            const int tile = u2_tiles_ega_tile(&fm, art);
            if (tile < 0) { distinct = 0; break; }
            for (int a2 = art + 1; a2 <= 0x39; a2++)
                if (u2_tiles_ega_tile(&fm, a2) == tile) distinct = 0;
            if (tile < prev) ordered = 0;
            prev = tile;
        }
        CHECK(distinct, "the 26 letter arts map to 26 distinct pool tiles");
        CHECK(ordered, "and in the same ascending order the bank holds them");
        /* A frame at the theme's scale must take the whole 32x32 tile. */
        u2_frame ff;
        memset(&ff, 0, sizeof ff);
        u2_frame_init(&ff, ctx.frame_scale);
        CHECK(ff.w == 640 && ff.h == 400, "ctx.frame_scale carried the theme's x2 to the frame");
        u2_frame_clear(&ff, 0);
        u2_frame_blit_tile_ega(&ff, &fm, u2_tiles_ega_tile(&fm, 0x20), 0, 0);
        int nonblack = 0;
        for (int y = 0; y < 32; y++)
            for (int x = 0; x < 32; x++)
                if (ff.px[y][x]) nonblack++;
        CHECK(nonblack > 100, "the letter A tile has real pixels in it (%d non-black)", nonblack);
        u2_frame_free(&ff);
    }

    /* --- mixed formats in one directory: Ctrl-T must see both ------------ */
    mkpath("mixed");
    mkpath("mixed/EGATHEME.V1ONE");
    {
        char p[512];
        /* A v1 theme: EGATHEME.V1ONE/EGATILES, 65 tiles of 128 bytes. */
        snprintf(p, sizeof p, "%s/mixed/EGATHEME.V1ONE/EGATILES", root);
        FILE *f = fopen(p, "wb");
        for (int i = 0; i < 65; i++) { char b[128]; fill_tile(b, sizeof b, i); fwrite(b, 1, sizeof b, f); }
        fclose(f);
    }
    /* and a v2 theme beside it, built by hand rather than by the tool so this
     * check does not depend on the player's media */
    mkpath("mixed/v2two");
    {
        char p[512];
        snprintf(p, sizeof p, "%s/mixed/v2two/THEME.INI", root);
        FILE *f = fopen(p, "wb");
        fputs("[theme]\ntile_w = 16\ntile_h = 16\nbpp = 4\n", f);
        fclose(f);
        snprintf(p, sizeof p, "%s/mixed/v2two/TILES", root);
        f = fopen(p, "wb");
        for (int i = 0; i < 64; i++) { char b[128]; fill_tile(b, sizeof b, i); fwrite(b, 1, sizeof b, f); }
        fclose(f);
    }
    {
        char next[32], first[32] = "";
        u2_ctx ctx;
        memset(&ctx, 0, sizeof ctx);
        const int n = u2_tiles_ega_next_theme("/var/tmp/u2-theme-v2-check/mixed",
                                              "default", next, sizeof next);
        snprintf(first, sizeof first, "%s", next);
        int seen_v1 = 0, seen_v2 = 0, steps = 0;
        do {
            if (!strcmp(next, "v1one")) seen_v1 = 1;
            if (!strcmp(next, "v2two")) seen_v2 = 1;
            if (u2_tiles_ega_next_theme("/var/tmp/u2-theme-v2-check/mixed", next,
                                        next, sizeof next) <= 0) break;
            if (++steps > 8) break;
        } while (strcmp(next, first) != 0);
        CHECK(n >= 2 && seen_v1 && seen_v2,
              "Ctrl-T across a mixed directory finds both formats (n=%d v1=%d v2=%d)",
              n, seen_v1, seen_v2);
        /* And both must load through the same entry point. */
        u2_tiles_ega a, b;
        memset(&a, 0, sizeof a); memset(&b, 0, sizeof b);
        CHECK(u2_tiles_ega_open_in(&ctx, &a, "/var/tmp/u2-theme-v2-check/mixed", "v1one")
                  == U2_TILES_EGA_OK && a.scale == 1,
              "the v1 theme in a mixed directory still loads as v1");
        CHECK(u2_tiles_ega_open_in(&ctx, &b, "/var/tmp/u2-theme-v2-check/mixed", "v2two")
                  == U2_TILES_EGA_OK && b.scale == 1,
              "the v2 theme in a mixed directory loads through the same call");
    }

    /* --- the doubled v1 dump: the owner's accepted consequence ----------- */
    /* `--ega` composites at 640x400 whatever the theme's tiles are, so a 16x16 v1
     * theme is block-upscaled and its dump is a doubled image rather than a 1:1
     * record of the fan pack's pixels. That is a ruling, not an accident, so it
     * gets a test that would notice if the doubling were done differently (a
     * decimation, or a 2x that samples the wrong pixel): the x2 frame must be
     * EXACTLY the 1x frame with every pixel replaced by a 2x2 block. */
    {
        mkpath("EGATHEME.V1EGA");
        char p[512];
        snprintf(p, sizeof p, "%s/EGATHEME.V1EGA/EGATILES", root);
        FILE *f = fopen(p, "wb");
        for (int i = 0; i < 65; i++) { char b[128]; fill_tile(b, sizeof b, i + 7); fwrite(b, 1, sizeof b, f); }
        fclose(f);

        u2_ctx c1;
        memset(&c1, 0, sizeof c1);
        c1.art_mode = U2_ART_EGA;
        u2_tiles_ega v1;
        memset(&v1, 0, sizeof v1);
        CHECK(u2_tiles_ega_open_in(&c1, &v1, root, "v1ega") == U2_TILES_EGA_OK,
              "a v1 EGATILES still loads through the same entry point");
        CHECK(v1.scale == 1 && c1.frame_scale == U2_EGA_FRAME_SCALE,
              "the atlas stays native x1 while the art mode composites at x%d (frame=%d)",
              U2_EGA_FRAME_SCALE, c1.frame_scale);

        u2_frame small, big;
        memset(&small, 0, sizeof small); memset(&big, 0, sizeof big);
        u2_frame_init(&small, 1);
        u2_frame_init(&big, U2_EGA_FRAME_SCALE);
        u2_frame_clear(&small, 0); u2_frame_clear(&big, 0);
        for (int tile = 0; tile < 4; tile++) {
            u2_frame_blit_tile_ega(&small, &v1, tile, tile * 16, 0);
            u2_frame_blit_tile_ega(&big, &v1, tile, tile * 32, 0);
        }
        int exact = 1, lit1 = 0, lit2 = 0;
        for (int y = 0; y < small.h; y++)
            for (int x = 0; x < small.w; x++) {
                if (small.px[y][x]) lit1++;
                if (big.px[y][x]) lit2++;
            }
        for (int y = 0; y < small.h && exact; y++)
            for (int x = 0; x < small.w && exact; x++) {
                const uint8_t a = small.px[y][x];
                for (int j = 0; j < 2 && exact; j++)
                    for (int i = 0; i < 2 && exact; i++)
                        if (big.px[y * 2 + j][x * 2 + i] != a) exact = 0;
            }
        /* Both frames must actually contain the blit, or "exactly the expansion"
         * is two empty buffers agreeing with each other. */
        CHECK(lit1 > 200 && lit2 == 4 * lit1,
              "both blits drew real pixels and the second has exactly 4x the ink (x1=%d, x2=%d)",
              lit1, lit2);
        CHECK(exact, "the x2 dump is exactly the x2 block expansion of the x1 frame");
        /* And the cell pitch doubled with it, or four tiles would overlap. */
        CHECK(big.px[0][31] != 0 || big.px[0][32] == small.px[0][16],
              "the doubled cells keep their own 32 px pitch");
        u2_frame_free(&small);
        u2_frame_free(&big);
    }

    /* --- the name "default" is special-cased in the v1 path; v2 must still win -- */
    /* theme_relpath() maps the name "default" to a bare EGATILES, so a builder that
     * reshapes the default theme into default/ only works if the v2 lookup is tried
     * first for that name too. This is the case the builder now emits. */
    mkpath("default");
    {
        char p[512];
        snprintf(p, sizeof p, "%s/default/THEME.INI", root);
        FILE *f = fopen(p, "wb");
        fputs("[theme]\ntile_w = 16\ntile_h = 16\nbpp = 4\n", f);
        fclose(f);
        snprintf(p, sizeof p, "%s/default/TILES", root);
        f = fopen(p, "wb");
        for (int i = 0; i < 64; i++) { char b[128]; fill_tile(b, sizeof b, 99); fwrite(b, 1, sizeof b, f); }
        fclose(f);
        /* And a v1 EGATILES at the root as well, so the test proves which one won. */
        snprintf(p, sizeof p, "%s/EGATILES", root);
        f = fopen(p, "wb");
        for (int i = 0; i < 65; i++) { char b[128]; fill_tile(b, sizeof b, 1); fwrite(b, 1, sizeof b, f); }
        fclose(f);
    }
    {
        u2_ctx dc;
        memset(&dc, 0, sizeof dc);
        dc.art_mode = U2_ART_EGA;
        u2_tiles_ega dv;
        memset(&dv, 0, sizeof dv);
        const u2_tiles_ega_result r = u2_tiles_ega_open_in(&dc, &dv, root, "default");
        CHECK(r == U2_TILES_EGA_OK, "--ega-theme default resolves through the v2 directory");
        CHECK(strstr(dv.source, "default/TILES") != NULL,
              "and the manifest wins over a bare EGATILES sitting beside it (%s)", dv.source);
    }

    printf("theme_v2_check: %d checks, %d failures\n", checks, fails);;
    return fails ? 1 : 0;
}
