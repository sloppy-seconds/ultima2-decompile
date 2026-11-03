#ifndef U2_PIC_EGA_H
#define U2_PIC_EGA_H

/*
 * The fan pack's EGA full-screen pictures (PICDRA-E and its siblings).
 *
 * Where core/pic.h unpacks the original's CGA mode-4 images (2bpp, planar,
 * even/odd field interleave), the EGA variants are the opposite: measured in
 * docs/ega-graphics-plan.md § 3 (spike S1), each `PIC*-E` file is exactly 64000
 * bytes = 320x200x1, one palette index per byte, top-down, values 0..15. There
 * is no interleave and no planar decode — the loader is a read and a bounds
 * check, and the frame already stores one index per pixel so it lands straight
 * in.
 *
 * The pack spells these names two ways depending on which copy you have: the
 * runtime dir uses `PICDRA-E` (dash) and the source package uses `PICDRA.EGA`
 * (dot). Both are tried, case-insensitively, so a FAT-uppercased copy works too.
 *
 * Copyright posture, identical to core/pic.h: the player's own files, read at run
 * time from the resolved themes/data directory, never committed. With no EGA
 * picture present the caller falls back to the CGA pic (or the text screen) and
 * nothing about a launch changes.
 */

#include "core/ctx.h"

struct u2_frame;

/* Non-zero when a readable EGA picture exists for `base` (e.g. "picdra"). The
 * caller branches on this so a missing EGA art falls back to the CGA path rather
 * than drawing a black rectangle where a picture was meant to be. */
int u2_pic_can_show_ega(u2_ctx *ctx, const char *base);

/* Read the EGA picture for `base` into f, filling all 320x200 pixels with 0..15
 * indices. Returns 0 on success and non-zero if no EGA variant is present or the
 * file is the wrong size, in which case f is left untouched. */
int u2_pic_blit_ega(u2_ctx *ctx, const char *base, struct u2_frame *f);

#endif /* U2_PIC_EGA_H */
