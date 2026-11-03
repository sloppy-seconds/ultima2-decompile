/* space_check.c — gate for the world coordinate model.
 *
 * Every assertion names the observation or the byte that earns it. The two
 * descent assertions are the interesting ones: they check a rule that was written
 * from bytes BEFORE anyone was inside a rocket, against the two cells the live
 * landings actually stopped on.
 *
 * It also carries mutants, because a gate that cannot go red is worse than a tool
 * that lies. `--mutant NAME` breaks exactly one rule and the run must fail;
 * tests/space_check_selftest.sh drives them and is wired into check_all.sh.
 */
#include "game/space.h"

#include <stdio.h>
#include <string.h>

static int failures;

#define CHECK(cond, what)                                                      \
    do {                                                                       \
        if (!(cond)) {                                                         \
            printf("  FAIL  %s\n", (what));                                    \
            ++failures;                                                        \
        } else {                                                               \
            printf("  PASS  %s\n", (what));                                    \
        }                                                                      \
    } while (0)

/* The mutant, applied to the pure rules so the mutants exercise the same code a
 * caller would. */
static int g_mutant_gate_pre = 0;       /* 1: test the count before the spend */
static int g_mutant_earth_sector = 0;   /* 1: Earth lands in 00, not 40 */
static int g_mutant_tile_any = 0;       /* 1: any tile survives */
static int g_mutant_step4 = 0;          /* 1: x steps on multiples of 4, not 8 */

static int gate_offcourse(uint8_t fuel)
{
    const uint8_t v = g_mutant_gate_pre ? fuel : (uint8_t)(fuel - 1u);
    return (v & 3u) == 3u;
}

static void do_step(uint8_t *x, uint8_t *y)
{
    if (!g_mutant_step4) {
        u2_space_descent_step(x, y);
        return;
    }
    *y = (uint8_t)((*y + 2u) & 0x3Fu);
    if ((*y & 3u) == 0u)
        *x = (uint8_t)((*x + 1u) & 0x3Fu);
}

static int earth_sector(void)
{
    return g_mutant_earth_sector ? 0 : u2_space_dive_sector(U2_WORLD_EARTH);
}

static int survives(uint8_t tile)
{
    return g_mutant_tile_any ? 1 : u2_space_dive_survives(tile);
}

int main(int argc, char **argv)
{
    if (argc > 2 && !strcmp(argv[1], "--mutant")) {
        const char *m = argv[2];
        if (!strcmp(m, "gate-pre")) g_mutant_gate_pre = 1;
        else if (!strcmp(m, "earth-00")) g_mutant_earth_sector = 1;
        else if (!strcmp(m, "tile-any")) g_mutant_tile_any = 1;
        else if (!strcmp(m, "step-4")) g_mutant_step4 = 1;
        else {
            printf("unknown mutant: %s\n", m);
            return 2;
        }
        printf("SPACE CHECK: running with mutant %s (this run MUST fail)\n", m);
    }

    /* --- the tables, as extracted from original/ultimaii.exe at 0x7212 --- */
    CHECK(u2_space_worlds[0].xeno == 6 && u2_space_worlds[0].yako == 6 &&
              u2_space_worlds[0].zabo == 6,
          "Earth reads 6/6/6 (observed on screen and in DS:4CA..4CC)");
    CHECK(u2_space_worlds[9].xeno == 9 && u2_space_worlds[9].yako == 9 &&
              u2_space_worlds[9].zabo == 9,
          "world 9 reads 9/9/9 (observed after typing 9 9 9)");
    CHECK(!strcmp(u2_space_worlds[0].name, "EARTH") &&
          !strcmp(u2_space_worlds[8].name, "PLUTO"),
          "names 0 and 8 are the literals asm/7030 prints");

    /* --- the orbit test is equality, not proximity --- */
    CHECK(u2_space_world_at(9, 9, 9) == 9, "9/9/9 is X");
    CHECK(u2_space_world_at(6, 6, 6) == 0, "6/6/6 is Earth");
    CHECK(u2_space_world_at(7, 1, 1) == U2_WORLD_DEEP_SPACE,
          "7/1/1 is no world, so deep space (observed off-course arrival)");
    CHECK(u2_space_world_at(6, 2, 3) == 3, "6/2/3 is MARS, one off Earth in two axes");
    CHECK(u2_space_world_at(6, 6, 7) == U2_WORLD_DEEP_SPACE,
          "one axis off Earth is deep space, so there is no tolerance");

    /* --- the off-course gate, observed on both arms --- */
    CHECK(gate_offcourse(8) == 1,
          "fuel 8 -> spends to 7 -> 7&3==3 -> OFF COURSE fires");
    CHECK(gate_offcourse(7) == 0,
          "fuel 7 -> spends to 6 -> 6&3==2 -> on course");
    /* Restated without the double negative so a reader can see both cases. */
    CHECK(gate_offcourse(8) == 1 && gate_offcourse(7) == 0,
          "the gate distinguishes the two observed fuel counts");
    CHECK(gate_offcourse(5) == 0 && gate_offcourse(4) == 1,
          "and it is the low two bits: 5 on-courses, 4 off-courses (4 spends to 3)");

    uint8_t dest[3] = { 9, 9, 9 };
    const uint8_t rng[3] = { 0xF7, 0x31, 0x99 };
    CHECK(u2_space_hyperwarp(8, rng, dest) == U2_HYPERWARP_OFF_COURSE,
          "hyperwarp at fuel 8 reports off-course");
    CHECK(dest[0] == 7 && dest[1] == 1 && dest[2] == 1,
          "and the roll replaced the destination with rand & 7 -> 7/1/1");
    uint8_t dest2[3] = { 9, 9, 9 };
    CHECK(u2_space_hyperwarp(7, rng, dest2) == U2_HYPERWARP_ON_COURSE,
          "hyperwarp at fuel 7 reports on course");
    CHECK(dest2[0] == 9 && dest2[1] == 9 && dest2[2] == 9,
          "and the typed destination survives untouched");
    uint8_t dest3[3] = { 1, 2, 3 };
    CHECK(u2_space_hyperwarp(0, rng, dest3) == U2_HYPERWARP_NO_FUEL,
          "no fuel, no warp");

    /* An off-course roll can never reach X, because X needs a 9 and the mask is 7. */
    int reached_x = 0;
    for (int a = 0; a < 8; ++a)
        for (int b = 0; b < 8; ++b)
            for (int c = 0; c < 8; ++c)
                if (u2_space_world_at((uint8_t)a, (uint8_t)b, (uint8_t)c) == 9)
                    reached_x = 1;
    CHECK(!reached_x, "no rand&7 triple reaches X, so X cannot be hit by misfortune");

    /* --- dive sector and permission --- */
    CHECK(earth_sector() == 40, "Earth dive lands in sector 40, not 00 (observed)");
    CHECK(u2_space_dive_sector(9) == 90, "world 9 dive lands in sector 90 (observed)");
    CHECK(u2_space_dive_sector(3) == 30, "world 3 dive lands in sector 30");
    CHECK(u2_space_dive_allowed(0) && u2_space_dive_allowed(9),
          "any orbiting world can be landed on");
    CHECK(!u2_space_dive_allowed(U2_WORLD_DEEP_SPACE),
          "deep space answers REQUEST DENIED (the cmp $0xa test)");

    /* --- armour --- */
    CHECK(u2_space_armour_survives(6) && u2_space_armour_survives(5),
          "POWER and REFLECT survive space (cmp $0x5 on DS:62)");
    CHECK(!u2_space_armour_survives(4), "PLATE does not, which is the unobserved arm");

    /* --- the descent: predicted from bytes, then observed to the cell --- */
    uint8_t x = 0, y = 0;
    while (y < 62)
        do_step(&x, &y);
    CHECK(x == 7 && y == 62, "descent from (0,0) reaches (7,62) — run 1's landing");
    x = 0; y = 0;
    while (y < 44)
        do_step(&x, &y);
    CHECK(x == 5 && y == 44, "descent from (0,0) reaches (5,44) — run 2's landing");

    /* --- the tile verdict --- */
    CHECK(survives(0x08), "0x08 grass survives (predicted safe, never tested)");
    CHECK(!survives(0x00), "0x00 water kills — observed, run 1");
    CHECK(!survives(0x0c), "0x0c forest kills — observed, run 2");
    CHECK(!survives(0x10), "0x10 mountain kills — inferred, same rule");

    if (failures) {
        printf("SPACE CHECK: FAIL (%d)\n", failures);
        return 1;
    }
    printf("SPACE CHECK: PASS\n");
    return 0;
}
