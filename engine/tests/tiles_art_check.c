/*
 * tests/tiles_art_check.c — the generated cleanroom art decodes correctly.
 *
 * The header under test is machine-generated, and a generated file is exactly
 * the kind of artefact that can be quietly wrong: right size, right shape,
 * pixels in the wrong place. Size assertions alone would not catch a bit-order
 * mistake, so this unpacks every tile through the engine's own u2_tile_pixel()
 * and re-hashes the result, comparing against the hash the generator recorded
 * from the pixels it parsed out of the SVGs. If the packing and the decode ever
 * disagree, this fails.
 *
 * Build and run by tests/run_cp4.sh.
 */

#include <stdio.h>
#include <string.h>

#include "core/tiles.h"
#include "core/tiles_builtin.h"

static int failures;

#define CHECK(cond, what)                                              \
    do {                                                               \
        if (!(cond)) {                                                 \
            printf("  FAIL  %s\n", (what));                            \
            ++failures;                                                \
        }                                                              \
    } while (0)

/* Must match fnv() in engine/tools/tiles2h.py: FNV-1a over all 256 pixel
 * values in raster order, including the unlit ones, so a bit-order error
 * changes the hash instead of preserving it. */
static uint32_t hash_tile(const u2_tiles *t, int tile)
{
    uint32_t h = 2166136261u;
    for (int y = 0; y < U2_TILE_H; ++y) {
        for (int x = 0; x < U2_TILE_W; ++x) {
            h ^= (uint32_t)u2_tile_pixel(t, tile, x, y);
            h *= 16777619u;
        }
    }
    return h;
}

int main(void)
{
    u2_tiles t;
    printf("tiles_art_check — generated cleanroom art\n");

    CHECK(u2_tiles_builtin(&t) == U2_TILES_OK, "builtin art loads");
    CHECK(strcmp(t.source, "builtin:cleanroom") == 0, "source identifies itself");
    CHECK(t.unverified == 1, "builtin art reports itself unverified (no exe to check)");
    CHECK(t.from_cache == 0, "builtin art is not a cache");

    /* The record header belongs to the in-exe layout; carrying it means no
     * consumer has to special-case the builtin set. */
    int hdr_ok = 1;
    for (int i = 0; i < U2_TILE_COUNT; ++i) {
        if (t.hdr[i][0] != U2_TILE_MAGIC_BYTE || t.hdr[i][1] != U2_TILE_MAGIC_BYTE2) {
            hdr_ok = 0;
        }
    }
    CHECK(hdr_ok, "every tile carries the 04 10 record header");

    /* The central guarantee: engine decode agrees with the generator's parse. */
    int hash_ok = 1, first_bad = -1;
    for (int i = 0; i < U2_TILE_COUNT; ++i) {
        if (hash_tile(&t, i) != u2_tiles_builtin_hash(i)) {
            if (first_bad < 0) {
                first_bad = i;
            }
            hash_ok = 0;
        }
    }
    CHECK(hash_ok, "u2_tile_pixel round-trips every tile against the SVG parse");
    if (!hash_ok) {
        printf("        first mismatch at tile %02X: decoded %08X expected %08X\n",
               first_bad, hash_tile(&t, first_bad), u2_tiles_builtin_hash(first_bad));
    }

    /* Art rules from the spec, re-checked here so a regenerated header cannot
     * quietly violate them. */
    int ink_ok = 1, empty_ok = 1;
    for (int i = 0; i < U2_TILE_COUNT; ++i) {
        int lit = 0;
        for (int y = 0; y < U2_TILE_H; ++y) {
            for (int x = 0; x < U2_TILE_W; ++x) {
                int v = u2_tile_pixel(&t, i, x, y);
                if (v < 0 || v > 3) {
                    ink_ok = 0;
                }
                if (v) {
                    ++lit;
                }
            }
        }
        /* Art 1D is "solid black", and black is the backdrop: it is correctly
         * an empty tile. Every other tile must have some ink. */
        if (i == 0x1D) {
            if (lit != 0) {
                empty_ok = 0;
            }
        } else if (lit == 0) {
            empty_ok = 0;
            printf("        tile %02X is blank\n", i);
        }
    }
    CHECK(ink_ok, "every pixel is a valid CGA index 0..3");
    CHECK(empty_ok, "only art 1D is empty; no other tile is blank");

    if (failures) {
        printf("TILES ART TEST: FAIL (%d)\n", failures);
        return 1;
    }
    printf("TILES ART TEST: PASS\n");
    return 0;
}
