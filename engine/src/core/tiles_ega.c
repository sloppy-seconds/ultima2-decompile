/*
 * tiles_ega.c — load the fan pack's 16-colour EGATILES atlas into the engine.
 *
 * See tiles_ega.h for the format evidence and the copyright posture. The short
 * version: EGATILES is a flat 65x128 array of 4bpp tiles with no header, and
 * tile N lines up with the CGA atlas's tile N, so the engine reads the first 64
 * and hands them to the EGA blit in core/frame.c.
 *
 * Zero game content is committed, so — exactly like the CGA extractor — the art
 * has to arrive at run time from a file the player owns. A missing or short file
 * is a clean NOT_READY, never a half-loaded atlas: the caller keeps the CGA path
 * and the screen is no worse than before this module existed.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define _POSIX_C_SOURCE 200809L   /* dirent, stat, strcasecmp under -std=c11 (mingw provides all) */
#include <dirent.h>
#include <strings.h>
#include <sys/stat.h>

#include "core/tiles_ega.h"

/* The theme name maps to a path under the themes dir. The names are matched
 * case-insensitively because a copy that came off a FAT volume can arrive with
 * them uppercased, and refusing to look is indistinguishable from the theme not
 * existing. */
static int theme_relpath(const char *theme, char *out, size_t n)
{
    if (!theme || !*theme || strcmp(theme, "default") == 0)
        return snprintf(out, n, "EGATILES") < (int)n ? 0 : -1;

    char up[16];
    size_t i = 0;
    for (; theme[i] && i + 1 < sizeof up; i++) {
        const char c = theme[i];
        up[i] = (c >= 'a' && c <= 'z') ? (char)(c - 32) : c;
    }
    up[i] = '\0';
    return snprintf(out, n, "EGATHEME.%s/EGATILES", up) < (int)n ? 0 : -1;
}

/* Candidate themes directories, in resolution order (docs/ega-graphics-plan.md
 * § 2). An explicit --ega-theme-dir is authoritative: the search is confined to
 * it, so naming a directory and not finding the theme there is a refusal rather
 * than a silent hit in a fallback. With no explicit dir, fall through --data-dir
 * and then the two bare-relative defaults where the Exodus upgrade package sits
 * on a dev checkout (the repo's references/ dir, one level up from engine/).
 * Returns the count. */
static int ega_candidates(u2_ctx *ctx, const char **cands)
{
    if (ctx && ctx->ega_theme_dir && *ctx->ega_theme_dir) {
        cands[0] = ctx->ega_theme_dir;
        return 1;
    }
    int nc = 0;
    if (ctx && ctx->data_dir && *ctx->data_dir)
        cands[nc++] = ctx->data_dir;
    cands[nc++] = "../references/u2upgrade";
    cands[nc++] = "references/u2upgrade";
    return nc;
}

static int path_is_dir(const char *p)
{
    struct stat st;
    return p && *p && stat(p, &st) == 0 && S_ISDIR(st.st_mode);
}

/* Size of a regular file, or -1 if it is not one. */
static long path_size(const char *p)
{
    struct stat st;
    if (!p || stat(p, &st) != 0 || !S_ISREG(st.st_mode)) return -1;
    return (long)st.st_size;
}

/* Try to read a whole EGATILES from `path`. On success fills t->px with the
 * first 64 tiles and returns U2_TILES_EGA_OK. A file that exists but is too
 * short is U2_TILES_EGA_BAD (present but wrong), distinct from absent. */
static u2_tiles_ega_result try_load(const char *path, const char *dir,
                                    u2_tiles_ega *t)
{
    FILE *f = fopen(path, "rb");
    if (!f)
        return U2_TILES_EGA_NOT_READY;

    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return U2_TILES_EGA_ERROR; }
    const long sz = ftell(f);
    rewind(f);
    if (sz < (long)(U2_TILE_COUNT * U2_TILE_EGA_BYTES)) {
        fclose(f);
        return U2_TILES_EGA_BAD;
    }
    const size_t got = fread(t->px, 1, sizeof t->px, f);
    fclose(f);
    if (got != sizeof t->px)
        return U2_TILES_EGA_BAD;

    snprintf(t->source, sizeof t->source, "%s", path);
    snprintf(t->dir, sizeof t->dir, "%s", dir ? dir : "");
    t->loaded = 1;
    return U2_TILES_EGA_OK;
}

u2_tiles_ega_result u2_tiles_ega_open_in(u2_ctx *ctx, u2_tiles_ega *t,
                                         const char *dir, const char *theme)
{
    (void)ctx;
    if (!t || !dir) return U2_TILES_EGA_ERROR;
    t->loaded = 0;
    t->source[0] = '\0';
    t->dir[0] = '\0';

    char rel[64];
    if (theme_relpath(theme, rel, sizeof rel) != 0)
        return U2_TILES_EGA_ERROR;

    char path[600];
    if (snprintf(path, sizeof path, "%s/%s", dir, rel) >= (int)sizeof path)
        return U2_TILES_EGA_ERROR;
    return try_load(path, dir, t);
}

u2_tiles_ega_result u2_tiles_ega_open(u2_ctx *ctx, u2_tiles_ega *t,
                                      const char *theme)
{
    if (!t) return U2_TILES_EGA_ERROR;
    t->loaded = 0;
    t->source[0] = '\0';

    char rel[64];
    if (theme_relpath(theme, rel, sizeof rel) != 0)
        return U2_TILES_EGA_ERROR;

    const char *cands[4];
    const int nc = ega_candidates(ctx, cands);

    char path[512];
    u2_tiles_ega_result last = U2_TILES_EGA_NOT_READY;
    for (int i = 0; i < nc; i++) {
        if (snprintf(path, sizeof path, "%s/%s", cands[i], rel) >= (int)sizeof path)
            continue;
        const u2_tiles_ega_result r = try_load(path, cands[i], t);
        if (r == U2_TILES_EGA_OK)
            return r;
        if (r == U2_TILES_EGA_BAD)      /* present but wrong: stop, do not fall through */
            return r;
        last = r;
    }
    return last;
}

/* Map a directory entry name to a theme name, or NULL if it is not a theme.
 * "EGATILES" (case-insensitive) is "default"; "EGATHEME.<X>" is "<x>" lower-
 * cased. This is the inverse of theme_relpath, so a name produced here loads
 * back through u2_tiles_ega_open_in unchanged. */
static int entry_to_theme(const char *d_name, char *out, size_t n)
{
    if (strcasecmp(d_name, "EGATILES") == 0)
        return snprintf(out, n, "default") < (int)n ? 1 : 0;
    if (strncasecmp(d_name, "EGATHEME.", 9) == 0) {
        char low[24];
        size_t i = 0;
        const char *s = d_name + 9;
        for (; s[i] && i + 1 < sizeof low; i++) {
            const char c = s[i];
            low[i] = (c >= 'A' && c <= 'Z') ? (char)(c + 32) : c;
        }
        low[i] = '\0';
        return snprintf(out, n, "%s", low) < (int)n ? 1 : 0;
    }
    return 0;
}

static int cmp_str(const void *a, const void *b)
{
    return strcmp(*(const char *const *)a, *(const char *const *)b);
}

int u2_tiles_ega_next_theme(const char *dir, const char *cur,
                            char *next, size_t n)
{
    if (!dir || !*dir || !next || n == 0) return 0;
    DIR *d = opendir(dir);
    if (!d) return 0;

    /* Collect the theme names, then sort them so the cycle order is the
     * alphabetical order of the directory's themes rather than readdir's
     * arbitrary order. A fixed cap is fine: no pack ships more than a handful. */
    #define U2_EGA_MAX_THEMES 32
    static char names[U2_EGA_MAX_THEMES][32];
    static const char *ptrs[U2_EGA_MAX_THEMES];
    int count = 0;
    struct dirent *e;
    while ((e = readdir(d)) != NULL && count < U2_EGA_MAX_THEMES) {
        if (strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0)
            continue;
        char theme[32];
        if (!entry_to_theme(e->d_name, theme, sizeof theme))
            continue;
        /* EGATILES must be a file and EGATHEME.* a directory; a stat keeps a
         * stray file named EGATHEME.FOO from being read as a theme dir. */
        char full[600];
        if (snprintf(full, sizeof full, "%s/%s", dir, e->d_name) < (int)sizeof full) {
            struct stat st;
            if (stat(full, &st) == 0) {
                const int want_dir = (strncasecmp(e->d_name, "EGATHEME.", 9) == 0);
                if (S_ISDIR(st.st_mode) != want_dir)
                    continue;
            }
        }
        snprintf(names[count], 32, "%s", theme);
        ptrs[count] = names[count];
        count++;
    }
    closedir(d);
    if (count == 0) return 0;

    qsort(ptrs, (size_t)count, sizeof ptrs[0], cmp_str);

    /* Find cur in the sorted list and take the next, wrapping. Absent cur (or a
     * NULL cur) yields the first theme, so the very first Ctrl-T from an unknown
     * state still lands on a real theme. */
    int idx = -1;
    for (int i = 0; i < count; i++)
        if (cur && strcmp(ptrs[i], cur) == 0) { idx = i; break; }
    const int nxt = (idx < 0) ? 0 : (idx + 1) % count;
    snprintf(next, n, "%s", ptrs[nxt]);
    return count;
    #undef U2_EGA_MAX_THEMES
}

/*
 * Fail-fast launch check for --ega. Confirms the chosen theme's EGATILES is
 * present and loadable WITHOUT filling a tile struct, so main() can refuse to
 * start rather than fall back to CGA after the title screen.
 *
 * The owner ruled (2026-11-04) that --ega is strict: it refuses to start when the
 * themes directory does not exist or the chosen theme is not in it. This
 * supersedes the plan's earlier "never fail a launch, fall back to CGA" default
 * (docs/ega-graphics-plan.md § 2/§ 7). On any non-OK result `err` holds a
 * one-line, actionable reason naming the directory searched.
 */
u2_tiles_ega_result u2_tiles_ega_validate(u2_ctx *ctx, char *err, size_t n)
{
    const char *theme = (ctx && ctx->ega_theme && *ctx->ega_theme)
                      ? ctx->ega_theme : U2_EGA_THEME_DEFAULT;
    char rel[64];
    if (theme_relpath(theme, rel, sizeof rel) != 0) {
        if (err) snprintf(err, n, "invalid theme name: %s", theme);
        return U2_TILES_EGA_ERROR;
    }

    /* An explicitly named themes dir that does not exist is the clearest error,
     * and it is checked before the fall-through search so a typo in
     * --ega-theme-dir is reported as such rather than as "theme not found". */
    if (ctx && ctx->ega_theme_dir && *ctx->ega_theme_dir &&
        !path_is_dir(ctx->ega_theme_dir)) {
        if (err) snprintf(err, n, "themes dir does not exist: %s", ctx->ega_theme_dir);
        return U2_TILES_EGA_NOT_READY;
    }

    const char *cands[4];
    const int nc = ega_candidates(ctx, cands);
    int any_dir = 0;
    char searched[256];
    searched[0] = '\0';
    size_t used = 0;

    for (int i = 0; i < nc; i++) {
        const int exists = path_is_dir(cands[i]);
        if (exists) any_dir = 1;
        if (err && used + 1 < sizeof searched) {
            const int w = snprintf(searched + used, sizeof searched - used,
                                   "%s%s", used ? ", " : "", cands[i]);
            if (w > 0) used += (size_t)w;
        }
        if (!exists) continue;
        char path[600];
        if (snprintf(path, sizeof path, "%s/%s", cands[i], rel) >= (int)sizeof path)
            continue;
        const long sz = path_size(path);
        if (sz >= (long)(U2_TILE_COUNT * U2_TILE_EGA_BYTES))
            return U2_TILES_EGA_OK;
        if (sz >= 0) {   /* present but too short: a real file, wrong shape */
            if (err) snprintf(err, n, "EGATILES present but wrong size (%ld B): %s",
                              sz, path);
            return U2_TILES_EGA_BAD;
        }
    }

    if (err) {
        if (!any_dir)
            snprintf(err, n, "no EGA themes directory found (looked in: %s)", searched);
        else
            snprintf(err, n, "theme '%s' not found (looked in: %s)", theme, searched);
    }
    return U2_TILES_EGA_NOT_READY;
}

const char *u2_tiles_ega_result_text(u2_tiles_ega_result r)
{
    switch (r) {
    case U2_TILES_EGA_OK:        return "ok";
    case U2_TILES_EGA_NOT_READY: return "no EGATILES in any themes dir";
    case U2_TILES_EGA_BAD:       return "EGATILES present but wrong size";
    case U2_TILES_EGA_ERROR:     return "I/O error";
    }
    return "unknown";
}
