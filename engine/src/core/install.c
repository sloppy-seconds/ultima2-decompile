/*
 * install.c — see install.h. The rules are in the header and in
 * docs/install-design.md; this file is their implementation and nothing else.
 */

#define _POSIX_C_SOURCE 200809L   /* dirent, stat, mkdir, rename under -std=c11 */

#include "core/install.h"

#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>
#include <unistd.h>

#include "core/compat.h"
#include "core/copy.h"
#include "core/fmtowns.h"
#include "core/sha256.h"

#define MAX_ROWS     1024
#define NAME_LEN     128
#define HASH_LEN     U2_HASH_LEN   /* the width core/copy.h hashes to */
#define MAX_FILE_COPY (8u * 1024u * 1024u)

typedef struct {
    char dst[512];                /* path relative to the target root */
    char src[600];                /* where it came from, as the player wrote it */
    long size;
    char sha[HASH_LEN + 1];
} row;

/* ---------------------------------------------------------------- classify */

/* The picture bases the pack ships, lowercase. */
static const char *const k_pic_bases[] = { "cas", "dng", "dra", "min", "out", "spa", "twn" };

static int two_digits(const char *s)
{
    return isdigit((unsigned char)s[0]) && isdigit((unsigned char)s[1]);
}

int u2_install_classify(const char *name, int *galaxy_spelling)
{
    char lo[NAME_LEN];
    const size_t n = strlen(name);

    if (galaxy_spelling)
        *galaxy_spelling = 0;
    if (!name || n == 0 || n >= sizeof lo)
        return 0;
    for (size_t i = 0; i < n; i++)
        lo[i] = (char)tolower((unsigned char)name[i]);
    lo[n] = '\0';

    /* The Galaxy spellings are what the engine's patch layer is consulted for, so
     * they are also what decides which layer a file belongs in. */
    if (n == 6 && two_digits(lo + 4) &&
        (!strncmp(lo, "mapg", 4) || !strncmp(lo, "mong", 4) || !strncmp(lo, "tlkg", 4))) {
        if (galaxy_spelling)
            *galaxy_spelling = 1;
        return 1;
    }
    if (n == 6 && two_digits(lo + 4) &&
        (!strncmp(lo, "mapx", 4) || !strncmp(lo, "monx", 4) || !strncmp(lo, "tlkx", 4)))
        return 1;

    if (!strcmp(lo, "monsters") || !strcmp(lo, "player") || !strcmp(lo, "ultimaii.exe"))
        return 1;

    /* piccas / PICDNG / PIC*-E and friends: the sidecar art the pack ships beside
     * the maps. Both the plain and the -E spelling are content. */
    if (!strncmp(lo, "pic", 3) && (n == 6 || (n == 8 && !strncmp(lo + 6, "-e", 2))))
        for (size_t i = 0; i < sizeof k_pic_bases / sizeof k_pic_bases[0]; i++)
            if (!strncmp(lo + 3, k_pic_bases[i], 3))
                return 1;

    return 0;
}

/* ------------------------------------------------------------------ files
 * The primitives are core/copy.c, shared with the theme builder so the two
 * builders cannot disagree about what "copied" means. */

static long file_size(const char *p) { return u2_file_size(p); }

static int is_dirpath(const char *p) { return u2_is_dir(p); }

static int hash_file(const char *p, char out[HASH_LEN + 1], long *out_size)
{
    return u2_hash_file(p, out, out_size);
}

static int mkdir_p(const char *path) { return u2_mkdir_p(path); }

/* Copy src to dst byte-for-byte, then prove it by hashing the destination back.
 * A copy that "succeeded" and landed wrong is the failure this whole tool is built
 * to refuse, so the proof is not optional diagnostics — it is the return value. */
static int copy_verified(const char *src, const char *dst, long want_size,
                         const char want_sha[HASH_LEN + 1])
{
    return u2_copy_verified(src, dst, want_size, want_sha);
}

/* ------------------------------------------------------------------ target */

typedef enum { T_ABSENT, T_EMPTY, T_MINE, T_FOREIGN, T_NOTDIR } t_state;

static int dir_is_empty(const char *to)
{
    DIR *d = opendir(to);
    if (!d)
        return 0;
    struct dirent *e;
    int empty = 1;
    while ((e = readdir(d))) {
        if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, ".."))
            continue;
        empty = 0;
        break;
    }
    closedir(d);
    return empty;
}

static t_state inspect_target(const char *to)
{
    if (!is_dirpath(to)) {
        struct stat st;
        if (stat(to, &st) == 0)
            return T_NOTDIR;
        return T_ABSENT;
    }
    if (dir_is_empty(to))
        return T_EMPTY;
    char m[1024];
    snprintf(m, sizeof m, "%.1000s/%s", to, U2_INSTALL_MANIFEST);
    return file_size(m) > 0 ? T_MINE : T_FOREIGN;
}

/* ---------------------------------------------------------------- manifest */

static void manifest_path(char *out, size_t n, const char *to)
{
    snprintf(out, n, "%.599s/%s", to, U2_INSTALL_MANIFEST);
}

static int manifest_write(const char *to, const row *rows, int n)
{
    char path[1024], tmp[1024];
    manifest_path(path, sizeof path, to);
    snprintf(tmp, sizeof tmp, "%.1010s.u2tmp", path);
    FILE *f = fopen(tmp, "wb");
    if (!f)
        return -1;
    fprintf(f, "# u2 install manifest, format 1\n");
    fprintf(f, "# dst\tkind\tsource\tsize\tsha256:16\n");
    for (int i = 0; i < n; i++)
        fprintf(f, "%s\tcontent\t%s\t%ld\t%s\n", rows[i].dst, rows[i].src,
                rows[i].size, rows[i].sha);
    if (fclose(f) != 0) { unlink(tmp); return -1; }
    if (rename(tmp, path) != 0) { unlink(tmp); return -1; }
    return 0;
}

/* Read the manifest back. Returns the row count, or -1 if it cannot be read. */
static int manifest_read(const char *to, row *rows, int max)
{
    char path[1024];
    manifest_path(path, sizeof path, to);
    FILE *f = fopen(path, "rb");
    if (!f)
        return -1;
    char line[1024];
    int n = 0;
    while (fgets(line, sizeof line, f) && n < max) {
        if (line[0] == '#' || line[0] == '\n')
            continue;
        char *dst = strtok(line, "\t");
        char *kind = strtok(NULL, "\t");
        char *src = strtok(NULL, "\t");
        char *size = strtok(NULL, "\t");
        char *sha = strtok(NULL, "\t");
        if (!dst || !kind || !src || !size || !sha)
            continue;
        snprintf(rows[n].dst, sizeof rows[n].dst, "%.*s", 511, dst);
        snprintf(rows[n].src, sizeof rows[n].src, "%.*s", 599, src);
        rows[n].size = strtol(size, NULL, 10);
        snprintf(rows[n].sha, sizeof rows[n].sha, "%.*s", HASH_LEN, sha);
        /* strip the trailing newline that the last field carries */
        rows[n].sha[strcspn(rows[n].sha, "\r\n")] = '\0';
        n++;
    }
    fclose(f);
    return n;
}

/* Is a manifest destination one of the sector files the game itself rewrites?
 * D6 keeps write-back in the content directory, so these are the files whose
 * bytes are expected to differ once someone has played. Reporting that as a
 * failure would make --check red for the normal case, and a check that is red for
 * the normal case is a check that gets ignored. */
static int is_writable_sector(const char *dst)
{
    const char *base = strrchr(dst, '/');
    base = base ? base + 1 : dst;
    return !strncasecmp(base, "mapx", 4) || !strncasecmp(base, "mapg", 4) ||
           !strncasecmp(base, "monx", 4) || !strncasecmp(base, "mong", 4);
}

/* ------------------------------------------------------------------- scan */

typedef struct {
    row *rows;
    int n;
    int shadowed;
    int patched_over;
    int skipped;
} plan;

static int plan_find(const plan *p, const char *dst)
{
    for (int i = 0; i < p->n; i++)
        if (!strcasecmp(p->rows[i].dst, dst))
            return i;
    return -1;
}

/* Does this filename look like a patch delta rather than content? The upgrade
 * package ships Moonstone Dragon's Map Patch as u2-map.pat, and the installer
 * cannot apply it, so silence here would be the worst of the three answers: the
 * player has the fix, we skip it, and nothing says so. */
static int is_patch_delta(const char *name)
{
    const size_t n = strlen(name);
    return n > 4 && !strcasecmp(name + n - 4, ".pat");
}

/* Scan one source directory into the plan.
 *
 * `may_override` is set only for the Galaxy patch source, and it is what makes a
 * patch mean what it says. The rule was "first source wins", and the release is
 * scanned first, so a corrupt release file beat the patched copy sitting beside it.
 * That is not hypothetical: of the 40 filenames the release and updated/ share,
 * exactly two differ, and one is mapx15, where 260 bytes at the end of the file are
 * the corruption GCHANGES.TXT -- the Moonstone Dragon patch's own readme -- was
 * written to fix. First-wins re-introduced a 1996 bug.
 *
 * So: a patch source may replace a planned release-layer file when the bytes
 * differ, and says so. Identical copies are still just shadowed. */
static void scan_source(const char *dir, plan *p, FILE *out, int may_override)
{
    DIR *d = opendir(dir);
    if (!d) {
        fprintf(out, "  cannot read source %s\n", dir);
        return;
    }
    struct dirent *e;
    char names[512][NAME_LEN];
    int count = 0;
    while ((e = readdir(d)) && count < (int)(sizeof names / sizeof names[0])) {
        if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, ".."))
            continue;
        char full[1024];
        snprintf(full, sizeof full, "%.890s/%.127s", dir, e->d_name);
        if (!is_dirpath(full))
            snprintf(names[count++], NAME_LEN, "%.127s", e->d_name);
    }
    closedir(d);

    for (int i = 0; i < count; i++) {
        int galaxy = 0;
        if (!u2_install_classify(names[i], &galaxy)) {
            p->skipped++;
            if (is_patch_delta(names[i]))
                fprintf(out, "  skip  %s (a patch delta; the installer applies only an "
                             "already-patched updated/ directory -- docs/install-design.md)\n",
                        names[i]);
            else
                fprintf(out, "  skip  %s (not game content)\n", names[i]);
            continue;
        }
        char dst[512];
        snprintf(dst, sizeof dst, "%s/%.127s",
                 galaxy ? U2_INSTALL_DATA_UPD : U2_INSTALL_DATA_ORIG, names[i]);
        char full[1024];
        snprintf(full, sizeof full, "%.890s/%.127s", dir, names[i]);
        long sz = 0;
        char sha[HASH_LEN + 1];
        if (hash_file(full, sha, &sz) != 0) {
            fprintf(out, "  error %s could not be read\n", names[i]);
            continue;
        }

        const int existing = plan_find(p, dst);
        if (existing >= 0) {
            const int differs = strcmp(p->rows[existing].sha, sha) != 0;
            if (differs && may_override) {
                snprintf(p->rows[existing].src, sizeof p->rows[existing].src,
                         "%.599s", full);
                p->rows[existing].size = sz;
                memcpy(p->rows[existing].sha, sha, sizeof sha);
                p->patched_over++;
                fprintf(out, "  patch   %s taken from this source, replacing a "
                             "different copy (D8)\n", names[i]);
            } else {
                p->shadowed++;
                fprintf(out, "  note  %s shadowed by an earlier source%s\n",
                        names[i], differs ? " and the copies DIFFER" : "");
            }
            continue;
        }
        if (p->n >= MAX_ROWS) {
            fprintf(out, "  error plan is full (%d rows)\n", MAX_ROWS);
            break;
        }
        snprintf(p->rows[p->n].dst, sizeof p->rows[p->n].dst, "%s", dst);
        snprintf(p->rows[p->n].src, sizeof p->rows[p->n].src, "%.599s", full);
        p->rows[p->n].size = sz;
        memcpy(p->rows[p->n].sha, sha, sizeof sha);
        p->n++;
    }
}

/* ------------------------------------------------------------------ config */

static int write_config(const char *to, int have_themes)
{
    char path[1024], tmp[1024];
    snprintf(path, sizeof path, "%.1000s/%s", to, U2_INSTALL_CONFIG);
    snprintf(tmp, sizeof tmp, "%.1010s.u2tmp", path);
    FILE *f = fopen(tmp, "wb");
    if (!f)
        return -1;
    fputs("# u2 engine configuration, written by --install.\n"
          "# Precedence: command line > this file > nothing.\n"
          "# A relative path here is relative to this file, not to the directory\n"
          "# you launch from, so the game runs correctly from anywhere.\n"
          "# An unknown key, a duplicated key or a path that does not exist is an\n"
          "# error at startup rather than a silent default.\n"
          "\n"
          "[paths]\n"
          "data = .\n"
          "saves = saves\n"
          "\n", f);
    if (have_themes)
        fputs("[themes]\ndir = themes\ntheme = default\n", f);
    if (fclose(f) != 0) { unlink(tmp); return -1; }
    if (rename(tmp, path) != 0) { unlink(tmp); return -1; }
    return 0;
}

/* ------------------------------------------------------------------ apply */

u2_install_result u2_install_apply(const u2_install_request *rq, FILE *out,
                                   char *err, size_t errsz)
{
    if (!rq || !rq->to || !*rq->to) {
        snprintf(err, errsz, "--install needs --to DIR");
        return U2_INSTALL_REFUSED;
    }
    if ((!rq->original_dir || !*rq->original_dir) &&
        (!rq->updated_dir || !*rq->updated_dir)) {
        snprintf(err, errsz,
                 "--install needs at least one source: --original-dir DIR and/or "
                 "--updated-dir DIR");
        return U2_INSTALL_REFUSED;
    }

    const t_state st = inspect_target(rq->to);
    if (st == T_NOTDIR) {
        snprintf(err, errsz, "%s exists and is not a directory", rq->to);
        return U2_INSTALL_REFUSED;
    }
    if (st == T_FOREIGN) {
        snprintf(err, errsz,
                 "%s is not empty and carries no %s, so it is not an install of "
                 "ours. Nothing here is merged, overwritten or deleted: point --to "
                 "at an empty or new directory and the old one is left alone.",
                 rq->to, U2_INSTALL_MANIFEST);
        return U2_INSTALL_REFUSED;
    }

    if (mkdir_p(rq->to) != 0) {
        snprintf(err, errsz, "cannot create %s", rq->to);
        return U2_INSTALL_ERROR;
    }

    row *rows = calloc(MAX_ROWS, sizeof *rows);
    if (!rows) {
        snprintf(err, errsz, "out of memory");
        return U2_INSTALL_ERROR;
    }
    plan p = { rows, 0, 0, 0, 0 };

    fprintf(out, "u2 install: %s\n", rq->to);
    if (st == T_MINE)
        fprintf(out, "  an existing install of ours; completing it\n");

    /* D9: the Galaxy patch lives INSIDE the release directory. `updated/` is a
     * subdirectory of the IA pack, not a separate download, so making a player
     * point at it separately asks them to know the pack's internal layout. If
     * --updated-dir was not given and <original>/updated exists, that is the patch
     * layer and we use it. An explicit --updated-dir always wins. */
    const char *upd = rq->updated_dir && *rq->updated_dir ? rq->updated_dir : NULL;
    char auto_upd[1024];
    if (!upd && rq->original_dir && *rq->original_dir) {
        snprintf(auto_upd, sizeof auto_upd, "%.890s/updated", rq->original_dir);
        if (is_dirpath(auto_upd)) {
            upd = auto_upd;
            fprintf(out, "  found the Galaxy patch inside the release at %s\n", auto_upd);
        }
    }

    /* Release first, so a file both layers carry is seen from the release and the
     * shadow -- or, per D8, the patch winning -- is reported rather than decided by
     * readdir order. */
    if (rq->original_dir && *rq->original_dir) {
        if (!is_dirpath(rq->original_dir)) {
            snprintf(err, errsz, "--original-dir %s is not a directory", rq->original_dir);
            free(rows);
            return U2_INSTALL_REFUSED;
        }
        fprintf(out, "-- source %s (release)\n", rq->original_dir);
        scan_source(rq->original_dir, &p, out, 0);
    }
    if (upd) {
        if (!is_dirpath(upd)) {
            snprintf(err, errsz, "--updated-dir %s is not a directory", upd);
            free(rows);
            return U2_INSTALL_REFUSED;
        }
        fprintf(out, "-- source %s (Galaxy patch)\n", upd);
        scan_source(upd, &p, out, 1);
    }
    if (p.n == 0) {
        snprintf(err, errsz, "no game content found in the sources given");
        free(rows);
        return U2_INSTALL_REFUSED;
    }

    fprintf(out, "-- %d file(s) to write, %d shadowed, %d patched over, %d skipped\n",
            p.n, p.shadowed, p.patched_over, p.skipped);

    if (rq->dry_run) {
        /* The data layer is planned file by file above, because that is where the
         * interesting decisions are (which copy of a shared filename wins). Themes
         * and the FM Towns derivation are deterministic given their sources, so a
         * dry run names the sources rather than re-planning every file. */
        fprintf(out, "-- dry run: nothing was written\n");
        if (rq->n_themes_dir)
            for (int i = 0; i < rq->n_themes_dir; i++)
                fprintf(out, "   themes would be built from %s\n", rq->themes_dir[i]);
        else
            fprintf(out, "   no theme source given, so themes/ would not be written\n");
        if (rq->fmtowns_media && *rq->fmtowns_media)
            fprintf(out, "   themes/fmtowns would be derived from %s\n", rq->fmtowns_media);
        free(rows);
        return U2_INSTALL_OK;
    }

    int written = 0, failed = 0;
    for (int i = 0; i < p.n; i++) {
        char full[1024];
        snprintf(full, sizeof full, "%.500s/%.511s", rq->to, p.rows[i].dst);
        char parent[1024];
        const char *slash = strrchr(full, '/');
        snprintf(parent, sizeof parent, "%.*s", slash ? (int)(slash - full) : 0, full);
        if (mkdir_p(parent) != 0) {
            fprintf(out, "  error cannot create %s\n", parent);
            failed++;
            continue;
        }
        if (copy_verified(p.rows[i].src, full, p.rows[i].size, p.rows[i].sha) != 0) {
            fprintf(out, "  error %s did not copy byte-identically\n", p.rows[i].dst);
            failed++;
            continue;
        }
        written++;
    }
    if (failed) {
        snprintf(err, errsz, "%d file(s) failed to copy; nothing was recorded as installed",
                 failed);
        free(rows);
        return U2_INSTALL_ERROR;
    }

    /* saves/ holds the live player record so a DOS run and an engine run stop
     * fighting over one file. Seed it from the release copy only when it is not
     * already there: an existing save is the player's and is never touched. */
    {
        char saves[1024], src[1024], dst[1024];
        snprintf(saves, sizeof saves, "%.1000s/%s", rq->to, U2_INSTALL_SAVES);
        snprintf(src, sizeof src, "%.1000s/%s/player", rq->to, U2_INSTALL_DATA_ORIG);
        snprintf(dst, sizeof dst, "%.1000s/%s/player", rq->to, U2_INSTALL_SAVES);
        if (mkdir_p(saves) == 0 && file_size(src) > 0 && file_size(dst) < 0) {
            char sha[HASH_LEN + 1];
            long sz = 0;
            if (hash_file(src, sha, &sz) == 0 && copy_verified(src, dst, sz, sha) == 0)
                fprintf(out, "  seeded saves/player from the release copy\n");
        }
    }

    int have_themes = 0;
    if (rq->n_themes_dir > 0) {
        char tdir[1024];
        snprintf(tdir, sizeof tdir, "%.1000s/%s", rq->to, U2_INSTALL_THEMES);
        u2_themes_request trq;
        memset(&trq, 0, sizeof trq);
        trq.out = tdir;
        trq.n_sources = rq->n_themes_dir;
        for (int i = 0; i < rq->n_themes_dir && i < U2_THEMES_MAX_SOURCES; i++)
            trq.sources[i] = rq->themes_dir[i];
        char terr[512];
        if (u2_themes_build(&trq, out, terr, sizeof terr) != 0) {
            snprintf(err, errsz, "%.511s", terr);
            free(rows);
            return U2_INSTALL_ERROR;
        }
        have_themes = 1;
    }

    /* The FM Towns theme is derived, not copied: the art comes off the player's own
     * disc and the mapping is compiled into the binary, so this works on a machine
     * that has the disc and nothing else. It lands inside themes/ and is recorded in
     * the same manifest, so --check covers it exactly as it covers a copied theme --
     * including when --themes-dir was not given at all. */
    if (rq->fmtowns_media && *rq->fmtowns_media) {
        char tdir[1024], fm[1300];
        snprintf(tdir, sizeof tdir, "%.1000s/%s", rq->to, U2_INSTALL_THEMES);
        snprintf(fm, sizeof fm, "%.1200s/%s", tdir, U2_FMTOWNS_THEME);
        if (u2_mkdir_p(tdir) != 0) {
            snprintf(err, errsz, "cannot create %s", tdir);
            free(rows);
            return U2_INSTALL_ERROR;
        }
        char ferr[512];
        if (u2_fmtowns_build(rq->fmtowns_media, fm, out, ferr, sizeof ferr) != 0) {
            snprintf(err, errsz, "%.511s", ferr);
            free(rows);
            return U2_INSTALL_ERROR;
        }
        char terr[512];
        if (u2_themes_record(tdir, U2_FMTOWNS_THEME, rq->fmtowns_media,
                             terr, sizeof terr) != 0) {
            snprintf(err, errsz, "%.511s", terr);
            free(rows);
            return U2_INSTALL_ERROR;
        }
        have_themes = 1;
    }

    if (write_config(rq->to, have_themes) != 0) {
        snprintf(err, errsz, "cannot write %s", U2_INSTALL_CONFIG);
        free(rows);
        return U2_INSTALL_ERROR;
    }
    if (manifest_write(rq->to, rows, p.n) != 0) {
        snprintf(err, errsz, "cannot write %s", U2_INSTALL_MANIFEST);
        free(rows);
        return U2_INSTALL_ERROR;
    }

    fprintf(out, "installed: %d file(s), manifest %s, config %s\n",
            written, U2_INSTALL_MANIFEST, U2_INSTALL_CONFIG);
    if (!have_themes)
        fprintf(out, "note: no themes installed; --ega needs a themes directory "
                     "(--themes-dir, or docs/install-design.md § 10)\n");
    free(rows);
    return U2_INSTALL_OK;
}

/* ------------------------------------------------------------------- check */

u2_install_result u2_install_check(const char *to, FILE *out, char *err, size_t errsz)
{
    if (!to || !*to) {
        snprintf(err, errsz, "--install --check needs --to DIR");
        return U2_INSTALL_REFUSED;
    }
    const t_state st = inspect_target(to);
    if (st == T_ABSENT || st == T_EMPTY) {
        snprintf(err, errsz, "%s is empty or absent; there is nothing to check", to);
        return U2_INSTALL_REFUSED;
    }
    if (st == T_FOREIGN) {
        snprintf(err, errsz, "%s has no %s, so this installer cannot say anything "
                 "about it", to, U2_INSTALL_MANIFEST);
        return U2_INSTALL_REFUSED;
    }

    row *rows = calloc(MAX_ROWS, sizeof *rows);
    if (!rows) {
        snprintf(err, errsz, "out of memory");
        return U2_INSTALL_ERROR;
    }
    const int n = manifest_read(to, rows, MAX_ROWS);
    if (n <= 0) {
        snprintf(err, errsz, "%s could not be read", U2_INSTALL_MANIFEST);
        free(rows);
        return U2_INSTALL_ERROR;
    }

    int missing = 0, wrong = 0, drifted = 0, ok = 0;
    for (int i = 0; i < n; i++) {
        char full[1024];
        snprintf(full, sizeof full, "%.500s/%.511s", to, rows[i].dst);
        char sha[HASH_LEN + 1];
        long sz = 0;
        if (hash_file(full, sha, &sz) != 0) {
            fprintf(out, "  missing %s\n", rows[i].dst);
            missing++;
            continue;
        }
        if (sz != rows[i].size) {
            fprintf(out, "  wrong   %s is %ld B, manifest says %ld B\n",
                    rows[i].dst, sz, rows[i].size);
            wrong++;
            continue;
        }
        if (strcmp(sha, rows[i].sha) != 0) {
            if (is_writable_sector(rows[i].dst)) {
                fprintf(out, "  played  %s differs from install (expected after play)\n",
                        rows[i].dst);
                drifted++;
            } else {
                fprintf(out, "  wrong   %s differs from install and is not a sector file\n",
                        rows[i].dst);
                wrong++;
            }
            continue;
        }
        ok++;
    }

    /* Strays: anything under data/ that the manifest does not know about. saves/
     * is excluded because it is the mutable area by design, and a stray there is
     * the player's own save, not a broken install. */
    int strays = 0;
    {
        char root[1024];
        snprintf(root, sizeof root, "%.1000s/data", to);
        DIR *d = opendir(root);
        if (d) {
            struct dirent *e;
            while ((e = readdir(d))) {
                if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, ".."))
                    continue;
                char layer[1024];
                snprintf(layer, sizeof layer, "%.890s/%.127s", root, e->d_name);
                if (!is_dirpath(layer)) {
                    fprintf(out, "  stray   %s/%s\n", "data", e->d_name);
                    strays++;
                    continue;
                }
                DIR *l = opendir(layer);
                if (!l) continue;
                struct dirent *f;
                while ((f = readdir(l))) {
                    if (!strcmp(f->d_name, ".") || !strcmp(f->d_name, ".."))
                        continue;
                    char dst[512];
                    snprintf(dst, sizeof dst, "data/%.127s/%.127s", e->d_name, f->d_name);
                    int known = 0;
                    for (int i = 0; i < n; i++)
                        if (!strcmp(rows[i].dst, dst)) { known = 1; break; }
                    if (!known) {
                        fprintf(out, "  stray   %s\n", dst);
                        strays++;
                    }
                }
                closedir(l);
            }
            closedir(d);
        }
    }

    fprintf(out, "check %s: %d ok, %d missing, %d wrong, %d strays",
            to, ok, missing, wrong, strays);
    if (drifted)
        fprintf(out, ", %d played-in", drifted);
    fputc('\n', out);

    /* The themes subtree carries its own manifest, because it is the theme
     * builder's output rather than a copy of the player's release, and each
     * manifest stays authoritative for its own half of the tree. */
    int themes_bad = 0;
    {
        char tdir[1024];
        snprintf(tdir, sizeof tdir, "%.1000s/%s", to, U2_INSTALL_THEMES);
        if (is_dirpath(tdir)) {
            char terr[512];
            if (u2_themes_check(tdir, out, terr, sizeof terr) != 0) {
                fprintf(out, "  themes: %s\n", terr);
                themes_bad = 1;
            }
        }
    }

    free(rows);
    if (missing || wrong || strays || themes_bad) {
        snprintf(err, errsz, "the tree does not match its manifest");
        return U2_INSTALL_REFUSED;
    }
    return U2_INSTALL_OK;
}
