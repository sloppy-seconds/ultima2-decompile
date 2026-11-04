/*
 * tests/install_check.c — the gate from docs/install-design.md § 7.
 *
 * The fixtures are engine-authored filler, not game content: a release directory
 * and a Galaxy patch directory are synthesised under the work dir, so this runs in
 * CI with no media present, and the byte-identity assertions are still real because
 * they compare the install against the bytes that went in.
 *
 * The assertion that matters most is the engine one: the installed tree, pointed at
 * with no other flags, loads Earth AND an outer planet. Everything else can pass
 * while the install is useless; that one cannot.
 *
 * Build and run by tests/run_cp4.sh.
 */

#define _POSIX_C_SOURCE 200809L   /* mkdir, unlink, opendir under -std=c11 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>

#include "core/config.h"
#include "core/ctx.h"
#include "core/install.h"
#include "core/world.h"

static int fails, checks;

#define CHECK(cond, msg)                                                \
    do {                                                                \
        checks++;                                                       \
        if (cond) printf("  ok    %s\n", msg);                          \
        else      { printf("  FAIL  %s\n", msg); fails++; }             \
    } while (0)

static long size_of(const char *p)
{
    struct stat st;
    return stat(p, &st) == 0 ? (long)st.st_size : -1;
}

static void write_bytes(const char *p, int fill, size_t n)
{
    FILE *f = fopen(p, "wb");
    if (!f) { printf("  FAIL  cannot write %s\n", p); fails++; return; }
    unsigned char *buf = malloc(n ? n : 1);
    for (size_t i = 0; i < n; i++)
        buf[i] = (unsigned char)((fill + i) & 0xFF);
    fwrite(buf, 1, n, f);
    free(buf);
    fclose(f);
}

static int copy_file(const char *src, const char *dst)
{
    FILE *i = fopen(src, "rb");
    if (!i) return -1;
    FILE *o = fopen(dst, "wb");
    if (!o) { fclose(i); return -1; }
    unsigned char buf[8192];
    size_t n;
    while ((n = fread(buf, 1, sizeof buf, i)) > 0)
        if (fwrite(buf, 1, n, o) != n) { fclose(i); fclose(o); return -1; }
    fclose(i);
    fclose(o);
    return 0;
}

static int file_exists(const char *p)
{
    struct stat st;
    return stat(p, &st) == 0 && S_ISREG(st.st_mode);
}

static int same_bytes(const char *a, const char *b)
{
    const long sa = size_of(a), sb = size_of(b);
    if (sa < 0 || sa != sb)
        return 0;
    unsigned char ba[4096], bb[4096];
    FILE *fa = fopen(a, "rb"), *fb = fopen(b, "rb");
    if (!fa || !fb) { if (fa) fclose(fa); if (fb) fclose(fb); return 0; }
    int same = 1;
    for (;;) {
        const size_t na = fread(ba, 1, sizeof ba, fa);
        const size_t nb = fread(bb, 1, sizeof bb, fb);
        if (na != nb || memcmp(ba, bb, na) != 0) { same = 0; break; }
        if (na == 0) break;
    }
    fclose(fa); fclose(fb);
    return same;
}

typedef struct { char name[512]; } entry;

static int collect(const char *root, const char *rel, entry *out, int n, int max)
{
    char path[1024];
    if (*rel) snprintf(path, sizeof path, "%.880s/%.130s", root, rel);
    else      snprintf(path, sizeof path, "%.1023s", root);
    DIR *d = opendir(path);
    if (!d)
        return n;
    struct dirent *e;
    while ((e = readdir(d)) && n < max) {
        if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, ".."))
            continue;
        char child[600], full[1024];
        if (*rel) snprintf(child, sizeof child, "%.460s/%.127s", rel, e->d_name);
        else      snprintf(child, sizeof child, "%.127s", e->d_name);
        snprintf(full, sizeof full, "%.880s/%.130s", root, child);
        struct stat st;
        if (stat(full, &st) != 0)
            continue;
        if (S_ISDIR(st.st_mode))
            n = collect(root, child, out, n, max);
        else {
            snprintf(out[n].name, sizeof out[n].name, "%.511s", child);
            n++;
        }
    }
    closedir(d);
    return n;
}

static int has(entry *list, int n, const char *name)
{
    for (int i = 0; i < n; i++)
        if (!strcmp(list[i].name, name))
            return 1;
    return 0;
}

/* The fixture contents. Both spellings of a shadowed name, tooling that must be
 * skipped, and a subdirectory that must not be walked into. */
static const char *const k_release[] = {
    "mapx00", "mapx40", "monx00", "monx40", "tlkx03", "monsters",
    "player", "ultimaii.exe", "picdng", "PICDNG-E",
};
#define N_PATCH_CONTENT 4
static const char *const k_patch[] = {
    "MAPG00", "MAPG40", "MONG40", "TLKG40",
    "mapx00",           /* also in the release: the patch copy wins (D8) */
    "cgapatch.exe",     /* patcher tooling, not content */
    "RENGAL.BAT",       /* a script that renames things, never run by us */
    /* The real release spells these lowercase and updated/ spells them uppercase,
     * so a case-sensitive plan would write both and leave the engine holding the
     * corrupt one. This is the mapx15 / TLKX03 case from the shipped media. */
    "TLKX03",
};

static int rel_fill(int i)  { return 0x10 + i * 7; }
static int rel_size(int i)  { return (i % 3) ? 4224 : 4096; }
static int upd_fill(int i)  { return 0x80 + i * 5; }

static void build_fixtures(const char *base_in)
{
    /* Copied into a bounded array so every snprintf below is provably large
     * enough: gcc's format-truncation check cannot bound a bare `const char *`
     * parameter, and -Werror is one of the engine's gates, not a suggestion. */
    char base[512];
    snprintf(base, sizeof base, "%.511s", base_in);

    char dir[1024];
    snprintf(dir, sizeof dir, "%.1000s/rel", base); mkdir(dir, 0755);
    snprintf(dir, sizeof dir, "%.1000s/upd", base); mkdir(dir, 0755);

    for (size_t i = 0; i < sizeof k_release / sizeof k_release[0]; i++) {
        snprintf(dir, sizeof dir, "%.1000s/rel/%.127s", base, k_release[i]);
        write_bytes(dir, rel_fill((int)i), (size_t)rel_size((int)i));
    }
    for (size_t i = 0; i < sizeof k_patch / sizeof k_patch[0]; i++) {
        snprintf(dir, sizeof dir, "%.1000s/upd/%.127s", base, k_patch[i]);
        write_bytes(dir, upd_fill((int)i), 4096);
    }
    snprintf(dir, sizeof dir, "%.1000s/rel/README.txt", base); write_bytes(dir, 1, 32);
    snprintf(dir, sizeof dir, "%.1000s/rel/run.bat", base);    write_bytes(dir, 2, 32);
    snprintf(dir, sizeof dir, "%.1000s/rel/updated", base);    mkdir(dir, 0755);
    snprintf(dir, sizeof dir, "%.1000s/rel/updated/MAPG99", base); write_bytes(dir, 3, 64);
}

int main(int argc, char **argv)
{
    char base[512];
    snprintf(base, sizeof base, "%.511s", argc > 1 ? argv[1] : ".");
    char to[1024], rel[1024], upd[1024], err[512], p[1024], q[1024];
    FILE *log = fopen("/dev/null", "w");
    entry files[512];

    snprintf(to, sizeof to, "%.1000s/game", base);
    snprintf(rel, sizeof rel, "%.1000s/rel", base);
    snprintf(upd, sizeof upd, "%.1000s/upd", base);
    build_fixtures(base);

    /* --- classification: content by name, and which layer it belongs to ---- */
    {
        int g = -1;
        CHECK(u2_install_classify("MAPG40", &g) && g == 1, "MAPG40 is content, patch layer");
        CHECK(u2_install_classify("mapx00", &g) && g == 0, "mapx00 is content, release layer");
        CHECK(u2_install_classify("TLKG03", &g) && g == 1, "TLKG03 is content, patch layer");
        CHECK(u2_install_classify("PICDNG-E", &g) && g == 0, "PICDNG-E is content");
        CHECK(u2_install_classify("monsters", &g) && g == 0, "monsters is content");
        CHECK(u2_install_classify("ultimaii.exe", &g), "ultimaii.exe is content");
        CHECK(!u2_install_classify("cgapatch.exe", &g), "a patcher binary is not content");
        CHECK(!u2_install_classify("RENGAL.BAT", &g), "a batch script is not content");
        CHECK(!u2_install_classify("README.txt", &g), "a README is not content");
        CHECK(!u2_install_classify("mapx0", &g), "a malformed sector name is not content");
        CHECK(!u2_install_classify("mapxy0", &g), "nor is a near miss");
    }

    /* --- a foreign non-empty target is refused, and left alone ------------- */
    {
        char foreign[1024], inside[1024];
        snprintf(foreign, sizeof foreign, "%.1000s/foreign", base); mkdir(foreign, 0755);
        snprintf(inside, sizeof inside, "%.1000s/foreign/keep.me", base);
        write_bytes(inside, 0x5A, 7);

        u2_install_request rq = { .to = foreign, .original_dir = rel, .updated_dir = upd };
        CHECK(u2_install_apply(&rq, log, err, sizeof err) == U2_INSTALL_REFUSED,
              "a non-empty directory with no manifest is refused");
        CHECK(size_of(inside) == 7, "  and nothing in it was touched");
        CHECK(strstr(err, "not empty") != NULL, "  and the refusal says why");
    }

    /* Snapshot two sources so "the source is untouched" is a comparison and not
     * a re-stat of the same thing twice. */
    snprintf(p, sizeof p, "%.1000s/snap-mapx00", base);
    snprintf(q, sizeof q, "%.1000s/snap-MAPG40", base);
    {
        char src[1024];
        snprintf(src, sizeof src, "%.1000s/rel/mapx00", base);   copy_file(src, p);
        snprintf(src, sizeof src, "%.1000s/upd/MAPG40", base);   copy_file(src, q);
    }

    /* --- greenfield install ------------------------------------------------ */
    u2_install_request rq = { .to = to, .original_dir = rel, .updated_dir = upd };
    CHECK(u2_install_apply(&rq, log, err, sizeof err) == U2_INSTALL_OK,
          "install into a nonexistent directory creates it");

    int n = collect(to, "", files, 0, 512);

    /* assertion 1: exactly the expected file set */
    CHECK(has(files, n, "_INSTALL.tsv"), "the manifest is written");
    CHECK(has(files, n, "config.ini"), "config.ini is written");
    CHECK(has(files, n, "data/original/mapx00"), "the release layer holds mapx00");
    CHECK(has(files, n, "data/updated/MAPG40"), "the patch layer holds MAPG40");
    CHECK(has(files, n, "data/original/PICDNG-E"), "picture sidecars are content");
    CHECK(has(files, n, "saves/player"), "saves/ holds the live player record");
    CHECK(!has(files, n, "data/original/README.txt"), "a README is not copied");
    CHECK(!has(files, n, "data/original/run.bat"), "DOS launcher scaffolding is not copied");
    CHECK(!has(files, n, "data/updated/cgapatch.exe"), "patcher tooling is not copied");
    CHECK(!has(files, n, "data/updated/RENGAL.BAT"), "  nor the rename script");
    CHECK(!has(files, n, "data/updated/MAPG99"), "a subdirectory of a source is not walked into");
    CHECK(!has(files, n, "data/original/mapx99"), "  and nothing leaked from it");
    CHECK(n == 17, "the tree holds exactly the expected number of files");
    if (n != 17)
        for (int i = 0; i < n; i++)
            printf("        have %s\n", files[i].name);

    /* assertion 2: byte-identical copies */
    {
        int all_same = 1;
        for (size_t i = 0; i < sizeof k_release / sizeof k_release[0]; i++) {
            /* mapx00 and tlkx03 exist in both fixtures, and per D8 the installed
             * copy is the patch's, so the release comparison cannot hold for them.
             * They get their own assertions below. */
            if (!strcmp(k_release[i], "mapx00") || !strcmp(k_release[i], "tlkx03"))
                continue;
            char a[1024], b[1024];
            snprintf(a, sizeof a, "%.1000s/rel/%.127s", base, k_release[i]);
            snprintf(b, sizeof b, "%.480s/data/original/%.127s", to, k_release[i]);
            if (!same_bytes(a, b)) { printf("        differs: %s\n", k_release[i]); all_same = 0; }
        }
        for (int i = 0; i < N_PATCH_CONTENT; i++) {
            char a[1024], b[1024];
            snprintf(a, sizeof a, "%.1000s/upd/%.127s", base, k_patch[i]);
            snprintf(b, sizeof b, "%.480s/data/updated/%.127s", to, k_patch[i]);
            if (!same_bytes(a, b)) { printf("        differs: %s\n", k_patch[i]); all_same = 0; }
        }
        CHECK(all_same, "every copied file is byte-identical to its source");
    }

    /* D8: a file in both sources takes the PATCH copy when the bytes differ, and
     * keeps the release's spelling of the name. The old rule was first-source-wins
     * with the release scanned first, which meant the corrupt release mapx15 beat
     * the copy written to fix it. */
    {
        char a[1024], b[1024], c[1024];
        snprintf(a, sizeof a, "%.1000s/rel/mapx00", base);
        snprintf(b, sizeof b, "%.1000s/upd/mapx00", base);
        snprintf(c, sizeof c, "%.480s/data/original/mapx00", to);
        CHECK(same_bytes(b, c) && !same_bytes(a, c),
              "a file in both sources is taken from the patch, not the release (D8)");
    }

    /* ...and the case difference does not fork the destination: TLKX03 from the
     * patch lands on the release's tlkx03, one file, patched bytes. */
    {
        char b[1024], c[1024], dup[1024];
        snprintf(b, sizeof b, "%.1000s/upd/TLKX03", base);
        snprintf(c, sizeof c, "%.480s/data/original/tlkx03", to);
        snprintf(dup, sizeof dup, "%.480s/data/original/TLKX03", to);
        CHECK(same_bytes(b, c), "the uppercase patch name lands on the release spelling");
        CHECK(!file_exists(dup), "the two casings collapse to one file, not two");
    }

    /* D9: with no --updated-dir, <original>/updated is the patch layer. The Galaxy
     * patch ships inside the release directory, so asking for it separately asks
     * the player to know the pack's layout. */
    {
        char game9[1024], want[1024];
        snprintf(game9, sizeof game9, "%.480s/game-d9", base);
        snprintf(want, sizeof want, "%.480s/game-d9/data/updated/MAPG99", base);
        u2_install_request d9 = { .to = game9, .original_dir = rel };
        CHECK(u2_install_apply(&d9, log, err, sizeof err) == U2_INSTALL_OK,
              "an install with no --updated-dir still finds the patch inside the release");
        CHECK(file_exists(want), "  and the patch layer it found is installed");
    }

    /* assertion 6: the sources are byte-for-byte untouched */
    {
        char src[1024];
        snprintf(src, sizeof src, "%.1000s/rel/mapx00", base);
        CHECK(same_bytes(src, p), "the release source is byte-identical after an install");
        snprintf(src, sizeof src, "%.1000s/upd/MAPG40", base);
        CHECK(same_bytes(src, q), "the patch source is byte-identical after an install");
    }

    /* assertion 4: re-running is a no-op (D7a) */
    {
        entry pre[512];
        const int npre = collect(to, "", pre, 0, 512);
        CHECK(u2_install_apply(&rq, log, err, sizeof err) == U2_INSTALL_OK,
              "re-running into our own tree is allowed (manifest recognised)");
        const int npost = collect(to, "", files, 0, 512);
        CHECK(npre == npost, "  and a second run changes nothing");
    }

    /* assertion 3: the engine reads the installed tree with no other flags */
    {
        u2_ctx ctx;
        u2_world w;
        memset(&ctx, 0, sizeof ctx);
        ctx.data_dir = to;
        CHECK(u2_world_open(&ctx) == U2_WORLD_OK, "the installed tree opens as a content dir");

        u2_sector_id earth = { .hi = 0, .lo = 0 };
        memset(&w, 0, sizeof w);
        CHECK(u2_world_load(&ctx, &w, 1, earth) == U2_WORLD_OK, "Earth loads from the installed tree");
        CHECK(w.map_root && strcmp(w.map_root, "data/original") == 0, "  from the release layer");

        ctx.state.world = 4;
        u2_sector_id jup = { .hi = 4, .lo = 0 };
        memset(&w, 0, sizeof w);
        CHECK(u2_world_load(&ctx, &w, 1, jup) == U2_WORLD_OK,
              "an outer planet loads from the installed tree, which is the whole point");
        CHECK(w.map_root && strcmp(w.map_root, "data/updated") == 0,
              "  from the patch layer, not the Earth clone beside it");
        ctx.state.world = 0;
    }

    /* config.ini is real: config.c reads it and resolves it against the file */
    {
        char path[1024];
        u2_config cfg;
        char cerr[512];
        snprintf(path, sizeof path, "%.1000s/config.ini", to);
        CHECK(u2_config_load(path, &cfg, cerr, sizeof cerr) == U2_CONFIG_OK,
              "the generated config.ini loads and refuses nothing");
        u2_ctx ctx;
        memset(&ctx, 0, sizeof ctx);
        u2_config_apply(&ctx, &cfg);
        CHECK(ctx.data_dir && strstr(ctx.data_dir, "game") != NULL,
              "  and it pins the content root to the installed tree");
        CHECK(ctx.save_dir && strstr(ctx.save_dir, "saves") != NULL,
              "  and the saves directory");
    }

    /* --- themes: the v1 reshape, built by the same installer ---------------- */
    {
        char art[1024], d[1024], e[1024];
        snprintf(art, sizeof art, "%.480s/art", base);            mkdir(art, 0755);
        snprintf(d, sizeof d, "%.480s/EGATILES", art);            write_bytes(d, 0x21, 8320);
        snprintf(d, sizeof d, "%.480s/EGACOLOR", art);            write_bytes(d, 0x22, 32);
        snprintf(d, sizeof d, "%.480s/PICDNG.EGA", art);          write_bytes(d, 0x23, 64000);
        snprintf(d, sizeof d, "%.480s/CGATILES", art);            write_bytes(d, 0x24, 8192);
        snprintf(d, sizeof d, "%.480s/README.txt", art);          write_bytes(d, 0x25, 40);
        snprintf(d, sizeof d, "%.480s/u2cfg.exe", art);           write_bytes(d, 0x26, 40);
        snprintf(d, sizeof d, "%.480s/EGATHEME.C64", art);        mkdir(d, 0755);
        snprintf(e, sizeof e, "%.480s/EGATILES", d);               write_bytes(e, 0x31, 8320);
        snprintf(e, sizeof e, "%.480s/EGACOLOR", d);               write_bytes(e, 0x32, 32);
        snprintf(d, sizeof d, "%.480s/EGATHEME.ALT", art);        mkdir(d, 0755);
        snprintf(e, sizeof e, "%.480s/EGATILES", d);               write_bytes(e, 0x41, 8320);

        /* A second source with no atlas at all, which is how the Galaxy directory
         * arrives: it ships the full PIC*-E picture set and no themes, and that is
         * a complete contribution rather than a defect. PICDNG-E is the same
         * picture as art's PICDNG.EGA in another spelling. */
        char art2[1024];
        snprintf(art2, sizeof art2, "%.480s/art2", base);          mkdir(art2, 0755);
        snprintf(d, sizeof d, "%.480s/PICDNG-E", art2);            write_bytes(d, 0x61, 64000);
        snprintf(d, sizeof d, "%.480s/PICMIN-E", art2);            write_bytes(d, 0x62, 64000);

        u2_install_request with_themes = { .to = to, .original_dir = rel, .updated_dir = upd,
                                           .themes_dir = { art, art2 }, .n_themes_dir = 2 };
        CHECK(u2_install_apply(&with_themes, log, err, sizeof err) == U2_INSTALL_OK,
              "install with --themes-dir builds themes/");

        int tn = collect(to, "", files, 0, 512);
        CHECK(has(files, tn, "themes/_BUILD.tsv"), "the themes manifest is written");
        CHECK(has(files, tn, "themes/default/TILES"),
              "the default theme is reshaped to a v2 directory (EGATILES becomes TILES)");
        CHECK(has(files, tn, "themes/default/THEME.INI"),
              "  and gains a THEME.INI describing it");
        CHECK(has(files, tn, "themes/default/EGACOLOR"), "  and keeps its colour remap");
        CHECK(has(files, tn, "themes/EGATHEME.C64/EGATILES") &&
              has(files, tn, "themes/EGATHEME.C64/EGACOLOR"),
              "a named theme is copied whole, extras included");
        CHECK(has(files, tn, "themes/EGATHEME.ALT/EGATILES"),
              "a theme that ships an atlas alone is still a theme");
        CHECK(has(files, tn, "themes/PICDNG.EGA"),
              "the default theme's picture is hoisted to the root, where pic_ega.c looks");
        CHECK(has(files, tn, "themes/PICMIN-E"),
              "a picture only the second source ships still lands");
        /* PICDNG.EGA and PICDNG-E are the same picture in two spellings and
         * pic_ega.c tries both, so the root holds one per base and the first
         * source wins. Keying the dedup on the filename instead fills the root
         * with duplicates that differ only in a dash -- the exact divergence the
         * C builder had against the Python one it replaces. */
        CHECK(!has(files, tn, "themes/PICDNG-E"),
              "two spellings of one picture base do not both land at the themes root");
        CHECK(has(files, tn, "themes/default/PICDNG.EGA"),
              "  and stays inside its own theme directory too");
        CHECK(!has(files, tn, "themes/CGATILES") && !has(files, tn, "themes/default/CGATILES"),
              "the CGA atlas is not theme content");
        CHECK(!has(files, tn, "themes/README.txt") && !has(files, tn, "themes/u2cfg.exe"),
              "docs and patcher binaries stay out of the themes tree");

        /* the atlas landed byte-identical, which is the whole no-re-encode rule */
        {
            char a[1024], b[1024];
            snprintf(a, sizeof a, "%.480s/EGATILES", art);
            snprintf(b, sizeof b, "%.480s/themes/default/TILES", to);
            CHECK(same_bytes(a, b), "the reshaped atlas is byte-identical to its source");
            snprintf(a, sizeof a, "%.480s/EGATHEME.C64/EGATILES", art);
            snprintf(b, sizeof b, "%.480s/themes/EGATHEME.C64/EGATILES", to);
            CHECK(same_bytes(a, b), "  and so is a named theme's");
        }

        /* config.ini gains [themes] only because themes actually exist now */
        {
            char path[1024];
            u2_config cfg2;
            char cerr[512];
            snprintf(path, sizeof path, "%.480s/config.ini", to);
            CHECK(u2_config_load(path, &cfg2, cerr, sizeof cerr) == U2_CONFIG_OK &&
                  *cfg2.themes && strstr(cfg2.themes, "themes") != NULL,
                  "config.ini names the themes directory once there is one");
        }

        CHECK(u2_install_check(to, log, err, sizeof err) == U2_INSTALL_OK,
              "--check verifies the themes subtree too");

        /* a half-copied theme must not pass */
        {
            char victim[1024], keep[1024];
            snprintf(victim, sizeof victim, "%.480s/themes/EGATHEME.C64/EGACOLOR", to);
            snprintf(keep, sizeof keep, "%.480s/snap-c64color", base);
            copy_file(victim, keep);
            unlink(victim);
            CHECK(u2_install_check(to, log, err, sizeof err) == U2_INSTALL_REFUSED,
                  "--check goes red when a theme loses a file its source ships");
            copy_file(keep, victim);
        }

        /* a themes source with no atlas anywhere in it is refused rather than
         * producing an empty themes tree, which the engine would report as
         * "no such theme" while the installer claimed success. */
        {
            char bare[1024], game3[1024];
            snprintf(bare, sizeof bare, "%.480s/artbare", base);   mkdir(bare, 0755);
            snprintf(d, sizeof d, "%.480s/README.txt", bare);      write_bytes(d, 0x71, 20);
            snprintf(game3, sizeof game3, "%.480s/game3", base);
            u2_install_request bare_rq = { .to = game3, .original_dir = rel, .updated_dir = upd,
                                           .themes_dir = { bare }, .n_themes_dir = 1 };
            CHECK(u2_install_apply(&bare_rq, log, err, sizeof err) != U2_INSTALL_OK,
                  "a themes source containing no atlas is refused, not silently empty");
        }

        /* a source whose atlas is the wrong size is refused before anything is
         * written, and the tree is not claimed as installed: no manifest, so a
         * later --check cannot mistake a half-built tree for a good one. */
        {
            char bad[1024], game2[1024];
            snprintf(bad, sizeof bad, "%.480s/artbad", base);
            snprintf(game2, sizeof game2, "%.480s/game2", base);
            mkdir(bad, 0755);
            snprintf(d, sizeof d, "%.480s/EGATILES", bad);
            write_bytes(d, 0x51, 100);          /* below the size the engine reads */
            u2_install_request bad_rq = { .to = game2, .original_dir = rel, .updated_dir = upd,
                                          .themes_dir = { bad }, .n_themes_dir = 1 };
            CHECK(u2_install_apply(&bad_rq, log, err, sizeof err) != U2_INSTALL_OK,
                  "a themes source with a short atlas is refused");
            char m[1024];
            snprintf(m, sizeof m, "%.480s/_INSTALL.tsv", game2);
            CHECK(size_of(m) < 0,
                  "  and the half-built tree carries no manifest to mistake it for good");
        }
    }

    /* --- assertion 5: --check, and the ways it goes red -------------------- */
    CHECK(u2_install_check(to, log, err, sizeof err) == U2_INSTALL_OK,
          "--check passes a freshly installed tree");

    {
        char victim[1024], keep[1024];
        snprintf(victim, sizeof victim, "%.480s/data/original/tlkx03", to);
        snprintf(keep, sizeof keep, "%.1000s/snap-tlkx03", base);
        copy_file(victim, keep);
        unlink(victim);
        CHECK(u2_install_check(to, log, err, sizeof err) == U2_INSTALL_REFUSED,
              "--check goes red on a missing file");
        copy_file(keep, victim);
        CHECK(u2_install_check(to, log, err, sizeof err) == U2_INSTALL_OK,
              "  and goes green again once it is restored");
    }
    {
        snprintf(p, sizeof p, "%.480s/data/original/stray.bin", to);
        write_bytes(p, 0x33, 16);
        CHECK(u2_install_check(to, log, err, sizeof err) == U2_INSTALL_REFUSED,
              "--check goes red on a stray file");
        unlink(p);
    }
    {
        /* D6: sector files are rewritten by play, so a content difference in one
         * is expected and must not read as a broken tree. */
        snprintf(p, sizeof p, "%.480s/data/original/mapx40", to);
        write_bytes(p, 0xEE, 4224);
        CHECK(u2_install_check(to, log, err, sizeof err) == U2_INSTALL_OK,
              "--check reports a played-in sector as drift, not failure (D6)");
    }
    {
        snprintf(p, sizeof p, "%.480s/data/original/monsters", to);
        write_bytes(p, 0xEE, 4224);
        CHECK(u2_install_check(to, log, err, sizeof err) == U2_INSTALL_REFUSED,
              "--check still goes red when a file the game never rewrites changes");
    }
    {
        char foreign[1024];
        snprintf(foreign, sizeof foreign, "%.1000s/foreign", base);
        CHECK(u2_install_check(foreign, log, err, sizeof err) == U2_INSTALL_REFUSED,
              "--check refuses a tree with no manifest rather than guessing");
    }

    fclose(log);
    printf(fails ? "install check: FAIL (%d of %d)\n" : "install check: all %d checks passed\n",
           fails ? fails : checks, checks);
    return fails != 0;
}
