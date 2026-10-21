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

/*
 * There is deliberately NO u2_bcd16_encode() here.
 *
 * The one that used to be here clamped to [0, 9999] and had zero callers. The
 * original does not clamp: asm/2DC1_combat_gold_gain and asm/2DEE_combat_exp_gain
 * add with adc/daa and discard the carry out of the top byte, so a reward landed
 * on the 9999 ceiling WRAPS — 9999 + 15 -> 14, measured at turn 209 of the
 * castle-03 fight. A clamping encoder sitting in core/ is a trap for whoever
 * writes the first BCD add: it compiles, it looks reasonable, and it silently
 * deviates. Owner decision 2026-10-22 (docs/phase4-state.md § BCD tickets, B1):
 * original mode reproduces the wrap.
 *
 * When CP5 needs an add, write bcd_adc() as the deliberate mirror of bcd_sbb()
 * in game/overworld.c — discard the carry, cite the asm, and pin it with the
 * measured 9999 + 15 -> 14. Do NOT route it through an int round-trip: decoding
 * a packed-decimal pair and re-encoding it REWRITES invalid nibbles
 * (0x9A 0x99 -> 10099 -> clamped -> 0x99 0x99), and the original preserves them.
 * That is ticket B4; this comment is what keeps it true.
 */

void u2_state_init(u2_state *s)
{
    memset(s, 0, sizeof *s);
    /* The rand_byte register at DS:0x23F..0x244 is seeded by the caller
     * (u2_rng_seed, mirroring asm/0100_sub_0100.asm), not here. */
    s->text_attr = 0x0F;      /* asm/53D9_sub_53d9.asm: movb $0xf,0x23e */
    s->right_margin = 0x28;   /* asm/4A2F_sub_4a2f.asm: movb $0x28,0x31 */
    s->left_margin = 0x00;    /* asm/48A7_sub_48a7.asm: movb $0x0,0x54f */
}
