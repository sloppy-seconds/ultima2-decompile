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
 * mapx -> mapg and monx -> mong (RENGAL.BAT; `updated/` carries MAPG10.. and
 * MONG10.. beside the lowercase originals), so both prefixes and both cases are
 * tried before declaring a sector missing. Order is the common case first.
 *
 * The two lists are separate on purpose. An earlier version shared one map-only
 * list, so `is_map == 0` read a *map* file into the monster buffer and the
 * creature table was silently wrong rather than missing — caught by
 * engine/tests/monsters_check.c, which could not load monx31 at all. */
static const char *const k_map_prefixes[] = { "mapx", "MAPX", "mapg", "MAPG" };
static const char *const k_mon_prefixes[] = { "monx", "MONX", "mong", "MONG" };

static const char *const *prefix_list(int is_map, size_t *count)
{
    if (is_map) {
        *count = sizeof k_map_prefixes / sizeof k_map_prefixes[0];
        return k_map_prefixes;
    }
    *count = sizeof k_mon_prefixes / sizeof k_mon_prefixes[0];
    return k_mon_prefixes;
}

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
             prefix ? prefix : k_map_prefixes[0],
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

    const char *const *prefixes;
    size_t nprefixes;
    prefixes = prefix_list(is_map, &nprefixes);

    for (size_t i = 0; i < nprefixes && !found; i++) {
        FILE *f;
        u2_world_path(path, sizeof path, ctx, prefixes[i], id);
        f = fopen(path, "rb");
        if (!f)
            continue;
        got = fread(is_map ? w->map : w->mon, 1, want, f);
        fclose(f);
        found = 1;
        used = prefixes[i];
    }

    if (!found)
        return U2_WORLD_MISSING;
    if (got != want)
        return U2_WORLD_SHORT;

    w->bytes_read = got;
    /* Per kind, never one shared field: see the note on the struct. The overworld loads
     * map then monsters into the same world, so a single field would always say "monx"
     * by the time anything is stored. */
    if (is_map) w->map_prefix = used; else w->mon_prefix = used;
    if (is_map) {
        w->map_id = id;
        w->map_loaded = 1;
        w->map_dirty = 0;
        /* The pristine copy the creature stamp is drawn over. Set here and only
         * here, so a stamped grid can always be rebuilt (see world.h). */
        memcpy(w->map_base, w->map, U2_SECTOR_TILES);
    } else {
        w->mon_id = id;
        w->mon_loaded = 1;
        w->mon_dirty = 0;
    }
    return U2_WORLD_OK;
}

/* asm/22D5's dialogue read. Prefixes mirror the map/monster lists because the shipped pack
 * carries both spellings, and a missing tlkx is normal rather than an error: several sectors
 * ship no dialogue file at all, and the caller must then fall back rather than print noise. */
static const char *const k_tlk_prefixes[] = { "tlkx", "TLKX", "tlkg", "TLKG" };

u2_world_result u2_world_load_tlkx(u2_ctx *ctx, u2_world *w, u2_sector_id id)
{
    char path[512];
    size_t got = 0;
    const char *used = NULL;

    for (size_t i = 0; i < sizeof k_tlk_prefixes / sizeof k_tlk_prefixes[0]; i++) {
        FILE *f;
        u2_world_path(path, sizeof path, ctx, k_tlk_prefixes[i], id);
        f = fopen(path, "rb");
        if (!f)
            continue;
        got = fread(w->tlkx, 1, U2_TLKX_BYTES, f);
        fclose(f);
        used = k_tlk_prefixes[i];
        break;
    }

    if (!used)
        return U2_WORLD_MISSING;
    if (got != U2_TLKX_BYTES)
        return U2_WORLD_SHORT;

    w->tlkx_prefix = used;
    w->tlkx_id = id;
    w->tlkx_loaded = 1;
    return U2_WORLD_OK;
}

/* asm/154E, in address order:
 *
 *   si = AL ; di = [DS:476]
 *   1564  al = es:[di] ; cmp 0 ; je 156E          scan forward to the next NUL
 *   156B  inc di ; jmp 1564
 *   156E  dec si ; je 1573 ; else jmp 156B        count boundaries until si reaches 0
 *   1573  inc di ; al = es:[di] ; cmp 0 ; je 1580 step onto the record; emit to its NUL
 *   157B  call emit_char ; jmp 1573
 *
 * Because byte 0 of the buffer is itself a NUL, the first `scan to NUL` succeeds without
 * moving, so index 1 selects the first real record. That is the whole reason the role byte
 * maps as role - 0x80 and no further offset is needed.
 *
 * The scan is bounded by the buffer on purpose. The original walks a 256-byte buffer with no
 * bound check and stops at whatever NUL it finds; a role byte pointing past the end would run
 * off into adjacent memory. Here it returns -1, which the caller renders as no line rather
 * than as garbage. */
int u2_world_tlkx_record(const u2_world *w, int index, char *out, size_t outsz)
{
    if (!w || !out || outsz == 0)
        return -1;
    out[0] = '\0';
    if (!w->tlkx_loaded || index < 1)
        return -1;

    size_t i = 0;
    for (int n = 0; n < index; n++) {
        while (i < U2_TLKX_BYTES && w->tlkx[i] != 0)
            i++;
        if (i >= U2_TLKX_BYTES)
            return -1;
        i++;                       /* step past the boundary NUL */
    }
    if (i >= U2_TLKX_BYTES)
        return -1;

    size_t len = 0;
    while (i < U2_TLKX_BYTES && w->tlkx[i] != 0) {
        if (len + 1 >= outsz)
            break;                 /* truncate rather than overrun the caller's buffer */
        out[len++] = (char)(w->tlkx[i] & 0x7Fu);
        i++;
    }
    out[len] = '\0';
    return (int)len;
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
    size_t nprefixes = 0;
    const uint8_t *buf = is_map ? w->map : w->mon;
    FILE *src, *dst;

    if (!id_of(w, is_map, &id))
        return U2_WORLD_ERROR;
    if (!dir_writable(ctx))
        return U2_WORLD_NOT_READY;

    /* The prefix must belong to the kind being written. This is the loud version of the
     * invariant the shared field used to violate: a map buffer reaching a monx filename
     * (or the reverse) is not a naming detail, it silently destroys the other file and
     * reports success. Refusing costs a save; writing the wrong file costs the player's
     * creature data, and there is no backup in the content directory.
     *
     * want_bytes() is checked the same way for the same reason: the sizes differ (4096 vs
     * 256), so a mismatch here is the other half of the same class of mistake. */
    const char *const *ok_prefixes = prefix_list(is_map, &nprefixes);
    const char *want_prefix = is_map ? w->map_prefix : w->mon_prefix;
    if (want_prefix) {
        int legal = 0;
        for (size_t i = 0; i < nprefixes; i++)
            if (strcmp(want_prefix, ok_prefixes[i]) == 0) { legal = 1; break; }
        if (!legal)
            return U2_WORLD_ERROR;
    }

    u2_world_path(path, sizeof path, ctx,
                  want_prefix ? want_prefix : prefix_list(is_map, &nprefixes)[0], id);
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
