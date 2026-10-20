/*
 * input_script.c — scripted keyboard for headless playthroughs.
 *
 * The whole automation story depends on this: an agent writes a key script,
 * the engine consumes it deterministically, and the transcript is evidence.
 *
 * Script format (one token per line, '#' starts a comment, blank lines skip):
 *   A               a single printable character
 *   SP  CR  LF  TAB ESC BS NUL
 *   0x41            explicit byte
 *   WAIT            one poll returns "no key" (models a real player pausing)
 *   EOF             stop feeding keys
 *
 * When the script runs out, poll() reports no key and wait() returns 0, which
 * is how the game loop reaches a clean end of input.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include "core/ctx.h"

typedef struct script_input {
    u2_key *keys;
    size_t  n;
    size_t  i;
} script_input;

static int named_key(const char *tok, u2_key *k)
{
    struct { const char *name; int ch; } table[] = {
        { "SP", ' ' }, { "CR", '\r' }, { "LF", '\n' }, { "TAB", '\t' },
        { "ESC", 0x1b }, { "BS", 0x08 }, { "NUL", 0x00 }, { "DEL", 0x7f },
    };
    for (size_t j = 0; j < sizeof table / sizeof table[0]; j++) {
        if (strcasecmp(tok, table[j].name) == 0) {
            k->ch = (uint8_t)table[j].ch;
            k->scan = 0;
            return 1;
        }
    }
    return 0;
}

static int script_input_init(u2_ctx *ctx)
{
    const char *path = ctx->script_path; /* set by main.c from --script */
    FILE *f = fopen(path, "r");
    if (!f) {
        fprintf(stderr, "u2: cannot open script '%s'\n", path ? path : "(null)");
        return -1;
    }
    script_input *si = calloc(1, sizeof *si);
    if (!si) { fclose(f); return -1; }

    char line[256];
    size_t cap = 64;
    si->keys = malloc(cap * sizeof *si->keys);
    if (!si->keys) { free(si); fclose(f); return -1; }

    while (fgets(line, sizeof line, f)) {
        char *p = line;
        char *hash = strchr(p, '#');
        if (hash) *hash = '\0';
        p = strtok(p, " \t\r\n");
        if (!p) continue;
        if (strcmp(p, "EOF") == 0) break;
        if (si->n == cap) {
            cap *= 2;
            u2_key *grown = realloc(si->keys, cap * sizeof *si->keys);
            if (!grown) { free(si->keys); free(si); fclose(f); return -1; }
            si->keys = grown;
        }
        u2_key k = { 0, 0 };
        if (strcmp(p, "WAIT") == 0) {
            k.ch = 0xFF; /* sentinel: "no key this poll" */
        } else if (named_key(p, &k)) {
            /* filled by named_key */
        } else if (strncmp(p, "0x", 2) == 0 || strncmp(p, "0X", 2) == 0) {
            long v = strtol(p, NULL, 16);
            k.ch = (uint8_t)(v & 0xFF);
        } else if (strlen(p) == 1) {
            k.ch = (uint8_t)(unsigned char)p[0];
        } else {
            fprintf(stderr, "u2: %s:%zu: unknown key token '%s'\n", path, si->n + 1, p);
            free(si->keys); free(si); fclose(f);
            return -1;
        }
        si->keys[si->n++] = k;
    }
    fclose(f);
    ctx->be_input = si;
    return 0;
}

static int script_input_poll(u2_ctx *ctx, u2_key *out)
{
    script_input *si = ctx->be_input;
    if (!si || si->i >= si->n)
        return 0;
    u2_key k = si->keys[si->i++];
    if (k.ch == 0xFF)
        return 0; /* WAIT */
    *out = k;
    return 1;
}

static int script_input_wait(u2_ctx *ctx, u2_key *out)
{
    script_input *si = ctx->be_input;
    while (si && si->i < si->n) {
        u2_key k = si->keys[si->i++];
        if (k.ch == 0xFF)
            continue;
        *out = k;
        return 1;
    }
    ctx->exit_code = 0;
    return 0;
}

static void script_input_shutdown(u2_ctx *ctx)
{
    script_input *si = ctx->be_input;
    if (si) {
        free(si->keys);
        free(si);
    }
    ctx->be_input = NULL;
}

const u2_input u2_input_script = {
    .name = "script",
    .init = script_input_init,
    .poll = script_input_poll,
    .wait = script_input_wait,
    .shutdown = script_input_shutdown,
};
