/*
 * tests/world_check.c — the guarantees of core/world.c.
 *
 * Every byte written here is engine-authored test filler, not game content: the
 * point of CP4 is that the map is runtime data the player supplies, so the test
 * proves the loader's structure (sizes, indexing, naming, write-back) without
 * committing a single tile byte.
 *
 * Build and run by tests/run_cp4.sh.
 */

#define _POSIX_C_SOURCE 200809L   /* mkdtemp, chmod under -std=c11 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "core/ctx.h"
#include "core/world.h"

static int fails;

#define CHECK(cond, msg)                                              \
    do {                                                              \
        if (cond) printf("  ok    %s\n", msg);                        \
        else      { printf("  FAIL  %s\n", msg); fails++; }           \
    } while (0)

static long filesize(const char *p)
{
    struct stat st;
    return stat(p, &st) == 0 ? (long)st.st_size : -1;
}

/* A deterministic, obviously-synthetic sector: tile = (x*3 + y) & 0xFF. */
static void fill_sector(uint8_t *buf, size_t n)
{
    for (size_t i = 0; i < n; i++)
        buf[i] = (uint8_t)(((i % U2_SECTOR_EDGE) * 3 + (i / U2_SECTOR_EDGE)) & 0xFF);
}

static void path_for(char *out, size_t n, const char *dir, const char *name)
{
    snprintf(out, n, "%s/%s", dir, name);
}

static int write_file(const char *p, const uint8_t *buf, size_t n)
{
    FILE *f = fopen(p, "wb");
    if (!f) return -1;
    if (fwrite(buf, 1, n, f) != n) { fclose(f); return -1; }
    fclose(f);
    return 0;
}

int main(int argc, char **argv)
{
    const char *base = argc > 1 ? argv[1] : ".";
    char dir[512], missing[512], p[512];
    uint8_t buf[U2_SECTOR_TILES + 256];
    uint8_t readback[U2_SECTOR_TILES + 256];
    u2_ctx ctx;
    u2_world w;
    u2_sector_id id;
    FILE *f;

    snprintf(dir, sizeof dir, "%s/content", base);
    snprintf(missing, sizeof missing, "%s/nope", base);
    mkdir(dir, 0755);

    memset(&ctx, 0, sizeof ctx);
    ctx.data_dir = dir;
    memset(&w, 0, sizeof w);
    id.hi = 3; id.lo = 0;          /* the sector the live capture was standing in */

    /* --- the content directory is never invented ---------------------- */
    ctx.data_dir = missing;
    CHECK(u2_world_open(&ctx) == U2_WORLD_NOT_READY,
          "a missing --data-dir is reported, not created");
    CHECK(filesize(missing) == -1,
          "opening a missing content dir leaves no directory behind");
    ctx.data_dir = dir;
    CHECK(u2_world_open(&ctx) == U2_WORLD_OK, "a real content dir opens");

    /* --- naming: MAPX + two digits, the self-patched FCB name --------- */
    u2_world_path(p, sizeof p, &ctx, "mapx", id);
    CHECK(strstr(p, "/mapx30") != NULL, "sector name is <dir>/mapx<hi><lo>");

    /* --- the read is 4096 bytes, whatever the file size -------------- */
    fill_sector(buf, U2_SECTOR_TILES + 128);
    path_for(p, sizeof p, dir, "mapx30");
    CHECK(write_file(p, buf, U2_SECTOR_TILES + 128) == 0, "test sector written");
    CHECK(u2_world_load(&ctx, &w, 1, id) == U2_WORLD_OK, "4224-byte sector loads");
    CHECK(w.bytes_read == U2_SECTOR_TILES, "exactly 4096 bytes are read (CX at asm/2290)");
    CHECK(filesize(p) == U2_SECTOR_TILES + 128, "loading does not touch the file");

    /* --- tile addressing: y*64 + x, one byte per tile (asm/50B3) ----- */
    CHECK(u2_world_tile_at(&w, 0, 0) == buf[0], "tile (0,0) is byte 0");
    CHECK(u2_world_tile_at(&w, 5, 0) == buf[5], "tile (5,0) is byte 5");
    CHECK(u2_world_tile_at(&w, 0, 1) == buf[U2_SECTOR_EDGE],
          "tile (0,1) is byte 64, so the row stride is 64");
    CHECK(u2_world_tile_at(&w, 63, 63) == buf[U2_SECTOR_TILES - 1],
          "tile (63,63) is the last byte of the sector");
    CHECK(u2_world_tile_index(64, 0) == 0 && u2_world_tile_index(-1, 0) == 63,
          "coordinates fold into the sector instead of running off the end");

    /* --- a sector with no 128-byte tail (the Galaxy content) --------- */
    path_for(p, sizeof p, dir, "mapx15");
    CHECK(write_file(p, buf, U2_SECTOR_TILES) == 0, "tail-less sector written");
    id.hi = 1; id.lo = 5;
    CHECK(u2_world_load(&ctx, &w, 1, id) == U2_WORLD_OK,
          "a 4096-byte sector loads — size is not asserted as 4224");
    id.hi = 3; id.lo = 0;

    /* --- missing and short files are named, not guessed at ----------- */
    id.hi = 9; id.lo = 9;
    CHECK(u2_world_load(&ctx, &w, 1, id) == U2_WORLD_MISSING,
          "an absent sector reports MISSING");
    id.hi = 4; id.lo = 4;
    path_for(p, sizeof p, dir, "mapx44");
    CHECK(write_file(p, buf, 100) == 0, "truncated sector written");
    CHECK(u2_world_load(&ctx, &w, 1, id) == U2_WORLD_SHORT,
          "a sector shorter than the read reports SHORT, not a partial success");

    /* --- the Galaxy rename: mapg / MAPG spellings are found ---------- */
    id.hi = 5; id.lo = 0;
    path_for(p, sizeof p, dir, "mapg50");
    CHECK(write_file(p, buf, U2_SECTOR_TILES) == 0, "mapg-spelled sector written");
    CHECK(u2_world_load(&ctx, &w, 1, id) == U2_WORLD_OK,
          "mapg spelling found (fan pack renames mapx -> mapg)");
    path_for(p, sizeof p, dir, "MAPG60");
    CHECK(write_file(p, buf, U2_SECTOR_TILES) == 0, "MAPG-spelled sector written");
    id.hi = 6; id.lo = 0;
    CHECK(u2_world_load(&ctx, &w, 1, id) == U2_WORLD_OK,
          "uppercase MAPG spelling found too");
    id.hi = 3; id.lo = 0;
    path_for(p, sizeof p, dir, "mapx30");

    /* --- write-back: dirty tracking, tail preservation, atomicity ---- */
    memset(&w, 0, sizeof w);
    CHECK(u2_world_load(&ctx, &w, 1, id) == U2_WORLD_OK, "reload mapx30 for write-back");
    CHECK(w.map_dirty == 0, "a freshly loaded sector is not dirty");
    u2_world_tile_put(&w, 7, 9, 0xA5);
    CHECK(w.map_dirty == 1, "writing a tile marks the sector dirty");
    CHECK(u2_world_tile_at(&w, 7, 9) == 0xA5, "the tile change is visible");
    CHECK(u2_world_store(&ctx, &w, 1) == U2_WORLD_OK, "dirty sector stores");
    CHECK(w.map_dirty == 0, "storing clears dirty");
    CHECK(filesize(p) == U2_SECTOR_TILES + 128,
          "write-back preserves the 128-byte tail the original never reads");
    snprintf(p, sizeof p, "%.400s/mapx30.u2tmp", dir);
    CHECK(filesize(p) == -1, "write-back leaves no temp file behind");

    path_for(p, sizeof p, dir, "mapx30");
    f = fopen(p, "rb");
    CHECK(f != NULL, "stored sector reopens");
    if (f) {
        size_t n = fread(readback, 1, sizeof readback, f);
        fclose(f);
        CHECK(n == U2_SECTOR_TILES + 128, "stored file is 4096 + the preserved tail");
        CHECK(readback[9 * U2_SECTOR_EDGE + 7] == 0xA5, "the changed tile is on disk");
        CHECK(readback[U2_SECTOR_TILES] == buf[U2_SECTOR_TILES],
              "the first tail byte survived untouched");
        CHECK(readback[U2_SECTOR_TILES + 127] == buf[U2_SECTOR_TILES + 127],
              "the last tail byte survived untouched");
    }

    /* --- a read-only content dir is reported when a write is needed --- */
    CHECK(chmod(dir, 0555) == 0, "content dir made read-only");
    memset(&w, 0, sizeof w);
    CHECK(u2_world_load(&ctx, &w, 1, id) == U2_WORLD_OK,
          "a read-only content dir still plays (load succeeds)");
    u2_world_tile_put(&w, 1, 1, 0x5A);
    CHECK(u2_world_store(&ctx, &w, 1) == U2_WORLD_NOT_READY,
          "storing into a read-only dir reports NOT_READY, the INSERT analogue");
    CHECK(chmod(dir, 0755) == 0, "content dir restored");

    /* --- the monster table is the same shape at 256 bytes (asm/22D5) -- */
    id.hi = 3; id.lo = 0;
    path_for(p, sizeof p, dir, "monx30");
    CHECK(write_file(p, buf, U2_MON_TILES + 128) == 0, "monx file written");
    memset(&w, 0, sizeof w);
    CHECK(u2_world_load(&ctx, &w, 0, id) == U2_WORLD_OK, "monx sector loads");
    CHECK(w.bytes_read == U2_MON_TILES, "monx read is 256 bytes (CX at asm/22D5)");

    printf(fails ? "world check: FAIL (%d)\n" : "world check: all %d checks passed\n",
           fails ? fails : 30);
    return fails != 0;
}
