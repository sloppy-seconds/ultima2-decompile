#ifndef U2_TILES_BUILTIN_H
#define U2_TILES_BUILTIN_H

/*
 * The compiled-in substitute tile set.
 *
 * Fills a u2_tiles from art generated out of the cleanroom SVGs, so the engine
 * has usable tiles with no game files present, no cache to resolve and nothing
 * to go stale. The player's own extracted art still wins when it exists — see
 * u2_tiles_open() in core/tiles.h, which this does not replace.
 */

#include "core/tiles.h"

/* Populate t with the built-in cleanroom art. Always succeeds: the data is
 * compiled in and its size is asserted at build time in tiles_builtin.c. */
u2_tiles_result u2_tiles_builtin(u2_tiles *t);

/* FNV-1a of a tile's 256 pixel values in raster order, recorded by the
 * generator from the pixels it parsed out of the SVGs. A test unpacks the
 * compiled bytes with the engine's own decode, re-hashes and compares, which is
 * what proves the packing agrees with u2_tile_pixel(). Returns 0 if tile is out
 * of range. Exposed as a function rather than the array because the generated
 * arrays have internal linkage in tiles_builtin.c. */
uint32_t u2_tiles_builtin_hash(int tile);

#endif /* U2_TILES_BUILTIN_H */
