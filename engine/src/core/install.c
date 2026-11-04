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
#include "core/sha256.h"

#define MAX_ROWS     1024
#define NAME_LEN     128
#define HASH_LEN     16           /* sha256 hex prefix, as themes/_BUILD.tsv uses */
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

/* ------------------------------------------------------------------ files */

static long file_size(const char *p)
{
    struct stat st;
    return stat(p, &st) == 0 ? (long)st.st_size : -1;
}

static int is_dirpath(const char *p)
{
    struct stat st;
    return stat(p, &st) == 0 && S_ISDIR(st.st_mode);
}

/* sha256 of a whole file, first 16 hex characters. The files here are sector maps
 * and atlases, a few kilobytes each, so reading one into memory is not a streaming
 * problem and the code is honest about the size it will not exceed. */
static int hash_file(const char *p, char out[HASH_LEN + 1], long *out_size)
{
    const long sz = file_size(p);
    if (sz < 0 || (unsigned long)sz > MAX_FILE_COPY)
        return -1;
    FILE *f = fopen(p, "rb");
    if (!f)
        return -1;
    unsigned char *buf = malloc((size_t)sz ? (size_t)sz : 1);
    if (!buf) { fclose(f); return -1; }
    const size_t got = fread(buf, 1, (size_t)sz, f);
    fclose(f);
    if (got != (size_t)sz) { free(buf); return -1; }

    char hex[65];
    sha256_hex(buf, (size_t)sz, hex);
    free(buf);
    memcpy(out, hex, HASH_LEN);
    out[HASH_LEN] = '\0';
    if (out_size)
        *out_size = sz;
    return 0;
}

static int mkdir_p(const char *path)
{
    char buf[512];
    snprintf(buf, sizeof buf, "%.511s", path);
    for (char *s = buf + 1; *s; s++) {
        if (*s != '/')
            continue;
        *s = '\0';
        if (mkdir(buf, 0755) != 0 && errno != EEXIST)
            return -1;
        *s = '/';
    }
    if (mkdir(buf, 0755) != 0 && errno != EEXIST)
        return -1;
    return 0;
}

/* Copy src to dst byte-for-byte, then prove it by hashing the destination back.
 * A copy that "succeeded" and landed wrong is the failure this whole tool is built
 * to refuse, so the proof is not optional diagnostics — it is the return value. */
static int copy_verified(const char *src, const char *dst, long want_size,
                         const char want_sha[HASH_LEN + 1])
{
    const long sz = file_size(src);
    if (sz < 0 || (unsigned long)sz > MAX_FILE_COPY)
        return -1;

    char tmp[1024];
    snprintf(tmp, sizeof tmp, "%.1010s.u2tmp", dst);
    FILE *o = fopen(tmp, "wb");
    if (!o)
        return -1;
    FILE *f = fopen(src, "rb");
    if (!f) { fclose(o); unlink(tmp); return -1; }

    unsigned char *chunk = malloc(65536);
    size_t total = 0;
    int ok = chunk != NULL;
    while (ok) {
        const size_t n = fread(chunk, 1, 65536, f);
        if (n == 0) break;
        if (fwrite(chunk, 1, n, o) != n) { ok = 0; break; }
        total += n;
    }
    free(chunk);
    fclose(f);
    if (fclose(o) != 0) ok = 0;
    if (!ok || total != (size_t)sz || total != (size_t)want_size || rename(tmp, dst) != 0) {
        unlink(tmp);
        return -1;
    }

    char sha[HASH_LEN + 1];
    long after = 0;
    if (hash_file(dst, sha, &after) != 0)
        return -1;
    if (after != want_size || strcmp(sha, want_sha) != 0)
        return -1;
    return 0;
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
    int skipped;
} plan;

static int plan_has(const plan *p, const char *dst)
{
    for (int i = 0; i < p->n; i++)
        if (!strcmp(p->rows[i].dst, dst))
            return 1;
    return 0;
}

static void scan_source(const char *dir, plan *p, FILE *out)
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
            fprintf(out, "  skip  %s (not game content)\n", names[i]);
            continue;
        }
        char dst[512];
        snprintf(dst, sizeof dst, "%s/%.127s",
                 galaxy ? U2_INSTALL_DATA_UPD : U2_INSTALL_DATA_ORIG, names[i]);
        if (plan_has(p, dst)) {
            p->shadowed++;
            fprintf(out, "  note  %s shadowed by an earlier source\n", names[i]);
            continue;
        }
        char full[1024];
        snprintf(full, sizeof full, "%.890s/%.127s", dir, names[i]);
        long sz = 0;
        char sha[HASH_LEN + 1];
        if (hash_file(full, sha, &sz) != 0) {
            fprintf(out, "  error %s could not be read\n", names[i]);
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
    plan p = { rows, 0, 0, 0 };

    fprintf(out, "u2 install: %s\n", rq->to);
    if (st == T_MINE)
        fprintf(out, "  an existing install of ours; completing it\n");

    /* Release first, so a file both layers carry is taken from the release and the
     * shadow is reported rather than decided by readdir order. */
    if (rq->original_dir && *rq->original_dir) {
        if (!is_dirpath(rq->original_dir)) {
            snprintf(err, errsz, "--original-dir %s is not a directory", rq->original_dir);
            free(rows);
            return U2_INSTALL_REFUSED;
        }
        fprintf(out, "-- source %s (release)\n", rq->original_dir);
        scan_source(rq->original_dir, &p, out);
    }
    if (rq->updated_dir && *rq->updated_dir) {
        if (!is_dirpath(rq->updated_dir)) {
            snprintf(err, errsz, "--updated-dir %s is not a directory", rq->updated_dir);
            free(rows);
            return U2_INSTALL_REFUSED;
        }
        fprintf(out, "-- source %s (Galaxy patch)\n", rq->updated_dir);
        scan_source(rq->updated_dir, &p, out);
    }
    if (p.n == 0) {
        snprintf(err, errsz, "no game content found in the sources given");
        free(rows);
        return U2_INSTALL_REFUSED;
    }

    fprintf(out, "-- %d file(s) to write, %d shadowed, %d skipped\n",
            p.n, p.shadowed, p.skipped);

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

    if (write_config(rq->to, 0) != 0) {
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
    if (!rq->themes_dir || !*rq->themes_dir)
        fprintf(out, "note: no themes installed; --ega needs a themes directory "
                     "(docs/install-design.md § 10)\n");
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

    free(rows);
    if (missing || wrong || strays) {
        snprintf(err, errsz, "the tree does not match its manifest");
        return U2_INSTALL_REFUSED;
    }
    return U2_INSTALL_OK;
}
