/*
 * scale.c — integer fit of the game frame into a window. See scale.h.
 */

#include "core/scale.h"

u2_fit u2_fit_integer(int out_w, int out_h, int src_w, int src_h)
{
    u2_fit r = { 0, 0, 0, 0, 0 };

    if (out_w <= 0 || out_h <= 0 || src_w <= 0 || src_h <= 0)
        return r;                       /* nothing to draw into; caller skips */

    int sx = out_w / src_w;
    int sy = out_h / src_h;
    int s  = sx < sy ? sx : sy;

    if (s < 1) {
        /* No integer scale fits. Fill the window and accept non-square pixels;
         * see the note in scale.h on why cropping is the worse option. */
        r.x = 0; r.y = 0; r.w = out_w; r.h = out_h; r.scale = 0;
        return r;
    }

    r.w     = src_w * s;
    r.h     = src_h * s;
    r.x     = (out_w - r.w) / 2;
    r.y     = (out_h - r.h) / 2;
    r.scale = s;
    return r;
}
