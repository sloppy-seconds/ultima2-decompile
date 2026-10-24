/*
 * tests/ai_check.c — CP5 W6/W6b: the creature turn, against the real ai.c.
 *
 * Every expectation cites the byte it came from; the routine is asm/0A6D..0AB5
 * (per-slot pass) and asm/2122..2260 (the move), written up in
 * docs/monster-spawn.md § 13. The four that are easiest to get wrong, and are
 * therefore pinned hardest here:
 *
 *   - an empty slot is mon_type == 0 (asm/0A74 `or %al,%al; je next`), NOT 0x40;
 *   - a creature never attacks for being adjacent: the special is a proximity
 *     gate plus a 1-in-8 roll (asm/0AAA), and contact stops the move rather than
 *     causing a blow (asm/2201 -> asm/218b);
 *   - the retreat threshold (hp < 15, asm/0B07) is not the regen threshold
 *     (hp < 16, asm/2126), so a creature on exactly 15 heals and keeps coming;
 *   - the step is a diagonal (asm/212e), which is two cells of Manhattan
 *     distance in one turn — the measured "movers shift 2 cells".
 *
 * Build and run by tests/run_cp5.sh.
 */
#include <stdio.h>
#include <string.h>

#include "core/ctx.h"
#include "core/rng.h"
#include "core/seam.h"
#include "core/state.h"
#include "core/vram.h"
#include "core/world.h"
#include "game/ai.h"
#include "game/monsters.h"
#include "game/status.h"   /* u2_status_draw, so the CMD window exists to print into */
#include "gen_content.h"

static int fails, checks;
#define CHECK(cond, ...) do { checks++; if (!(cond)) { fails++; \
    printf("  FAIL  " __VA_ARGS__); printf("\n"); } } while (0)

#define GRASS 0x08u          /* passable for the player and for land creatures */
#define WATER 0x00u          /* asm/21d8: the only tile a sea monster accepts */

static const char *msg_text(u2_ctx *ctx, int row, char *buf)
{
    int n = 0;
    for (int c = 0; c <= 29; c++)
        buf[n++] = (char)ctx->vram.cell[row][c].ch;
    while (n > 0 && buf[n - 1] == ' ') n--;
    buf[n] = '\0';
    char *p = buf;
    while (*p == ' ') p++;
    return p;
}

/* A sector of one tile, with map_base matching so a restamp has something to
 * restore. Engine-authored filler; no game bytes here (same rule as
 * monsters_check.c). */
static void ground(u2_world *w, uint8_t tile)
{
    memset(w, 0, sizeof *w);
    for (int i = 0; i < U2_SECTOR_TILES; i++)
        w->map[i] = w->map_base[i] = tile;
    w->map_loaded = 1;
}

static void arm(u2_ctx *ctx, u2_world *w, uint8_t tile,
                int slot, uint8_t x, uint8_t y, uint8_t hp, uint8_t type)
{
    memset(ctx, 0, sizeof *ctx);
    u2_vram_init(&ctx->vram);
    u2_state_init(&ctx->state);
    u2_rng_seed(ctx, 7);
    ground(w, tile);

    ctx->state.mon_x[slot]    = (uint8_t)x;
    ctx->state.mon_y[slot]    = (uint8_t)y;
    ctx->state.mon_hp[slot]   = hp;
    ctx->state.mon_type[slot] = type;
}

/* The first roll a freshly-seeded ctx serves, so a test can pick a seed whose
 * gate roll lands under 0x20 instead of hoping one does. */
static uint8_t first_roll(uint8_t seed)
{
    u2_ctx p;
    memset(&p, 0, sizeof p);
    u2_rng_seed(&p, seed);
    return u2_rand_byte(&p);
}

int main(void)
{
    u2_ctx ctx;
    u2_world w;
    u2_ai_report rep;
    char buf[64];

    /* --- an empty sector does nothing, and touches no randomness ------------ */
    arm(&ctx, &w, GRASS, 0, 0, 0, 0, 0);
    rep = u2_ai_creature_turn(&ctx, &w, 10, 10);
    CHECK(rep.examined == 0 && rep.moved == 0 && u2_rng_rolls(&ctx) == 0,
          "empty sector: nothing examined, nothing moved, no roll");

    /* --- the step is a diagonal toward the player (asm/212e) ---------------- */
    /* Everything in this file down to the role-gate section runs on the world map
     * (sector digit 0), which asm/0A38 sends to the UNGATED sweep — mon_role is
     * not consulted there, so the role-1 writes below are belt-and-braces for
     * creatures that would act either way. The gated sweep is tested on its own.
     */
    arm(&ctx, &w, GRASS, 3, 5, 5, 40, 0x30);       /* Fighter, plain */
    ctx.state.mon_role[3] = 1;
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(ctx.state.mon_x[3] == 6 && ctx.state.mon_y[3] == 6,
          "pursuit is the diagonal (5,5)->(6,6), i.e. two Manhattan cells in one turn");
    CHECK(rep.moved == 1 && u2_rng_rolls(&ctx) == 0,
          "outside the 3-cell ring the gate is not rolled at all (asm/0AB6/0AC0)");

    /* --- the two HP thresholds are different numbers ------------------------ */
    arm(&ctx, &w, GRASS, 4, 5, 5, 15, 0x30);
    ctx.state.mon_role[4] = 1;
    u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(ctx.state.mon_hp[4] == 16 && ctx.state.mon_x[4] == 6,
          "hp 15 regenerates (asm/2126, <16) and still pursues (asm/0B07, >=15)");

    arm(&ctx, &w, GRASS, 4, 5, 5, 14, 0x30);
    ctx.state.mon_role[4] = 1;
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(ctx.state.mon_hp[4] == 15 && ctx.state.mon_x[4] == 4 && ctx.state.mon_y[4] == 4,
          "hp 14 regenerates AND flees: the vector is negated (asm/0B0F)");
    CHECK(rep.retreated == 1, "the retreat is reported, so a caller can log it");

    /* --- species: a sea monster lives in water and nowhere else ------------- */
    arm(&ctx, &w, GRASS, 6, 5, 5, 40, 0x2c);
    ctx.state.mon_role[6] = 1;       /* Sea Monster */
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(rep.moved == 0 && ctx.state.mon_x[6] == 5,
          "asm/21d8: a sea monster refuses grass");

    arm(&ctx, &w, WATER, 6, 5, 5, 40, 0x2c);
    ctx.state.mon_role[6] = 1;
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(rep.moved == 1 && ctx.state.mon_x[6] == 6,
          "asm/21d8: the same sea monster accepts water");

    arm(&ctx, &w, WATER, 7, 5, 5, 40, 0x30);
    ctx.state.mon_role[7] = 1;       /* Fighter on water */
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(rep.moved == 0,
          "asm/21c9: the general ladder refuses tile 0x00, so land creatures do not swim");

    /* --- contact stops the move and does not cause a blow ------------------- */
    arm(&ctx, &w, GRASS, 8, 7, 7, 40, 0x30);
    ctx.state.mon_role[8] = 1;
    const uint32_t rolls_before = u2_rng_rolls(&ctx);
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(ctx.state.mon_x[8] == 7 && ctx.state.mon_y[8] == 7,
          "asm/2201: the candidate cell is the player's, so the creature does not step");
    /* Corrected the same day it was written: the first version of this check said
     * "and nothing else — there is no melee site". There is: asm/0B4D's contact arm
     * also draws asm/0B62's hit roll, so two rolls per contact, and a landed blow
     * adds mon_hp>>2 + 1 to the pool. */
    CHECK(rep.moved == 0 && rep.gates == 1 && rep.contacts == 1 &&
          u2_rng_rolls(&ctx) == rolls_before + 2,
          "contact: the special gate AND asm/0B62's melee roll, and no step");
    CHECK(rep.damage_pool == 0 || rep.damage_pool == (40 >> 2) + 1,
          "a landed melee blow pools mon_hp>>2 + 1 (asm/0B79); a dodged one pools 0");

    /* --- the special gate: proximity, then 1 in 8, then the type dispatch --- */
    uint8_t seed = 0;
    while (first_roll(seed) >= 0x20 && seed < 255) seed++;
    CHECK(first_roll(seed) < 0x20, "a seed exists whose first roll passes asm/0ACF");

    arm(&ctx, &w, GRASS, 9, 7, 7, 40, 0x34);
    ctx.state.mon_role[9] = 1;       /* legs paralyser */
    u2_rng_seed(&ctx, seed);
    u2_status_draw(&ctx);
    seam_goto(&ctx, 0, U2_MSG_BOTTOM);
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(rep.gates == 1 && rep.landed == 1,
          "asm/0E70 with no boots: the effect lands with no resist roll (C2)");
    /* The message scrolls the moment its own newline lands, exactly like the death
     * tail, so it is searched across the window rather than assumed to sit on the
     * bottom row. */
    int found = 0;
    for (int row = U2_MSG_TOP; row <= U2_MSG_BOTTOM; row++)
        if (strstr(msg_text(&ctx, row, buf), "LEGS PARALIZED!") != NULL)
            found = 1;
    CHECK(found, "asm/0E70 announces the paralysis before it rolls anything");

    /* And a creature outside the ring must not print or roll: without this, a
       gate that always fired would look the same in the check above. */
    arm(&ctx, &w, GRASS, 9, 1, 1, 40, 0x34);
    ctx.state.mon_role[9] = 1;
    u2_rng_seed(&ctx, seed);
    rep = u2_ai_creature_turn(&ctx, &w, 20, 20);
    CHECK(rep.gates == 0 && rep.landed == 0 && u2_rng_rolls(&ctx) == 0,
          "control: the same paralyser far away neither rolls nor prints");

    /* --- DS:26A freezes every creature before the species test (asm/2199) --- */
    arm(&ctx, &w, GRASS, 11, 5, 5, 40, 0x30);
    ctx.state.mon_role[11] = 1;
    ctx.state.counter_26A = 1;
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(rep.moved == 0 && ctx.state.mon_x[11] == 5,
          "asm/2199: a non-zero DS:26A refuses every move (inert until W7 ticks it)");

    /* --- the grid follows the creature, and the terrain follows the grid ---- */
    arm(&ctx, &w, GRASS, 12, 5, 5, 40, 0x30);
    ctx.state.mon_role[12] = 1;
    w.map[5 * U2_SECTOR_EDGE + 5] = 0x30;          /* the spawn stamp */
    u2_ai_creature_turn(&ctx, &w, 8, 8);
    u2_monsters_restamp(&ctx, &w);
    CHECK(w.map[5 * U2_SECTOR_EDGE + 5] == GRASS,
          "the vacated cell is terrain again, not a permanent invisible monster");
    CHECK(w.map[6 * U2_SECTOR_EDGE + 6] == 0x30,
          "the new cell carries the creature's type byte, which is what the renderer draws");

    /* --- the role gate (asm/102B / asm/1033): most slots are inert ----------- */
    /* Only on the TOWN sweep: asm/0A38 sends sector digits 1..3 to the role-gated
     * chain at asm/1013/1015, so every check in this block sets the second digit
     * first. monxNN ships role 0 in six to eleven slots and
     * 0x81..0x85 in four or five, and both of those do nothing at all. Without
     * this control the checks above would pass while every creature in a town
     * acted. */
    arm(&ctx, &w, GRASS, 13, 5, 5, 40, 0x30);
    ctx.state.sector_second = 1;
    ctx.state.mon_role[13] = 0;
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(rep.moved == 0 && ctx.state.mon_x[13] == 5,
          "role 0: asm/102B sends the slot to next, so an inert creature stays put");

    arm(&ctx, &w, GRASS, 13, 5, 5, 40, 0x30);
    ctx.state.sector_second = 1;
    ctx.state.mon_role[13] = 0x81;          /* a scripted townsperson */
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(rep.moved == 0,
          "role 0x81: asm/1033 is `js next`, so bit 7 excludes the scripted folk");

    arm(&ctx, &w, GRASS, 13, 5, 5, 40, 0x34);   /* a paralyser... */
    ctx.state.sector_second = 1;
    ctx.state.mon_role[13] = 2;                /* ...but alerted */
    u2_rng_seed(&ctx, seed);
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);  /* far enough that it is not contact */
    CHECK(rep.gates == 0 && rep.contacts == 0 && u2_rng_rolls(&ctx) == 0,
          "role 2 goes straight to the move routine: it chases, never casts, rolls nothing");

    arm(&ctx, &w, GRASS, 13, 5, 5, 14, 0x30);
    ctx.state.sector_second = 1;
    ctx.state.mon_role[13] = 2;
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(rep.retreated == 0 && ctx.state.mon_x[13] == 6,
          "role 2 does not run: the retreat test is on the role-1 path only");

    /* --- the world-map sweep is NOT role-gated (asm/0A38 -> asm/0A6D) -------- */
    /* The regression this exists for. asm/0A38 dispatches the post-command tail on
     * the sector's second decimal digit: 0 jumps to the sweep at asm/0A6D, which
     * never reads mon_role; 1..3 branch to the gated chain; 6..9 fall through to
     * 0A6D too. The engine applied the town gate to both, so every wandering
     * spawn — born role 0, because monx20 ships role 0 in all 32 slots — stood
     * still while the player walked past it. Owner-reported 2026-10-28: "any
     * monster I can see in the viewport has a turn and usually comes to attack me".
     * Flip the gated_sweep test in ai.c and one of these two goes red. */
    arm(&ctx, &w, GRASS, 14, 5, 5, 40, 0x30);
    ctx.state.sector_second = 0;         /* the world map */
    ctx.state.mon_role[14]  = 0;         /* what a wandering spawn leaves behind */
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(rep.moved == 1 && ctx.state.mon_x[14] == 6 && ctx.state.mon_y[14] == 6,
          "world map: a role-0 creature takes the full pass and pursues (asm/0A6D has no role test)");

    arm(&ctx, &w, GRASS, 14, 5, 5, 40, 0x30);
    ctx.state.sector_second = 1;         /* a town sector, same creature */
    ctx.state.mon_role[14]  = 0;
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(rep.moved == 0 && ctx.state.mon_x[14] == 5,
          "control: the identical role-0 creature in a digit-1..3 sector stays put");

    arm(&ctx, &w, GRASS, 13, 5, 5, 40, 0x30);
    ctx.state.sector_second = 1;         /* the gated sweep, where role means something */
    ctx.state.mon_role[13] = 3;
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(rep.moved == 0 && ctx.state.mon_x[13] == 5,
          "role 3 is undecoded (asm/1086) and the engine under-moves rather than guess");

    /* --- the melee pool and the armour dodge (asm/0B62 / asm/0B79) ----------- */
    /* A role-2 creature in contact draws exactly one roll, the melee roll, so the
       seed controls it directly — which is why these run on the gated (interior)
       sweep: on the world map the same creature also rolls for a special first and
       the seed would be spent on the wrong thing. Find a seed whose first roll is
       non-negative and whose low three bits are 0: with armour 0 the blow lands,
       with armour 1 it is dodged. That is the whole of what armour does in the
       original, and it is the only damage a plain melee creature can ever do. */
    uint8_t mseed = 0;
    while (mseed < 255) {
        const uint8_t r = first_roll(mseed);
        if (r < 0x80 && (r & 7) == 0) break;
        mseed++;
    }
    const uint8_t mr = first_roll(mseed);
    CHECK(mr < 0x80 && (mr & 7) == 0, "a seed exists whose first roll is hit-able at SKIN");

    arm(&ctx, &w, GRASS, 14, 7, 7, 40, 0x30);
    ctx.state.sector_second = 1;
    ctx.state.mon_role[14] = 2;
    ctx.state.worn_armour = 0;                      /* SKIN */
    u2_rng_seed(&ctx, mseed);
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(rep.contacts == 1 && rep.damage_pool == (40 >> 2) + 1,
          "SKIN: the blow lands and pools mon_hp>>2 + 1 = %d", (40 >> 2) + 1);

    arm(&ctx, &w, GRASS, 14, 7, 7, 40, 0x30);
    ctx.state.sector_second = 1;
    ctx.state.mon_role[14] = 2;
    ctx.state.worn_armour = 1;                      /* one step of armour */
    u2_rng_seed(&ctx, mseed);
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(rep.contacts == 1 && rep.damage_pool == 0,
          "control: the same roll against armour index 1 is dodged (asm/0B71)");

    /* --- the alarm (asm/113A): violence inside a site wakes slots 0..7 -------- */
    arm(&ctx, &w, GRASS, 3, 5, 5, 40, 0x30);
    ctx.state.sector_second = 0;                /* the world map */
    u2_ai_alarm(&ctx);
    CHECK(ctx.state.mon_role[0] == 0 && ctx.state.mon_role[7] == 0,
          "asm/113A: on the world map there is nobody to alert");

    ctx.state.sector_second = 2;                /* inside a town */
    u2_ai_alarm(&ctx);
    int all_one = 1;
    for (int i = 0; i <= 7; i++)
        if (ctx.state.mon_role[i] != 1) all_one = 0;
    CHECK(all_one, "asm/114A: slots 7..0 all take role 1");
    CHECK(ctx.state.mon_role[8] == 0, "and slot 8 does not: the loop counts 7 down to 0");

    /* --- the step gate, exhaustively: asm/2199..21FC, corroborated by Apple $6672 ----------
     *
     * The existing checks above probe the gate one case at a time, which is how a gate passes
     * while being wrong about a tile nobody thought to try. This block enumerates every tile
     * byte that can actually occur in a sector map — all multiples of 4, per
     * docs/passability-findings.md F12 — against an expectation written from the clause list in
     * asm/2199's header and independently confirmed clause for clause on the Apple II side at
     * $6672. The expectation is NOT read out of ai.c: if the engine and this table ever
     * disagree, one of them is wrong, and a test that copies the implementation proves nothing.
     *
     * The accept set the original has five members: 0x08, 0x0C, 0x5C, 0x70, and 0x00 for the two
     * water kinds only. Anything else must be refused, and that "anything else" is the part a
     * spot-check cannot cover. */
    {
        /* Written from asm/2199's rule, not from ai.c. */
        int bad = 0, cases = 0;
        const uint8_t types[] = { 0x2c, 0x48, 0x30, 0x34, 0x74, 0x78, 0x7c, 0xfc };
        for (int ti = 0; ti < (int)(sizeof types / sizeof types[0]); ti++) {
            for (int tile = 0; tile <= 0xfc; tile += 4) {
                uint8_t t = types[ti];
                int water = (t == 0x2c || t == 0x48);
                int want;
                if (water) {
                    want = (tile == 0x00);
                } else {
                    int ladder = !(tile == 0x10 || tile == 0x04 || tile == 0x00)
                              && (tile < 0x14 || tile == 0x70);
                    want = (t < 0x78) ? (tile == 0x5c || ladder) : ladder;
                }
                arm(&ctx, &w, GRASS, 7, 5, 5, 40, t);
                ctx.state.mon_role[7] = 1;
                ctx.state.sector_second = 0;      /* world sweep: no site guard, no role gate */
                w.map[6 * U2_SECTOR_EDGE + 6] = (uint8_t)tile;
                rep = u2_ai_creature_turn(&ctx, &w, 9, 9);
                int got = (ctx.state.mon_x[7] == 6 && ctx.state.mon_y[7] == 6);
                cases++;
                if (got != want) {
                    bad++;
                    if (bad <= 6)
                        printf("  FAIL  gate: type %02X onto tile %02X -> %s, spec says %s\n",
                               t, tile, got ? "accept" : "refuse", want ? "accept" : "refuse");
                }
            }
        }
        CHECK(bad == 0, "asm/2199 step gate: %d/%d (type x tile) combinations agree with the "
                        "clause list (%d disagree)", cases - bad, cases, bad);

        /* The freeze counter refuses everything, before any tile is consulted (asm/2199). */
        int frozen_bad = 0;
        for (int tile = 0; tile <= 0xfc; tile += 4) {
            arm(&ctx, &w, GRASS, 7, 5, 5, 40, 0x30);
            ctx.state.mon_role[7] = 1;
            ctx.state.sector_second = 0;
            ctx.state.counter_26A = 0x14;     /* the value asm/3C04_coin_rub stores */
            w.map[6 * U2_SECTOR_EDGE + 6] = (uint8_t)tile;
            u2_ai_creature_turn(&ctx, &w, 9, 9);
            if (ctx.state.mon_x[7] != 5) frozen_bad++;
        }
        CHECK(frozen_bad == 0,
              "asm/2199: DS:26A = 0x14 refuses all 64 tiles, whatever the species (%d leaked)",
              frozen_bad);

        /* The site guard (asm/21e2): inside a site, column 0 and row 0 are refused; on the
         * world map the grid wraps and they are walkable. */
        arm(&ctx, &w, GRASS, 7, 1, 5, 40, 0x30);
        ctx.state.mon_role[7] = 1;
        ctx.state.sector_second = 1;
        u2_ai_creature_turn(&ctx, &w, 0, 8);      /* step lands on column 0 */
        CHECK(ctx.state.mon_x[7] == 1,
              "asm/21e2: inside a site a step onto column 0 is refused");

        arm(&ctx, &w, GRASS, 7, 1, 5, 40, 0x30);
        ctx.state.mon_role[7] = 1;
        ctx.state.sector_second = 0;
        u2_ai_creature_turn(&ctx, &w, 0, 8);
        CHECK(ctx.state.mon_x[7] == 0,
              "control: on the world map the same step is allowed — the guard is the site digit");

        arm(&ctx, &w, GRASS, 7, 2, 5, 40, 0x30);
        ctx.state.mon_role[7] = 1;
        ctx.state.sector_second = 1;
        u2_ai_creature_turn(&ctx, &w, 0, 8);      /* step lands on column 1 */
        CHECK(ctx.state.mon_x[7] == 1,
              "control: inside a site a step onto column 1 is fine — the guard is the edge, not x");

        /* Row 0 is a separate arm of the same `||`, and a table that only tries column 0 will
         * pass while row 0 is unguarded. Found by mutation, not by writing the test. */
        arm(&ctx, &w, GRASS, 7, 5, 1, 40, 0x30);
        ctx.state.mon_role[7] = 1;
        ctx.state.sector_second = 1;
        u2_ai_creature_turn(&ctx, &w, 9, 0);      /* step lands on row 0 */
        CHECK(ctx.state.mon_y[7] == 1,
              "asm/21e2: inside a site a step onto row 0 is refused");

        arm(&ctx, &w, GRASS, 7, 5, 1, 40, 0x30);
        ctx.state.mon_role[7] = 1;
        ctx.state.sector_second = 0;
        u2_ai_creature_turn(&ctx, &w, 9, 0);
        CHECK(ctx.state.mon_y[7] == 0,
              "control: on the world map the same row-0 step is allowed");

        arm(&ctx, &w, GRASS, 7, 5, 2, 40, 0x30);
        ctx.state.mon_role[7] = 1;
        ctx.state.sector_second = 1;
        u2_ai_creature_turn(&ctx, &w, 9, 0);      /* step lands on row 1 */
        CHECK(ctx.state.mon_y[7] == 1,
              "control: inside a site a step onto row 1 is fine");
    }

    printf("ai_check: %d checks, %d failures\n", checks, fails);
    return fails != 0;
}
