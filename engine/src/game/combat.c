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

    *slot = bcd_dec1(*slot);        /* deletion, not a flag: the C2 gates read
                                     * this array live, so a stolen item must
                                     * stop conferring its resist. */
    return (uint16_t)(ITEM_LO + idx);
}
