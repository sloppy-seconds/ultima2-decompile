/*
 * commerce.c — the TRANSACT ray, the vendor selector, and the shops it reaches.
 *
 * See commerce.h for the shape and docs/commerce.md for the evidence. Every claim about
 * order in this file is byte-cited to the asm/ tree; where a shop is deliberately NOT
 * implemented, the gap is named at the branch that would have done it, because a silent
 * fall-through is how an unmodelled subsystem starts looking like a working one.
 *
 * Content policy: as everywhere in the engine, no game text is hard-coded here. Every
 * literal comes from the extractor's table, which reads it out of the user's own copy at
 * build time.
 */
#include "game/commerce.h"

#include <stdio.h>
#include <string.h>

#include "core/seam.h"
#include "core/state.h"
#include "core/world.h"
#include "game/monsters.h"

#include "gen_content.h"

/* The merchant marker, and the one non-sign tile the ray also accepts in the near cell.
 * Both are stamped-grid values (DS:1800), not mapx file bytes: the grid is what
 * asm/50B3_map_tile_ptr reads, and it is the map plus the creature stamps on top of it. */
#define TILE_MERCHANT_MARK  0x68u
#define TILE_SHOP_COUNTER   0x7Cu

/* ---- asm/20AB: the price --------------------------------------------------- */

/*
 * The `adc` + `daa` pair from asm/20AB's loop body, with DAA's carry-out taken only from
 * the >0x99 adjustment. That restriction is not a shortcut: an earlier model let the
 * low-nibble fixup feed the following adc and produced 4, 8, 112, 220 — plausible-looking
 * and wrong from the third term onward, which is the shape of error asm/20AB's header
 * exists to record. The corrected walk reproduces the two anchors the file hand-computes
 * and both live prices measured on 2026-10-29.
 */
static uint8_t daa_add(uint8_t a, uint8_t b, int cin, int *cout)
{
    unsigned sum = (unsigned)a + (unsigned)b + (unsigned)cin;
    const int af = ((a & 0x0Fu) + (b & 0x0Fu) + cin) > 0x0F;
    int cf = sum > 0xFF;
    unsigned v = sum & 0xFFu;

    if ((v & 0x0Fu) > 9u || af)
        v += 6u;
    if (v > 0x99u || cf) {
        v += 0x60u;
        cf = 1;
    }
    *cout = cf;
    return (uint8_t)(v & 0xFFu);
}

/* asm/20CF: `inc %si ; clc ; rcr $1,%al ; or %al,%al ; jne` — shifts to reach zero, so a
 * zero input still costs one shift. That is a bit length, not a popcount; an earlier pass
 * called it popcount and asm/20AB records the correction. */
static int shifts_to_zero(uint8_t v)
{
    int n = 0;
    do {
        n++;
        v = (uint8_t)(v >> 1);
    } while (v != 0);
    return n;
}

void u2_price_from_stats(uint8_t index, uint8_t stat_int, uint8_t stat_cha, uint8_t price[2])
{
    /* asm/20AD: `clc ; adc $0x8,%al` — the caller's index, offset by eight, and the carry
     * it leaves is the same one the int+cha add below consumes. */
    unsigned seed = (unsigned)index + 8u;
    const int carry_from_seed = seed > 0xFF;

    /* asm/20B2: both pairs seeded to 0004. */
    unsigned p1_hi = 0x00u, p1_lo = 0x04u;   /* DS:27 / DS:28 — printed and charged */
    unsigned p2_hi = 0x00u, p2_lo = 0x04u;   /* DS:29 / DS:2A — the other half of the walk */

    /* asm/20C2: `mov [DS:50],%al ; adc [DS:4E],%al` — int + charisma, added as raw packed
     * decimal bytes with no daa, which is a quirk of the original and is kept. */
    const unsigned stat_sum = (unsigned)stat_int + (unsigned)stat_cha + (carry_from_seed ? 1u : 0u);
    int loops = (int)seed - shifts_to_zero((uint8_t)(stat_sum & 0xFFu));
    if (loops < 0)
        loops = 0;
    /* asm/231E: `dec %di ; jne`. A loop count of zero does not skip the loop, it wraps to
     * 0xFFFF and runs 65536 times. Reachable in principle, never observed; mirrored because
     * the bytes say so and guessing that the original guarded it would be the invention. */
    if (loops == 0)
        loops = 0x10000;

    for (int i = 0; i < loops; i++) {
        int cf = 0;
        const unsigned old_lo = p1_lo, old_hi = p1_hi;
        p1_lo = daa_add((uint8_t)p1_lo, (uint8_t)p2_lo, 0, &cf);
        p2_lo = old_lo;
        p1_hi = daa_add((uint8_t)p1_hi, (uint8_t)p2_hi, cf, &cf);
        p2_hi = old_hi;
    }

    price[0] = (uint8_t)p1_hi;
    price[1] = (uint8_t)p1_lo;
}

/* The four-digit print: asm/17B7 loads AL=[DS:27] and DI=[DS:28] and asm/51A5 emits AL's
 * two decimal digits then DI's, so DS:27 is the high byte and the pair reads in address
 * order. This is the same order asm/2052 charges in, and it is why state.h's gold_lo /
 * gold_hi names are about address, not significance. */
static void print_price(u2_ctx *ctx, const uint8_t price[2])
{
    char buf[5];
    buf[0] = (char)('0' + (price[0] >> 4));
    buf[1] = (char)('0' + (price[0] & 0x0Fu));
    buf[2] = (char)('0' + (price[1] >> 4));
    buf[3] = (char)('0' + (price[1] & 0x0Fu));
    buf[4] = '\0';
    seam_str_out(ctx, buf);
}

/* ---- asm/2052: the charge -------------------------------------------------- */

/* asm/2052's `cmc ; sbb ; das ; cmc` pair, byte by byte, with the borrow threaded from the
 * low byte to the high byte the way the two `cmc`s do it. Mirrors the same helper
 * game/overworld.c keeps private for HP and food: no int round-trip, because decoding a
 * packed-decimal pair and re-encoding it rewrites nibbles the original preserves. */
static int bcd_sbb(unsigned a, unsigned sub, int borrow_in, unsigned *out)
{
    const int af = ((a & 0x0Fu) < (sub & 0x0Fu) + (unsigned)borrow_in) ? 1 : 0;
    int d = (int)a - (int)sub - borrow_in;
    const int cf = (d < 0) ? 1 : 0;
    d &= 0xFF;
    if ((unsigned)(d & 0x0F) > 9u || af)
        d = (d - 6) & 0xFF;
    if (cf || (unsigned)d > 0x99u)
        d = (d - 0x60) & 0xFF;
    *out = (unsigned)d;
    return cf;
}

/* `clc ; adc $1,%al ; daa` — the one-step BCD increment asm/181A uses for food and asm/2045
 * uses for an owned-count slot. Both discard the carry out of the byte, so 99 wraps to 00
 * and nothing upstream guards it. */
static uint8_t bcd_inc1(uint8_t v)
{
    int cf = 0;
    return daa_add(v, 1u, 0, &cf);
}

int u2_spend_price(u2_ctx *ctx, const uint8_t price[2])
{
    u2_state *st = &ctx->state;

    /* asm/2052 subtracts [DS:27]:[DS:28] from [DS:58]:[DS:59], high byte first in address
     * order, and the second `das`'s borrow is the verdict: `jb` is taken when there was NO
     * borrow, because the trailing `cmc` inverts it. So a returned borrow of 1 means the
     * player cannot pay, and asm/2070 adds the pair back and prints the refusal — and then
     * does not return to the shop, which is why a caller must not print a success line
     * after a 0. */
    unsigned lo = 0, hi = 0;
    int borrow = bcd_sbb(st->gold_hi, price[1], 0, &lo);      /* DS:59 - DS:28 */
    borrow = bcd_sbb(st->gold_lo, price[0], borrow, &hi);     /* DS:58 - DS:27 */
    if (borrow) {
        seam_str_out(ctx, U2_S_DONT_HAVE_THAT_MUCH);
        return 0;
    }
    st->gold_hi = (uint8_t)lo;
    st->gold_lo = (uint8_t)hi;
    return 1;
}

/* ---- the input the shops need ---------------------------------------------- */

/* asm/2028_read_decimal_digit: block until one decimal digit arrives, echo it, return it.
 * Non-digits are rejected by reading again. Returns -1 only when the engine's input is
 * exhausted, which has no counterpart in the original (it blocks forever) and is the
 * caller's cue to do nothing rather than to guess. */
static int read_digit(u2_ctx *ctx)
{
    for (;;) {
        u2_key k;
        if (seam_key_wait(ctx, &k) == 0)
            return -1;
        if (k.ch >= '0' && k.ch <= '9') {
            seam_char_print(ctx, k.ch);
            return k.ch - '0';
        }
    }
}

/* asm/1FEB / asm/2017: read ONE key of any kind, echo it, and treat only 'Y' as yes.
 *
 * Uppercase is the byte (`cmp $0x59,%al`), not a stylistic choice, and it is a real quirk:
 * a player who types lowercase y is refused. Captures that appear to show a lowercase 'y'
 * working were driven through tools/spice86_type.py, which reports `sent y as Y` — the
 * injector sends the shifted key. Do not "fix" this by accepting both.
 *
 * The original also emits 0x8D after the key. asm/2028's own DOUBT block calls that byte
 * unexplained, and cmd_M made the same call for the same reason: emitting a line break
 * nobody can account for is a worse guess than not emitting one. */
static int read_yes(u2_ctx *ctx)
{
    u2_key k;
    if (seam_key_wait(ctx, &k) == 0)
        return 0;
    seam_char_print(ctx, k.ch);
    return k.ch == 'Y';
}

/* ---- the two catalogues that share one shape ------------------------------- */

/*
 * asm/1D1D (armour) and asm/1E4F (weapons) are the same routine twice:
 *
 *   print the menu
 *   read a digit; 0, or the digit the shop's own bound names, is "THANKS FOR COMING BY..."
 *   [DS:1F] = digit
 *   "AH! YES! " / "AH! YES! A " then the item NAME from the indexed pool
 *   "\rFOR YOU ONLY " then the four price digits
 *   "\rHOW 'BOUT IT? " then one key
 *   not 'Y' -> "OH, WELL."
 *   'Y'     -> charge, "SOLD!", then ONE packed-decimal increment into the owned-count
 *              array at [DS:96 + digit] / [DS:76 + digit]
 *
 * The array index is the menu digit, not digit-minus-one, and slot 0 is never sold: buying
 * CLOTH (menu 1) moved DS:97 and buying AX (menu 3) moved DS:79, both measured live
 * (captures/spice86/armour-buy and captures/spice86/g23-weapons). `counts_base` carries
 * that difference instead of hiding it in a call site.
 */
static u2_transact_result sell_from_catalogue(u2_ctx *ctx,
                                              const char *menu,
                                              const char *ah_yes,
                                              int max_digit,
                                              int price_doubles,
                                              const char *const *names,
                                              int names_n,
                                              uint8_t *counts,
                                              int counts_n,
                                              int counts_base)
{
    seam_str_out(ctx, menu);

    const int digit = read_digit(ctx);
    if (digit < 0)
        return U2_TRANSACT_REFUSED;
    if (digit == 0 || digit > max_digit) {
        seam_str_out(ctx, U2_S_SHOP_THANKS);
        return U2_TRANSACT_REFUSED;
    }

    seam_str_out(ctx, ah_yes);
    /* asm/1FC1 / asm/20E9: `clc ; adc $0x1d,%al` (armour) and `adc $0x13,%al` (weapons)
     * before the pool printer at asm/508C. Those constants are the group bases the
     * extractor already folds into U2_T_ARMOUR and U2_T_WEAPONS, so the menu digit indexes
     * the pool directly — the same thing cmd_W does for the WEAR menu. */
    seam_str_out(ctx, (digit >= 0 && digit < names_n) ? names[digit] : "");

    uint8_t price[2];
    u2_price_from_stats((uint8_t)(price_doubles ? digit * 2 : digit),
                        ctx->state.stat_int, ctx->state.stat_cha, price);
    seam_str_out(ctx, U2_S_SHOP_FOR_YOU_ONLY);
    print_price(ctx, price);

    seam_str_out(ctx, U2_S_SHOP_HOW_BOUT);
    if (!read_yes(ctx)) {
        seam_str_out(ctx, U2_S_SHOP_OH_WELL);
        return U2_TRANSACT_REFUSED;
    }
    if (!u2_spend_price(ctx, price))
        return U2_TRANSACT_REFUSED;

    seam_str_out(ctx, U2_S_SHOP_SOLD);
    const int idx = digit + counts_base;
    if (idx >= 0 && idx < counts_n)
        counts[idx] = bcd_inc1(counts[idx]);
    return U2_TRANSACT_OPEN;
}

/* asm/1D1D. Price index is the digit DOUBLED (`add %al,%al` at runtime 1DD8), which is why
 * CLOTH at 12 is fib-step 2 and not step 1. */
static u2_transact_result shop_armour(u2_ctx *ctx)
{
#ifdef U2_T_ARMOUR_N
    return sell_from_catalogue(ctx, U2_S_ARMOUR_MENU, U2_S_SHOP_AH_YES, 6, 1,
                               U2_T_ARMOUR, U2_T_ARMOUR_N,
                               ctx->state.armour_owned,
                               (int)sizeof ctx->state.armour_owned, -1);
#else
    (void)ctx;
    return U2_TRANSACT_NO_DEALER;
#endif
}

/* asm/1E4F. Price index is the digit itself, confirmed live: menu 3 (AX) entered
 * asm/20AB with AL=0x03 and left DS:27/28 = 00 20, and the charge took exactly 20
 * (captures/spice86/g23-weapons).
 *
 * The offer prefix is "AH! YES! ", the same literal the armour shoppe uses, and that call is
 * made by the frame rather than the listing. The binary holds a second offer literal
 * "AH! YES! A " at 0x1ED9, and a listing-only reading assigned it here — which rendered menu 3
 * as "AH! YES! A AXE". captures/spice86/g23-weapons/w5-axe.png shows "AH! YES! AXE", so the
 * shoppe does not use it. Who does is unresolved: it sits in the same string neighbourhood as
 * the magic shoppe's menu, and no capture has run the wizard shoppe, so it stays unassigned
 * rather than being moved somewhere plausible. */
static u2_transact_result shop_weapons(u2_ctx *ctx)
{
#ifdef U2_T_WEAPONS_N
    return sell_from_catalogue(ctx, U2_S_WEAPONS_MENU, U2_S_SHOP_AH_YES, 8, 0,
                               U2_T_WEAPONS, U2_T_WEAPONS_N,
                               ctx->state.weapons_owned,
                               (int)sizeof ctx->state.weapons_owned, 0);
#else
    (void)ctx;
    return U2_TRANSACT_NO_DEALER;
#endif
}

/* asm/1799 -> asm/17B2 -> asm/17B7 -> asm/17C5: the grocery quote. The price index is the
 * constant 3, and the pair it produces is both what is printed and what is charged —
 * measured 2026-10-29 with asm/17B7 and asm/2052 both stopped and both reading 00 20, and
 * gold falling 9999 -> 9979 (captures/spice86/g23-food-live). */
static u2_transact_result shop_grocery(u2_ctx *ctx)
{
    uint8_t price[2];
    u2_price_from_stats(3, ctx->state.stat_int, ctx->state.stat_cha, price);

    seam_str_out(ctx, U2_S_FOOD_COSTS);
    print_price(ctx, price);
    seam_str_out(ctx, U2_S_FOOD_PER100);

    if (!read_yes(ctx)) {
        seam_str_out(ctx, U2_S_FOOD_NO);
        return U2_TRANSACT_REFUSED;
    }
    seam_str_out(ctx, U2_S_FOOD_YES_A);
    seam_str_out(ctx, U2_S_FOOD_YES_B);
    if (!u2_spend_price(ctx, price))
        return U2_TRANSACT_REFUSED;

    /* asm/181A: `clc ; mov [DS:53],%al ; adc $0x1,%al ; daa ; mov %al,[DS:53]` — one food
     * unit, in packed decimal, on the low byte only. "PER 100" is the vendor's joke about
     * the price, not a quantity: the byte adds one. */
    ctx->state.food = bcd_inc1(ctx->state.food);
    seam_str_out(ctx, U2_S_THANK_YOU_AGAIN);
    return U2_TRANSACT_OPEN;
}

/* asm/1F75: the transport shoppe. The price index is the constant 4, which is what makes
 * a horse 32 gold for a maxed character and 52 for the character with charisma 0x20 —
 * the second of those is the measurement that proved [DS:4E] is charisma.
 *
 * A bought horse is not an inventory item. The transaction writes gold and DS:13 and the
 * mount happens as part of the purchase; no tile is stamped and no slot moves
 * (captures/spice86/shop-window-transport). */
static u2_transact_result shop_transport(u2_ctx *ctx)
{
    uint8_t price[2];
    u2_price_from_stats(4, ctx->state.stat_int, ctx->state.stat_cha, price);

    seam_str_out(ctx, U2_S_TRANSPORT_MENU);
    print_price(ctx, price);
    seam_str_out(ctx, U2_S_TRANSPORT_DEAL);

    if (!read_yes(ctx)) {
        seam_str_out(ctx, U2_S_TRANSPORT_BYE);
        return U2_TRANSACT_REFUSED;
    }
    if (!u2_spend_price(ctx, price))
        return U2_TRANSACT_REFUSED;

    seam_str_out(ctx, U2_S_TRANSPORT_RIDE);
    ctx->state.player_stamp = 0x22u;      /* HORSE, the constant at asm/201C */
    return U2_TRANSACT_OPEN;
}

/* ---- the selector ---------------------------------------------------------- */

u2_shop u2_commerce_shop_for(int x, int y, int site_kind)
{
    const int east = (x & 0xFF) >= 0x20;
    const int south = (y & 0xFF) >= 0x20;
    const int town = (site_kind == 2);

    if (east && !south) return town ? U2_SHOP_ARMOUR  : U2_SHOP_GROCERY;
    if (!east && !south) return town ? U2_SHOP_WEAPONS : U2_SHOP_CLUE;
    if (east && south)  return town ? U2_SHOP_TRANSPORT : U2_SHOP_CLERIC;
    return town ? U2_SHOP_PUB     : U2_SHOP_WIZARD;
}

u2_transact_result u2_commerce_transact(u2_ctx *ctx, u2_overworld *ow, int dx, int dy)
{
    u2_state *st = &ctx->state;

    /* asm/406E: nothing deals in the open world. */
    if (st->sector_second == 0 || !ow->world.map_loaded) {
        seam_str_out(ctx, U2_S_NO_RESPONSE);
        return U2_TRANSACT_NO_DEALER;
    }

    /* asm/23E6_find_creature_at_cursor: cursor = player + delta, then a scan of the
     * creature slots for one standing on that cell. The scan is `DI = 31` down through
     * `dec %di ; jne`, so slot 0 is never examined — recorded, not fixed: whether that is
     * a bug or a deliberate reserve slot is not established, and monx31 slot 0 is a
     * populated Guard. */
    const int cx = (ow->x + dx) & (U2_SECTOR_EDGE - 1);
    const int cy = (ow->y + dy) & (U2_SECTOR_EDGE - 1);
    int slot = 0;
    for (int i = U2_MON_SLOTS - 1; i >= 1; i--) {
        if (st->mon_type[i] == 0)
            continue;                       /* asm/2406: an empty slot is type 0 */
        if (st->mon_x[i] == (uint8_t)cx && st->mon_y[i] == (uint8_t)cy) {
            slot = i;
            break;
        }
    }

    if (slot != 0) {
        /* GAP — the talking branch, deliberately not implemented.
         *
         * asm/40C0 splits on the slot's role byte: bit 7 set means "this NPC has a
         * scripted line" and asm/4209 prints record (role - 0x80) out of the sector's
         * tlkx buffer at [DS:476] via asm/154E; bit 7 clear walks the creature-type chain
         * (0x60 guard, 0x64 jester, 0x68 merchant, 0xF0 fighter, 0xF4 cleric, 0xF8 wizard,
         * 0xFC thief), each printing one fixed line. The selector was observed executing
         * on 2026-10-29 with AL=0x02 for a role-0x82 Jester (captures/spice86/g23-food-live),
         * so the mechanism is no longer the open question docs/handoff-commerce-transact.md
         * recorded. What is still missing is the engine half: there is no tlkx loader
         * (core/world.c reads mapx and monx only) and the street lines have no extractor
         * entries. Both are CP6 work, and printing a plausible line from neither is exactly
         * the guess the handoff told this branch to avoid. */
        return U2_TRANSACT_NO_DEALER;
    }

    /* asm/407C: the near cell. asm/407F's `js` skips the counter test when the tile has
     * its high bit set, which is what lets a ray cross a shop's sign band — the sign
     * letters are high-bit tiles. That is the whole answer to the ray-extent question in
     * the handoff: the ray is exactly two cells, and the sign row is not an obstacle
     * because it is the transparent case. */
    const uint8_t near1 = u2_world_tile_at(&ow->world, cx, cy);
    if (!(near1 == TILE_SHOP_COUNTER || (near1 & 0x80u))) {
        seam_str_out(ctx, U2_S_NO_RESPONSE);
        return U2_TRANSACT_NO_DEALER;
    }

    /* asm/4085 steps the cursor by the same delta and asm/409F requires the merchant
     * marker there. On a match asm/40A3 tail-jumps to asm/1590. */
    const int fx = (cx + dx) & (U2_SECTOR_EDGE - 1);
    const int fy = (cy + dy) & (U2_SECTOR_EDGE - 1);
    if (u2_world_tile_at(&ow->world, fx, fy) != TILE_MERCHANT_MARK) {
        seam_str_out(ctx, U2_S_NO_RESPONSE);
        return U2_TRANSACT_NO_DEALER;
    }

    switch (u2_commerce_shop_for(ow->x, ow->y, st->sector_second)) {
    case U2_SHOP_ARMOUR:    return shop_armour(ctx);
    case U2_SHOP_WEAPONS:   return shop_weapons(ctx);
    case U2_SHOP_GROCERY:   return shop_grocery(ctx);
    case U2_SHOP_TRANSPORT: return shop_transport(ctx);
    case U2_SHOP_CLERIC:
    case U2_SHOP_WIZARD:
        /* GAP — both spell shops are reached and gated in the original (asm/1841 tests
         * [DS:47] == 1 for the cleric and asm/19AF tests [DS:47] == 2 for the wizard, so
         * the class byte the handoff listed as unnamed is DS:47, already state.h's
         * `pclass`), and both quote through asm/20AB with the menu digit as the index.
         * What is not established is where a bought spell LANDS: the wizard menu offers
         * 4-M.M., 5-BLINK, 6-KILL while those names sit at pool slots 7/8/9, so the menu
         * number and the ready number may be different axes, and asm/19D7's "FIVE "/"S FOR "
         * framing is unread. Writing spell_counts[digit] would be a guess wearing a
         * citation. */
        return U2_TRANSACT_NO_DEALER;
    case U2_SHOP_CLUE:
        /* GAP — the clue seller takes digit x 100 by byte placement (the digit goes into
         * the hundreds byte and the low byte is zeroed; there is no multiply), but the clue
         * itself is a pool this project has not mapped to a selection rule. */
        return U2_TRANSACT_NO_DEALER;
    case U2_SHOP_PUB:
        /* GAP — the pub's 1-BUY is a constant 5 gold and its 2-TIP drives the barkeep
         * chatter table (asm/155D + asm/16BD), which is read but has never been observed
         * executing. Half a pub is worse than none. */
        return U2_TRANSACT_NO_DEALER;
    case U2_SHOP_NONE:
        break;
    }
    seam_str_out(ctx, U2_S_NO_RESPONSE);
    return U2_TRANSACT_NO_DEALER;
}
