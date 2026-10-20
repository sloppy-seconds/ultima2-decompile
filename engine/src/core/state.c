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
    /* The rand_byte register at DS:0x23F..0x244 is seeded by the caller
     * (u2_rng_seed, mirroring asm/0100_sub_0100.asm), not here. */
    s->text_attr = 0x0F;      /* asm/53D9_sub_53d9.asm: movb $0xf,0x23e */
    s->right_margin = 0x28;   /* asm/4A2F_sub_4a2f.asm: movb $0x28,0x31 */
    s->left_margin = 0x00;    /* asm/48A7_sub_48a7.asm: movb $0x0,0x54f */
}
