/*
 * tests/wander_check.c — the wandering spawn: selector table and spawner behaviour.
 *
 * Two separate jobs, and the first is the one that would be silent if broken.
 *
 *   1. the selector table. asm/0D01..0D21 walks the bits of DS:60 from bit 0 up and
 *      takes the arm of the LOWEST set bit, with a zero byte falling through to the
 *      Balron arm. Every one of the nine rows was pinned at runtime by forcing the
 *      byte (docs/monster-spawn.md § 15.4), so this asserts the table against that
 *      measurement for all 256 selector values — including 0x12, the case that
 *      distinguishes "lowest" from "highest" or "any".
 *
 *   2. the spawner's shape: highest free slot wins, the two coordinate gates refuse
 *      before anything is written, a refused arm rolls the selector back but still
 *      leaves its coordinates and terrain byte behind, and a successful arm stamps
 *      the grid. The rolls are not random here: the engine's rand_byte is a pure
 *      function of its state, so the test predicts the next two rolls from a copy
 *      of the ctx and only asserts the deep invariants on attempts whose rolls
 *      actually clear the gates.
 *
 * The terrain is engine-authored filler, same rule as monsters_check.c: no game
 * bytes are committed here.
 *
 * Build and run by tests/run_cp5.sh.
 */
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "core/ctx.h"
#include "core/rng.h"
#include "core/world.h"
#include "game/monsters.h"

static int fails, checks;
#define CHECK(cond, ...) do { checks++; if (!(cond)) { fails++; \
    printf("  FAIL  " __VA_ARGS__); printf("\n"); } } while (0)

/* The nine arms as measured, in bit order. Kept here rather than imported from
 * monsters.c on purpose: if someone edits the table in the module, this copy is
 * what catches it. */
static const uint8_t want_type[9] = {
    0x30, 0xFC, 0x34, 0x2C, 0xF0, 0x48, 0x38, 0xF8, 0x3C
};
static const uint8_t want_hp[9] = {
    0x10, 0x20, 0x40, 0x40, 0x80, 0xA0, 0xC0, 0xE0, 0xFF
};
static const uint8_t want_tile[9] = {
    0x08, 0x08, 0x08, 0x00, 0x08, 0x00, 0x08, 0x08, 0x08
};
static const char *want_name[9] = {
    "Orc", "Thief", "Daemon", "SeaSerpent", "Fighter",
    "Frigate", "Devil", "Wizard", "Balron"
};

static int arm_index_of(uint8_t selector)
{
    for (int bit = 0; bit < 8; bit++)
        if (selector & (1u << bit))
            return bit;
    return 8;
}

/* Predict the next two rand_byte() values without disturbing the real ctx. */
static void predict(u2_ctx *ctx, uint8_t *a, uint8_t *b)
{
    u2_ctx copy = *ctx;
    *a = u2_rand_byte(&copy);
    *b = u2_rand_byte(&copy);
}

/* Run exactly one attempt whose coordinate rolls are known to clear both gates,
 * with the selector parked so the next arm is the one under test. Returns the
 * spawner's result, or -2 if no roll pair in the sequence ever cleared the gates.
 *
 * The selector has to be forced because a refused arm rolls it back, so a uniform
 * terrain world gets stuck on the first arm that does not match it — which is
 * faithful behaviour, but it makes "keep calling and hope" a bad way to reach a
 * specific arm. */
static int one_attempt(u2_ctx *ctx, u2_world *w, uint8_t selector_before,
                       uint8_t *rx_out, uint8_t *ry_out)
{
    for (int n = 0; n < 4000; n++) {
        uint8_t rx, ry;
        predict(ctx, &rx, &ry);
        if (rx >= 0x3F || (ry & 0x80u)) {
            u2_rand_byte(ctx);
            u2_rand_byte(ctx);
            continue;
        }
        *rx_out = rx;
        *ry_out = ry;
        ctx->state.spawn_selector = selector_before;
        const int slot = u2_monsters_wander(ctx, w);
        return slot;
    }
    return -2;
}

static void setup(u2_ctx *ctx, u2_world *w, uint8_t terrain)
{
    memset(ctx, 0, sizeof *ctx);
    memset(w, 0, sizeof *w);
    u2_rng_seed(ctx, U2_RNG_DEFAULT_SEED);
    for (int i = 0; i < U2_SECTOR_TILES; i++)
        w->map[i] = w->map_base[i] = terrain;
    w->map_loaded = true;
}

int main(void)
{
    /* ---- 1. the selector table, all 256 values ---- */
    for (int v = 0; v < 256; v++) {
        const int idx = arm_index_of((uint8_t)v);
        const struct u2_spawn_arm arm = u2_spawn_arm_for((uint8_t)v);
        CHECK(arm.type == want_type[idx] && arm.hp == want_hp[idx] &&
              arm.want_tile == want_tile[idx],
              "selector 0x%02x -> %s", v, want_name[idx]);
    }

    /* The rows the capture actually observed, named so a regression says which
     * measurement it contradicts rather than just a number. */
    CHECK(u2_spawn_arm_for(0x01).type == 0x30, "chain 0x01 is the Orc arm");
    CHECK(u2_spawn_arm_for(0x02).type == 0xFC, "chain 0x02 is the Thief arm");
    CHECK(u2_spawn_arm_for(0x04).type == 0x34, "chain 0x04 is the Daemon arm");
    CHECK(u2_spawn_arm_for(0x08).type == 0x2C, "chain 0x08 is the sea serpent arm");
    CHECK(u2_spawn_arm_for(0x10).type == 0xF0, "chain 0x10 is the Fighter arm");
    CHECK(u2_spawn_arm_for(0x20).type == 0x48, "chain 0x20 is the Frigate arm");
    CHECK(u2_spawn_arm_for(0x40).type == 0x38, "chain 0x40 is the Devil arm");
    CHECK(u2_spawn_arm_for(0x80).type == 0xF8, "chain 0x80 is the Wizard arm");
    CHECK(u2_spawn_arm_for(0x00).type == 0x3C, "chain 0x00 falls through to Balron");
    /* The discriminating one: bits 1 and 4 both set, and the capture showed the
     * Thief stamp, so the chain takes the LOWEST set bit. */
    CHECK(u2_spawn_arm_for(0x12).type == 0xFC,
          "chain 0x12 takes bit1 (Thief), not bit4 (Fighter)");
    CHECK(u2_spawn_arm_for(0xFF).type == 0x30, "chain 0xFF takes bit0");
    /* The two water arms are the only ones wanting 0x00, and they are the only two
     * sea creatures. If this ever fails the terrain reading is wrong. */
    CHECK(want_tile[3] == 0x00 && want_tile[5] == 0x00 &&
          want_tile[0] != 0x00 && want_tile[1] != 0x00 && want_tile[2] != 0x00 &&
          want_tile[4] != 0x00 && want_tile[6] != 0x00 && want_tile[7] != 0x00 &&
          want_tile[8] != 0x00,
          "exactly the two sea creatures want water terrain");

    /* ---- 2a. a mixed world: every success must match the arm the selector picked ---- */
    {
        u2_ctx ctx; u2_world w;
        setup(&ctx, &w, 0x08);
        for (int i = 0; i < U2_SECTOR_TILES; i++)
            if ((i / U2_SECTOR_EDGE + i % U2_SECTOR_EDGE) % 2)
                w.map[i] = 0x00;          /* checkerboard land/water */
        int spawned = 0, refused = 0, roll_refused = 0;
        for (int n = 0; n < 600; n++) {
            uint8_t rx, ry;
            predict(&ctx, &rx, &ry);
            const int gate_ok = (rx < 0x3F) && !(ry & 0x80u);
            const uint8_t before = ctx.state.spawn_selector;
            const int idx = arm_index_of((uint8_t)(before + 1));
            /* Read the terrain BEFORE the call: a successful arm stamps its type
             * over the cell, so reading afterwards compares the creature against
             * itself and every refusal looks like a mismatch. The first draft of
             * this test did exactly that and reported 0 spawns. */
            const uint8_t tile = gate_ok
                ? w.map[(ry & 0x3F) * U2_SECTOR_EDGE + rx] : 0;
            const int slot = u2_monsters_wander(&ctx, &w);
            if (!gate_ok) {
                roll_refused++;
                CHECK(slot < 0, "a failing coordinate roll spawns nothing");
                CHECK(ctx.state.spawn_selector == before,
                      "a failing roll leaves the selector alone");
                continue;
            }
            if (tile != want_tile[idx]) {
                refused++;
                CHECK(slot < 0, "arm %s refuses terrain 0x%02x", want_name[idx], tile);
                CHECK(ctx.state.spawn_selector == before,
                      "a refused arm rolls the selector back");
                continue;
            }
            CHECK(slot >= 0, "a matching arm spawns");
            CHECK(ctx.state.spawn_selector == (uint8_t)(before + 1),
                  "a successful arm keeps the increment");
            CHECK(ctx.state.mon_type[slot] == want_type[idx] &&
                  ctx.state.mon_hp[slot] == want_hp[idx],
                  "slot %d carries the arm's type and hp", slot);
            const int cell = (int)ctx.state.mon_y[slot] * U2_SECTOR_EDGE +
                             (int)ctx.state.mon_x[slot];
            CHECK(w.map[cell] == want_type[idx], "the grid cell is stamped");
            CHECK(ctx.state.mon_kind[slot] == tile,
                  "the slot keeps the terrain byte it was tested against");
            spawned++;
        }
        CHECK(spawned >= 4 && refused >= 4 && roll_refused >= 4,
              "the run exercised spawns, terrain refusals and roll refusals "
              "(%d/%d/%d)", spawned, refused, roll_refused);
    }

    /* ---- 2b. one arm at a time, on terrain that suits it and terrain that does not ---- */
    {
        /* bit index -> the selector value whose NEXT increment lands on it. */
        static const struct { uint8_t before; int idx; } pick[9] = {
            { 0x00, 0 }, { 0x01, 1 }, { 0x03, 2 }, { 0x07, 3 }, { 0x0F, 4 },
            { 0x1F, 5 }, { 0x3F, 6 }, { 0x7F, 7 }, { 0xFF, 8 },
        };
        for (int k = 0; k < 9; k++) {
            for (int t = 0; t < 2; t++) {
                const uint8_t terrain = t ? 0x08 : 0x00;
                const int fits = (terrain == want_tile[pick[k].idx]);
                u2_ctx ctx; u2_world w;
                setup(&ctx, &w, terrain);
                uint8_t rx, ry;
                const int slot = one_attempt(&ctx, &w, pick[k].before, &rx, &ry);
                if (slot == -2) { CHECK(0, "no roll pair cleared the gates"); continue; }
                if (fits) {
                    CHECK(slot >= 0, "%s on its own terrain spawns", want_name[pick[k].idx]);
                    CHECK(ctx.state.spawn_selector == (uint8_t)(pick[k].before + 1),
                          "%s keeps the selector increment", want_name[pick[k].idx]);
                    CHECK(ctx.state.mon_type[slot] == want_type[pick[k].idx] &&
                          ctx.state.mon_hp[slot] == want_hp[pick[k].idx],
                          "%s writes type %02x hp %02x",
                          want_name[pick[k].idx], want_type[pick[k].idx],
                          want_hp[pick[k].idx]);
                    CHECK(w.map[(int)ctx.state.mon_y[slot] * U2_SECTOR_EDGE +
                                (int)ctx.state.mon_x[slot]] == want_type[pick[k].idx],
                          "%s stamps the grid", want_name[pick[k].idx]);
                } else {
                    CHECK(slot < 0, "%s refuses terrain 0x%02x",
                          want_name[pick[k].idx], terrain);
                    CHECK(ctx.state.spawn_selector == pick[k].before,
                          "%s rolls the selector back", want_name[pick[k].idx]);
                    CHECK(ctx.state.mon_type[slot < 0 ? 31 : slot] == 0,
                          "%s writes no type", want_name[pick[k].idx]);
                }
            }
        }
    }

    /* ---- 2c. the residue a refused arm leaves behind ---- */
    {
        u2_ctx ctx; u2_world w;
        setup(&ctx, &w, 0x08);
        /* Force the selector so the next arm is the sea serpent (bit3, wants 0x00)
         * and feed it a roll that clears both gates. */
        int done = 0;
        for (int n = 0; n < 600 && !done; n++) {
            uint8_t rx, ry;
            predict(&ctx, &rx, &ry);
            if (!(rx < 0x3F && !(ry & 0x80u))) { u2_monsters_wander(&ctx, &w); continue; }
            ctx.state.spawn_selector = 0x07;   /* next incb -> 0x08 -> bit3 */
            const int slot = u2_monsters_wander(&ctx, &w);
            CHECK(slot < 0, "the sea serpent arm refuses land");
            CHECK(ctx.state.spawn_selector == 0x07, "and rolls the selector back");
            /* asm/0CC0 and asm/0CDC store the coordinates before the arm runs, so a
             * refused attempt still leaves them set. Live reads found exactly this
             * residue; a slot with x, y and terrain and no type. */
            CHECK(ctx.state.mon_type[slot < 0 ? 31 : slot] == 0, "no type is written");
            CHECK(ctx.state.mon_x[31] == rx && ctx.state.mon_y[31] == (ry & 0x3Fu),
                  "the refused attempt still leaves its coordinates behind");
            CHECK(ctx.state.mon_kind[31] == 0x08, "and the terrain byte it tested");
            done = 1;
        }
        CHECK(done, "found a roll pair that clears both gates");
    }

    /* ---- 2d. a full sector spawns nothing and does not touch the selector ---- */
    {
        u2_ctx ctx; u2_world w;
        setup(&ctx, &w, 0x08);
        for (int i = 0; i < U2_MON_SLOTS; i++)
            ctx.state.mon_type[i] = 0x30;
        const uint8_t before = ctx.state.spawn_selector;
        int any = 0;
        for (int n = 0; n < 50; n++)
            if (u2_monsters_wander(&ctx, &w) >= 0)
                any = 1;
        CHECK(!any, "a full sector gives no spawn");
        CHECK(ctx.state.spawn_selector == before,
              "a no-free-slot attempt never reaches the selector");
    }

    printf("wander_check: %d checks, %d failures\n", checks, fails);
    return fails ? 1 : 0;
}
