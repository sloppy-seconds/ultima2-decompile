/*
 * CP5 — combat specials (paralysis, sleep) and thief theft.
 *
 * Tickets C1, C2, C6 of docs/phase4-state.md § CP5. The acceptance spec is
 * tests/combat_check.c; this file implements the bytes, not the spec's fixture.
 * That distinction matters for theft: the faithful control model picks uniformly
 * among non-empty slots, which satisfies the assertions but is NOT what the
 * original does. The original rolls a probability and then a slot index, and a
 * miss on either is silent. Both are implemented here.
 *
 * Storage lives in u2_state, keyed by the DS offset the spec names:
 *   counters  DS:26B/26C/26D  -> state.paral_legs / paral_arms / paral_sleep
 *   items     DS:D6..DS:E5    -> state.items_held[0..15]
 */
#include <string.h>

#include "game/combat.h"
#include "game/monsters.h"   /* U2_MON_SLOTS: the attack takes a creature slot */
#include "core/rng.h"
#include "core/state.h"

/* DS offsets, as named by the spec. */
#define C_LEGS   0x26B   /* spec: asm/0E70.asm  (mov al,[0x26b]; and 0xf) */
#define C_ARMS   0x26C   /* spec: asm/0EC2.asm */
#define C_SLEEP  0x26D   /* spec: asm/0F48.asm */

#define I_BOOTS  0xD9    /* legs resist gate   spec: asm/0E70 file 0x108D */
#define I_CLOAK  0xDA    /* arms resist gate   spec: asm/0EC2 file 0x10DF */
#define I_IDOL   0xE4    /* sleep resist gate  spec: asm/0F48 file 0x1162 */

#define ITEM_LO  0xD6
#define ITEM_N   16

/* C2: the resist threshold. `cmp $0x40,%al` then a branch, so a roll BELOW 0x40
 * lets the effect through and a roll AT OR ABOVE it is resisted: roughly 75%
 * resist when the gating item is held. It is a roll, not immunity — the same
 * character with boots can be paralysed on one turn and save on the next. */
#define RESIST_ROLL  0x40

/* C6: the theft attempt threshold, asm/0FCD file 0x11D1. Same shape, different
 * event: roughly 25% of thief turns attempt a theft at all. */
#define STEAL_ROLL   0x40

static uint8_t *counter_slot(u2_ctx *ctx, uint16_t counter_ds)
{
    switch (counter_ds) {
    case C_LEGS:  return &ctx->state.paral_legs;
    case C_ARMS:  return &ctx->state.paral_arms;
    case C_SLEEP: return &ctx->state.paral_sleep;
    default:      return NULL;
    }
}

static const uint8_t *counter_slot_c(const u2_ctx *ctx, uint16_t counter_ds)
{
    switch (counter_ds) {
    case C_LEGS:  return &ctx->state.paral_legs;
    case C_ARMS:  return &ctx->state.paral_arms;
    case C_SLEEP: return &ctx->state.paral_sleep;
    default:      return NULL;
    }
}

/* Which live inventory slot gates which special. A gate wired to the wrong slot
 * passes the legs tests and fails the per-slot tests, which is why this is a
 * table rather than one shared "has an item" flag. */
static uint16_t gate_item_ds(uint16_t counter_ds)
{
    switch (counter_ds) {
    case C_LEGS:  return I_BOOTS;
    case C_ARMS:  return I_CLOAK;
    case C_SLEEP: return I_IDOL;
    default:      return 0xFFFF;
    }
}

uint8_t u2_combat_item(const u2_ctx *ctx, uint16_t item_ds)
{
    if (item_ds < ITEM_LO || item_ds >= ITEM_LO + ITEM_N) return 0;
    return ctx->state.items_held[item_ds - ITEM_LO];
}

void u2_combat_set_item(u2_ctx *ctx, uint16_t item_ds, uint8_t count)
{
    if (item_ds < ITEM_LO || item_ds >= ITEM_LO + ITEM_N) return;
    ctx->state.items_held[item_ds - ITEM_LO] = count;
}

uint8_t u2_combat_counter(const u2_ctx *ctx, uint16_t counter_ds)
{
    const uint8_t *p = counter_slot_c(ctx, counter_ds);
    return p ? *p : 0;
}

void u2_combat_set_counter(u2_ctx *ctx, uint16_t counter_ds, uint8_t value)
{
    uint8_t *p = counter_slot(ctx, counter_ds);
    if (p) *p = value;
}

int u2_combat_special(u2_ctx *ctx, uint16_t counter_ds)
{
    uint8_t *dst = counter_slot(ctx, counter_ds);
    if (dst == NULL) return 0;

    uint16_t slot = gate_item_ds(counter_ds);
    if (slot != 0xFFFF && u2_combat_item(ctx, slot) != 0) {
        /* Item held: roll for the save. The gate roll is the FIRST byte the
         * event consumes, so it must be taken here and nowhere else — the spec
         * pins the decision to exactly this roll. */
        if (u2_rand_byte(ctx) >= RESIST_ROLL) {
            return 0;               /* resisted: counter left untouched */
        }
    }
    /* No item, or the save failed: the effect lands and its length is a roll
     * of 0..15 turns. */
    *dst = (uint8_t)(u2_rand_byte(ctx) & 0x0F);
    return 1;
}

/* Packed-decimal subtract one. asm/0FCD uses `stc; mov; cmc; sbb $0x1,%al; das`
 * — the stc/cmc pair only clears carry for the das, so the arithmetic is a plain
 * BCD decrement. Item counts are BCD, so a naive `-1` would corrupt 0x10 into
 * 0x0F rather than 0x09. */
static uint8_t bcd_dec1(uint8_t v)
{
    uint8_t lo = (uint8_t)(v & 0x0F);
    uint8_t hi = (uint8_t)(v >> 4);
    if (lo == 0) {
        if (hi == 0) return 0;      /* already zero; never wrap */
        lo = 9;
        hi--;
    } else {
        lo--;
    }
    return (uint8_t)((hi << 4) | lo);
}

uint16_t u2_combat_thief_steal(u2_ctx *ctx)
{
    /* asm/0FCD file 0x11D1: `call rand; cmp $0x40,%al; jb steal; ret`.
     * So most thief turns attempt nothing, and they are silent about it. */
    if (u2_rand_byte(ctx) >= STEAL_ROLL) return 0;

    /* Then a slot index, `and 0xf`, over the 16-slot live array — NOT a pick
     * among the slots that hold something. Landing on an empty slot takes
     * nothing and prints nothing (asm/0FCD file 0x1212 is a bare ret). */
    uint16_t idx = (uint16_t)(u2_rand_byte(ctx) & 0x0F);
    uint8_t *slot = &ctx->state.items_held[idx];
    if (*slot == 0) return 0;

    *slot = bcd_dec1(*slot);        /* deletion, not a flag: the C2 gates read this
                                     * array live, so a stolen item must stop
                                     * conferring its resist. */
    return (uint16_t)(ITEM_LO + idx);
}

/* C4 — asm/0F12. Unlike asm/0E70/0EC2/0F48 there is NO inventory gate and NO
 * resist roll on this path: the damage always applies. Deliberately consumes no
 * random byte, which is what the spec asserts.
 *
 * NOT modelled: the accumulation into DS:20/21/22 (+2, +2, +0x40 per cast). Its
 * BCD weight against the HP subtract is unproven, and DS:20 is separately
 * claimed as move_scratch (disputed). Encoding a magnitude here would state a
 * fact the bytes do not support, so the function returns only "applied". */
int u2_combat_magic_missile(u2_ctx *ctx)
{
    (void)ctx;
    return 1;
}

/* C5 — asm/24B5. Gate is [DS:D6], the RING slot of the live item array
 * (file 0x26B8: `mov al,[ds:d6]; cmp al,0; je <damage>`). Non-zero prints
 * RING PROTECTS FROM FIELD! and changes nothing. Zero takes
 * `stc; sbb al,0x10; das` on [DS:51], the high byte of the 4-digit BCD HP,
 * which is exactly -1000: 0x88 -> 0x78 turns 8842 into 7842, as observed live.
 * A borrow (high nibble already zero, i.e. HP < 1000) branches to the death
 * handler at file 0x271B, so it kills rather than wrapping. */
int u2_combat_force_field(u2_ctx *ctx)
{
    if (ctx->state.items_held[0] != 0) return 0;       /* FIELD_PROTECTED */
    uint8_t hp = ctx->state.hp;
    if ((hp >> 4) == 0) {                              /* subtract would borrow */
        ctx->state.hp = 0;
        return 2;                                      /* FIELD_KILLED */
    }
    /* The low nibble is a decimal digit carried through untouched, so
     * subtracting 0x10 from the byte is already the das-adjusted result. */
    ctx->state.hp = (uint8_t)(hp - 0x10);
    return 1;                                          /* FIELD_DAMAGED */
}

/* ---------------------------------------------------------------------------
 * W3 — the player's attack. asm/2E3D_combat_attack_flow (arithmetic) reached
 * through the cmd_A chain asm/2B8F -> 2B9B -> 2BA5 -> 2BD7 -> 2BDA.
 * ------------------------------------------------------------------------- */

/* DAA for the ADD case: the caller has already done the binary add and passes
 * the raw 16-bit result plus the carry and auxiliary-carry it produced. Kept
 * separate from overworld.c's bcd_sbb (the `das` half) so the pair reads as the
 * deliberate mirror the B1 ticket asks for. */
static uint8_t daa_add(unsigned raw, int cf, int af, int *carry_out)
{
    unsigned v = raw & 0xFFu;
    if ((v & 0x0Fu) > 9u || af) v += 6u;
    if (v > 0x9Fu || cf)        v += 0x60u;
    *carry_out = (v > 0xFFu) ? 1 : 0;
    return (uint8_t)(v & 0xFFu);
}

/*
 * Add a small amount to a two-byte packed-decimal field, low byte first, with
 * the carry out of the pair DISCARDED. asm/2DC1 (gold) and asm/2DEE (exp):
 *   al = [lo]; adc amount,al ; daa ; [lo] = al
 *   al = [hi]; adc $0,al     ; daa ; [hi] = al
 * No carry escapes the pair, which is why 9999 + 15 lands on 14 instead of
 * faulting or saturating — the B1 ticket's measured value, and the same wrap
 * seen live when a +2 exp on a 9999 character displayed 0001.
 */
static void bcd_adc2(uint8_t *hi, uint8_t *lo, uint8_t amount)
{
    int c = 0, af = 0;
    unsigned raw = (unsigned)(*lo) + amount;
    af = (((*lo & 0x0Fu) + (amount & 0x0Fu)) > 9u) ? 1 : 0;
    *lo = daa_add(raw, raw > 0xFFu, af, &c);

    raw = (unsigned)(*hi) + (unsigned)c;
    af = (((*hi & 0x0Fu) + (unsigned)c) > 9u) ? 1 : 0;
    *hi = daa_add(raw, raw > 0xFFu, af, &c);   /* this carry is dropped on purpose */
}

/*
 * The attack itself. Returns 0 = MISS, 1 = hit and the creature survived,
 * 2 = killed, and fills *out when given one.
 *
 * Every step below is a byte, cited to file offset in asm/2E3D's header. What
 * is NOT modelled here, and deliberately so:
 *   - the arms-paralysis gate: asm/2BA5_attack_arms_gate refuses the attack and
 *     prints PARALIZED! before any roll, so it belongs to the command layer;
 *   - the site-kind gate at asm/2B9B ([DS:4A] vs 4), same reason;
 *   - the map-cell stamp clear on a kill (asm/2E3D file 0x30F4), which needs the
 *     sector writer and is wired at the caller.
 */
int u2_combat_attack(u2_ctx *ctx, int slot, u2_attack *out)
{
    u2_attack r;
    memset(&r, 0, sizeof r);

    if (slot < 0 || slot >= U2_MON_SLOTS) {
        if (out) *out = r;
        return 0;
    }

    /* asm/2E3D file 0x307E / asm/2BDA file 0x2DDA:
     *   call rand ; clc ; rcr $1,%al ; cmp 0x4c,%al ; jb hit
     * rcr through a cleared carry is a shift, so a hit needs (rand >> 1) < the
     * agility BYTE. Chance is agi_byte/128: agi 40 (byte 0x40 = 64) hits 50%,
     * agi 5 hits 3.9%. Measured both ways — 12 swings at agi 5 landed exactly
     * one hit (capture cp5-hit), which is what agility predicts and rules out
     * strength as the operand. */
    if ((u2_rand_byte(ctx) >> 1) >= ctx->state.stat_agi) {
        if (out) *out = r;
        return 0;
    }

    /* asm/2E3D file 0x309F: al = [DS:61]; add x3; adc [DS:4B],al; rcr; rcr
     * => (8 * readied_weapon + strength) >> 2, **on the raw packed-decimal
     * bytes**. Strength 40 is stored 0x40 = 64, so the maxed seed gives
     * (72 + 64) >> 2 = 34 — exactly what one clean hit removed (Fighter 50->16,
     * capture cp5-dmg). Plugging in the decimal 40 gives 28 and is the mistake
     * this comment exists to prevent. */
    unsigned dmg = (((unsigned)ctx->state.readied_weapon * 8u)
                    + (unsigned)ctx->state.stat_str) >> 2;
    r.damage = (uint8_t)dmg;

    /* asm/2E3D file 0x30BC: stc; cmc (clear CF); sbb [DS:20],al; cmc; jae -> the
     * DEATH branch. Note the inverted sense, and that hp == damage falls through
     * and stores 0, leaving a live creature at zero hp. */
    unsigned hp = ctx->state.mon_hp[slot];
    if (dmg > hp) {
        /* Death clears hp, type and kind — and NOT x/y (file 0x30D2..0x30DC). */
        ctx->state.mon_hp[slot]   = 0;
        ctx->state.mon_type[slot] = 0;
        ctx->state.mon_kind[slot] = 0;

        /* asm/2E3D file 0x3114 / 0x3141: gold += (rand & 0x17) | 1, exp += rand & 7.
         * Reproduces the live `KILLED--GOLD+1--EXP.+02` shape exactly. */
        r.gold = (uint8_t)((u2_rand_byte(ctx) & 0x17u) | 1u);
        r.exp  = (uint8_t)(u2_rand_byte(ctx) & 0x07u);

        /* WARNING, and it is a trap in state.h rather than here: the field NAMES
         * are inverted relative to significance. gold_lo is DS:58 and gold_hi is
         * DS:59, but asm/2DC1 adds into DS:59 FIRST and carries into DS:58, so
         * DS:59 is the LOW byte. Same inversion for exp (low is DS:57 = exp_hi).
         * Reading the names at face value swaps the bytes and corrupts every
         * reward. Flagged in state.h; fix both sides together or neither. */
        bcd_adc2(&ctx->state.gold_lo, &ctx->state.gold_hi, r.gold);  /* hi=58 lo=59 */
        bcd_adc2(&ctx->state.exp_lo,  &ctx->state.exp_hi,  r.exp);   /* hi=56 lo=57 */
        if (out) *out = r;
        return 2;
    }

    ctx->state.mon_hp[slot] = (uint8_t)(hp - dmg);
    if (out) *out = r;
    return 1;
}
