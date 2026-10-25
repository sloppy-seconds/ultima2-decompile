/*
 * food_check.c — CP4b T2: time passes, food drains, starvation kills.
 *
 * Every claim here is a byte in the original, cited by file address:
 *
 *   file 0x0B0D..0x0B33  the PASS arm. `sbb $0x0a` on DS:55, borrow up through
 *                        DS:54 then DS:53, each corrected with `das`. The three
 *                        bytes are one 6-digit packed-decimal number, low byte
 *                        at DS:55, so one PASS spends 10 units.
 *   file 0x0B2E          `jb` — a borrow out of DS:53 is the death condition.
 *   runtime 0x0E62 (asm/0C62)
 *                        the death handler: DS:51..DS:59 all to zero (HP, FOOD,
 *                        EXP, GOLD together), then a redraw call. There is no
 *                        intermediate "food is zero, now HP ticks down" step in
 *                        the tree, so the engine has none either.
 *   asm/5129 + file 0x5340
 *                        the status band prints only DS:53/DS:54, the top four
 *                        digits. A fresh character (DS:53=04, DS:54=00,
 *                        DS:55=00) therefore displays FOOD=0400 while holding
 *                        4000 units, and the first PASS moves the display only
 *                        on every tenth pass. That is the original's own
 *                        arithmetic, reproduced rather than tidied away.
 *
 * The numbers below come from a reference model of the three-byte sbb/das
 * chain built before the C port, so they are the asm's behaviour and not the
 * test author's expectation.
 */
#include <stdio.h>
#include <string.h>

#include "core/ctx.h"
#include "core/state.h"
#include "game/overworld.h"

static int fails, checks;
#define CHECK(cond, ...) do { checks++; if (!(cond)) { fails++; \
    printf("  FAIL  " __VA_ARGS__); printf("\n"); } } while (0)

static void set_food(u2_ctx *ctx, uint8_t hi, uint8_t mid, uint8_t lo)
{
    ctx->state.food = hi; ctx->state.food_hi = mid; ctx->state.food_lo = lo;
}
/* The four digits the player actually sees, i.e. DS:53 then DS:54. */
static int shown(u2_ctx *ctx)
{
    return (ctx->state.food << 8) | ctx->state.food_hi;
}

int main(void)
{
    u2_ctx ctx;
    memset(&ctx, 0, sizeof ctx);

    /* --- one PASS off a fresh character: 4000 -> 3990, display 0400 -> 0399 */
    set_food(&ctx, 0x04, 0x00, 0x00);
    CHECK(u2_overworld_spend_food(&ctx, 0x0A) == 0, "first PASS must not kill");
    CHECK(shown(&ctx) == 0x0399, "display must read 0399, got %04d", shown(&ctx));
    CHECK(ctx.state.food_lo == 0x90, "the hidden low byte carries the borrow (0x90)");

    /* --- ten PASSes land the hidden byte back on 00, display still 0399 --- */
    for (int i = 0; i < 9; i++) u2_overworld_spend_food(&ctx, 0x0A);
    CHECK(ctx.state.food_lo == 0x00, "10 passes must clear the low byte");
    CHECK(shown(&ctx) == 0x0399, "10 passes read 0399 on the band, got %04d", shown(&ctx));

    /* --- the step rate: asm/2599 and asm/2626 do `sbb $0x19` ---------------
     * The argument is the immediate byte, so 0x19 is nineteen, not twenty-five.
     * The low byte is the half that discriminates: a decimal 19 passed by mistake
     * subtracts thirteen and leaves 0x87 here, and the four visible digits read
     * 0999 either way. That is how the port charged 13 per step and still passed
     * every test written before 2026-10-25. */
    memset(&ctx, 0, sizeof ctx);
    set_food(&ctx, 0x10, 0x00, 0x00);           /* 100000 */
    CHECK(u2_overworld_spend_food(&ctx, 0x19) == 0, "100000 - 19 must not kill");
    CHECK(shown(&ctx) == 0x0999, "100000 - 19 must show 0999, got %04d", shown(&ctx));
    CHECK(ctx.state.food_lo == 0x81, "100000 - 19 leaves 0x81 in the low byte, got %02X",
          ctx.state.food_lo);

    /* --- death: a borrow out of DS:53 zeroes every stat byte (asm/0C62) -- */
    memset(&ctx, 0, sizeof ctx);
    ctx.state.hp = 0x62; ctx.state.unk_52 = 0x84;
    ctx.state.exp_lo = 0x21; ctx.state.exp_hi = 0x35;
    ctx.state.gold_lo = 0x00; ctx.state.gold_hi = 0x38;
    set_food(&ctx, 0x00, 0x00, 0x05);           /* 5 units: one PASS underflows */
    CHECK(u2_overworld_spend_food(&ctx, 0x0A) == 1, "5 - 10 must underflow");
    CHECK(ctx.state.food == 0 && ctx.state.food_hi == 0 && ctx.state.food_lo == 0,
          "death zeroes FOOD");
    CHECK(ctx.state.hp == 0 && ctx.state.unk_52 == 0, "death zeroes HP (DS:51/52)");
    CHECK(ctx.state.exp_lo == 0 && ctx.state.exp_hi == 0, "death zeroes EXP (DS:56/57)");
    CHECK(ctx.state.gold_lo == 0 && ctx.state.gold_hi == 0, "death zeroes GOLD (DS:58/59)");

    /* --- a fresh character survives exactly 4000 passes and dies on the
     *     4001st. This is the number the reference model of the asm gives,
     *     and it is the one a player would measure. ----------------------- */
    memset(&ctx, 0, sizeof ctx);
    set_food(&ctx, 0x04, 0x00, 0x00);
    int deaths = 0, died_on = 0;
    for (int i = 1; i <= 5000; i++) {
        if (u2_overworld_spend_food(&ctx, 0x0A)) { deaths++; died_on = i; break; }
    }
    CHECK(deaths == 1, "the run must end in exactly one death");
    CHECK(died_on == 4001, "4000 food units at 10 a pass dies on pass 4001, got %d", died_on);

    printf("food_check: %d checks, %d failures\n", checks, fails);
    return fails ? 1 : 0;
}
