#ifndef U2_SCALE_H
#define U2_SCALE_H

/*
 * scale.h — how a 320x200 frame maps onto a window of an arbitrary size.
 *
 * This lives in core rather than in a backend on purpose, for the same reason the
 * palette and the do-not-draw rule do: a renderer is allowed to move pixels, not
 * to decide what they should look like. Two backends that each invented their own
 * fit would drift, and the one that got it wrong would be the one the player was
 * looking at. It is also pure integer arithmetic with no SDL dependency, so it is
 * testable in a build that has no SDL at all (tests/scale_check.c).
 *
 * Why integer, and not just "stretch it to the window". The source is 2bpp CGA:
 * a pixel is the smallest unit the art has, and at a fractional scale some source
 * pixels become 3 device pixels wide and some 4. On the dragon logo that reads as
 * the outline wobbling, and on the town's 8x8 cells it reads as text with uneven
 * strokes. An integer scale makes every source pixel exactly scale x scale device
 * pixels, so the blocks stay square and the art stays crisp at any window size.
 * The cost is letterboxing: a window that is not a multiple of 320x200 gets black
 * bars, which is what the original on a real monitor never had and what every
 * emulator of this era does anyway.
 *
 * Below 1:1 the rule changes, and says so by returning scale 0. If the window is
 * smaller than the frame there is no integer scale that fits, and the alternative
 * to a fractional fit is cropping the picture, which loses content. Squashing is
 * the lesser defect: nothing is hidden, and the player can drag the window wider.
 */

typedef struct u2_fit {
    int x, y;       /* top-left of the destination rectangle, in device pixels */
    int w, h;       /* destination size                                          */
    int scale;      /* integer scale applied; 0 means "fractional fit", see above */
} u2_fit;

/* Largest integer scale at which src_w x src_h still fits inside out_w x out_h,
 * centred in the output. Returns scale 0 filling the output when the window is
 * smaller than the source, and all zeros when the output has no area. */
u2_fit u2_fit_integer(int out_w, int out_h, int src_w, int src_h);

#endif /* U2_SCALE_H */
