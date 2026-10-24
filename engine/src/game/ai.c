/*
 * ai.c — the creature turn, implemented against asm/0A6D..0AB5 and
 * asm/2122..2260. Written up in docs/monster-spawn.md § 13.
 *
 * One routine, two sweeps: asm/0A38 sends the world map (sector digit 0) and
 * digits 6..9 here ungated, and the town sectors (digits 1..3) to the role-gated
 * chain at asm/1013/1015; digits 4 and 5 branch into the dungeon flow, which is
 * parked. The `gated_sweep` test below is that dispatch; mon_role means nothing
 * on the world map.
 *
 * The shape that surprises people, and that every line below is trying to be
 * faithful to: a creature never attacks the player for being next to it. It
 * rolls for a special from within two cells, it walks toward the player if the
 * tile it is aiming at is enterable for its species, it runs away below 15 HP
 * while it regenerates, and if the cell it would step into is the player's, it
 * does not step — unless it is a thief, in which case it steals.
 *
 * Damage to the player is therefore limited to what the specials do. There is no
 * melee damage site in the corpus: the types asm/0AD3's header calls plain melee
 * attackers (0x30, 0xF4, 0xFC) have no located subtract against DS:51/DS:52, and
 * the measured HP drop of 9999 -> 9796 in a live town fight is still unexplained.
 * That is stated here rather than papered over with an invented bite.
 */
#include <stdint.h>
#include <string.h>

#include "game/ai.h"
#include "game/combat.h"
#include "game/monsters.h"   /* U2_MON_SLOTS */
#include "core/rng.h"
#include "core/seam.h"
#include "core/state.h"
#include "core/world.h"
#include "gen_content.h"

/* asm/0AB6 and asm/0AC0: `cmp $0x3,%al; jae <skip>`, so strictly inside 3. */
#define U2_AI_SPECIAL_RANGE 3
/* asm/0ACF: `cmp $0x20,%al; jae <skip>` — 32 of 256, once per creature turn. */
#define U2_AI_SPECIAL_ROLL  0x20
/* asm/0B07: `cmp $0xf,%al; jae <keep pursuing>` — so 14 and below runs. */
#define U2_AI_RETREAT_HP    0x0F
/* asm/2126: `cmp $0x10,%al; jae <no regen>` — so 15 and below regens. Note the
 * one-value gap with the retreat threshold: at exactly 15 a creature regenerates
 * but still pursues, and at 14 it does both. That is what the two immediates
 * say, and it is the kind of off-by-one a reimplementation "fixes" by accident. */
#define U2_AI_REGEN_HP      0x10
/* asm/212e and asm/216e: `and $0x3f,%al` — the sector grid is a 64-wide torus. */
#define U2_AI_GRID_MASK     0x3f
#define U2_AI_GRID_SIZE     (U2_AI_GRID_MASK + 1)

/* The four special types, from the dispatch at asm/0AD3 (proven by bytes and by
 * execution in the castle-03-live harvest; see asm/0AD3's header). */
#define U2_AI_TYPE_LEGS      0x34   /* asm/0E70, resisted by BOOTS  [DS:D9] */
#define U2_AI_TYPE_ARMS      0x38   /* asm/0EC2, resisted by CLOAK  [DS:DA] */
#define U2_AI_TYPE_SLEEP     0x3C   /* asm/0F48, resisted by IDOL   [DS:E4] */
#define U2_AI_TYPE_MISSILE   0xF8   /* asm/0F12, no save exists            */
#define U2_AI_TYPE_THIEF     0xFC   /* asm/0FCD, on the contact path only  */

/* asm/50EF: values below 0x80 pass through, so this is |x| of a signed byte. */
static int abs8(uint8_t v)
{
    const int8_t s = (int8_t)v;
    return s < 0 ? -s : s;
}

/*
 * asm/4F11..4F35: the unit step toward the player along one axis.
 *
 * The bytes are `al := player - creature; add al,al; add al,al; call asm/50D8`,
 * and asm/50D8 is `zero -> 0`, else the sign bit decides between +1 (asm/50E1)
 * and -1 (asm/50DE). The doubling is not padding: multiplying by four moves bit 6
 * of the difference into the sign bit, so a difference of 32..63 comes out
 * negative. On a 64-wide torus that is exactly "the shorter way round is
 * backwards", which is why the creature never walks the long way across the map.
 *
 * So the step is one cell, not the distance. The raw difference is still what
 * asm/0AAA measures for the proximity gate — that one wants the real distance —
 * which is why the loop computes the vector twice, from two different routines.
 */
static int step_toward(int player, int creature)
{
    const int m = ((player - creature) % U2_AI_GRID_SIZE + U2_AI_GRID_SIZE) % U2_AI_GRID_SIZE;
    if (m == 0) return 0;
    return (m < U2_AI_GRID_SIZE / 2) ? 1 : -1;
}

/* The general species ladder, asm/21bd..21d5. */
static int tile_enterable_by_default(uint8_t tile)
{
    if (tile == 0x10 || tile == 0x04 || tile == 0x00) return 0;  /* three explicit refusals */
    if (tile < 0x14) return 1;                                   /* `cmp $0x14; jb accept` */
    if (tile == 0x70) return 1;
    return 0;
}

/*
 * asm/2199 (the DS:26A freeze and the DS:1F store) plus asm/21a6..21f6 (the
 * species test). `nx`/`ny` are the candidate cell; the tile is read the same way
 * the original's probe reads it, which means a cell stamped with another
 * creature's type byte is that creature's tile — creatures block each other
 * without a separate occupancy rule.
 */
static int creature_may_enter(const u2_ctx *ctx, const u2_world *w,
                              uint8_t type, int nx, int ny)
{
    /* asm/2199: `mov [DS:26A],al; cmp $0; je <species test>` — while the fourth
     * counter is non-zero nothing moves at all. In the engine this is inert
     * until CP5 W7 finds the caller of asm/0C33..0C53, because nothing ticks
     * the counter yet; the rule is here so it starts working when that lands. */
    if (ctx->state.counter_26A != 0) return 0;

    const uint8_t tile = u2_world_tile_at(w, nx, ny);

    if (type == 0x2c || type == 0x48) {
        /* asm/21aa/21ae then asm/21d8: sea monster and frigate accept water and
         * nothing else. */
        if (tile != 0x00) return 0;
    } else if (type < 0x78) {
        /* asm/21b6: tile 0x5c is accepted ahead of the ladder; everything else
         * falls into it. */
        if (tile != 0x5c && !tile_enterable_by_default(tile)) return 0;
    } else {
        if (!tile_enterable_by_default(tile)) return 0;
    }

    /* asm/21e2: in a sector whose second digit is non-zero, a candidate on
     * column 0 or row 0 is refused. */
    if (ctx->state.sector_second != 0 && (nx == 0 || ny == 0)) return 0;
    return 1;
}

/* asm/0AAA: proximity, then the roll. The roll is only taken inside the ring, so
 * a creature far away consumes no random byte — that is what makes this testable
 * against the rng counter rather than against a distribution. */
static int special_gate(u2_ctx *ctx, uint8_t type, int dx, int dy, u2_ai_report *rep)
{
    if (abs8((uint8_t)dx) >= U2_AI_SPECIAL_RANGE ||
        abs8((uint8_t)dy) >= U2_AI_SPECIAL_RANGE)
        return 0;
    rep->gates++;
    if (u2_rand_byte(ctx) >= U2_AI_SPECIAL_ROLL)
        return 0;

    switch (type) {
    case U2_AI_TYPE_LEGS:
        /* asm/0E70 prints the announcement first and the rescue second, so both
         * lines appear when boots save you. Reproduced exactly; "improving" this
         * into a single message is the obvious mistake here. */
        seam_str_out(ctx, U2_S_LEGS_PARALYZED); seam_char_print(ctx, '\r');
        if (u2_combat_special(ctx, 0x26B)) rep->landed++;
        else { seam_str_out(ctx, U2_S_SAVED_BY_BOOTS); seam_char_print(ctx, '\r'); }
        return 1;
    case U2_AI_TYPE_ARMS:
        seam_str_out(ctx, U2_S_ARMS_PARALYZED); seam_char_print(ctx, '\r');
        if (u2_combat_special(ctx, 0x26C)) rep->landed++;
        else { seam_str_out(ctx, U2_S_SAVED_BY_CLOAK); seam_char_print(ctx, '\r'); }
        return 1;
    case U2_AI_TYPE_SLEEP:
        seam_str_out(ctx, U2_S_SLEEP_SPELL); seam_char_print(ctx, '\r');
        if (u2_combat_special(ctx, 0x26D)) rep->landed++;
        else { seam_str_out(ctx, U2_S_SAVED_BY_IDOL); seam_char_print(ctx, '\r'); }
        return 1;
    case U2_AI_TYPE_MISSILE:
        /* asm/0F12: the string is the first thing in the routine and there is no
         * save path at all. The damage magnitude is still unmodelled — see
         * C4 in docs/phase4-state.md — so this prints and changes no HP, and the
         * comment next to the call is the only place that claim lives. */
        seam_str_out(ctx, U2_S_MAGIC_MISSILE); seam_char_print(ctx, '\r');
        if (u2_combat_magic_missile(ctx)) rep->landed++;
        return 1;
    default:
        return 0;
    }
}

/*
 * asm/2122..2260. Three candidates in the original's order: the diagonal, then
 * (only if dy is non-zero) the y-only step, then the x-only step. The first
 * candidate that passes the tile test wins; if that cell is the player's, the
 * creature does not move at all rather than trying another way round — the
 * original branches out of the move routine entirely (asm/2213 -> asm/218b).
 */
static int creature_step(u2_ctx *ctx, u2_world *w, int slot, int dx, int dy,
                         int px, int py)
{
    u2_state *st = &ctx->state;

    /* asm/2122/212a: below 16 HP, +1 per turn. */
    if (st->mon_hp[slot] < U2_AI_REGEN_HP)
        st->mon_hp[slot]++;

    int cands[3][2];
    int n = 0;
    cands[n][0] = dx; cands[n++][1] = dy;
    if (dy != 0) { cands[n][0] = 0;  cands[n++][1] = dy; }   /* asm/2155's guard */
    cands[n][0] = dx; cands[n++][1] = 0;

    for (int i = 0; i < n; i++) {
        const int nx = (st->mon_x[slot] + cands[i][0]) & U2_AI_GRID_MASK;
        const int ny = (st->mon_y[slot] + cands[i][1]) & U2_AI_GRID_MASK;
        if (!creature_may_enter(ctx, w, st->mon_type[slot], nx, ny))
            continue;
        if (nx == px && ny == py)
            return 0;                    /* asm/2201: accepted, but it is the player */
        st->mon_x[slot] = (uint8_t)nx;
        st->mon_y[slot] = (uint8_t)ny;
        return 1;
    }
    return 0;
}

u2_ai_report u2_ai_creature_turn(u2_ctx *ctx, u2_world *w, int px, int py)
{
    u2_ai_report rep;
    memset(&rep, 0, sizeof rep);
    u2_state *st = &ctx->state;

    /* asm/0A6D: `mov $0x1f,%bl` — the cursor starts at slot 31 and counts down
     * (asm/0AA1 `dec %di; jne`). Order matters for reproducibility, so the
     * engine walks the same direction rather than the intuitive one. */
    for (int slot = U2_MON_SLOTS - 1; slot >= 0; slot--) {
        /* asm/0A74: an empty slot is mon_type == 0. Not 0x40 — see the
         * correction in asm/0AD3's header and docs/monster-spawn.md § 13. */
        if (st->mon_type[slot] == 0) continue;
        rep.examined++;

        /* Two sweeps hang off the post-command tail, and asm/0A38 picks between
         * them on the sector's second decimal digit: digit 0 — the world map —
         * jumps here (asm/0A6D), digits 1..3 branch to the role-gated sweep at
         * asm/1013/1015, digits 4 and 5 branch into runtime 135E/135F inside
         * asm/1151's span (the dungeon flow, parked per AGENTS.md § 3), and
         * digits 6..9 fall through to asm/0A6D as well. So mon_role gates the
         * TOWN sweep and not the world map: on the world map every live slot gets
         * the full pass, which is why a wandering spawn walks at you even though
         * monx20 ships role 0 in all thirty-two slots. The engine applied the
         * town gate here, so the world map was frozen — owner-reported 2026-10-28,
         * and the dispatch is in the bytes of asm/0A38 (docs/monster-spawn.md § 14
         * documented the gate without the dispatch that selects it).
         *
         * Inside the gated sweep, asm/102B and asm/1033:
         *
         *   role == 0    -> asm/1040, the Minax proximity check, and thence next
         *                   slot for everything that is not Minax. Inert, in
         *                   practice: monx00 ships 0 in every slot, and eight of
         *                   the thirty-two in a town do nothing until violence
         *                   wakes them (see u2_ai_alarm). The Minax arm is still
         *                   not modelled.
         *   role & 0x80  -> next slot. asm/1033 is `js <next>`, so bit 7 excludes
         *                   0x81..0x85, which are the scripted townsfolk that
         *                   asm/3C2E_cmd_O enumerates one by one.
         *   role == 1    -> asm/1082 -> asm/0AA7: the full pass. Raw pursuit
         *                   vector, the proximity gate and the special, the unit
         *                   step, the retreat test, then the move.
         *   role == 2    -> asm/1039 -> asm/107B: recompute the unit pursuit vector
         *                   and jump straight to the move routine. No gate, no
         *                   special, and no retreat test either — an alerted
         *                   creature walks in on you and neither casts nor runs.
         *                   This is the state the alarm produces, so the guard that
         *                   chases you is not the guard that paralyses you.
         *   role >= 3    -> asm/1086, a wander driven by the per-slot pair at
         *                   DS:1F7/DS:217 that this project has not decoded yet.
         *                   The engine does NOTHING for these, which under-moves
         *                   rather than invents a gait: monx21 has 24 of 32 slots at
         *                   role 3, and guessing their step would be exactly the
         *                   "plausible reading promoted past its evidence" failure
         *                   AGENTS.md § 5 names. Decoding asm/1086 is the open item.
         */
        const int gated_sweep = (st->sector_second >= 1 && st->sector_second <= 3);
        int casts = 1, retreat = 1, moves = 1;   /* the ungated world-map pass */
        if (gated_sweep) {
            const uint8_t role = st->mon_role[slot];
            if (role == 0 || (role & 0x80)) continue;
            if (role > 3) continue;
            casts   = (role == 1);   /* asm/0AAA is only on the role-1 path */
            retreat = (role == 1);   /* asm/0B07 likewise                   */
            moves   = (role == 1 || role == 2);
        }

        /* asm/4F36: the raw pursuit vector, player minus creature, signed byte.
         * This is what the proximity gate measures, and it is a distance, not a
         * step. asm/4F11 recomputes the same pair as a unit step below. */
        int dx = (int)(int8_t)(uint8_t)(px - st->mon_x[slot]);
        int dy = (int)(int8_t)(uint8_t)(py - st->mon_y[slot]);

        /* asm/0A7C/0A83 skip whole slots while the player is in the vehicle the
         * bytes call DS:13 == 0x22. The engine has no vehicles yet, so the
         * filter cannot fire; it is named here rather than silently omitted. */

        /* asm/0AAA..0AD3: the special, before any movement. Only the role-1 pass
         * reaches the gate (asm/102B sends role 2 to asm/107B, which is the move
         * routine with no gate in front of it). */
        if (casts && special_gate(ctx, st->mon_type[slot], dx, dy, &rep))
            seam_str_out(ctx, U2_S_CMD_PROMPT);

        /* asm/0AFC: `call L_005111` overwrites DS:19/1A with the unit step, so
         * everything from here on moves one cell, not the distance. asm/107B makes
         * the same call on the role-2 path. */
        int sx = step_toward(px, st->mon_x[slot]);
        int sy = step_toward(py, st->mon_y[slot]);

        /* asm/0B07/0B0F: at 14 HP or less the vector is negated in place, which is
         * the retreat. The wiki claim that started this search is now bytes — and
         * it only holds on the role-1 path: an alerted (role 2) creature walks in
         * on you at 1 HP and does not run. */
        if (retreat && st->mon_hp[slot] < U2_AI_RETREAT_HP) {
            sx = -sx; sy = -sy;
            rep.retreated++;
        }

        /* asm/0B25/0B39: the candidate cell is tested against the player before
         * the move routine is entered at all, and landing on the player routes to
         * the thief test at asm/0B4D instead of to a step. */
        const int cx = (st->mon_x[slot] + sx) & U2_AI_GRID_MASK;
        const int cy = (st->mon_y[slot] + sy) & U2_AI_GRID_MASK;
        if (cx == px && cy == py) {
            /* asm/0B4D: the creature does not step onto the player. It stays where
             * it was and takes a swing, and this is the ONLY way a plain melee
             * creature can hurt the player — there is no separate attack action in
             * the original. DS:20 counts the contacts and asm/0BD1 applies the
             * pooled damage once, so a town full of converging guards hits harder
             * than one guard. */
            rep.contacts++;

            if (st->mon_type[slot] == U2_AI_TYPE_THIEF &&
                u2_combat_thief_steal(ctx) != 0) {
                rep.stolen++;
                seam_str_out(ctx, U2_S_THIEF_STOLE);
                seam_char_print(ctx, '\r');
                seam_str_out(ctx, U2_S_CMD_PROMPT);
            }

            /* asm/0B62/0B71: two tests before a blow counts. The roll must be
             * non-negative and its low three bits must reach the worn-armour index
             * at DS:62 — so armour is an 1-in-8-per-point dodge: SKIN lets every
             * blow through and the best armour stops seven of eight. */
            const uint8_t roll = u2_rand_byte(ctx);
            if (roll < 0x80 && (roll & 7) >= st->worn_armour) {
                /* asm/0B79: the pool grows by a share of the creature's OWN hit
                 * points. Counter-intuitive and straight from the bytes: a wounded
                 * creature hits weaker, a full-health one hits harder. */
                rep.damage_pool += (st->mon_hp[slot] >> 2) + 1;
            }
            continue;
        }

        if (moves && creature_step(ctx, w, slot, sx, sy, px, py))
            rep.moved++;
    }

    return rep;
}

void u2_ai_alarm(u2_ctx *ctx)
{
    /* asm/113A: on the world map there is nobody to alert. */
    if (ctx->state.sector_second == 0)
        return;

    /* asm/1142/114A: slots 7 down to 0, role 1. Fixed slots, not "the guards" as a
     * class — the sector file decides which slots are the guard slots by what it
     * ships there, and monxNN puts 0x00 in eight of them in a town precisely so
     * this write has something to switch on. */
    for (int slot = 7; slot >= 0; slot--)
        ctx->state.mon_role[slot] = 1;
}
