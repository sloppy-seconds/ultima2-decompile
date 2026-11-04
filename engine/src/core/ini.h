/*
 * ini.h — the engine's one `key = value` reader.
 *
 * There is exactly one of these on purpose. THEME.INI (docs/theme-format.md) and
 * config.ini (docs/install-design.md § 4) are different files with different
 * writers, and the ruling that made config.ini reuse the THEME.INI grammar was
 * "so there is one parser and one set of refusals rather than two" — which is only
 * true if the parser is actually shared rather than copied. A second copy would
 * accept something the first refuses, and the two files would drift in the one
 * direction that matters: what a malformed file does.
 *
 * The grammar is deliberately tiny, because the writers are our own tools and a
 * general INI parser would only add ways to accept something no writer emits:
 *
 *   # comment          ; comment also accepted
 *   [section]          brackets set the current section for later keys
 *   key = value        spaces around the key and value are trimmed
 *
 * Keys are matched case-insensitively, as DOS filenames taught everyone to expect.
 * Values are capped at 255 characters; a longer value is a refusal (-1), never a
 * truncation, because a truncated path is a path that points somewhere else and a
 * reader that silently halves one is worse than one that stops.
 */

#ifndef U2_CORE_INI_H
#define U2_CORE_INI_H

#include <stddef.h>

/* Look up `key`. With `section == NULL` every key matches regardless of where it
 * sits, which is the THEME.INI behaviour and the reason the parameter is optional
 * rather than mandatory. With a section named, only keys under that `[section]`
 * header match; a key before any header belongs to no section and matches nothing.
 *
 * Returns 1 on a hit, 0 on no such key, and -1 when the value does not fit in
 * `out`. */
int u2_ini_get(const char *buf, const char *section, const char *key,
               char *out, size_t n);

/* Walk the keys of `section` (all sections when NULL), one call per key.
 * `*cursor` starts at 0 and is advanced by the caller's loop; returns 1 and fills
 * `out` with the key name, or 0 when the buffer is exhausted.
 *
 * This exists for the one check a get-by-name cannot do: noticing a key nobody
 * asked for. A typo in config.ini is otherwise silent, and silent is the failure
 * mode docs/install-design.md § 4 refuses to ship — "a typo in the ini is
 * reported, never papered over". */
int u2_ini_next_key(const char *buf, const char *section, size_t *cursor,
                    char *out, size_t n);

#endif
