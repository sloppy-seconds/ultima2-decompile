#ifndef U2_STATE_H
#define U2_STATE_H

/*
 * Game state — the DS working segment.
 *
 * At startup the original sets DS to its own 64 KiB working segment
 * (asm/0100_sub_0100.asm: `mov $0x741,%ax` patched by the MZ loader to the
 * real segment, `mov %ax,%ds`; runtime DS = 0x08BE per captures/README.md).
 * All the bare-displacement globals in the asm tree (mov 0x23, mov 0x240, ...)
 * live there. The engine mirrors that segment as an explicit struct so a
 * lifted routine can be checked field-by-field against the asm it cites.
 *
 * Two rules keep 16-bit fidelity:
 *   - fields are uint8_t/uint16_t, never int; arithmetic that the original
 *     relies on wrapping is masked at the assignment site;
 *   - counters the original keeps in packed decimal (gold, food, exp) stay
 *     BCD pairs, hundreds byte first — see u2_bcd16()/u2_bcd16_encode().
 *
 * A second variable space exists in the original and is NOT here: the CS-side
 * data area (jump table at cs:0x730, the timed_wait parameter block at
 * cs:0x4F04..cs:0x4F0A, item tables around cs:0x48D0). Those are static
 * per-module state and live with the module that owns them, cited in its
 * header. See disasm/selfmod-capture.md.
 *
 * Offsets below are proven by the asm that reads them; each is cited.
 * Offsets not yet lifted stay in `reserved` and are filled in as phases
 * progress — never guessed.
 */

#include <stdint.h>
#include <stddef.h>
#include <string.h>

typedef struct u2_state {
    /* 0x00 */ uint8_t reserved_00[0x23];
    /* 0x23 */ uint8_t player_x;      /* asm/50B3_map_tile_ptr.asm: x + (y<<6) + map base */
    /* 0x24 */ uint8_t player_y;      /* asm/50B3_map_tile_ptr.asm */
    /* 0x25 */ uint8_t reserved_25[0x09];
    /* 0x2E */ uint8_t cursor_col;    /* asm/51FD_str_out_core.asm: DL for INT 10h AH=02h */
    /* 0x2F */ uint8_t cursor_row;    /* asm/51FD_str_out_core.asm: DH for INT 10h AH=02h */
    /* 0x30 */ uint8_t reserved_30;
    /* 0x31 */ uint8_t right_margin;  /* last printable column; 0x26 or 0x28 at the
                                         sites asm/456B_sub_456b.asm, asm/48A7_sub_48a7.asm,
                                         asm/4A2F_sub_4a2f.asm; read by char_print's wrap
                                         test in asm/504A_sub_504a.asm */
    /* 0x32 */ uint8_t reserved_32[0x18];
    /* 0x4A */ uint8_t last_key;      /* last key byte consumed by the command loop */
    /* 0x4B */ uint8_t reserved_4B[0x0D];
    /* 0x58 */ uint8_t gold_lo;       /* BCD pair, hundreds byte first; display site
                                         asm/5175_sub_5175.asm (string at file 0x5382) */
    /* 0x59 */ uint8_t gold_hi;
    /* 0x5A */ uint8_t reserved_5A[0x09];
    /* 0x63 */ uint8_t spell_pick;    /* readied spell slot */
    /* 0x64 */ uint8_t reserved_64[0x1D5];
    /* 0x239 */ uint8_t story_flag;   /* "story/poem shown"; cleared at asm/0133_sub_0133.asm,
                                         set at asm/03AC_sub_03ac.asm, branched on in the
                                         same region */
    /* 0x23A */ uint8_t reserved_23A[4];
    /* 0x23E */ uint8_t text_attr;    /* INT 10h AH=09h attribute: 0x0F normal, 0x70 dim,
                                         0x02 red — asm/53D9_sub_53d9.asm,
                                         asm/53E6_sub_53e6.asm, asm/53EE_sub_53ee.asm */
    /* 0x23F */ uint8_t rng_state[6]; /* the rand_byte shift register, DS:0x23F..0x244.
                                         Seeded once at asm/0100_sub_0100.asm from the BIOS
                                         keyboard flags at 0x40:6C, then rewritten only by
                                         asm/5217_rand_byte.asm + asm/522B_sub_522b.asm.
                                         rng_state[0] is DS:0x23F, the last value produced;
                                         rng_state[1..5] are DS:0x240..0x244.
                                         NB: docs/phase4-plan.md §1 called these "tick
                                         counters"; the full decode shows PRNG state, and
                                         nothing else in the binary writes them. */
    /* 0x245 */ uint8_t reserved_245[0x22D];
    /* 0x472 */ uint16_t map_base;    /* map table base offset, asm/50B3_map_tile_ptr.asm */
    /* 0x474 */ uint8_t reserved_474[0x0DB];
    /* 0x54F */ uint8_t left_margin;  /* column a CR returns to; 0 or 1 at the sites
                                         asm/456B_sub_456b.asm, asm/48A7_sub_48a7.asm;
                                         read by asm/500D_sub_500d.asm */
    /* 0x550 */ uint8_t reserved_550[0x100];
} u2_state;

#define U2_OFF(f) ((int)offsetof(u2_state, f))

/* Compile-time proof that the struct still matches the asm offsets. */
_Static_assert(U2_OFF(player_x)   == 0x023, "player_x moved");
_Static_assert(U2_OFF(player_y)   == 0x024, "player_y moved");
_Static_assert(U2_OFF(cursor_col) == 0x02E, "cursor_col moved");
_Static_assert(U2_OFF(cursor_row) == 0x02F, "cursor_row moved");
_Static_assert(U2_OFF(right_margin)== 0x031, "right_margin moved");
_Static_assert(U2_OFF(last_key)   == 0x04A, "last_key moved");
_Static_assert(U2_OFF(gold_lo)    == 0x058, "gold_lo moved");
_Static_assert(U2_OFF(spell_pick) == 0x063, "spell_pick moved");
_Static_assert(U2_OFF(story_flag) == 0x239, "story_flag moved");
_Static_assert(U2_OFF(text_attr)  == 0x23E, "text_attr moved");
_Static_assert(U2_OFF(rng_state)  == 0x23F, "rng_state moved");
_Static_assert(sizeof(((u2_state *)0)->rng_state) == 6, "rng_state is DS:0x23F..0x244");
_Static_assert(U2_OFF(map_base)   == 0x472, "map_base moved");
_Static_assert(U2_OFF(left_margin)== 0x54F, "left_margin moved");

/* Packed-decimal helpers: a BCD pair is stored hundreds byte first
 * (0x99 0x97 == 9997), per captures/README.md and the display sites. */
int  u2_bcd16(uint8_t lo, uint8_t hi);
void u2_bcd16_encode(int value, uint8_t *lo, uint8_t *hi);

void u2_state_init(u2_state *s);

#endif /* U2_STATE_H */
