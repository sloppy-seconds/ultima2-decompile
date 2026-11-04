/*
 * fmtowns.h — derive the format-v2 FM Towns theme from the player's own disc.
 *
 * This is the port of the derivation that used to live in tools/build_themes.py,
 * and it is the reason that tool could be deleted rather than mourned: reading a CD
 * image, decoding GRAPH banks and assembling a theme is not Python work, it is
 * work, and doing it here means a player with the disc gets FM Towns art from the
 * same binary that installed everything else. No interpreter, and no second
 * builder of the same format.
 *
 * What it needs and where each piece comes from:
 *
 *   the art        the player's own FM Towns disc image. Never committed, never
 *                  shipped, read at install time from --fmtowns-media-dir.
 *   the mapping    disasm/fmtowns-crosswalk.tsv, compiled into the binary as
 *                  engine/content/fmtowns_map.h. It is our own analysis of how the
 *                  two games' art corresponds, and a player has the disc but not
 *                  the repository, so the mapping has to travel with the binary.
 *   the palette    read off the running FM Towns machine (see the note in
 *                  docs/fmtowns-graphics.md § 3); it is a constant, so it is a
 *                  constant here.
 *
 * The output is four files — THEME.INI, TILES, PALETTE.RGB, MAP.TSV — and the gate
 * on this file is that they are byte-identical to what the Python derivation
 * produced, which is the only kind of port check that means anything for a
 * generator. tools/fmtowns_theme.py remains as the developer's version of the same
 * derivation, and is what you use to look at more FM Towns media; the two are
 * checked against each other rather than allowed to agree by assertion.
 */

#ifndef U2_CORE_FMTOWNS_H
#define U2_CORE_FMTOWNS_H

#include <stddef.h>
#include <stdio.h>

#define U2_FMTOWNS_THEME "fmtowns"

/* Derive the theme into out_dir (which is created if absent). `media` is either a
 * directory holding a .img disc image, or the path of one; the first .img in a
 * directory, sorted, is taken, which is the rule the developer tool uses too.
 *
 * Returns 0 on success. A missing disc, a missing GRAPH bank or a tile index past
 * the end of its bank is a refusal with a reason in `err`, never a partial theme: a
 * themes tree that quietly omits the FM Towns art shows up as a theme bug rather
 * than a build bug, and that is the failure this whole path is built to prevent. */
int u2_fmtowns_build(const char *media, const char *out_dir, FILE *report,
                     char *err, size_t errsz);

/* Exposed for the gate: the ISO-9660-over-raw-sectors reader. `lba` is a logical
 * block address (2048-byte data block), and the disc image stores each one at
 * offset lba*2352+16. Returns the number of bytes copied, or -1. */
long u2_iso_read(const char *img_path, long lba, size_t length,
                 unsigned char *out, size_t outsz);

#endif
