/* space.c — see space.h for the evidence and the grade of every claim here. */
#include "game/space.h"

const u2_space_world u2_space_worlds[U2_WORLD_COUNT] = {
    /* xeno, yako, zabo, name — names are the literals asm/7030 prints, in its
     * cmp $0x0 .. cmp $0x8 order. The name for index 9 is NOT a literal in that
     * file: the dispatch falls through to a routine past 0x729B, the highest
     * offset ever executed, so "X" is what a screen showed and not what a decoder
     * found. It is kept because it was seen, and flagged because it is not proven. */
    { 6, 6, 6, "EARTH" },    /* 0 */
    { 5, 4, 5, "MERCURY" },  /* 1 */
    { 3, 3, 4, "VENUS" },    /* 2 */
    { 6, 2, 3, "MARS" },     /* 3 */
    { 1, 3, 4, "JUPITER" },  /* 4 */
    { 2, 8, 5, "SATURN" },   /* 5 */
    { 9, 4, 6, "URANUS" },   /* 6 */
    { 4, 0, 5, "NEPTUNE" },  /* 7 */
    { 0, 1, 4, "PLUTO" },    /* 8 */
    { 9, 9, 9, "X" },        /* 9 — name inferred from one frame, see above */
};

uint8_t u2_space_world_at(uint8_t xeno, uint8_t yako, uint8_t zabo)
{
    for (int i = 0; i < U2_WORLD_COUNT; ++i) {
        const u2_space_world *w = &u2_space_worlds[i];
        if (w->xeno == xeno && w->yako == yako && w->zabo == zabo)
            return (uint8_t)i;
    }
    return U2_WORLD_DEEP_SPACE;
}

u2_hyperwarp_result u2_space_hyperwarp(uint8_t fuel_count, const uint8_t rng[3],
                                       uint8_t dest[3])
{
    if (fuel_count == 0)
        return U2_HYPERWARP_NO_FUEL;

    /* The gate tests the count AFTER the spend, which is what makes fuel 8 -> 7
     * fire and fuel 7 -> 6 not. Getting this order wrong is invisible in play and
     * obvious in a test, so the off-by-one is called out rather than absorbed. */
    const uint8_t after = (uint8_t)(fuel_count - 1u);

    if ((after & 3u) != 3u)
        return U2_HYPERWARP_ON_COURSE;

    /* asm/6DFD: three calls to the random source, each masked to 0..7. */
    for (int i = 0; i < 3; ++i)
        dest[i] = (uint8_t)(rng[i] & 7u);
    return U2_HYPERWARP_OFF_COURSE;
}

int u2_space_dive_sector(uint8_t world)
{
    if (world == U2_WORLD_EARTH)
        return 40; /* asm/7030 hardcodes tens = 4 for Earth, not 0 */
    return (int)world * 10;
}

int u2_space_dive_allowed(uint8_t world)
{
    return world != U2_WORLD_DEEP_SPACE;
}

int u2_space_armour_ok(uint8_t worn_armour)
{
    return worn_armour >= 5; /* REFLECT or POWER */
}

void u2_space_descent_step(uint8_t *x, uint8_t *y)
{
    /* asm/3B94: `adc $0x2,%al` then `and $7,%al ; jne`. Byte arithmetic, so it
     * wraps at 64 the way the original's does. */
    *y = (uint8_t)((*y + 2u) & 0x3Fu);
    if ((*y & 7u) == 0u)
        *x = (uint8_t)((*x + 1u) & 0x3Fu);
}

int u2_space_dive_survives(uint8_t tile)
{
    return (tile & 0x7Fu) == 0x08;
}
