/*
 * tiles_builtin.c — the compiled-in cleanroom substitute art.
 *
 * The generated header is included here and nowhere else, as core/font.c does
 * with font8x8_basic.h: the arrays are `static const`, so a second inclusion
 * would silently create a second copy rather than link against one.
 *
 * Nothing in this file is derived from the game binary. The bytes come from the
 * tile_NN.svg files under engine/assets/tiles/cleanroom/tiles, via
 * engine/tools/tiles2h.py; see that directory's PROVENANCE.md and
 * docs/tile-art-spec.md.
 */

#include <stdio.h>
#include <string.h>

#include "core/tiles_builtin.h"
#include "core/tiles_cleanroom.h"

_Static_assert(U2_TILES_CLEANROOM_COUNT == U2_TILE_COUNT,
               "cleanroom set must cover every art index (64)");
_Static_assert(U2_TILES_CLEANROOM_BYTES == U2_TILE_BYTES,
               "cleanroom tile must be 16 rows x 4 bytes at 2bpp");
_Static_assert(sizeof u2_tiles_cleanroom ==
                   (size_t)U2_TILE_COUNT * U2_TILE_BYTES,
               "cleanroom array size drifted");

_Static_assert(sizeof u2_tiles_cleanroom_hash /
                   sizeof u2_tiles_cleanroom_hash[0] == U2_TILE_COUNT,
               "cleanroom hash table must cover every art index");

uint32_t u2_tiles_builtin_hash(int tile)
{
    if (tile < 0 || tile >= U2_TILE_COUNT) {
        return 0;
    }
    return u2_tiles_cleanroom_hash[tile];
}

u2_tiles_result u2_tiles_builtin(u2_tiles *t)
{
    if (!t) {
        return U2_TILES_ERROR;
    }
    memset(t, 0, sizeof *t);
    for (int i = 0; i < U2_TILE_COUNT; i++) {
        memcpy(t->px[i], u2_tiles_cleanroom[i], U2_TILE_BYTES);
        /* The 04 10 pair is a property of the record layout inside the
         * executable, not of the art. Carrying it here means a u2_tiles filled
         * this way is indistinguishable from an extracted one to anything that
         * reads hdr, so no consumer has to special-case the builtin set. */
        t->hdr[i][0] = U2_TILE_MAGIC_BYTE;
        t->hdr[i][1] = U2_TILE_MAGIC_BYTE2;
    }
    t->from_cache = 0;
    /* Honest, not a degraded state: there is no executable for this art to be
     * checked against, by design. The source string is what distinguishes a
     * substitute set from an extraction that merely could not be verified. */
    t->unverified = 1;
    if (snprintf(t->source, sizeof t->source, "builtin:cleanroom")
            >= (int)sizeof t->source) {
        return U2_TILES_ERROR;
    }
    return U2_TILES_OK;
}
