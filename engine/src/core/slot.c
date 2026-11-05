/*
 * slot.c — see slot.h. The path arithmetic for one save game, and nothing else.
 *
 * It is its own file rather than a few statics inside save.c because two other
 * files need the same answer and must not be allowed to invent their own: world.c
 * reads its overlay from here and writes its sectors here, and the installer
 * migrates a flat save into this shape. "Where does a save live" existing twice
 * is how a player's world changes end up beside the release files again, which is
 * the defect docs/save-scoped-worlds.md was written to close.
 */

#define _POSIX_C_SOURCE 200809L   /* stat, mkdir under -std=c11 */

#include "core/slot.h"

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

#include "core/compat.h"
#include "core/ctx.h"

const char *u2_slot_name(const u2_ctx *ctx)
{
    (void)ctx;                 /* no --save flag yet (D5); this is where it lands */
    return U2_SAVE_SLOT_DEFAULT;
}

void u2_save_dir(const u2_ctx *ctx, char *buf, size_t bufsz)
{
    if (ctx && ctx->save_dir && *ctx->save_dir)
        snprintf(buf, bufsz, "%.400s", ctx->save_dir);
    else
        snprintf(buf, bufsz, "%s", U2_SAVE_DEFAULT_DIR);
}

/* Every snprintf below bounds each field explicitly, because the Makefile builds
 * with -Werror and gcc's format-truncation check only accepts the arithmetic when
 * it can bound every part of it. A slot name is at most 8 characters and a save
 * directory at most 400, which is well past any real path here and small enough
 * for gcc to prove. */
void u2_slot_dir(const u2_ctx *ctx, char *buf, size_t bufsz)
{
    char dir[430];
    u2_save_dir(ctx, dir, sizeof dir);
    snprintf(buf, bufsz, "%.429s/%.8s", dir, u2_slot_name(ctx));
}

int u2_slot_ensure(const u2_ctx *ctx)
{
    char dir[430], slot[448];
    struct stat st;

    u2_save_dir(ctx, dir, sizeof dir);
    if (stat(dir, &st) == 0) {
        if (!S_ISDIR(st.st_mode))
            return -1;             /* a file where the save directory belongs */
    } else if (mkdir(dir, 0755) != 0 && errno != EEXIST) {
        return -1;
    }

    u2_slot_dir(ctx, slot, sizeof slot);
    if (stat(slot, &st) == 0)
        return S_ISDIR(st.st_mode) ? 0 : -1;
    if (mkdir(slot, 0755) != 0 && errno != EEXIST)
        return -1;
    return 0;
}

void u2_slot_path(char *buf, size_t bufsz, const u2_ctx *ctx, const char *name)
{
    char dir[448];                        /* u2_slot_dir writes at most 438 */
    u2_slot_dir(ctx, dir, sizeof dir);
    snprintf(buf, bufsz, "%.437s/%.16s", dir, name ? name : "");
}

int u2_slot_find(const u2_ctx *ctx, const char *name, char *out, size_t bufsz)
{
    struct stat st;
    u2_slot_path(out, bufsz, ctx, name);
    if (name && *name && stat(out, &st) == 0 && !S_ISDIR(st.st_mode))
        return 1;
    out[0] = '\0';
    return 0;
}
