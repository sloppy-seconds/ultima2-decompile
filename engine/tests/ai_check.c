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
    arm(&ctx, &w, GRASS, 3, 5, 5, 40, 0x30);       /* Fighter, plain */
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(ctx.state.mon_x[3] == 6 && ctx.state.mon_y[3] == 6,
          "pursuit is the diagonal (5,5)->(6,6), i.e. two Manhattan cells in one turn");
    CHECK(rep.moved == 1 && u2_rng_rolls(&ctx) == 0,
          "outside the 3-cell ring the gate is not rolled at all (asm/0AB6/0AC0)");

    /* --- the two HP thresholds are different numbers ------------------------ */
    arm(&ctx, &w, GRASS, 4, 5, 5, 15, 0x30);
    u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(ctx.state.mon_hp[4] == 16 && ctx.state.mon_x[4] == 6,
          "hp 15 regenerates (asm/2126, <16) and still pursues (asm/0B07, >=15)");

    arm(&ctx, &w, GRASS, 4, 5, 5, 14, 0x30);
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(ctx.state.mon_hp[4] == 15 && ctx.state.mon_x[4] == 4 && ctx.state.mon_y[4] == 4,
          "hp 14 regenerates AND flees: the vector is negated (asm/0B0F)");
    CHECK(rep.retreated == 1, "the retreat is reported, so a caller can log it");

    /* --- species: a sea monster lives in water and nowhere else ------------- */
    arm(&ctx, &w, GRASS, 6, 5, 5, 40, 0x2c);       /* Sea Monster */
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(rep.moved == 0 && ctx.state.mon_x[6] == 5,
          "asm/21d8: a sea monster refuses grass");

    arm(&ctx, &w, WATER, 6, 5, 5, 40, 0x2c);
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(rep.moved == 1 && ctx.state.mon_x[6] == 6,
          "asm/21d8: the same sea monster accepts water");

    arm(&ctx, &w, WATER, 7, 5, 5, 40, 0x30);       /* Fighter on water */
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(rep.moved == 0,
          "asm/21c9: the general ladder refuses tile 0x00, so land creatures do not swim");

    /* --- contact stops the move and does not cause a blow ------------------- */
    arm(&ctx, &w, GRASS, 8, 7, 7, 40, 0x30);
    const uint32_t rolls_before = u2_rng_rolls(&ctx);
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(ctx.state.mon_x[8] == 7 && ctx.state.mon_y[8] == 7,
          "asm/2201: the candidate cell is the player's, so the creature does not step");
    CHECK(rep.moved == 0 && rep.gates == 1 && u2_rng_rolls(&ctx) == rolls_before + 1,
          "contact rolls the special gate and nothing else — there is no melee site");

    /* --- the special gate: proximity, then 1 in 8, then the type dispatch --- */
    uint8_t seed = 0;
    while (first_roll(seed) >= 0x20 && seed < 255) seed++;
    CHECK(first_roll(seed) < 0x20, "a seed exists whose first roll passes asm/0ACF");

    arm(&ctx, &w, GRASS, 9, 7, 7, 40, 0x34);       /* legs paralyser */
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
    u2_rng_seed(&ctx, seed);
    rep = u2_ai_creature_turn(&ctx, &w, 20, 20);
    CHECK(rep.gates == 0 && rep.landed == 0 && u2_rng_rolls(&ctx) == 0,
          "control: the same paralyser far away neither rolls nor prints");

    /* --- DS:26A freezes every creature before the species test (asm/2199) --- */
    arm(&ctx, &w, GRASS, 11, 5, 5, 40, 0x30);
    ctx.state.counter_26A = 1;
    rep = u2_ai_creature_turn(&ctx, &w, 8, 8);
    CHECK(rep.moved == 0 && ctx.state.mon_x[11] == 5,
          "asm/2199: a non-zero DS:26A refuses every move (inert until W7 ticks it)");

    /* --- the grid follows the creature, and the terrain follows the grid ---- */
    arm(&ctx, &w, GRASS, 12, 5, 5, 40, 0x30);
    w.map[5 * U2_SECTOR_EDGE + 5] = 0x30;          /* the spawn stamp */
    u2_ai_creature_turn(&ctx, &w, 8, 8);
    u2_monsters_restamp(&ctx, &w);
    CHECK(w.map[5 * U2_SECTOR_EDGE + 5] == GRASS,
          "the vacated cell is terrain again, not a permanent invisible monster");
    CHECK(w.map[6 * U2_SECTOR_EDGE + 6] == 0x30,
          "the new cell carries the creature's type byte, which is what the renderer draws");

    printf("ai_check: %d checks, %d failures\n", checks, fails);
    return fails != 0;
}
