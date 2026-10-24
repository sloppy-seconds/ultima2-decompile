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
 *     BCD pairs, hundreds byte first — see u2_bcd16(), and the note in
 *     core/state.c on why there is deliberately no encoder.
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
 *
 * THIS STRUCT IS THE ONE TABLE FOR DS OFFSETS. It is compiled, and every named
 * field is pinned by a _Static_assert below, so a drift is a build failure
 * rather than a stale document. docs/spice86-live-findings.md § 11 is the live
 * evidence behind it and defers to it on layout; when a field is filled in
 * here, § 11 should not grow a competing copy. When you prove a DS byte, name
 * it here in the same commit and add its _Static_assert.
 */

#include <stdint.h>
#include <stddef.h>
#include <string.h>

typedef struct u2_state {
    /* 0x00 */ uint8_t sector_x;      /* asm/5AE1 fill loop: window origin is (x-9, y-5);
                                        also the >= 0x40 sector-reload test (asm/242D).
                                        Unreconciled: asm/5AB1 computes (x-10, y-6) -- see
                                        that file's header, this is an open question. */
    /* 0x01 */ uint8_t sector_y;      /* asm/5AE1, asm/2434 */
    /* 0x02 */ uint8_t reserved_02[0x10];
    /* --- movement and passability cluster. Filled 2026-10-21 from the full
     * re-decode of asm/2423_passability.asm and the raw writer scan; narrative
     * in docs/passability-findings.md. Before this these bytes sat inside
     * `reserved_02`, which is why the walk loop had to be re-derived by hand. */
    /* 0x12 */ uint8_t view_mode;       /* RENAMED 2026-10-28 from tile_offsector,
                                        * owner-approved. It was never a tile and never an
                                        * off-sector tile source: it is a mode byte --
                                        * 0xFF on the world map, 4 in an interior sector --
                                        * written by asm/0C1F/asm/0C2B on the DS:4A branch
                                        * (DS:4A is the sector's low decimal digit), and its
                                        * only readers are asm/5AB1_view_origin_by_mode and
                                        * asm/5AF9. 5AB1 is the routine the monster spawn
                                        * arms call, and DS:12 == 0xFF is how it decides
                                        * whether the viewport origin wraps (`and $0x3f`).
                                        * Live: 0xFF in sector 20, 4 in sector 32.
                                        * The new name says what the byte selects: how the
                                        * view origin is computed. Nothing in the engine
                                        * reads it; it is written so the state block matches
                                        * a live capture. docs/monster-spawn.md § 15.2. */
    /* 0x13 */ uint8_t player_stamp;    /* the sprite stamped INTO the map cell.
                                         * 0x78 = on foot. NOT the terrain under the
                                         * player: observed 0x78 while standing on
                                         * tile 0x0C (create-test-live), and constant
                                         * 0x78 across every in-world capture. The
                                         * old "player tile id" reading was wrong and
                                         * the asm/2423 first ladder never fires on
                                         * foot because of it. */
    /* 0x14 */ uint8_t mode_a;          /* <- DS:2DF (asm/5B71_mode_table_copy) */
    /* 0x15 */ uint8_t mode_walk;       /* the walk loop's passability argument on
                                         * three of four arms: mov al,[0x15] at
                                         * runtime 0x0962. Origin is DS:2CB via
                                         * asm/5B71_mode_table_copy.asm. */
    /* 0x16 */ uint8_t mode_b;          /* <- DS:2F3 (asm/5B71_mode_table_copy) */
    /* 0x17 */ uint8_t mode_c;          /* <- DS:2E0 (asm/5B71_mode_table_copy) */
    /* 0x18 */ uint8_t mode_walk_alt;   /* the fourth arm's argument: mov al,[0x18]
                                         * at runtime 0x09AF. Origin is DS:2DE. */
    /* 0x19 */ uint8_t reserved_19[7];
    /* 0x20 */ uint8_t move_scratch;    /* DISPUTED: docs called this an
                                         * invalid-move counter, but the harvest
                                         * shows it decremented in the walk loop and
                                         * overwritten at runtime 0x2BC7. Treat as
                                         * scratch; do not use as a reject signal. */
    /* 0x21 */ uint8_t reserved_21[2];
    /* 0x23 */ uint8_t player_x;      /* asm/50B3_map_tile_ptr.asm: x + (y<<6) + map base.
                                        The relationship between this pair and the
                                        DS:00/01 pair above is not yet established by
                                        the asm, so both are kept rather than merged. */
    /* 0x24 */ uint8_t player_y;      /* asm/50B3_map_tile_ptr.asm */
    /* 0x25 */ uint8_t reserved_25;
    /* 0x26 */ uint8_t moved_flag;    /* the accept tail of the walk loop xors it
                                         * with 0xFF (runtime 0x09E9) and it is
                                         * zeroed at 0x09F7; a rejected step never
                                         * reaches the xor. */
    /* 0x27 */ uint8_t reserved_27[2];
    /* 0x29 */ uint8_t mode_arg;      /* asm/2423_passability.asm stores its AL
                                         * argument here on entry and the mode
                                         * ladder reads it back masked & 0x7F.
                                         * NB it has FOUR writers (runtime 0x20B7,
                                         * 0x2423, 0x54E8, 0x5A7A), so it is shared
                                         * scratch: a snapshot of it does not tell
                                         * you the last passability argument. */
    /* 0x2A */ uint8_t reserved_2A[4];
    /* 0x2E */ uint8_t cursor_col;    /* asm/51FD_str_out_core.asm: DL for INT 10h AH=02h */
    /* 0x2F */ uint8_t cursor_row;    /* asm/51FD_str_out_core.asm: DH for INT 10h AH=02h */
    /* 0x30 */ uint8_t reserved_30;
    /* 0x31 */ uint8_t right_margin;  /* last printable column; 0x26 or 0x28 at the
                                         sites asm/456B_sub_456b.asm, asm/48A7_sub_48a7.asm,
                                         asm/4A2F_sub_4a2f.asm; read by char_print's wrap
                                         test in asm/504A_sub_504a.asm */
    /* --- player record: the 256 bytes the game saves, DS:36..135 ----------
     * Proven by assignment in the creation routine (see
     * disasm/redecoded/5400_sub_5400.txt) and by the FCB read/write sites in
     * asm/5400 and asm/3823; narrative in
     * docs/phase4-implementation.md § CP2.5. Anything not proven by an
     * assignment or a display site stays in `reserved` — never guessed. */
    /* 0x32 */ uint8_t reserved_32[4];
    /* 0x36 */ uint8_t name[16];      /* cleared, then typed; entry ends on CR */
    /* 0x46 */ uint8_t sex;           /* 'M' or 'F' as typed, not converted */
    /* 0x47 */ uint8_t pclass;        /* 0..3 after `sub $0x31`: FIGHTER..THIEF */
    /* 0x48 */ uint8_t race;          /* '1'..'4' as typed: HUMAN ELF DWARF HOBBIT */
    /* 0x49 */ uint8_t sector_first;   /* first digit of the sector filename: asm/2290
                                        * patches [0x49],[0x4A] into MAPXFF. Set to 2
                                        * at creation (redecoded 5400 tail, file 0x5BE8),
                                        * so a fresh character starts in sector 2x. */
    /* 0x4A */ uint8_t sector_second;  /* second digit of the sector filename and,
                                        * outside a sector read, the site kind:
                                        * 0 overworld, 1 village, 2 town, 4 tower.
                                        * Evidence: asm/2290 patches [0x49],[0x4A]
                                        * into MAPXFF; asm/243E zeroes it on sector
                                        * reload; asm/343F writes 2 and 4 beside the
                                        * -TOWN/-TOWER strings; the P path branches
                                        * `cmp $0x4` on it (file 0x0A76). The plan §1
                                        * "last key" reading is RETIRED: seam.c used
                                        * to store polled keys here, which corrupted
                                        * the saved sector digit (observed live as
                                        * "sector 289" — 'Y' from the creation
                                        * confirm). cmd_D's compares against 4 and 5
                                        * are site-kind compares, not key compares. */
    /* 0x4B */ uint8_t stat_str;
    /* 0x4C */ uint8_t stat_agi;
    /* 0x4D */ uint8_t stat_sta;
    /* 0x4E */ uint8_t stat_cha;
    /* 0x4F */ uint8_t stat_wis;
    /* 0x50 */ uint8_t stat_int;
    /* 0x51 */ uint8_t hp;            /* set to 4 at creation */
    /* 0x52 */ uint8_t unk_52;        /* adjacent to hp; no assignment traced yet */
    /* 0x53 */ uint8_t food;          /* set to 4 at creation; BCD pair with 0x54,
                                        read at asm/5129_sub_5129.asm (FOOD=) */
    /* 0x54 */ uint8_t food_hi;
    /* 0x55 */ uint8_t food_lo;       /* FOOD's third BCD byte. The status band
                                         prints only 0x53/0x54 (4 digits), but the
                                         drain routines subtract from 0x55 first and
                                         borrow upward: PASS does `sbb $0x0a` on this
                                         byte (file 0x0B10..0x0B15), so one PASS is
                                         10 food. asm/2599/asm/2626 do the same with
                                         $0x19 (19). Underflow is the death trigger
                                         (jb to runtime 0x0E62, which zeroes
                                         0x51..0x59). */
    /* 0x56 */ uint8_t exp_lo;        /* EXP.= display loads [0x56],[0x57] — note
                                         it is NOT 0x55; file 0x5367.
                                         * NAMING WART, do not fix one side alone:
                                         * exp_lo is the HIGH byte and exp_hi the
                                         * LOW one. asm/2DEE adds into DS:57 first
                                         * and carries into DS:56, so 57 is least
                                         * significant. asm/2E3D and attack_check.c
                                         * both depend on that reading. */
    /* 0x57 */ uint8_t exp_hi;
    /* 0x58 */ uint8_t gold_lo;       /* BCD pair, hundreds byte first; display site
                                         asm/5175_sub_5175.asm (string at file 0x5382).
                                         * NAMING WART, same as exp_lo/exp_hi:
                                         * gold_lo (DS:58) is the HIGH byte and
                                         * gold_hi (DS:59) the LOW one — asm/2DC1
                                         * adds into DS:59 first and carries into
                                         * DS:58. Read at face value the reward adds
                                         * are byte-swapped and every payout is
                                         * corrupted silently. Rename both pairs
                                         * together, with their _Static_asserts and
                                         * every call site, or leave them alone. */
    /* 0x59 */ uint8_t gold_hi;
    /* 0x5A */ uint8_t entry_x;        /* spawn x: the P path copies [0x5A]->[0x00]
                                        * (file 0x0A26); creation sets 20 (file 0x5BDE);
                                        * the sector reload restores [0x5A]->[0x00] too
                                        * (asm/243E), so it is the entry point of the
                                        * current sector. */
    /* 0x5B */ uint8_t entry_y;        /* spawn y: [0x5B]->[0x01] (file 0x0A2C),
                                        * creation sets 20 (file 0x5BE3) */
    /* 0x5C */ uint8_t reserved_5C[4];
    /* 0x60 */ uint8_t spawn_selector; /* NOT a spawn counter. The wandering spawner does
                                        * `incb` here, walks the bits of the result from 0
                                        * upward, and takes the arm belonging to the LOWEST
                                        * set bit; an arm whose terrain test fails does
                                        * `decb`, which is why the byte creeps instead of
                                        * marching. Pinned at runtime for all nine arms by
                                        * forcing this byte — docs/monster-spawn.md 15.4.
                                        * asm/0CEE_spawn_tile_store, asm/0D4F, asm/0D6F,
                                        * asm/0DAF, asm/0DC4. */
    /* 0x61 */ uint8_t readied_weapon; /* weapon index 0..9, 0 = HANDS. Proven by
                                        * live read/write-back, findings § 11;
                                        * name table at file 0x4F53. */
    /* 0x62 */ uint8_t worn_armour;    /* armour index 0..7, 0 = SKIN. Proven,
                                        * findings § 11; name table at file 0x4F9E. */
    /* 0x63 */ uint8_t spell_pick;    /* readied spell slot */
    /* 0x64 */ uint8_t torches;        /* one packed-decimal byte, ceiling 99.
                                        * asm/2D22 adds, asm/37AE subtracts. */
    /* 0x65 */ uint8_t keys;           /* packed decimal, ceiling 99. asm/2CD8
                                        * adds 2, asm/435E subtracts 1. */
    /* 0x66 */ uint8_t tools;          /* packed decimal, ceiling 99. asm/2CF6
                                        * adds 1, asm/277B subtracts 1. */
    /* 0x67 */ uint8_t reserved_67[6];
    /* 0x6D */ uint8_t boots_count;    /* non-zero gates the paralysis save at
                                        * runtime 0x22FD. STALE COPY — after a thief
                                        * stole the boots this still read 1 while the
                                        * live gate DS:D9 (items_held[BOOTS]) went
                                        * to 0. Resist checks read items_held, never
                                        * this byte. */
    /* 0x6E */ uint8_t reserved_6E[8];
    /* 0x76 */ uint8_t weapons_owned[10]; /* one count per weapon, 10 entries.
                                        * Proven, docs/save-format.md. asm/363B and
                                        * asm/19D7 add; asm/3F5D steals. */
    /* 0x80 */ uint8_t owned_armour[8]; /* the owned-armour counts the Z screen's ARMOUR:
                                        * list reads — `mov al,[di+0x80]` in the loop at
                                        * asm/464E's tail, bounds 1..6, plural "S-". This
                                        * retires the CANDIDATE note that used to sit on
                                        * reserved_80: the display site is the citation
                                        * that was missing. docs/status-screen-z.md § 7. */
    /* 0x88 */ uint8_t reserved_88[0x0E];
    /* 0x96 */ uint8_t reserved_96[0x20];   /* 0x96..0xB5 */
    /* 0xB6 */ uint8_t spell_counts[10];   /* the SPELLS: list counts, `mov al,[di+0xB6]`,
                                        * bounds 1..9. New finding from the same read; no
                                        * other reader or writer is identified yet, so
                                        * nothing but the Z screen should touch it. */
    /* 0xC0 */ uint8_t reserved_C0[0x16];   /* 0xC0..0xD5 */
    /* 0xD6 */ uint8_t items_held[16]; /* the LIVE inventory array, one count per
                                        * item, 16 slots. The C2 resist gates read
                                        * slots inside it (0xD9 BOOTS, 0xDA CLOAK,
                                        * 0xE4 GREEN IDOL) and asm/0FCD theft deletes
                                        * from it. Name table at file 0x501D. */
    /* 0xE6 */ uint8_t reserved_E6[0x51];   /* 0xE6..0x136 */
    /* ------------------------------------------------------------------------
     * The creature table: six parallel 32-slot arrays, loaded from monxNN by
     * asm/22D5 (CX=0x100 = 256 bytes, which covers all six arrays at 192 bytes
     * with 64 to spare). Field order and the monx offset of each array are
     * measured, not inferred: docs/monster-spawn.md § 6 matched them live against
     * four sectors, `type` at 32/32 in all of them and `hp` at 31-32/32.
     * DI is the slot index throughout the original (`mov 0x197(%di),%al`).
     * ---------------------------------------------------------------------- */
    /* 0x137 */ uint8_t mon_x[32];    /* monx[0..31]. Spawn x; drifts in play,
                                       * because monsters move (observed live: a
                                       * Guard walked (30,14)->(36,20) while idle). */
    /* 0x157 */ uint8_t mon_y[32];    /* monx[32..63]. Spawn y. */
    /* 0x177 */ uint8_t mon_hp[32];   /* monx[64..95]. PROVEN field: asm/2E3D
                                       * subtracts the player's damage from it and
                                       * clears the record on borrow. One byte, so
                                       * 255 is the ceiling (docs/bestiary.md § 6). */
    /* 0x197 */ uint8_t mon_type[32]; /* monx[96..127]. Sprite/type byte: 0x60 Guard,
                                       * 0x68 Merchant, 0xF0 Fighter. asm/40CB compares
                                       * it against 0x6c. NOT the art index — art comes
                                       * from the map cell, docs/art-index.md. */
    /* 0x1B7 */ uint8_t mon_kind[32]; /* monx[128..159]. Kind index; asm/0AD3 dispatches
                                       * the special attacks on it. Does not hold across
                                       * every sector (docs/monster-spawn.md § 6). */
    /* 0x1D7 */ uint8_t mon_role[32]; /* monx[160..191]. Per-slot state/identity.
                                       * 0 = empty slot (asm/102B tests it for zero);
                                       * 0x81/0x82/0x83 = scripted recipients, enumerated
                                       * one by one by asm/3C2E_cmd_O (ENILNO / the RING /
                                       * a third), so bit 7 is "has a scripted response";
                                       * and 0x01 reads as "will attack the player". It is
                                       * BOTH a birth value and an acquired one: monx31 ships
                                       * 0x01 on the 0xFC and 0x2C slots, while Guards (0x60)
                                       * are born 0x03/0x00 and every guard in the sector
                                       * flips to 0x01 the moment a blow lands on anything in
                                       * town — a missed swing and 65 s of idle flip nothing
                                       * (docs/spice86-live-findings.md § 16, capture
                                       * cp5-g25-aggro; the monx31 column check is
                                       * engine/tests/monsters_check.c). Merchants are 0x02
                                       * and were never seen to attack.
                                       * Whether 0x01 is read back as the cause of attacking
                                       * is OPEN: the born-hostile kinds were out of range in
                                       * every capture so far, so their half of the reading is
                                       * inferred, not observed. Do not treat it as a cause
                                       * without a test that proves it. */
    /* 0x1F7 */ uint8_t reserved_1F7[0x42];  /* 0x1F7..0x238 */
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
    /* 0x245 */ uint8_t reserved_245[0x25];  /* 0x245..0x269 */
    /* 0x26A */ uint8_t counter_26A;   /* NAME UNKNOWN — do not invent one. Ticks and
                                        * is zeroed exactly alongside the three paralysis
                                        * counters (asm/0C33..0C53 decrements it, asm/080D
                                        * zeroes DS:26A..26D), but it read 0x00 in every
                                        * frame of the 3000-turn fight recording and in
                                        * every live run since. Something sets it and no
                                        * observation has met that something.
                                        * docs/needs-gameplay.md G27. */
    /* 0x26B */ uint8_t paral_legs;   /* C1: legs-paralysis turns, 0..15.
                                       * Set by asm/0E70 (`and 0xf`), read live by the
                                       * movement check. Resisted by a roll on
                                       * items_held[BOOTS] (DS:D9), not by immunity. */
    /* 0x26C */ uint8_t paral_arms;   /* C1: arms-paralysis turns, 0..15 (asm/0EC2,
                                       * gate items_held[CLOAK] at DS:DA). */
    /* 0x26D */ uint8_t paral_sleep;   /* C1: sleep turns, 0..15 (asm/0F48,
                                       * gate items_held[GREEN IDOL] at DS:E4). */
    /* 0x26E */ uint8_t reserved_26E[0x204];  /* 0x26E..0x471 */
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
_Static_assert(U2_OFF(view_mode)      == 0x012, "view_mode moved");
_Static_assert(U2_OFF(player_stamp)   == 0x013, "player_stamp moved");
_Static_assert(U2_OFF(mode_a)         == 0x014, "mode_a moved");
_Static_assert(U2_OFF(mode_walk)      == 0x015, "mode_walk moved");
_Static_assert(U2_OFF(mode_b)         == 0x016, "mode_b moved");
_Static_assert(U2_OFF(mode_c)         == 0x017, "mode_c moved");
_Static_assert(U2_OFF(mode_walk_alt)  == 0x018, "mode_walk_alt moved");
_Static_assert(U2_OFF(move_scratch)   == 0x020, "move_scratch moved");
_Static_assert(U2_OFF(moved_flag)     == 0x026, "moved_flag moved");
_Static_assert(U2_OFF(mode_arg)       == 0x029, "mode_arg moved");
_Static_assert(U2_OFF(cursor_col) == 0x02E, "cursor_col moved");
_Static_assert(U2_OFF(cursor_row) == 0x02F, "cursor_row moved");
_Static_assert(U2_OFF(right_margin)== 0x031, "right_margin moved");
_Static_assert(U2_OFF(sector_second)== 0x04A, "sector_second moved");
_Static_assert(U2_OFF(sector_first)== 0x049, "sector_first moved");
_Static_assert(U2_OFF(entry_x)    == 0x05A, "entry_x moved");
_Static_assert(U2_OFF(entry_y)    == 0x05B, "entry_y moved");
_Static_assert(U2_OFF(name)       == 0x036, "name moved — it anchors the save record");
_Static_assert(sizeof(((u2_state *)0)->name) == 16, "name is 16 bytes");
_Static_assert(U2_OFF(sex)        == 0x046, "sex moved");
_Static_assert(U2_OFF(pclass)     == 0x047, "pclass moved");
_Static_assert(U2_OFF(race)       == 0x048, "race moved");
_Static_assert(U2_OFF(stat_str)   == 0x04B, "stat_str moved");
_Static_assert(U2_OFF(stat_int)   == 0x050, "stat_int moved");
_Static_assert(U2_OFF(hp)         == 0x051, "hp moved");
_Static_assert(U2_OFF(food)       == 0x053, "food moved");
_Static_assert(U2_OFF(exp_lo)     == 0x056, "exp_lo moved");
_Static_assert(U2_OFF(gold_lo)    == 0x058, "gold_lo moved");
_Static_assert(U2_OFF(spell_pick) == 0x063, "spell_pick moved");
_Static_assert(U2_OFF(readied_weapon) == 0x061, "readied_weapon moved");
_Static_assert(U2_OFF(spawn_selector) == 0x060, "spawn_selector moved");
_Static_assert(U2_OFF(worn_armour)    == 0x062, "worn_armour moved");
_Static_assert(U2_OFF(torches)        == 0x064, "torches moved");
_Static_assert(U2_OFF(keys)           == 0x065, "keys moved");
_Static_assert(U2_OFF(tools)          == 0x066, "tools moved");
_Static_assert(U2_OFF(boots_count)    == 0x06D, "boots_count moved");
_Static_assert(U2_OFF(weapons_owned)  == 0x076, "weapons_owned moved");
_Static_assert(U2_OFF(items_held)     == 0x0D6, "items_held moved");
_Static_assert(U2_OFF(owned_armour)   == 0x080, "owned_armour moved");
_Static_assert(U2_OFF(spell_counts)   == 0x0B6, "spell_counts moved");
_Static_assert(U2_OFF(paral_legs)     == 0x26B, "paral_legs moved");
_Static_assert(U2_OFF(paral_arms)     == 0x26C, "paral_arms moved");
_Static_assert(U2_OFF(paral_sleep)    == 0x26D, "paral_sleep moved");
_Static_assert(U2_OFF(counter_26A)    == 0x26A, "counter_26A moved");
/* The creature table: six parallel arrays, each exactly 32 slots, contiguous in
 * the order asm/22D5 lays them out in monx. Any drift here silently reassigns
 * every monster's x/y/hp/type/kind/role, so all six are pinned. */
_Static_assert(U2_OFF(mon_x)    == 0x137, "mon_x moved");
_Static_assert(U2_OFF(mon_y)    == 0x157, "mon_y moved");
_Static_assert(U2_OFF(mon_hp)   == 0x177, "mon_hp moved");
_Static_assert(U2_OFF(mon_type) == 0x197, "mon_type moved");
_Static_assert(U2_OFF(mon_kind) == 0x1B7, "mon_kind moved");
_Static_assert(U2_OFF(mon_role) == 0x1D7, "mon_role moved");
_Static_assert(sizeof(((u2_state *)0)->mon_x)    == 32, "mon_x is 32 slots");
_Static_assert(sizeof(((u2_state *)0)->mon_role) == 32, "mon_role is 32 slots");
_Static_assert(U2_OFF(mon_role) + 32 == 0x1F7, "mon_role must end where reserved_1F7 starts");
_Static_assert(sizeof(((u2_state *)0)->weapons_owned) == 10,
               "weapons_owned is 10 entries");
_Static_assert(sizeof(((u2_state *)0)->items_held) == 16,
               "items_held is 16 slots");
/* The struct mirrors the whole DS working segment. Naming fields must never
 * change its size; if this fires, a split lost or gained bytes. */
_Static_assert(sizeof(u2_state) == 0x650, "u2_state size changed");
_Static_assert(U2_OFF(story_flag) == 0x239, "story_flag moved");
_Static_assert(U2_OFF(text_attr)  == 0x23E, "text_attr moved");
_Static_assert(U2_OFF(rng_state)  == 0x23F, "rng_state moved");
_Static_assert(sizeof(((u2_state *)0)->rng_state) == 6, "rng_state is DS:0x23F..0x244");
_Static_assert(U2_OFF(map_base)   == 0x472, "map_base moved");
_Static_assert(U2_OFF(left_margin)== 0x54F, "left_margin moved");

/* Packed-decimal decode: a BCD pair is stored hundreds byte first
 * (0x99 0x97 == 9997), per captures/README.md and the display sites.
 * There is no encoder on purpose — see the note in core/state.c. */
int  u2_bcd16(uint8_t lo, uint8_t hi);

void u2_state_init(u2_state *s);

#endif /* U2_STATE_H */
