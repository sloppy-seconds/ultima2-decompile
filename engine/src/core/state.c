/*
 * state.c — DS working segment helpers.
 * spec: asm/0100_sub_0100.asm (segment setup, tick seeding),
 *       asm/50B3_map_tile_ptr.asm, asm/51FD_str_out_core.asm,
 *       asm/5217_rand_byte.asm
 */
#include "core/state.h"

int u2_bcd16(uint8_t lo, uint8_t hi)
{
    return (((lo >> 4) * 10 + (lo & 0x0F)) * 100) +
            (((hi >> 4) * 10 + (hi & 0x0F)));
}

void u2_bcd16_encode(int value, uint8_t *lo, uint8_t *hi)
{
    if (value < 0) value = 0;
    if (value > 9999) value = 9999;
    *lo = (uint8_t)((((value / 100) / 10) << 4) | ((value / 100) % 10));
    *hi = (uint8_t)((((value % 100) / 10) << 4) | (value % 10));
}

void u2_state_init(u2_state *s)
{
    memset(s, 0, sizeof *s);
    /* asm/0100_sub_0100.asm seeds the tick bytes from ES:0x6C (BIOS keyboard
     * flags) and then increments; the engine seeds deterministically and lets
     * the clock drive them, see core/rng.c. */
}
