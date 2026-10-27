/*
 * tests/monsters_check.c — CP5 W1: the monx block <-> the creature arrays.
 *
 * Proves three things, in order of how expensive they are to get wrong:
 *
 *   1. the six monx columns land on the six DS arrays with no off-by-one and no
 *      swapped pair (the offsets are measured in docs/monster-spawn.md § 6, and a
 *      silent swap would relabel every monster in the game);
 *   2. the lookup the movement and combat code will use finds a creature by cell
 *      and reports empty cells as empty;
 *   3. a store round trip writes back exactly what was changed and nothing else,
 *      because the original rewrites the whole 256-byte block on save and the
 *      engine only stores dirty sectors.
 *
 * The synthetic sector is engine-authored filler, same rule as world_check.c: no
 * game bytes are committed here. When a real monxNN is passed as argv[2] the test
 * additionally checks it against values read out of the live emulator, which is
 * the only place the offset table can actually be falsified.
 *
 * Build and run by tests/run_cp5.sh.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "core/ctx.h"
#include "core/world.h"
#include "game/monsters.h"

static int fails, checks;
#define CHECK(cond, ...) do { checks++; if (!(cond)) { fails++; \
    printf("  FAIL  " __VA_ARGS__); printf("\n"); } } while (0)

#define SLOT_X   0
#define SLOT_Y   1
#define SLOT_HP  2
#define SLOT_TYP 3
#define SLOT_KIN 4
#define SLOT_ROL 5

/* Per-slot columns, deliberately all different from each other so that a swapped
 * monx offset cannot pass: column values are slot*8 + column-index, so no two
 * columns share a byte and none is a permutation of another. */
static void synth(uint8_t *mon)
{
    memset(mon, 0, U2_MON_TILES);
    for (int i = 0; i < U2_MON_SLOTS; i++) {
        mon[SLOT_X   * U2_MON_SLOTS + i] = (uint8_t)(i * 8 + 1);   /* never 0 */
        mon[SLOT_Y   * U2_MON_SLOTS + i] = (uint8_t)(i * 8 + 2);
        mon[SLOT_HP  * U2_MON_SLOTS + i] = (uint8_t)(i * 8 + 3);
        mon[SLOT_TYP * U2_MON_SLOTS + i] = (uint8_t)(i * 8 + 4);
        mon[SLOT_KIN * U2_MON_SLOTS + i] = (uint8_t)(i * 8 + 5);
        mon[SLOT_ROL * U2_MON_SLOTS + i] = (uint8_t)(i * 8 + 6);
    }
    /* leave slot 31 unoccupied (x and y both zero) to exercise the empty path */
    mon[SLOT_X * U2_MON_SLOTS + 31] = 0;
    mon[SLOT_Y * U2_MON_SLOTS + 31] = 0;
}

int main(int argc, char **argv)
{
    const char *base = argc > 1 ? argv[1] : ".";
    const char *real = argc > 2 ? argv[2] : NULL;
    char dir[256], p[320];
    uint8_t mon[U2_MON_TILES];
    u2_ctx ctx;
    u2_world w;
    u2_sector_id id = { 3, 1 };

    snprintf(dir, sizeof dir, "%s", base);
    snprintf(p, sizeof p, "%s/monx31", dir);

    memset(&ctx, 0, sizeof ctx);
    ctx.data_dir = dir;
    memset(&w, 0, sizeof w);
    synth(mon);

    FILE *f = fopen(p, "wb");
    if (!f) { printf("  FAIL  cannot write %s\n", p); return 1; }
    fwrite(mon, 1, U2_MON_TILES, f);
    fclose(f);

    if (u2_world_open(&ctx) != U2_WORLD_OK) {
        printf("  FAIL  content dir did not open\n");
        return 1;
    }
    if (u2_world_load(&ctx, &w, 0, id) != U2_WORLD_OK) {
        printf("  FAIL  monx31 did not load\n");
        return 1;
    }

    /* A sector map too, so the grid the creatures are stamped INTO exists. Same
     * rule as the monx filler: engine-authored, no game bytes. The pattern never
     * reaches 0x80, so a cell left at 0x80 after a restamp cannot be confused
     * with terrain. */
    snprintf(p, sizeof p, "%s/mapx31", dir);
    FILE *mf = fopen(p, "wb");
    if (!mf) { printf("  FAIL  cannot write %s\n", p); return 1; }
    for (int i = 0; i < U2_SECTOR_TILES; i++) {
        uint8_t b = (uint8_t)(i & 0x3F);
        fwrite(&b, 1, 1, mf);
    }
    fclose(mf);
    if (u2_world_load(&ctx, &w, 1, id) != U2_WORLD_OK) {
        printf("  FAIL  mapx31 did not load\n");
        return 1;
    }

    /* --- 1. the columns land where docs/monster-spawn.md § 6 says ------ */
    int occupied = u2_monsters_spawn(&ctx, &w);
    CHECK(occupied == 31, "31 occupied slots, the one all-zero slot reported empty (got %d)", occupied);

    int col_ok = 1;
    for (int i = 0; i < 31; i++) {
        if (ctx.state.mon_x[i]    != (uint8_t)(i * 8 + 1) ||
            ctx.state.mon_y[i]    != (uint8_t)(i * 8 + 2) ||
            ctx.state.mon_hp[i]   != (uint8_t)(i * 8 + 3) ||
            ctx.state.mon_type[i] != (uint8_t)(i * 8 + 4) ||
            ctx.state.mon_kind[i] != (uint8_t)(i * 8 + 5) ||
            ctx.state.mon_role[i] != (uint8_t)(i * 8 + 6))
            col_ok = 0;
    }
    CHECK(col_ok, "each monx column reached its own DS array, none swapped");

    /* The control that makes the assertion above mean something: if two columns
     * shared a byte pattern, a swap would pass silently. */
    CHECK(memcmp(ctx.state.mon_x, ctx.state.mon_y, U2_MON_SLOTS) != 0 &&
          memcmp(ctx.state.mon_hp, ctx.state.mon_type, U2_MON_SLOTS) != 0 &&
          memcmp(ctx.state.mon_kind, ctx.state.mon_role, U2_MON_SLOTS) != 0,
          "control: the six columns are distinguishable, so a swap cannot pass");

    /* --- 2. lookup by cell --------------------------------------------- */
    CHECK(u2_monsters_at(&ctx, ctx.state.mon_x[7], ctx.state.mon_y[7]) == 7,
          "a creature is found by its cell");
    CHECK(u2_monsters_at(&ctx, 0, 0) == -1,
          "an unoccupied cell reports none rather than slot 0");
    CHECK(u2_monsters_nearest(&ctx, ctx.state.mon_x[12], ctx.state.mon_y[12]) == 12,
          "nearest returns the slot standing on the queried cell");

    /* --- 3. store round trip ------------------------------------------- */
    uint8_t before[U2_MON_TILES];
    memcpy(before, w.mon, U2_MON_TILES);
    ctx.state.mon_hp[7] = 0;                 /* a killed monster */
    ctx.state.mon_role[8] = 0x01;            /* the alarm (§ 16) */
    u2_monsters_store(&ctx, &w);
    CHECK(w.mon[SLOT_HP * U2_MON_SLOTS + 7] == 0, "a hp change reaches the sector buffer");
    CHECK(w.mon[SLOT_ROL * U2_MON_SLOTS + 8] == 0x01, "a role change reaches the sector buffer");
    CHECK(w.mon_dirty == 1, "storing marks the sector dirty, so the save will write it");

    int untouched = 1;
    for (int i = 0; i < U2_MON_TILES; i++) {
        int changed = (i == SLOT_HP * U2_MON_SLOTS + 7) || (i == SLOT_ROL * U2_MON_SLOTS + 8);
        if (!changed && w.mon[i] != before[i])
            untouched = 0;
    }
    CHECK(untouched, "nothing else in the 256-byte block moved");

    /* --- 4. against the real sector, if the caller supplied one -------- */
    if (real) {
        FILE *rf = fopen(real, "rb");
        if (!rf) {
            printf("  FAIL  real monx %s not readable\n", real);
            fails++;
        } else {
            uint8_t rb[U2_MON_TILES];
            size_t got = fread(rb, 1, U2_MON_TILES, rf);
            fclose(rf);
            CHECK(got == U2_MON_TILES, "real monx31 is 256 bytes (got %zu)", got);
            /* Values read out of the running game seconds after loading sector 31,
             * captures/spice86/cp5-g25-aggro/roles-at-load.txt. This is the only
             * assertion in this file that can falsify the offset table rather than
             * just check the copy. */
            struct { int slot, x, y, type, role, hp; } live[] = {
                { 18, 51, 21, 0xF0, 0x03,  50 },
                { 19, 55, 21, 0xF0, 0x03,  60 },
                {  8, 55, 19, 0x68, 0x02,  30 },
                { 16, 51, 15, 0x68, 0x81,  30 },
                { 17, 48, 26, 0x64, 0x82, 255 },
                {  7, 43, 19, 0x60, 0x03, 255 },
            };
            for (unsigned k = 0; k < sizeof live / sizeof live[0]; k++) {
                int s = live[k].slot;
                CHECK(rb[SLOT_X * 32 + s] == live[k].x &&
                      rb[SLOT_Y * 32 + s] == live[k].y &&
                      rb[SLOT_TYP * 32 + s] == live[k].type &&
                      rb[SLOT_ROL * 32 + s] == live[k].role &&
                      rb[SLOT_HP * 32 + s] == live[k].hp,
                      "monx31 slot %d matches the live capture (%d,%d,%02x,%02x,%d)",
                      s, live[k].x, live[k].y, live[k].type, live[k].role, live[k].hp);
            }
            /* The reading that forced two corrections to § 16: 0x01 is a birth
             * value for some kinds, not only an alarm. Pinned so nobody re-derives
             * it wrongly a third time. */
            CHECK(rb[SLOT_ROL * 32 + 27] == 0x01 && rb[SLOT_TYP * 32 + 27] == 0x2C,
                  "control: slot 27 is born role 0x01, so 0x01 is not only an acquired alarm");
        }
    }

    /* --- 5. the grid is derived: a departure puts the terrain back ---------- */
    /* Slot 7 is the one slot of the synthetic set whose x and y are both inside
     * the 64x64 sector (57,58); slot 5 (41,42) is the control that stays alive.
     * Section 3 zeroed slot 7's hp, which is exactly the state a kill leaves
     * apart from the type byte this block clears itself. */
    {
        const int dead = 7, alive = 5;
        const int dcell = (int)ctx.state.mon_y[dead] * U2_SECTOR_EDGE
                        + (int)ctx.state.mon_x[dead];
        const int acell = (int)ctx.state.mon_y[alive] * U2_SECTOR_EDGE
                        + (int)ctx.state.mon_x[alive];
        const uint8_t terrain = w.map_base[dcell];

        CHECK(w.map[dcell] == ctx.state.mon_type[dead],
              "a live creature's type byte is the cell the renderer reads");

        /* The kill, the way asm/2E3D leaves the record: three fields cleared,
         * the coordinates left alone. */
        ctx.state.mon_hp[dead] = 0;
        ctx.state.mon_type[dead] = 0;
        ctx.state.mon_kind[dead] = 0;
        u2_monsters_restamp(&ctx, &w);
        CHECK(w.map[dcell] == terrain,
              "a killed creature's cell returns to the terrain underneath");

        /* The regression this whole section exists for. The kill path used to
         * stamp 0x80 over the cell and the restamp used to exempt any cell
         * carrying it, which is how a dead creature stayed on screen as the
         * letter A (0x80 >> 2 = art 32) for the rest of the visit. Re-add either
         * half and this check goes red. */
        w.map[dcell] = 0x80;
        u2_monsters_restamp(&ctx, &w);
        CHECK(w.map[dcell] == terrain,
              "restamp does NOT exempt a cell carrying 0x80 (got 0x%02x, want terrain 0x%02x)",
              w.map[dcell], terrain);

        /* The zero-hp creature, and the asymmetry that is the ORIGINAL's, not a defect.
         *
         * asm/2E3D kills only when dmg > hp, so a blow exactly equal to hp leaves hp == 0
         * with the type byte set. Measured against the original on 2026-10-26: such a slot
         * is DRAWN and WALKS (asm/0A74 keys the sweep and the stamp on mon_type) but is
         * UNHITTABLE (the attack scan skips hp 0) — a swing at a poked-to-zero slot missed,
         * and the next swing after the regen killed it from the same geometry.
         *
         * So the two rules are different on purpose and both halves are pinned here. An
         * earlier attempt today "unified" them onto mon_type and that is the wrong
         * direction; these checks are what stops it coming back.
         *
         * In normal play the unhittable window is nearly unreachable: the blow that zeroes
         * hp is followed in the SAME command by the sweep's regen (asm/2122/212a, +1 below
         * 16 HP), so the player's next swing meets hp 1. The observable effect of dmg == hp
         * is one extra swing, not a ghost. */
        ctx.state.mon_hp[dead]   = 0;
        ctx.state.mon_type[dead] = 0x3C;        /* wounded to exactly zero, not killed */
        CHECK(u2_monsters_at(&ctx, ctx.state.mon_x[dead], ctx.state.mon_y[dead]) < 0,
              "a zero-hp creature is NOT attackable — the original's scan skips hp 0");
        u2_monsters_restamp(&ctx, &w);
        CHECK(w.map[dcell] == 0x3C,
              "but it IS drawn (got 0x%02x, want 0x3C) — asm/0A74 keys the stamp on type",
              w.map[dcell]);

        /* And a real kill is absent from both, because death clears the type byte along
         * with hp and kind. */
        ctx.state.mon_type[dead] = 0;
        CHECK(u2_monsters_at(&ctx, ctx.state.mon_x[dead], ctx.state.mon_y[dead]) < 0,
              "a killed slot is not attackable");
        u2_monsters_restamp(&ctx, &w);
        CHECK(w.map[dcell] == terrain,
              "and a killed slot is not drawn (got 0x%02x, want terrain 0x%02x)",
              w.map[dcell], terrain);

        CHECK(w.map[acell] == ctx.state.mon_type[alive],
              "the rebuild re-stamps the creatures still standing, it does not blank the grid");
    }

    printf("monsters_check: %d checks, %d failures\n", checks, fails);
    return fails ? 1 : 0;
}
