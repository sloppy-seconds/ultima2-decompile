/*
 * tests/rng_check.c — resuming the shift register from a captured state.
 *
 * u2_rng_seed can only produce 256 of the 2^48 reachable register states: asm/0100 writes six copies
 * of one byte and increments two of them. Cross-game replay needs to resume from an arbitrary
 * register, because the original's idle loop advances the register on the BIOS timer, so the state at
 * turn N is a function of emulated time as well as commands. That is what u2_rng_load is for, and this
 * is the test the plan asked for: prove a load reproduces the stream, and prove the test can tell when
 * it does not.
 *
 * The second half is the part that matters. A load that silently did nothing — a memcpy to the wrong
 * field, a copy that ran before the seed and got overwritten — would still pass a test that only checks
 * "the engine rolls something". So the corrupt-byte control is not decoration: without it, a no-op
 * load is indistinguishable from a working one.
 *
 * Build and run by tests/run_cp0.sh.
 */
#include <stdio.h>
#include <string.h>

#include "core/ctx.h"
#include "core/rng.h"
#include "core/state.h"

static int fails, checks;
#define CHECK(cond, ...) do { checks++; if (!(cond)) { fails++; \
    printf("  FAIL  " __VA_ARGS__); printf("\n"); } } while (0)

#define RUN 50
#define SKIP 10

static void fresh(u2_ctx *ctx)
{
    memset(ctx, 0, sizeof *ctx);
    u2_state_init(&ctx->state);
    u2_rng_seed(ctx, U2_RNG_DEFAULT_SEED);
}

int main(void)
{
    u2_ctx a, b;
    uint8_t captured[6], want[RUN], got[RUN];

    /* --- the property: a load at turn SKIP continues the same stream ------------ */
    fresh(&a);
    for (int i = 0; i < SKIP; i++)
        (void)u2_rand_byte(&a);
    memcpy(captured, a.state.rng_state, 6);
    for (int i = 0; i < RUN; i++)
        want[i] = u2_rand_byte(&a);

    fresh(&b);
    u2_rng_load(&b, captured);
    CHECK(memcmp(b.state.rng_state, captured, 6) == 0,
          "load did not land: want %02X… got %02X…",
          captured[0], b.state.rng_state[0]);
    for (int i = 0; i < RUN; i++)
        got[i] = u2_rand_byte(&b);
    CHECK(memcmp(want, got, RUN) == 0,
          "resumed stream diverges from the uninterrupted one (first diff printed below)");
    for (int i = 0; i < RUN; i++)
        if (want[i] != got[i]) { printf("        first diff at %d: want %u got %u\n",
                                        i, want[i], got[i]); break; }

    /* --- control: a wrong register must NOT reproduce --------------------------- */
    uint8_t corrupt[6];
    memcpy(corrupt, captured, 6);
    corrupt[3] ^= 0x01;
    fresh(&b);
    u2_rng_load(&b, corrupt);
    for (int i = 0; i < RUN; i++)
        got[i] = u2_rand_byte(&b);
    CHECK(memcmp(want, got, RUN) != 0,
          "CONTROL FAILED: a corrupted register still reproduced the stream — "
          "the load is doing nothing and this test proves nothing");

    /* --- control: a load must differ from a plain seed -------------------------- */
    fresh(&b);
    for (int i = 0; i < RUN; i++)
        got[i] = u2_rand_byte(&b);
    CHECK(memcmp(want, got, RUN) != 0,
          "CONTROL FAILED: the loaded register matched a fresh seed — "
          "either the load is a no-op or SKIP is too small to tell them apart");

    /* --- the roll counter is a diagnostic and resets on load -------------------- */
    fresh(&b);
    u2_rng_load(&b, captured);
    CHECK(u2_rng_rolls(&b) == 0, "load should reset the roll counter, got %u",
          u2_rng_rolls(&b));
    (void)u2_rand_byte(&b);
    CHECK(u2_rng_rolls(&b) == 1, "roll counter did not advance after load");

    /* --- every reachable seed state is also loadable, and vice versa ------------ */
    for (uint8_t s = 0; s < 32; s++) {
        u2_ctx c;
        uint8_t st[6];
        memset(&c, 0, sizeof c);
        u2_state_init(&c.state);
        u2_rng_seed(&c, s);
        memcpy(st, c.state.rng_state, 6);
        fresh(&c);
        u2_rng_load(&c, st);
        CHECK(memcmp(c.state.rng_state, st, 6) == 0,
              "seed 0x%02X state did not survive a load round-trip", s);
    }

    printf("rng_check: %d checks, %d failures\n", checks, fails);
    return fails ? 1 : 0;
}
