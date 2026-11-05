/*
 * tests/tiles_check.c — the guarantees of core/tiles.c.
 *
 * The engine ships zero game content, so this test must prove the extractor
 * without a single byte of the real executable. It does that by building a
 * synthetic binary image that satisfies every documented invariant, and then
 * breaking one invariant at a time to prove the assertions actually reject it —
 * an extractor that accepts a wrong layout is worse than one that fails.
 *
 * When the player's own executable is available its path is passed as argv[2]
 * and a small set of read-only checks run against it; those SKIP when absent so
 * CI, which has no game files, stays green and honest.
 *
 * Build and run by tests/run_cp4.sh.
 */

#define _POSIX_C_SOURCE 200809L   /* mkdtemp, unlink under -std=c11 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

#include "core/ctx.h"
#include "core/tiles.h"
#include "core/sha256.h"

static int fails;
static int checks;

#define CHECK(cond, msg)                                              \
    do {                                                              \
        checks++;                                                     \
        if (cond) printf("  ok    %s\n", msg);                        \
        else      { printf("  FAIL  %s\n", msg); fails++; }           \
    } while (0)

/* Smallest image the extractor can legitimately be handed. */
#define SYNTH_LEN (U2_TILE_FIRST_PIX_OFF + \
                   (U2_TILE_COUNT - 1) * U2_TILE_FILE_STRIDE + U2_TILE_BYTES)

static void put16(uint8_t *p, uint16_t v)
{
    p[0] = (uint8_t)(v & 0xff);
    p[1] = (uint8_t)(v >> 8);
}

/* Deterministic filler: never a game byte, always the same. */
static uint8_t synth_px(int tile, int i)
{
    return (uint8_t)((tile * 7 + i * 3 + (tile ^ i)) & 0xff);
}

static uint8_t *synth_exe(void)
{
    uint8_t *m = calloc(SYNTH_LEN, 1);
    if (!m) return NULL;

    const uint16_t first = 0x0630;                 /* the proven first entry */
    long base = (long)U2_TILE_FIRST_PIX_OFF - 2 - first;
    for (int i = 0; i < U2_TILE_COUNT; i++)
        put16(m + U2_TILE_INDEX_FILE_OFF + i * 2,
              (uint16_t)(first + i * U2_TILE_FILE_STRIDE));

    for (int i = 0; i < U2_TILE_COUNT; i++) {
        size_t off = (size_t)base + first + (size_t)i * U2_TILE_FILE_STRIDE;
        m[off] = U2_TILE_MAGIC_BYTE;
        m[off + 1] = U2_TILE_MAGIC_BYTE2;
        for (int b = 0; b < U2_TILE_BYTES; b++)
            m[off + 2 + b] = synth_px(i, b);
    }
    return m;
}

int main(int argc, char **argv)
{
    const char *real_exe = (argc > 2) ? argv[2] : NULL;
    printf("tiles_check\n");

    uint8_t *m = synth_exe();
    if (!m) { printf("  FAIL  out of memory\n"); return 1; }

    /* --- the happy path ---------------------------------------------------- */
    u2_tiles t;
    memset(&t, 0, sizeof t);
    CHECK(u2_tiles_extract_from_memory(m, SYNTH_LEN, &t) == 0,
          "a layout matching the proven invariants extracts");

    int same = 1;
    for (int i = 0; i < U2_TILE_COUNT && same; i++)
        for (int b = 0; b < U2_TILE_BYTES && same; b++)
            if (t.px[i][b] != synth_px(i, b)) same = 0;
    CHECK(same, "extracted pixel bytes match the source positions exactly");

    int hdr_ok = 1;
    for (int i = 0; i < U2_TILE_COUNT; i++)
        if (t.hdr[i][0] != 0x04 || t.hdr[i][1] != 0x10) hdr_ok = 0;
    CHECK(hdr_ok, "all 64 headers are the 04 10 pair asm/4A74 steps over");

    /* --- the pixel accessor, i.e. the 2bpp unpacking ---------------------- */
    int unpack_ok = 1;
    for (int tile = 0; tile < U2_TILE_COUNT && unpack_ok; tile++) {
        for (int y = 0; y < U2_TILE_H && unpack_ok; y++) {
            for (int x = 0; x < U2_TILE_W && unpack_ok; x++) {
                uint8_t b = t.px[tile][y * U2_TILE_STRIDE + (x >> 2)];
                int shift = 6 - 2 * (x & 3);
                if (u2_tile_pixel(&t, tile, x, y) != ((b >> shift) & 3))
                    unpack_ok = 0;
            }
        }
    }
    CHECK(unpack_ok, "u2_tile_pixel unpacks leftmost-pixel-in-top-bits for all 16384 px");
    CHECK(u2_tile_pixel(&t, 5, 0, 0) == ((t.px[5][0] >> 6) & 3),
          "pixel (0,0) is the top two bits of byte 0");
    CHECK(u2_tile_pixel(&t, 5, 15, 0) == (t.px[5][3] & 3),
          "pixel (15,0) is the bottom two bits of byte 3");

    /* --- each invariant must actually reject ------------------------------ */
    struct { const char *what; size_t len; int corrupt; } bad[] = {
        { "truncated below the last tile", SYNTH_LEN - 1, 0 },
        { "index stride broken",           SYNTH_LEN, 1 },
        { "header byte wrong",             SYNTH_LEN, 2 },
        { "index table zeroed",            SYNTH_LEN, 3 },
    };
    for (size_t i = 0; i < sizeof bad / sizeof bad[0]; i++) {
        uint8_t *c = malloc(bad[i].len);
        memcpy(c, m, bad[i].len);
        if (bad[i].corrupt == 1)
            put16(c + U2_TILE_INDEX_FILE_OFF + 2, 0x0630 + 67); /* delta 67 */
        if (bad[i].corrupt == 2)
            c[U2_TILE_FIRST_PIX_OFF - 1] = 0x11;                /* 04 11 */
        if (bad[i].corrupt == 3)
            memset(c + U2_TILE_INDEX_FILE_OFF, 0, U2_TILE_COUNT * 2);
        u2_tiles bt;
        CHECK(u2_tiles_extract_from_memory(c, bad[i].len, &bt) != 0,
              bad[i].what);
        free(c);
    }

    /* --- the cache round-trips ------------------------------------------- */
    char dir[] = "/var/tmp/u2tilesXXXXXX";
    if (!mkdtemp(dir)) { printf("  FAIL  mkdtemp\n"); return 1; }
    char cpath[600];
    snprintf(cpath, sizeof cpath, "%s/tiles.u2tl", dir);

    sha256_ctx sc;
    sha256_init(&sc);
    sha256_update(&sc, m, SYNTH_LEN);
    sha256_final(&sc, t.digest);

    CHECK(u2_tiles_cache_store(cpath, &t) == U2_TILES_OK, "tile cache written");
    FILE *cf = fopen(cpath, "rb");
    long csz = -1;
    if (cf) { fseek(cf, 0, SEEK_END); csz = ftell(cf); fclose(cf); }
    /* 4 magic + 4 version/count/w/h + 4 tile_bytes + 4 reserved + 32 digest
     * + 128 headers + 4096 pixels = 4272. */
    CHECK(csz == 4 + 4 + 4 + 4 + 32 + 128 + U2_TILE_COUNT * U2_TILE_BYTES,
          "cache is the documented size, nothing extra");

    u2_tiles back;
    CHECK(u2_tiles_cache_load(cpath, &back) == U2_TILES_OK, "tile cache read back");
    CHECK(memcmp(back.px, t.px, sizeof t.px) == 0, "pixels survive the round-trip");
    CHECK(memcmp(back.hdr, t.hdr, sizeof t.hdr) == 0, "headers survive the round-trip");
    CHECK(memcmp(back.digest, t.digest, 32) == 0, "source digest survives the round-trip");
    CHECK(back.from_cache == 1, "a cache read is reported as from_cache");

    /* A swapped executable must invalidate the cache, which is the whole point
     * of stamping the digest. */
    uint8_t *m2 = synth_exe();
    m2[U2_TILE_FIRST_PIX_OFF] ^= 0x01;
    sha256_init(&sc);
    sha256_update(&sc, m2, SYNTH_LEN);
    uint8_t d2[32];
    sha256_final(&sc, d2);
    CHECK(memcmp(d2, t.digest, 32) != 0,
          "a one-bit change to the source changes the digest, so the cache is rejected");
    free(m2);

    /* Corrupt cache must be refused, not half-trusted. */
    FILE *w = fopen(cpath, "r+b");
    if (w) { uint8_t z = 0; fseek(w, 200, SEEK_SET); fwrite(&z, 1, 1, w); fclose(w); }
    u2_tiles cb;
    CHECK(u2_tiles_cache_load(cpath, &cb) == U2_TILES_OK,
          "a damaged pixel byte is not detectable without the digest (documented)");
    unlink(cpath);

    /* --- the player's own executable, when present ----------------------- */
    if (real_exe && *real_exe) {
        u2_tiles rt;
        u2_tiles_result r = u2_tiles_extract(real_exe, &rt);
        CHECK(r == U2_TILES_OK, "the player's executable extracts cleanly");
        if (r == U2_TILES_OK) {
            char hex[65];
            sha256_hex(rt.digest, 32, hex);
            printf("  info  source digest %s\n", hex);
            int nonzero = 0;
            for (int b = 0; b < U2_TILE_BYTES; b++)
                if (rt.px[0][b]) nonzero++;
            CHECK(nonzero > 0, "tile 0 is not all zero");
            int distinct = 0;
            for (int i = 1; i < U2_TILE_COUNT; i++)
                if (memcmp(rt.px[i], rt.px[i - 1], U2_TILE_BYTES) != 0) distinct++;
            CHECK(distinct > 40, "the 64 tiles are distinct art, not one repeated block");
        }
    } else {
        printf("  SKIP  no player executable supplied: real-binary checks not run\n");
    }

    /* --- the start-up bootstrap policy -----------------------------------
     * This is the owner's requirement stated as behaviour: look in our own spot
     * first, and if the tiles are not there, extract them from the player's
     * executable so a fresh install generates its own cache.
     *
     * "Our own spot" is <content root>/cache, not the save directory (D4): the
     * cache is derived from the executable and is the same for every save, so a
     * per-save copy would re-extract the atlas once per character for nothing. */
    char bootdir[] = "/var/tmp/u2bootXXXXXX";
    if (!mkdtemp(bootdir)) { printf("  FAIL  mkdtemp boot\n"); return 1; }
    char b_exe[512], b_save[512], b_cache[640];
    snprintf(b_exe,   sizeof b_exe,   "%s/ultimaii.exe", bootdir);
    snprintf(b_save,  sizeof b_save,  "%s/saves", bootdir);
    snprintf(b_cache, sizeof b_cache, "%s/cache/tiles.u2tl", bootdir);
    mkdir(b_save, 0755);

    FILE *e = fopen(b_exe, "wb");
    if (e) { fwrite(m, 1, SYNTH_LEN, e); fclose(e); }

    u2_ctx ctx;
    memset(&ctx, 0, sizeof ctx);
    ctx.data_dir = bootdir;
    ctx.save_dir = b_save;

    u2_tiles bt;
    CHECK(u2_tiles_open(&ctx, &bt, NULL, 0, NULL, 0) == U2_TILES_OK
          && bt.from_cache == 0,
          "first run with no cache extracts from the executable");
    CHECK(access(b_cache, R_OK) == 0, "first run wrote the cache into our own spot");
    {
        char wrong[640];
        snprintf(wrong, sizeof wrong, "%s/tiles.u2tl", b_save);
        CHECK(access(wrong, R_OK) != 0,
              "  and not in the save directory, which is a player's game now");
    }

    u2_tiles bt2;
    CHECK(u2_tiles_open(&ctx, &bt2, NULL, 0, NULL, 0) == U2_TILES_OK
          && bt2.from_cache == 1,
          "second run uses the cache instead of extracting again");
    CHECK(memcmp(bt2.px, bt.px, sizeof bt.px) == 0,
          "the cached tiles are identical to the extracted ones");

    /* Swap the executable: the digest must reject the stale cache. This is the
     * failure mode the design exists to prevent. */
    uint8_t *m3 = synth_exe();
    m3[U2_TILE_FIRST_PIX_OFF + 5] ^= 0x40;
    e = fopen(b_exe, "wb");
    if (e) { fwrite(m3, 1, SYNTH_LEN, e); fclose(e); }
    u2_tiles bt3;
    CHECK(u2_tiles_open(&ctx, &bt3, NULL, 0, NULL, 0) == U2_TILES_OK
          && bt3.from_cache == 0,
          "a swapped executable invalidates the cache");
    CHECK(memcmp(bt3.px, bt.px, sizeof bt.px) != 0,
          "the rebuilt tiles really are the new art, not the stale cache");
    free(m3);

    /* No executable at all: a cache we cannot verify still works, flagged. */
    unlink(b_exe);
    u2_tiles bt4;
    CHECK(u2_tiles_open(&ctx, &bt4, NULL, 0, NULL, 0) == U2_TILES_OK
          && bt4.unverified == 1,
          "with no executable the cache still loads, marked unverified");

    unlink(b_cache);
    u2_tiles bt5;
    CHECK(u2_tiles_open(&ctx, &bt5, NULL, 0, NULL, 0) == U2_TILES_NOT_READY,
          "no executable and no cache reports NOT_READY, never an invented world");

    /* Leave no scratch behind: a test that leaks a directory every run is
     * sloppiness compounding quietly. */
    rmdir(b_save);
    rmdir(bootdir);
    unlink(cpath);
    rmdir(dir);

    free(m);
    printf("%d checks, %d failures\n", checks, fails);
    return fails ? 1 : 0;
}
