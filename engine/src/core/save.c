/*
 * Player save record implementation. See save.h for the evidence behind the
 * layout and the disk model.
 *
 * Portability note: mkdir() and stat() are POSIX. The engine's stated target is
 * Linux (docs/phase4-plan.md §1), and this is the only place the engine touches
 * the filesystem for gameplay, so the dependency lives here and nowhere else.
 * A Windows port would need an alternative for these two calls and nothing more.
 */

#define _POSIX_C_SOURCE 200809L   /* mkdir, stat under -std=c11; stated rather
                                     than left to the compiler's default */

#include <errno.h>
#include <dirent.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>
#include <sys/types.h>

#include "core/save.h"
#include "core/compat.h"

_Static_assert(U2_OFF(name) == U2_PLAYER_RECORD_DS,
               "the saved record starts at the name field");
_Static_assert(U2_PLAYER_FILE_SIZE > U2_PLAYER_RECORD_SIZE,
               "the file is larger than the record; see save.h");
_Static_assert(U2_PLAYER_BLANK_MARK_OFF >= U2_PLAYER_RECORD_SIZE,
               "the blank marker must live in the tail, not the record");

#define U2_SAVE_DEFAULT_DIR "saves"
#define U2_SAVE_FILE_NAME   "PLAYER"

void u2_save_blank_template(uint8_t *buf)
{
    memset(buf, 0, U2_PLAYER_FILE_SIZE);
    buf[U2_PLAYER_BLANK_MARK_OFF] = U2_PLAYER_BLANK_MARK_BYTE;
}

static const char *save_dir(const u2_ctx *ctx)
{
    return (ctx->save_dir && *ctx->save_dir) ? ctx->save_dir : U2_SAVE_DEFAULT_DIR;
}

/* Resolve the save file's name in a directory, case-insensitively.
 *
 * The original asks for "PLAYER  " in DOS FCB form (the literal is at file
 * 0x09A2 and four more sites), and DOS filenames are case-insensitive, so the
 * spelling a distribution happens to ship is arbitrary: this pack spells it
 * `player`. On a case-sensitive filesystem that split is a silent fresh start,
 * because we open PLAYER, do not find player, and go on to create a second file.
 *
 * So prefer the exact name the original used, and only when it is absent adopt a
 * case variant -- for reading AND writing. Adopting it for writing is the part
 * that matters: resolving on read alone would leave two copies diverging, which
 * is already what a played install looks like on disk.
 *
 * If several variants exist, exact PLAYER wins (handled before the scan), then
 * the pack's lowercase `player`, then whatever else matches. */
static void resolve_save_name(const char *dir, char *out, size_t outsz)
{
    snprintf(out, outsz, "%s", U2_SAVE_FILE_NAME);

    char exact[512];
    snprintf(exact, sizeof exact, "%s/%s", dir, U2_SAVE_FILE_NAME);
    struct stat st;
    if (stat(exact, &st) == 0) return;          /* the original's own spelling */

    DIR *d = opendir(dir);
    if (!d) return;
    char best[256] = "";
    int best_rank = 0;
    struct dirent *e;
    while ((e = readdir(d)) != NULL) {
        if (strcasecmp(e->d_name, U2_SAVE_FILE_NAME) != 0) continue;
        const int rank = (strcmp(e->d_name, "player") == 0) ? 2 : 1;
        if (rank > best_rank) {
            best_rank = rank;
            snprintf(best, sizeof best, "%s", e->d_name);
        }
    }
    closedir(d);
    if (best_rank > 0) snprintf(out, outsz, "%s", best);
}

void u2_save_path(const u2_ctx *ctx, char *buf, size_t bufsz)
{
    char name[256];
    resolve_save_name(save_dir(ctx), name, sizeof name);
    snprintf(buf, bufsz, "%s/%s", save_dir(ctx), name);
}

/* Read the whole PLAYER file. Returns bytes read, or -1 on failure. A file
 * longer than the expected size is reported as too big rather than truncated,
 * so a wrong path is never silently rewritten. */
static long read_file(const char *path, uint8_t *buf, size_t cap, long *size_out)
{
    FILE *f = fopen(path, "rb");
    struct stat st;
    if (!f) return -1;
    if (size_out && stat(path, &st) == 0) *size_out = (long)st.st_size;
    long n = (long)fread(buf, 1, cap, f);
    fclose(f);
    return n;
}

u2_save_result u2_save_ensure(u2_ctx *ctx)
{
    char path[512];
    const char *dir = save_dir(ctx);
    struct stat st;

    if (stat(dir, &st) == 0) {
        if (!S_ISDIR(st.st_mode)) return U2_SAVE_NOT_READY;
    } else if (mkdir(dir, 0755) != 0 && errno != EEXIST) {
        return U2_SAVE_NOT_READY;
    }

    u2_save_path(ctx, path, sizeof path);
    if (stat(path, &st) != 0) {
        uint8_t blank[U2_PLAYER_FILE_SIZE];
        u2_save_blank_template(blank);
        FILE *f = fopen(path, "wb");
        if (!f) return U2_SAVE_NOT_READY;
        size_t n = fwrite(blank, 1, sizeof blank, f);
        if (fclose(f) != 0 || n != sizeof blank) return U2_SAVE_ERROR;
        ctx->save_seeded = 1;
        return U2_SAVE_BLANK;
    }
    /* A file too small to hold a record is not something we overwrite. */
    if (st.st_size < U2_PLAYER_RECORD_SIZE) return U2_SAVE_NOT_READY;
    return U2_SAVE_OK;
}

u2_save_result u2_save_load(u2_ctx *ctx)
{
    char path[512];
    uint8_t file[U2_PLAYER_FILE_SIZE];
    long size = -1;
    long n;

    u2_save_path(ctx, path, sizeof path);
    n = read_file(path, file, sizeof file, &size);
    if (n < 0) return U2_SAVE_NOT_READY;
    if (n < U2_PLAYER_RECORD_SIZE || size > U2_PLAYER_FILE_SIZE) {
        return U2_SAVE_NOT_READY;
    }
    memcpy(U2_REC(&ctx->state), file, U2_PLAYER_RECORD_SIZE);
    /* The original's own blank test: asm/5400 `cmp byte [0x36],0`. */
    return U2_REC_RO(&ctx->state)[0] ? U2_SAVE_OK : U2_SAVE_BLANK;
}

u2_save_result u2_save_store(const u2_ctx *ctx)
{
    char path[512];
    uint8_t file[U2_PLAYER_FILE_SIZE];
    long size = -1;
    u2_save_path(ctx, path, sizeof path);
    long n = read_file(path, file, sizeof file, &size);

    if (n >= U2_PLAYER_RECORD_SIZE && size <= U2_PLAYER_FILE_SIZE) {
        if (n < U2_PLAYER_FILE_SIZE) {
            memset(file + n, 0, U2_PLAYER_FILE_SIZE - (size_t)n);
        }
    } else if (n >= 0 && size <= U2_PLAYER_FILE_SIZE) {
        /* Existing but short: keep what is there and pad, rather than
         * discarding a file the user may have produced some other way. */
        memset(file + (n < 0 ? 0 : n), 0, U2_PLAYER_FILE_SIZE - (size_t)(n < 0 ? 0 : n));
    } else {
        u2_save_blank_template(file);
    }

    /* Only the record is replaced; the tail survives, as it does on a real disk. */
    memcpy(file, U2_REC_RO(&ctx->state), U2_PLAYER_RECORD_SIZE);

    FILE *f = fopen(path, "wb");
    if (!f) return U2_SAVE_NOT_READY;
    size_t w = fwrite(file, 1, sizeof file, f);
    if (fclose(f) != 0 || w != sizeof file) return U2_SAVE_ERROR;
    return U2_SAVE_OK;
}

int u2_save_record_present(const u2_ctx *ctx)
{
    return U2_REC_RO(&ctx->state)[0] != 0;
}
