/*
 * scale_check.c — the integer fit of a 320x200 frame into an arbitrary window.
 *
 * Pure integer arithmetic with no SDL dependency, which is the point of keeping
 * the geometry in core/scale.c: this compiles and runs in the default cc-only
 * build, on a machine with no display and no SDL installed, and it is the same
 * code the SDL backend calls.
 *
 * The checks are chosen so a wrong implementation cannot pass by accident:
 *   - maximality catches a fit that under-scales (leaves the window mostly black)
 *     or uses only one axis (overflows the other and gets cropped),
 *   - the aspect cross-product catches any fractional or per-axis scale without
 *     needing floating point in the assertion,
 *   - "never exceeds the output" catches a centring bug that pushes the image
 *     partly off screen, which is the failure a player sees as a cut-off edge
 *     rather than as a bar,
 *   - the degenerate cases catch a division by zero, which would be a crash on
 *     startup rather than a visual bug.
 */

#include <stdio.h>

#include "core/scale.h"

static int fails;

static void ok(const char *what)  { printf("  ok    %s\n", what); }
static void bad(const char *what) { printf("  FAIL  %s\n", what); fails++; }

#define W 320
#define H 200

static void expect(int ow, int oh, int ex, int ey, int ew, int eh, int es,
                   const char *what)
{
    u2_fit f = u2_fit_integer(ow, oh, W, H);
    char buf[256];
    if (f.x == ex && f.y == ey && f.w == ew && f.h == eh && f.scale == es) {
        snprintf(buf, sizeof buf, "%s (%dx%d -> %d,%d %dx%d x%d)",
                 what, ow, oh, f.x, f.y, f.w, f.h, f.scale);
        ok(buf);
    } else {
        snprintf(buf, sizeof buf,
                 "%s: %dx%d gave %d,%d %dx%d x%d, wanted %d,%d %dx%d x%d",
                 what, ow, oh, f.x, f.y, f.w, f.h, f.scale, ex, ey, ew, eh, es);
        bad(buf);
    }
}

/* Properties that must hold for every output size, integer or not. Failures here
 * come from a sweep of ~52k sizes, so the reporting is capped: a wall of identical
 * lines buries the one real message and slows a human down. */
#define INVARIANT_REPORT_MAX 10
static int invariant_reports;

static void inv_bad(const char *msg)
{
    if (invariant_reports < INVARIANT_REPORT_MAX) {
        printf("  FAIL  %s\n", msg);
        invariant_reports++;
    }
    fails++;
}

static void invariants(int ow, int oh)
{
    u2_fit f = u2_fit_integer(ow, oh, W, H);
    char buf[256];

    if (ow <= 0 || oh <= 0) {
        if (f.w == 0 && f.h == 0) return;
        inv_bad("degenerate output must produce an empty rect");
        return;
    }

    /* Never draw outside the window: an overflowing rect reads as a cut-off
     * edge, which a player reports as a bug and not as a missing bar. */
    if (f.x < 0 || f.y < 0 || f.w <= 0 || f.h <= 0 ||
        f.x + f.w > ow || f.y + f.h > oh) {
        snprintf(buf, sizeof buf,
                 "%dx%d: rect %d,%d %dx%d escapes the window", ow, oh, f.x, f.y, f.w, f.h);
        inv_bad(buf);
    }

    if (f.scale >= 1) {
        /* Square source pixels, exactly: same aspect, cross-multiplied so no
         * float rounding can hide a per-axis scale. */
        if ((long)f.w * H != (long)f.h * W) {
            snprintf(buf, sizeof buf, "%dx%d: %dx%d distorts the aspect", ow, oh, f.w, f.h);
            inv_bad(buf);
        }
        /* Largest integer that fits. A fit that picked min() wrongly shows up
         * here before it shows up as an unexpectedly small picture. */
        if ((long)(f.scale + 1) * W <= ow && (long)(f.scale + 1) * H <= oh) {
            snprintf(buf, sizeof buf, "%dx%d: scale %d is not maximal", ow, oh, f.scale);
            inv_bad(buf);
        }
        /* Centred: the two bars differ by at most one pixel, and integer
         * division puts the spare pixel on the right and bottom, so 2*x is the
         * remainder or one less than it. */
        if (2 * f.x != ow - f.w && 2 * f.x != ow - f.w - 1) {
            snprintf(buf, sizeof buf, "%dx%d: not horizontally centred (x=%d)", ow, oh, f.x);
            inv_bad(buf);
        }
        if (2 * f.y != oh - f.h && 2 * f.y != oh - f.h - 1) {
            snprintf(buf, sizeof buf, "%dx%d: not vertically centred (y=%d)", ow, oh, f.y);
            inv_bad(buf);
        }
    } else {
        /* Below 1:1 the contract is to fill the window rather than crop. */
        if (f.w != ow || f.h != oh) {
            snprintf(buf, sizeof buf, "%dx%d: sub-1 fit should fill, got %dx%d",
                     ow, oh, f.w, f.h);
            inv_bad(buf);
        }
    }
}

int main(void)
{
    printf("scale: integer fit of %dx%d into a resized window\n", W, H);

    /* The default window: exactly 2x, so no bars at all. */
    expect(640, 400, 0, 0, 640, 400, 2, "default window is an exact 2x");
    /* 1x at the source size. */
    expect(320, 200, 0, 0, 320, 200, 1, "source size is 1x");
    /* Wide window: height binds, so the bars are left and right. */
    expect(800, 600, 80, 100, 640, 400, 2, "wide window letterboxes sideways");
    /* Tall window: width binds, so the bars are top and bottom. */
    expect(400, 800, 40, 300, 320, 200, 1, "tall window letterboxes vertically");
    /* A 16:9 window: 5x is the largest that fits vertically, and the horizontal
     * bars are the difference. This is the common laptop case. */
    expect(1920, 1080, 160, 40, 1600, 1000, 5, "1920x1080 scales 5x with side bars");
    /* One pixel over the source in both axes: still 1x, and the spare pixel goes
     * to the right and bottom because integer division rounds down. */
    expect(321, 201, 0, 0, 320, 200, 1, "one pixel of slack is still 1x");
    /* Just under 2x: must drop to 1x, not round up and overflow. */
    expect(639, 399, 159, 99, 320, 200, 1, "639x399 rounds down to 1x, not up");
    /* Smaller than the source: fill, and say so with scale 0. */
    expect(200, 150, 0, 0, 200, 150, 0, "window smaller than the frame fills");
    expect(1, 1, 0, 0, 1, 1, 0, "1x1 window fills");
    /* Degenerate outputs must not divide by zero or produce a negative rect. */
    expect(0, 0, 0, 0, 0, 0, 0, "zero-area window draws nothing");
    expect(-100, 400, 0, 0, 0, 0, 0, "negative width draws nothing");

    /* A zero source is a caller bug, but a crash on startup is not the answer. */
    {
        u2_fit f = u2_fit_integer(640, 400, 0, 0);
        if (f.w == 0 && f.h == 0) ok("zero source size is refused, not a division by zero");
        else bad("zero source size produced a rect");
    }

    /* Sweep the properties across a range of sizes, including awkward ones, so a
     * fit that happens to work on the tested cases cannot pass. The verdict is
     * counted, not assumed: an earlier draft printed this line unconditionally and
     * reported ok alongside 21,732 failures. */
    int before = fails;
    for (int oh = 1; oh <= 1200; oh += 7)
        for (int ow = 1; ow <= 2000; ow += 11)
            invariants(ow, oh);
    invariants(320, 200); invariants(319, 199); invariants(1600, 1000);
    invariants(2560, 1440); invariants(320, 1000); invariants(1000, 200);
    if (fails == before)
        printf("  ok    invariants hold across a 286x182 sweep of window sizes\n");
    else
        printf("  FAIL  invariants broke on %d of the swept window sizes\n", fails - before);

    printf("\n");
    if (fails == 0) { printf("SCALE CHECK: PASS\n"); return 0; }
    printf("SCALE CHECK: FAIL (%d)\n", fails);
    return 1;
}
