/*
 * tests/config_check.c — the guarantees of core/config.c and core/ini.c.
 *
 * config.ini is the one place a shipped binary is allowed to learn where things
 * live, so the property under test is not "does it parse" but "can it lie". A
 * config that silently ignores a typo is worse than no config: the player edits a
 * line, nothing happens, and the engine goes looking somewhere else. Every refusal
 * here is that lie made impossible. docs/install-design.md § 4.
 *
 * Build and run by tests/run_cp4.sh.
 */

#define _POSIX_C_SOURCE 200809L   /* mkdir under -std=c11 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#include "core/config.h"
#include "core/ctx.h"
#include "core/ini.h"

static int fails, checks;

#define CHECK(cond, msg)                                                \
    do {                                                                \
        checks++;                                                       \
        if (cond) printf("  ok    %s\n", msg);                          \
        else      { printf("  FAIL  %s\n", msg); fails++; }             \
    } while (0)

static void write_text(const char *path, const char *text)
{
    FILE *f = fopen(path, "wb");
    if (!f) { printf("  FAIL  cannot write %s\n", path); fails++; return; }
    fputs(text, f);
    fclose(f);
}

/* Load `text` as config.ini in `dir`, returning the result code. */
static u2_config_result load_from(const char *dir, const char *name, const char *text,
                                  u2_config *cfg, char *err, size_t errsz)
{
    char path[600];
    snprintf(path, sizeof path, "%.380s/%.100s", dir, name);
    write_text(path, text);
    return u2_config_load(path, cfg, err, errsz);
}

static int refused(const char *dir, const char *name, const char *text,
                   char *err, size_t errsz)
{
    u2_config cfg;
    char e[512];
    const u2_config_result r = load_from(dir, name, text, &cfg, e, sizeof e);
    if (err && errsz)
        snprintf(err, errsz, "%.511s", e);
    return r == U2_CONFIG_REFUSED;
}

int main(int argc, char **argv)
{
    const char *base = argc > 1 ? argv[1] : ".";
    char dir[400], sub[600], err[512];
    u2_config cfg;
    u2_ctx ctx;

    snprintf(dir, sizeof dir, "%.380s/cfg", base);
    mkdir(dir, 0755);
    snprintf(sub, sizeof sub, "%.380s/content", dir);
    mkdir(sub, 0755);
    snprintf(sub, sizeof sub, "%.380s/themes", dir);
    mkdir(sub, 0755);

    /* --- absent is the normal case, not a fault ------------------------ */
    {
        char missing[600];
        snprintf(missing, sizeof missing, "%.380s/no-such-config.ini", dir);
        memset(&cfg, 0xAA, sizeof cfg);
        CHECK(u2_config_load(missing, &cfg, err, sizeof err) == U2_CONFIG_OK,
              "a config.ini that does not exist is not an error");
        CHECK(cfg.present == 0, "an absent config reports itself as absent");
        CHECK(cfg.data[0] == '\0', "an absent config has no opinion about paths");

        memset(&ctx, 0, sizeof ctx);
        u2_config_apply(&ctx, &cfg);
        CHECK(ctx.data_dir == NULL && ctx.save_dir == NULL &&
              ctx.ega_theme == NULL && ctx.ega_theme_dir == NULL,
              "applying an absent config changes nothing at all");
    }

    /* --- a well-formed file populates every field ---------------------- */
    CHECK(load_from(dir, "good.ini",
                    "# comment\n"
                    "; another comment\n"
                    "\n"
                    "[paths]\n"
                    "data = content\n"
                    "saves = saves\n"
                    "\n"
                    "[themes]\n"
                    "dir = themes\n"
                    "theme = c64\n",
                    &cfg, err, sizeof err) == U2_CONFIG_OK,
          "a well-formed config loads");
    {
        char want[600];
        snprintf(want, sizeof want, "%.380s/content", dir);
        CHECK(strcmp(cfg.data, want) == 0,
              "[paths] data resolves against the config file, not the cwd");
        snprintf(want, sizeof want, "%.380s/themes", dir);
        CHECK(strcmp(cfg.themes, want) == 0,
              "[themes] dir resolves the same way");
    }
    CHECK(strcmp(cfg.saves, "saves") == 0 || strstr(cfg.saves, "/saves"),
          "[paths] saves parsed");
    CHECK(strcmp(cfg.theme, "c64") == 0, "[themes] theme parsed");
    CHECK(cfg.present == 1, "a real config reports itself as present");

    /* An absolute value is taken exactly as written: the resolution rule is for
     * relative paths and must not mangle a player who spells out a location. */
    {
        u2_config abs_cfg;
        char e2[512];
        char p2[600];
        snprintf(p2, sizeof p2, "%.380s/abs.ini", dir);
        write_text(p2, "[paths]\ndata = /tmp\n");
        CHECK(u2_config_load(p2, &abs_cfg, e2, sizeof e2) == U2_CONFIG_OK &&
              strcmp(abs_cfg.data, "/tmp") == 0,
              "an absolute path in the config is left alone");
    }

    /* --- precedence: flag > ini > nothing ------------------------------ */
    memset(&ctx, 0, sizeof ctx);
    ctx.data_dir = "flagged";
    ctx.ega_theme = "10";
    u2_config_apply(&ctx, &cfg);
    CHECK(strcmp(ctx.data_dir, "flagged") == 0,
          "a command-line --data-dir survives the config (flag > ini)");
    CHECK(strcmp(ctx.ega_theme, "10") == 0,
          "a command-line --ega-theme survives the config (flag > ini)");
    CHECK(ctx.save_dir && strcmp(ctx.save_dir, cfg.saves) == 0,
          "what the flag left unset the config fills (ini > nothing)");
    CHECK(ctx.ega_theme_dir && strcmp(ctx.ega_theme_dir, cfg.themes) == 0,
          "the themes directory comes from the ini when no flag named it");

    memset(&ctx, 0, sizeof ctx);
    u2_config_apply(&ctx, &cfg);
    CHECK(ctx.data_dir && strstr(ctx.data_dir, "content") != NULL,
          "with no flag at all the config is the only source");

    /* --- refusals: every one of these is a lie made impossible --------- */
    char why[512];
    CHECK(refused(dir, "r1.ini", "[paths]\ndata = content\nextra = 1\n", why, sizeof why),
          "an unknown key in [paths] is refused, not ignored");
    CHECK(*why && strstr(why, "extra") != NULL,
          "  and the refusal names the offending key");
    CHECK(refused(dir, "r2.ini", "[themes]\ndir = themes\ncolour = red\n", why, sizeof why),
          "an unknown key in [themes] is refused");
    CHECK(refused(dir, "r3.ini", "[paths]\ndata = content\n[themes]\ndir = themes\nstray = x\n",
                  why, sizeof why),
          "a key in the wrong section is refused");
    CHECK(refused(dir, "r4.ini", "data = content\n", why, sizeof why),
          "a key outside every section is refused");
    CHECK(refused(dir, "r5.ini", "[paths]\ndata = content\ndata = elsewhere\n", why, sizeof why),
          "a key written twice is refused rather than first-one-wins");
    CHECK(refused(dir, "r6.ini", "[paths]\ndata = /no/such/directory/anywhere\n",
                  why, sizeof why),
          "a [paths] data that is not a directory is an error at startup");
    CHECK(refused(dir, "r7.ini", "[themes]\ndir = /no/such/theme/dir\n", why, sizeof why),
          "a [themes] dir that is not a directory is an error at startup");
    CHECK(refused(dir, "r8.ini",
                  "[themes]\ntheme = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                  "aaaaaaaa\n", why, sizeof why),
          "a value longer than the parser's cap is refused, not truncated");

    /* `saves` is the one path allowed to not exist yet: it is output, and save.c
     * creates it on first write the way the original would have created its own
     * directory. Refusing it would break a fresh install for no benefit. */
    CHECK(load_from(dir, "fresh.ini", "[paths]\ndata = content\nsaves = brand/new/dir\n",
                    &cfg, err, sizeof err) == U2_CONFIG_OK,
          "a saves dir that does not exist yet is allowed (it is output, not content)");

    /* A file that is empty, or only comments, is a valid opinion of "nothing". */
    CHECK(load_from(dir, "empty.ini", "", &cfg, err, sizeof err) == U2_CONFIG_OK &&
          cfg.present == 1 && cfg.data[0] == '\0',
          "an empty config is present and says nothing");
    CHECK(load_from(dir, "comments.ini", "# just a note\n; nothing here\n",
                    &cfg, err, sizeof err) == U2_CONFIG_OK && cfg.theme[0] == '\0',
          "a comments-only config is present and says nothing");

    /* --- the shared parser's own semantics ----------------------------- */
    {
        const char *ini =
            "[a]\nKEY = one\nkey2=two\n"
            "[b]\nKEY = three\n";
        char v[64];
        CHECK(u2_ini_get(ini, "a", "KEY", v, sizeof v) == 1 && strcmp(v, "one") == 0,
              "keys are matched case-insensitively within their section");
        CHECK(u2_ini_get(ini, "b", "KEY", v, sizeof v) == 1 && strcmp(v, "three") == 0,
              "the same key in two sections resolves to the right one");
        CHECK(u2_ini_get(ini, "c", "KEY", v, sizeof v) == 0,
              "an unknown section matches nothing");
        CHECK(u2_ini_get(ini, NULL, "KEY", v, sizeof v) == 1 && strcmp(v, "one") == 0,
              "an unscoped lookup takes the first, which is the THEME.INI rule");
        CHECK(u2_ini_get(ini, "a", "key2", v, sizeof v) == 1 && strcmp(v, "two") == 0,
              "no spaces around the equals sign is still one grammar");
        CHECK(u2_ini_get(ini, "a", "KEY", v, 2) == -1,
              "a value that does not fit is a refusal, not a truncation");

        size_t cur = 0;
        int n = 0;
        char k[64];
        while (u2_ini_next_key(ini, "a", &cur, k, sizeof k)) n++;
        CHECK(n == 2, "the key walk sees both keys of one section and no others");
    }

    printf(fails ? "config check: FAIL (%d of %d)\n" : "config check: all %d checks passed\n",
           fails ? fails : checks, checks);
    return fails != 0;
}
