/*
 * ini.c — see ini.h. This is the parser that used to be a static function inside
 * tiles_ega.c, moved rather than rewritten so THEME.INI keeps the exact refusals
 * it was gated with (engine/tests/theme_v2_check.c, 39 checks) while config.ini
 * inherits them for free.
 */

#define _POSIX_C_SOURCE 200809L

#include "core/ini.h"

#include <stdio.h>
#include <string.h>
#include <strings.h>

#define U2_INI_MAX_VALUE 256

static void trim(char *s)
{
    char *e = s + strlen(s);
    while (e > s && (e[-1] == '\r' || e[-1] == '\n' || e[-1] == ' ' || e[-1] == '\t'))
        *--e = '\0';
    while (*s == ' ' || *s == '\t') memmove(s, s + 1, strlen(s));
}

/* The name inside a `[section]` header, trimmed of brackets and spaces. Returns 0
 * when the line is not a header. */
static int header_name(const char *line, size_t ll, char *out, size_t n)
{
    if (ll < 2 || line[0] != '[')
        return 0;
    const char *close = memchr(line, ']', ll);
    if (!close)
        return 0;                       /* a malformed header is not a header */
    const char *s = line + 1;
    const char *e = close;
    while (s < e && (*s == ' ' || *s == '\t')) s++;
    while (e > s && (e[-1] == ' ' || e[-1] == '\t')) e--;
    const size_t len = (size_t)(e - s);
    if (len >= n)
        return 0;                       /* absurd: refuse it as a header */
    memcpy(out, s, len);
    out[len] = '\0';
    return 1;
}

int u2_ini_get(const char *buf, const char *section, const char *key,
               char *out, size_t n)
{
    const size_t kl = strlen(key);
    char cur[64];                       /* the section we are inside, "" before any */
    int in_section = 0;

    cur[0] = '\0';
    if (!buf || !key || !out || n == 0)
        return 0;

    const char *p = buf;
    while (p && *p) {
        const char *eol = strchr(p, '\n');
        const size_t ll = eol ? (size_t)(eol - p) : strlen(p);

        char hdr[64];
        if (header_name(p, ll, hdr, sizeof hdr)) {
            snprintf(cur, sizeof cur, "%s", hdr);
            in_section = 1;
            p = eol ? eol + 1 : NULL;
            continue;
        }

        /* A scoped lookup only matches inside its own section. An unscoped one
         * (section == NULL) matches anywhere, which is what THEME.INI has always
         * done and why the parameter is optional. */
        const int here = !section ||
                         (in_section && strcasecmp(cur, section) == 0);

        if (here && ll > kl + 1 && p[0] != '#' && p[0] != ';' && p[0] != '[') {
            const char *eq = memchr(p, '=', ll);
            if (eq && (size_t)(eq - p) >= kl) {
                const char *ks = p;
                while (ks < eq && (*ks == ' ' || *ks == '\t')) ks++;
                const char *ke = eq;
                while (ke > ks && (ke[-1] == ' ' || ke[-1] == '\t')) ke--;
                const size_t klen = (size_t)(ke - ks);
                if (klen == kl && strncasecmp(ks, key, kl) == 0) {
                    char val[U2_INI_MAX_VALUE];
                    const char *vs = eq + 1;
                    size_t vl = ll - (size_t)(vs - p);
                    /* Refuse, never truncate. A truncated path is a path that
                     * points somewhere else, and silently reading half of it is
                     * the one thing a config reader must not do. */
                    if (vl >= sizeof val)
                        return -1;
                    memcpy(val, vs, vl);
                    val[vl] = '\0';
                    trim(val);
                    if (snprintf(out, n, "%s", val) >= (int)n) return -1;
                    return 1;
                }
            }
        }
        p = eol ? eol + 1 : NULL;
    }
    return 0;
}

int u2_ini_next_key(const char *buf, const char *section, size_t *cursor,
                    char *out, size_t n)
{
    char cur[64];
    char hdr[64];
    int in_section = 0, seen = 0;
    const char *p;

    if (!buf || !out || n == 0 || !cursor)
        return 0;
    cur[0] = '\0';

    for (p = buf; p && *p; ) {
        const char *eol = strchr(p, '\n');
        const size_t ll = eol ? (size_t)(eol - p) : strlen(p);

        if (header_name(p, ll, hdr, sizeof hdr)) {
            snprintf(cur, sizeof cur, "%s", hdr);
            in_section = 1;
            p = eol ? eol + 1 : NULL;
            continue;
        }

        const int here = !section || (in_section && strcasecmp(cur, section) == 0);
        if (here && p[0] != '#' && p[0] != ';' && p[0] != '[') {
            const char *eq = memchr(p, '=', ll);
            if (eq && eq > p) {
                const char *ks = p, *ke = eq;
                while (ks < eq && (*ks == ' ' || *ks == '\t')) ks++;
                while (ke > ks && (ke[-1] == ' ' || ke[-1] == '\t')) ke--;
                const size_t klen = (size_t)(ke - ks);
                if (klen > 0 && klen < n) {
                    if (seen == (int)*cursor) {
                        memcpy(out, ks, klen);
                        out[klen] = '\0';
                        (*cursor)++;
                        return 1;
                    }
                    seen++;
                }
            }
        }
        p = eol ? eol + 1 : NULL;
    }
    return 0;
}
