#ifndef U2_TILES_H
#define U2_TILES_H

/*
 * Tile art — extracted from the player's own executable, never shipped.
 *
 * The 64 tiles are the whole visual vocabulary of the overworld: terrain,
 * buildings, figures, and the custom A-Z letters the site-name banners use.
 * They live inside ultimaii.exe, and every number below is proven in
 * docs/phase4-implementation.md § CP4 and re-proven at run time by the
 * assertions in tiles.c:
 *
 *   - index table: 64 little-endian words at file 0x7BC0, first entry 0x0630,
 *     every consecutive delta exactly 66.
 *   - tile N's pixels: 0x7C42 + 66*N, preceded by a 2-byte header (04 10) on
 *     all 64 tiles without exception. asm/4A74 does `add si,2` to step over it,
 *     which is what proves it is a header and not pixel data.
 *   - one tile = 64 bytes = 16 rows x 4 bytes, 2 bits per pixel, leftmost pixel
 *     in the top two bits. asm/4A74 loops `dl = 0x10` times copying 4 bytes.
 *   - the index values are offsets into the loaded data image, not file offsets:
 *     0x7C42 - 2 - 0x630 = 0x7610, the same DS base derived independently from
 *     DS:0x26E mapping to file 0x787E.
 *
 * The cache exists so the engine pays extraction cost once. It is derived data
 * and is gitignored; it carries the source digest so a stale cache cannot
 * silently survive a swapped game copy, which is the failure mode this design
 * is built to prevent.
 */

#include <stddef.h>
#include <stdint.h>
#include "core/ctx.h"

#define U2_TILE_COUNT  64
#define U2_TILE_W      16
#define U2_TILE_H      16
#define U2_TILE_STRIDE 4                                   /* 16 px at 2bpp */
#define U2_TILE_BYTES  (U2_TILE_H * U2_TILE_STRIDE)        /* 64 */

/* Proven locations inside the executable (file offsets). */
#define U2_TILE_INDEX_FILE_OFF 0x7BC0
#define U2_TILE_FIRST_PIX_OFF  0x7C42
#define U2_TILE_FILE_STRIDE    66
#define U2_TILE_MAGIC_BYTE     0x04
#define U2_TILE_MAGIC_BYTE2    0x10

typedef enum u2_tiles_result {
    U2_TILES_OK = 0,
    U2_TILES_NOT_READY,   /* neither an executable nor a usable cache was found */
    U2_TILES_BAD_EXE,     /* executable present but the invariants failed */
    U2_TILES_BAD_CACHE,   /* cache truncated, corrupt, or from another source */
    U2_TILES_ERROR        /* I/O failure */
} u2_tiles_result;

typedef struct u2_tiles {
    uint8_t hdr[U2_TILE_COUNT][2];        /* the 04 10 headers, kept verbatim */
    uint8_t px[U2_TILE_COUNT][U2_TILE_BYTES];
    uint8_t digest[32];                   /* SHA-256 of the source executable */
    int     from_cache;                   /* loaded from cache, not extracted */
    int     unverified;                   /* no executable available to check against */
    char    source[512];                  /* what we loaded, for diagnostics */
} u2_tiles;

/* Colour index 0..3 of one pixel. CGA palette: 0 black, 1 cyan, 2 magenta,
 * 3 white — but the renderer owns that mapping, never the game logic. */
static inline int u2_tile_pixel(const u2_tiles *t, int tile, int x, int y)
{
    uint8_t b = t->px[tile][y * U2_TILE_STRIDE + (x >> 2)];
    return (b >> (6 - 2 * (x & 3))) & 3;
}

/* Try the executable spellings the shipped pack and its variants use, inside
 * the content directory. Returns U2_TILES_NOT_READY if none exist. */
u2_tiles_result u2_tiles_find_exe(char *buf, size_t bufsz, const u2_ctx *ctx);

/* Read the executable and extract, asserting every proven invariant. On any
 * mismatch the tiles struct is untouched and U2_TILES_BAD_EXE is returned —
 * a wrong binary must never produce a cache of nonsense tiles. */
u2_tiles_result u2_tiles_extract(const char *exe_path, u2_tiles *t);

/* The pure core of the above, with no I/O, so a test can feed it a crafted
 * buffer and prove the assertions actually fire. Returns 0 on success, -1 if
 * any invariant fails. Does not touch t->digest; the caller owns the hash. */
int u2_tiles_extract_from_memory(const uint8_t *mem, size_t len, u2_tiles *t);

/* Cache read/write. The cache is our own format (see tiles.c) and is atomic on
 * write, for the same reason the sector write-back is. */
u2_tiles_result u2_tiles_cache_load(const char *path, u2_tiles *t);
u2_tiles_result u2_tiles_cache_store(const char *path, const u2_tiles *t);

/*
 * The start-up policy the owner asked for: look in our own spot first, and if
 * the tiles are not there, extract them from the player's executable and write
 * them there — so a fresh install generates its own cache on first run.
 *
 * exe_path / cache_path may be NULL to use <data_dir>/ultimaii.exe and
 * <data_dir>/cache/tiles.u2tl. The cache sits with the content it was derived
 * from and not in the save directory: it is the same bytes for every save, and it
 * checks itself against the executable's digest (docs/save-scoped-worlds.md D4).
 * The resolved paths are written back when the buffers are supplied, so the
 * caller can report what happened.
 */
u2_tiles_result u2_tiles_open(u2_ctx *ctx, u2_tiles *t,
                              char *exe_out, size_t exe_sz,
                              char *cache_out, size_t cache_sz);

const char *u2_tiles_result_text(u2_tiles_result r);

#endif /* U2_TILES_H */
