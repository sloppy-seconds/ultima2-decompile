/*
 * world.c — read and write the player's own sector files.
 *
 * The contract this file exists to honour (docs/phase4-plan.md § CP4 design,
 * docs/phase4-implementation.md § CP4):
 *
 *   - the map is runtime data, never extracted content, so nothing here embeds
 *     a tile byte or a map string;
 *   - the original rewrites its own sector files (asm/2305, AH=28h), and the
 *     owner chose the faithful behaviour for `original` mode, so a write-back
 *     has to survive a crash: a half-written world file has no pristine copy in
 *     the save directory the way the PLAYER record does;
 *   - a content directory that cannot be used is reported, never worked around.
 *     A silently empty map would be worse than the original, which has no way to
 *     lose a map change.
 */

#define _POSIX_C_SOURCE 200809L   /* access(), rename() under -std=c11 */

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "core/world.h"

/* Spelling candidates for the sector name. DOS names are case-insensitive, the
 * shipped pack is lowercase, and the Galaxy patch in the fan pack renames
 * mapx -> mapg (RENGAL.BAT), so both prefixes and both cases are tried before
 * declaring a sector missing. Order is the common case first. */
static const char *const k_prefixes[] = { "mapx", "MAPX", "mapg", "MAPG" };

const char *u2_world_result_text(u2_world_result r)
{
    switch (r) {
    case U2_WORLD_OK:        return "ok";
    case U2_WORLD_NOT_READY: return "content directory is missing or not writable";
    case U2_WORLD_MISSING:   return "no such sector file";
    case U2_WORLD_SHORT:     return "sector file is shorter than the original's read";
    case U2_WORLD_ERROR:     return "I/O error";
    }
    return "unknown";
}

static const char *world_dir(const u2_ctx *ctx)
{
    return (ctx && ctx->data_dir && *ctx->data_dir) ? ctx->data_dir : ".";
}

void u2_world_path(char *buf, size_t bufsz, const u2_ctx *ctx,
                   const char *prefix, u2_sector_id id)
{
    snprintf(buf, bufsz, "%s/%s%u%u", world_dir(ctx),
             prefix ? prefix : k_prefixes[0],
             (unsigned)(id.hi & 0x0F), (unsigned)(id.lo & 0x0F));
}

/* The original's FCB drive byte is 0 — the default drive — so the game plays in
 * whatever directory it was launched from. --data-dir is that directory. It is
 * never created here: an empty world directory would look like success and show
 * an empty map, which is the failure mode this refuses to produce. */
u2_world_result u2_world_open(const u2_ctx *ctx)
{
    struct stat st;
    const char *dir = world_dir(ctx);

    if (stat(dir, &st) != 0)
        return U2_WORLD_NOT_READY;
    if (!S_ISDIR(st.st_mode))
        return U2_WORLD_NOT_READY;
    if (access(dir, R_OK | X_OK) != 0)
        return U2_WORLD_NOT_READY;
    return U2_WORLD_OK;
}

/* Writability is checked at store time, not at open time: a read-only content
 * directory is perfectly playable right up until the game needs to write a
 * sector, and that is exactly when the original would have shown its INSERT
 * prompt. Refusing to start would be a deviation nobody asked for. */
static int dir_writable(const u2_ctx *ctx)
{
    return access(world_dir(ctx), W_OK | X_OK) == 0;
}

static size_t want_bytes(int is_map)
{
    return is_map ? (size_t)U2_SECTOR_TILES : (size_t)U2_MON_TILES;
}

static int id_of(const u2_world *w, int is_map, u2_sector_id *out)
{
    if (is_map) { *out = w->map_id; return w->map_loaded; }
    *out = w->mon_id;
    return w->mon_loaded;
}

u2_world_result u2_world_load(u2_ctx *ctx, u2_world *w, int is_map, u2_sector_id id)
{
    char path[512];
    size_t want = want_bytes(is_map);
    size_t got = 0;
    int found = 0;
    const char *used = NULL;

    for (size_t i = 0; i < sizeof k_prefixes / sizeof k_prefixes[0] && !found; i++) {
        FILE *f;
        u2_world_path(path, sizeof path, ctx, k_prefixes[i], id);
        f = fopen(path, "rb");
        if (!f)
            continue;
        got = fread(is_map ? w->map : w->mon, 1, want, f);
        fclose(f);
        found = 1;
        used = k_prefixes[i];
    }

    if (!found)
        return U2_WORLD_MISSING;
    if (got != want)
        return U2_WORLD_SHORT;

    w->bytes_read = got;
    w->found_prefix = used;
    if (is_map) {
        w->map_id = id;
        w->map_loaded = 1;
        w->map_dirty = 0;
    } else {
        w->mon_id = id;
        w->mon_loaded = 1;
        w->mon_dirty = 0;
    }
    return U2_WORLD_OK;
}

/*
 * Atomic write: temp file in the same directory, then rename. Same directory
 * matters — rename(2) is atomic only within one filesystem, and a cross-device
 * rename would fail or degrade into a copy.
 *
 * The file is laid down as [live sector][whatever the original file had past the
 * read length]. A shipped 4224-byte file keeps its 128-byte tail because the
 * engine replaces only the 4096 bytes the original reads and copies the rest
 * through verbatim — the same rule the save path follows for the PLAYER record's
 * tail. A file that is exactly 4096 bytes (the Galaxy content) stays 4096.
 */
u2_world_result u2_world_store(u2_ctx *ctx, u2_world *w, int is_map)
{
    u2_sector_id id;
    char path[512], tmp[544];
    size_t want = want_bytes(is_map);
    const uint8_t *buf = is_map ? w->map : w->mon;
    FILE *src, *dst;

    if (!id_of(w, is_map, &id))
        return U2_WORLD_ERROR;
    if (!dir_writable(ctx))
        return U2_WORLD_NOT_READY;

    u2_world_path(path, sizeof path, ctx,
                  w->found_prefix ? w->found_prefix : k_prefixes[0], id);
    snprintf(tmp, sizeof tmp, "%s.u2tmp", path);

    dst = fopen(tmp, "wb");
    if (!dst)
        return U2_WORLD_ERROR;
    if (fwrite(buf, 1, want, dst) != want) {
        fclose(dst); unlink(tmp);
        return U2_WORLD_ERROR;
    }

    src = fopen(path, "rb");
    if (src) {
        if (fseek(src, (long)want, SEEK_SET) == 0) {
            uint8_t chunk[512];
            size_t n;
            while ((n = fread(chunk, 1, sizeof chunk, src)) > 0) {
                if (fwrite(chunk, 1, n, dst) != n) {
                    fclose(src); fclose(dst); unlink(tmp);
                    return U2_WORLD_ERROR;
                }
            }
        }
        fclose(src);
    }

    if (fflush(dst) != 0 || fsync(fileno(dst)) != 0) {
        fclose(dst); unlink(tmp);
        return U2_WORLD_ERROR;
    }
    if (fclose(dst) != 0) { unlink(tmp); return U2_WORLD_ERROR; }
    if (rename(tmp, path) != 0) {
        unlink(tmp);
        return U2_WORLD_ERROR;
    }

    if (is_map) w->map_dirty = 0; else w->mon_dirty = 0;
    return U2_WORLD_OK;
}
