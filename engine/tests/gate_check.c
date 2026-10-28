/*
 * tests/gate_check.c — the time-door spec, as far as it is proven.
 *
 * Every expectation here is a live observation from 2026-10-29 (docs/moongates.md,
 * captures/spice86/moongate-cycle). The point of this file is not only to pin what is
 * known but to REJECT what is not: the unobserved pairings must report unknown, so an
 * implementation that quietly invents a destination era for slot 0 or 3 goes red here
 * rather than shipping a door that opens onto a guess.
 *
 * Build and run from engine/:
 *   cc -std=c11 -Wall -Wextra -Werror -Isrc -o /tmp/gate_check \
 *      tests/gate_check.c src/game/gates.c src/core/state.c && /tmp/gate_check
 */

#include <stdio.h>
#include <string.h>

#include "core/ctx.h"
#include "core/state.h"
#include "game/gates.h"

static int checks, fails;

#define CHECK(cond, ...) do {                                  \
        ++checks;                                              \
        if (cond) { printf("  ok    "); }                      \
        else { ++fails; printf("  FAIL  "); }                  \
        printf(__VA_ARGS__);                                   \
        printf("\n");                                          \
    } while (0)

/* The 20 table cells, read off original/ultimaii.exe at file 0x2998 and confirmed
 * against 12 live gate cells across eras 1, 2 and 3. */
static const struct { int era, slot, x, y; } k_table[] = {
    { 0, 0, 29, 56 }, { 0, 1, 31, 56 }, { 0, 2, 33, 56 }, { 0, 3, 35, 56 },
    { 1, 0, 34,  8 }, { 1, 1, 47, 28 }, { 1, 2, 36, 56 }, { 1, 3, 20, 37 },
    { 2, 0, 16, 16 }, { 2, 1, 48, 24 }, { 2, 2, 42, 24 }, { 2, 3, 19, 52 },
    { 3, 0, 56, 52 }, { 3, 1, 28, 12 }, { 3, 2, 33, 23 }, { 3, 3, 20, 52 },
    { 4, 0, 18, 23 }, { 4, 1, 50, 34 }, { 4, 2, 52, 24 }, { 4, 3,  8, 11 },
};

int main(void)
{
    /* --- the table ------------------------------------------------------- */
    for (size_t i = 0; i < sizeof k_table / sizeof k_table[0]; ++i) {
        int x = -1, y = -1;
        const int got = u2_gate_cell(k_table[i].era, k_table[i].slot, &x, &y);
        CHECK(got == 1 && x == k_table[i].x && y == k_table[i].y,
              "gate cell era%d slot%d = (%d,%d), got (%d,%d)",
              k_table[i].era, k_table[i].slot, k_table[i].x, k_table[i].y, x, y);
    }
    CHECK(u2_gate_cell(5, 0, NULL, NULL) == 0, "era 5 is out of range");
    CHECK(u2_gate_cell(2, 4, NULL, NULL) == 0, "slot 4 is out of range");

    /* --- the observed pairings ------------------------------------------- */
    CHECK(u2_gate_partner_era(1, 1) == 2, "era1 slot1 -> era2 (observed both ways)");
    CHECK(u2_gate_partner_era(2, 1) == 1, "era2 slot1 -> era1 (observed both ways)");
    CHECK(u2_gate_partner_era(2, 2) == 3, "era2 slot2 -> era3 (observed both ways)");
    CHECK(u2_gate_partner_era(3, 2) == 2, "era3 slot2 -> era2 (observed both ways)");

    /* The control that makes this spec able to fail in the place that matters. Slots 0
     * and 3 were never transited; a partner here is an invention, not a finding. */
    for (int era = 0; era < 5; ++era) {
        CHECK(u2_gate_partner_era(era, 0) == -1, "era%d slot0 stays unobserved", era);
        CHECK(u2_gate_partner_era(era, 3) == -1, "era%d slot3 stays unobserved", era);
    }

    /* --- index to slot ---------------------------------------------------- */
    CHECK(u2_gate_slot(0x00) == 0, "index 00 -> slot 0");
    CHECK(u2_gate_slot(0x02) == 1, "index 02 -> slot 1");
    CHECK(u2_gate_slot(0x04) == 2, "index 04 -> slot 2");
    CHECK(u2_gate_slot(0x06) == 3, "index 06 -> slot 3");
    CHECK(u2_gate_slot(0x08) == 0, "index 08 masks to 0, i.e. `and $0x7`");

    /* --- the rotation ------------------------------------------------------ */
    u2_ctx ctx;
    memset(&ctx, 0, sizeof ctx);
    ctx.state.gate_index = 0;
    ctx.state.gate_countdown = U2_GATE_COUNTDOWN_RELOAD;
    for (int i = 0; i < U2_GATE_COUNTDOWN_RELOAD - 1; ++i)
        u2_gate_turn(&ctx);
    CHECK(ctx.state.gate_index == 0, "index has not moved while the countdown runs");
    u2_gate_turn(&ctx);                          /* the expiry */
    CHECK(ctx.state.gate_countdown == U2_GATE_COUNTDOWN_RELOAD,
          "countdown reloads to 8 on expiry, got %u", ctx.state.gate_countdown);
    CHECK(ctx.state.gate_index == 2, "index advances by 2 on expiry, got %u",
          ctx.state.gate_index);
    for (int cycle = 0; cycle < 3; ++cycle) {
        for (int i = 0; i < U2_GATE_COUNTDOWN_RELOAD; ++i)
            u2_gate_turn(&ctx);
    }
    CHECK(ctx.state.gate_index == 0, "index wraps 06 -> 00 after four rotations, got %u",
          ctx.state.gate_index);

    printf("gate_check: %d checks, %d failures\n", checks, fails);
    return fails ? 1 : 0;
}
