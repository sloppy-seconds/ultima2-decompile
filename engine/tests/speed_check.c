/*
 * tests/speed_check.c — the speed model, against a live memory dump.
 *
 * The control here is not a hand-written expectation. Every number in MEASURED_* was
 * read out of captures/spice86/g30-clockcal/spice86dumpMemoryDump.bin, the DS window
 * located by the unique occurrence of the DS:74 value. If the rescale arithmetic in
 * game/speed.py is wrong in any way, reproducing all 20 slots from an independent
 * observation fails. That is what makes this a test rather than a restatement.
 *
 * Build and run by tests/run_cp5.sh.
 */
#include <stdio.h>
#include <string.h>

#include "core/ctx.h"
#include "core/state.h"
#include "game/speed.h"

static int fails, checks;
#define CHECK(cond, ...) do { checks++; if (!(cond)) { fails++; \
    printf("  FAIL  " __VA_ARGS__); printf("\n"); } } while (0)

/* All three arrays measured from the live dump at DS:74, DS:554 and DS:558.. */
#define MEASURED_SPEED    14871u      /* 0x3A17 */
#define MEASURED_BASELINE  1674u      /* 0x068A */

static const uint16_t MEASURED_MULT[U2_SPEED_SLOTS] = {
    6, 734, 8192, 1280, 3, 3, 3, 1280, 10, 4096,
    480, 320, 576, 512, 2048, 1, 0, 0, 0, 0
};

/* What the original had actually stored in DS:580.. when the dump was taken. */
static const uint16_t MEASURED_DELAY[U2_SPEED_SLOTS] = {
    47, 5786, 64581, 10090, 23, 23, 23, 10090, 78, 32290,
    3784, 2522, 4540, 4036, 16145, 7, 0, 0, 0, 0
};

static void load(u2_ctx *ctx, uint16_t speed)
{
    memset(ctx, 0, sizeof *ctx);
    u2_state_init(&ctx->state);
    ctx->state.speed          = speed;
    ctx->state.speed_baseline = MEASURED_BASELINE;
    for (int i = 0; i < U2_SPEED_SLOTS; i++)
        ctx->state.speed_mult[i] = MEASURED_MULT[i];
}

int main(void)
{
    u2_ctx ctx;

    /* --- the control: reproduce the original's own output table ---------------- */
    load(&ctx, MEASURED_SPEED);
    int faults = u2_speed_rescale(&ctx);
    int bad = 0;
    for (int i = 0; i < U2_SPEED_SLOTS; i++)
        if (ctx.state.speed_delay[i] != MEASURED_DELAY[i]) {
            if (bad < 5)
                printf("  slot %2d: engine %5u, original %5u\n",
                       i, ctx.state.speed_delay[i], MEASURED_DELAY[i]);
            bad++;
        }
    CHECK(bad == 0, "asm/06ED rescale: %d/%d slots reproduce the live dump (%d wrong)",
          U2_SPEED_SLOTS - bad, U2_SPEED_SLOTS, bad);
    CHECK(faults == 0, "no slot should overflow a 16-bit DIV at the measured speed (%d did)",
          faults);

    /* --- the clamp: a speed below the baseline zeroes every slot (asm/06F9) ----- */
    load(&ctx, MEASURED_BASELINE - 1);
    u2_speed_rescale(&ctx);
    int all_zero = 1;
    for (int i = 0; i < U2_SPEED_SLOTS; i++)
        if (ctx.state.speed_delay[i] != 0) all_zero = 0;
    CHECK(all_zero, "speed just below the baseline must zero every slot (jb -> mov $0x0,%%ax)");

    /* exactly at the baseline: `sub` gives 0 with no borrow, so every slot is 0*mult/b */
    load(&ctx, MEASURED_BASELINE);
    u2_speed_rescale(&ctx);
    all_zero = 1;
    for (int i = 0; i < U2_SPEED_SLOTS; i++)
        if (ctx.state.speed_delay[i] != 0) all_zero = 0;
    CHECK(all_zero, "speed == baseline gives 0 in every slot, not a borrow");

    /* --- F7 / F8: step, bounds, and that the rescale only runs on a change ------ */
    load(&ctx, 0x3a00);                       /* already at the ceiling */
    CHECK(u2_speed_faster(&ctx) == 0 && ctx.state.speed == 0x3a00,
          "asm/4FA5: F7 at the ceiling is rejected and leaves DS:74 alone");

    load(&ctx, 0x3a00 - U2_SPEED_STEP);
    CHECK(u2_speed_faster(&ctx) == 1 && ctx.state.speed == 0x3a00,
          "asm/4FA5: one F7 from just below lands exactly on 0x3a00");

    /* Pins the ceiling to the exact value rather than to "somewhere above here".
     * Found by mutation: with the bound written as 0x3a01 every earlier F7 test still
     * passed, because none of them tried the first value that must be rejected. */
    load(&ctx, (uint16_t)(0x3a00 - U2_SPEED_STEP + 1));
    CHECK(u2_speed_faster(&ctx) == 0 && ctx.state.speed == 0x3a00 - U2_SPEED_STEP + 1,
          "asm/4FA5: a step landing one above 0x3a00 is rejected -- the ceiling is exact");

    load(&ctx, 0x3a00 - 1);
    u2_speed_faster(&ctx);
    CHECK(ctx.state.speed == 0x3a00 - 1,
          "asm/4FA5: the ceiling is unsigned `ja`, so a step that would pass it is dropped");

    load(&ctx, MEASURED_BASELINE);
    CHECK(u2_speed_slower(&ctx) == 0,
          "asm/4F8E: F8 at the floor is rejected (cmp [0x554]; jb)");

    load(&ctx, MEASURED_BASELINE + U2_SPEED_STEP);
    CHECK(u2_speed_slower(&ctx) == 1 && ctx.state.speed == MEASURED_BASELINE,
          "asm/4F8E: one F8 from one step above lands exactly on the floor");

    /* A rejected keypress must not rescale: asm/4FA5's `ja` jumps past asm/4FB3. */
    load(&ctx, 0x3a00);
    u2_speed_rescale(&ctx);
    uint16_t before = ctx.state.speed_delay[0];
    ctx.state.speed_mult[0] = 999;            /* would change slot 0 if it rescaled */
    u2_speed_faster(&ctx);
    CHECK(ctx.state.speed_delay[0] == before,
          "a rejected F7 must not rescale (the `ja` skips asm/4FB3)");

    /* --- the accessor: asm/0711 takes a byte offset, the API takes an index ----- */
    load(&ctx, MEASURED_SPEED);
    u2_speed_rescale(&ctx);
    CHECK(u2_speed_delay(&ctx, 0x00 / 2) == ctx.state.speed_delay[0]
       && u2_speed_delay(&ctx, 0x14 / 2) == ctx.state.speed_delay[0x0A],
          "asm/0711 callers pass bx (a byte offset); index must be bx/2");
    CHECK(u2_speed_delay(&ctx, U2_SPEED_SLOTS) == 0,
          "an out-of-range slot returns 0 rather than reading past the table");

    /* --- a zero baseline is a DIV-by-zero fault on the real CPU, not a value ---- */
    load(&ctx, MEASURED_SPEED);
    ctx.state.speed_baseline = 0;
    CHECK(u2_speed_rescale(&ctx) == -1,
          "baseline 0 must be reported, not divided by (the original raises #DE)");

    printf("speed_check: %d checks, %d failures\n", checks, fails);
    return fails != 0;
}
