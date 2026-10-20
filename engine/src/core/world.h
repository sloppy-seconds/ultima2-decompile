#ifndef U2_WORLD_H
#define U2_WORLD_H

/*
 * Sector model — the map is runtime data, read from the player's own files.
 *
 * Everything here is proven in docs/phase4-implementation.md § CP4. The short
 * version, with the asm citations:
 *
 *   - The sector file name is not a string literal anywhere in the binary. It is
 *     assembled by self-patching two ASCII digits over the `F` placeholders of
 *     an inline FCB name: asm/2290 (runtime 0x2290, file 0x2490) reads DS:0x49
 *     and DS:0x4A, adds 0x30 to each, and stores them at cs:0x22bb / cs:0x22bc,
 *     which are the fifth and sixth bytes of the `MAPXFF  ` name at file
 *     0x24b7. So the name is MAPX + two decimal digits, no extension.
 *   - The read is FCB random block read through the generic DOS wrapper:
 *     AH=27h, CX=0x1000 (4096 records, record size 1), DX=[DS:0x472]. asm/22D5
 *     is the same shape for MONX with CX=0x100 into [DS:0x476].
 *   - asm/2305 writes the sector back out (AH=28h, CX=0x1000, same name), so the
 *     original mutates its own map files. Owner decision 2026-10-27: the engine
 *     does the same in `original` mode, which makes --data-dir writable content
 *     and makes an atomic write non-negotiable.
 *   - A tile is ONE BYTE, indexed y*64 + x (asm/50B3_map_tile_ptr: shl $6 of
 *     DS:0x24, add DS:0x23, add [DS:0x472]). A sector is therefore 64x64 tiles
 *     = 4096 bytes, which is exactly the CX of the read.
 *   - The shipped files are 4224 bytes: 4096 tiles plus a 128-byte tail that is
 *     never read. Do NOT assert 4224 — the Galaxy content in the fan pack ships
 *     sectors of exactly 4096 with no tail, and the read is 4096 either way.
 *   - The second digit is the SITE KIND, not a coordinate: asm/343F prints
 *     "-TOWN" before selecting 2 and "-TOWER" before 4, asm/243E selects 0 for
 *     the overworld, and asm/2423 branches on [DS:4A]==0 for overworld-vs-site.
 *     The fan pack's own file list agrees (10 Mercury overworld, 15 Mercury
 *     dungeon, 32 Mars town, 41 Jupiter village).
 *
 * No game bytes live in this file or in world.c. The engine ships zero content;
 * the tiles come from the player's directory at run time.
 */

#include <stddef.h>
#include <stdint.h>
#include "core/ctx.h"

#define U2_SECTOR_EDGE  64                       /* asm/50B3: shl $6 */
#define U2_SECTOR_TILES (U2_SECTOR_EDGE * U2_SECTOR_EDGE) /* 4096 = CX at asm/2290 */
#define U2_MON_TILES    256                      /* CX at asm/22D5 */
#define U2_MAP_PREFIXES 4                        /* mapx / MAPX / mapg / MAPG */

/* Site kinds, i.e. the second digit. Proven for 0, 2 and 4 by the strings at
 * asm/243E and asm/343F; 1, 3 and 5 come from the fan pack's file list and are
 * marked inferred until the asm says so directly. */
typedef enum u2_site_kind {
    U2_SITE_OVERWORLD = 0,  /* proven: asm/243E, asm/2423 */
    U2_SITE_VILLAGE   = 1,  /* inferred: asm/342A selects 1 */
    U2_SITE_TOWN      = 2,  /* proven: asm/343F prints "-TOWN" */
    U2_SITE_CASTLE    = 3,  /* inferred: mapx03 exists, TLKX03 is "Legends Castle" */
    U2_SITE_TOWER     = 4,  /* proven: asm/343F prints "-TOWER" */
    U2_SITE_DUNGEON   = 5   /* inferred: fan pack names MAPG15/45 as dungeons */
} u2_site_kind;

typedef enum u2_world_result {
    U2_WORLD_OK = 0,        /* sector read / written */
    U2_WORLD_NOT_READY,     /* content dir missing or unwritable: the "insert disk" analogue */
    U2_WORLD_MISSING,       /* dir is fine, this sector file is not there */
    U2_WORLD_SHORT,         /* file exists but is smaller than the bytes the original reads */
    U2_WORLD_ERROR          /* unexpected I/O failure */
} u2_world_result;

/* A sector is named by two decimal digits: high = world / planet, low = site kind. */
typedef struct u2_sector_id {
    uint8_t hi;
    uint8_t lo;
} u2_sector_id;

/*
 * One resident sector at a time. The viewport never straddles a file: crossing
 * x or y >= 0x40 reloads the sector (asm/242D, asm/2434 -> asm/243E), so there
 * is no second buffer and no seam between adjacent files to get wrong.
 */
typedef struct u2_world {
    uint8_t      map[U2_SECTOR_TILES];
    uint8_t      mon[U2_MON_TILES];
    u2_sector_id map_id;
    u2_sector_id mon_id;
    int          map_loaded;
    int          mon_loaded;
    int          map_dirty;   /* set by a tile write; only dirty sectors are stored */
    int          mon_dirty;
    const char  *found_prefix;/* which spelling the last successful load used */
    size_t       bytes_read;  /* diagnostics and tests */
} u2_world;

/* Tile addressing, exactly as asm/50B3 computes it. Coordinates are masked to
 * the sector by the caller, which is what the original does at the edges. */
static inline int u2_world_tile_index(int x, int y)
{
    return ((y & (U2_SECTOR_EDGE - 1)) * U2_SECTOR_EDGE) + (x & (U2_SECTOR_EDGE - 1));
}

static inline uint8_t u2_world_tile_at(const u2_world *w, int x, int y)
{
    return w->map[u2_world_tile_index(x, y)];
}

/* Marking dirty here is deliberate: the only way to change a tile is through
 * this function, so a sector cannot be mutated without the write-back knowing. */
static inline void u2_world_tile_put(u2_world *w, int x, int y, uint8_t v)
{
    w->map[u2_world_tile_index(x, y)] = v;
    w->map_dirty = 1;
}

/* "<dir>/<prefix><hi><lo>" — the caller supplies the prefix spelling. */
void u2_world_path(char *buf, size_t bufsz, const u2_ctx *ctx,
                   const char *prefix, u2_sector_id id);

/* Is the content directory usable? Never creates it: unlike the save directory
 * there is nothing to seed, and inventing an empty world directory would hide a
 * wrong --data-dir behind a silent empty map. */
u2_world_result u2_world_open(const u2_ctx *ctx);

/* Read a sector. Tries the mapx/MAPX/mapg/MAPG spellings in order, because DOS
 * names are case-insensitive and the Galaxy patch renames mapx -> mapg. */
u2_world_result u2_world_load(u2_ctx *ctx, u2_world *w, int is_map, u2_sector_id id);

/* Write a sector back, atomically (temp file + rename in the same directory).
 * Callers must only store sectors that are dirty. */
u2_world_result u2_world_store(u2_ctx *ctx, u2_world *w, int is_map);

/* Human-readable reason for the last failure, for the INSERT-style message. */
const char *u2_world_result_text(u2_world_result r);

#endif /* U2_WORLD_H */
