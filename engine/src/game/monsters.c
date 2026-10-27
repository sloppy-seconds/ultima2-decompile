/*
 * monsters.c — CP5 W1: the monx block <-> the creature arrays in the state block.
 *
 * No combat rules and no AI live here on purpose. Every byte movement in this file
 * is a copy between two buffers whose layout is measured, not guessed:
 *
 *   monxNN offset -> DS field   (docs/monster-spawn.md § 6, matched live on four sectors)
 *        0..31     -> mon_x   (DS:137)
 *       32..63     -> mon_y   (DS:157)
 *       64..95     -> mon_hp  (DS:177)
 *       96..127    -> mon_type(DS:197)
 *      128..159    -> mon_kind(DS:1B7)
 *      160..191    -> mon_role(DS:1D7)
 *
 * asm/22D5 reads 256 bytes (CX=0x100) for six 32-byte arrays totalling 192, so
 * the tail of the buffer is unread by anything found so far and is left alone on
 * a store round trip.
 */
#include "game/monsters.h"

#include <string.h>

#include "core/ctx.h"
#include "core/rng.h"          /* u2_rand_byte: the spawner's two coordinate rolls */

/* monx offset of each array. Kept as one table so a future re-measurement is a
 * single edit, and so the store path cannot drift from the load path. */
#define MON_OFF_X    0
#define MON_OFF_Y    32
#define MON_OFF_HP   64
#define MON_OFF_TYPE 96
#define MON_OFF_KIND 128
#define MON_OFF_ROLE 160

int u2_monsters_spawn(u2_ctx *ctx, u2_world *w)
{
    if (ctx == NULL || w == NULL || !w->mon_loaded)
        return 0;

    u2_state *s = &ctx->state;
    memcpy(s->mon_x,    w->mon + MON_OFF_X,    U2_MON_SLOTS);
    memcpy(s->mon_y,    w->mon + MON_OFF_Y,    U2_MON_SLOTS);
    memcpy(s->mon_hp,   w->mon + MON_OFF_HP,   U2_MON_SLOTS);
    memcpy(s->mon_type, w->mon + MON_OFF_TYPE, U2_MON_SLOTS);
    memcpy(s->mon_kind, w->mon + MON_OFF_KIND, U2_MON_SLOTS);
    memcpy(s->mon_role, w->mon + MON_OFF_ROLE, U2_MON_SLOTS);

    /* The role-3 wander vectors are deliberately ZERO-FILLED, not copied from the sector file.
     *
     * monx does have bytes at the offsets these map to (monx[192] and monx[224] under the established
     * monx[0] -> DS:137 mapping), and in every shipped file they are all zero. They are not data that
     * happens to be empty: the original WRITES them at runtime. asm/10AA and asm/10BF store
     * sign_of_al(rand_byte) into them, and asm/1086 reads them back into the step pair. A fresh
     * sector therefore starts with a zero vector and the creature does not move until the first re-roll
     * on the 25% branch — which is faithful behaviour, not a gap.
     *
     * Zero-filling rather than memcpy-ing is the visible signal at the call site that this is runtime
     * state with a data-shaped address. See asm/1086_creature_wander_step.asm for the whole chain.
     */
    memset(s->mon_wander_x, 0, U2_MON_SLOTS);
    memset(s->mon_wander_y, 0, U2_MON_SLOTS);

    int occupied = 0;
    for (int i = 0; i < U2_MON_SLOTS; i++) {
        if (s->mon_x[i] || s->mon_y[i])
            occupied++;
    }

    /* CP5 W2: the stamp.
     *
     * The renderer does not read the monster record. docs/art-index.md settled
     * that on the only slot in the corpus where the two fields disagree — grid
     * 0x38 versus type 0x34 — where the drawn pixels matched 0x38>>2 at 256/256
     * and 0x34>>2 at 171/256. So the original stamps the type byte into the
     * in-memory sector map at spawn and the view draws the map, which is what
     * this loop reproduces.
     *
     * Stamping the one grid rather than keeping a second is deliberate: the same
     * cell is what passability reads, so a creature blocks movement the way the
     * original does it — by not being a walkable tile — with no extra check
     * anywhere. One grid, one truth.
     *
     * The empty-slot test is the module's own (x||y), not hp, so a slot the
     * spawner left alone is never stamped. On a kill the record is cleared and
     * the terrain underneath shows again — see u2_monsters_restamp, and note
     * that the 0x80 at asm/2E3D file 0x30F4 is not this grid.
     *
     * INFERRED, and it is the line to suspect first if a creature ever draws in
     * the wrong cell: that the stamp lands at y*64+x with the sector's own stride
     * is assumed from the grid geometry, not read off the stamping site.
     *
     * The layout this stamps was re-confirmed live on 2026-10-23 against sector 31
     * with G23MAX loaded: mon_hp, mon_type and mon_role matched monx31 at 32/32
     * each, mon_kind 30/32, and x/y under-matched only because creatures walk.
     * That is a fourth independent capture agreeing with docs/monster-spawn.md § 2,
     * which is also the capture that disproved a false alarm raised against this
     * same file the same day — see § 10 there before doubting these offsets. */

    for (int i = 0; i < U2_MON_SLOTS; i++) {
        /* type 0 is empty, which is asm/0A74's own test. The x||y pair above is
         * kept because a monx file can carry coordinates on a slot the original
         * never gave a type, but a type-less slot must not stamp 0 over terrain —
         * the wandering spawner produces exactly such slots whenever its arm
         * refuses, because asm/0CC0 writes the coordinates before the arm runs. */
        if (!(s->mon_x[i] || s->mon_y[i]) || s->mon_type[i] == 0)
            continue;
        const int cell = (int)s->mon_y[i] * U2_SECTOR_EDGE + (int)s->mon_x[i];
        if (cell < 0 || cell >= U2_SECTOR_TILES)
            continue;
        w->map[cell] = s->mon_type[i];
    }
    return occupied;
}

/*
 * Re-stamp the grid after the creature arrays changed — a walk, a kill, a spawn.
 *
 * The grid is rebuilt from `w->map_base` rather than patched cell by cell, so a
 * creature leaving a cell puts the terrain back instead of leaving its own type
 * byte behind forever. asm/2233 commits a move by writing the new coordinates
 * and the kind byte, and the cell bookkeeping around it (the `and 0xf0` then
 * `or [di+0x197]` pair at asm/1151's tail) is only partly read, so the exact
 * nibble arithmetic of the original's stamp is NOT reproduced here — what is
 * reproduced is the observable property: one creature per cell, and the cell
 * under it survives its departure.
 *
 * One cell used to be exempt, and that was wrong (2026-10-28). This loop left any
 * cell carrying 0x80 alone, because asm/2E3D file 0x30F4 does write
 * `movb $0x80,(%bx,%si)` on a kill and the address pair was assumed to name the
 * map cell. Whatever it names, it is not the cell the renderer reads: 0x80 is a
 * staging-space flag, and in map space the `>>2` transform turns it into art 32,
 * the first letter glyph — so the engine drew a letter A on the grass where the
 * creature had died, permanently, because nothing would clear it.
 * captures/spice86/cp5-fight/screen3.png -> screen4.png (sector 31, a town,
 * `ATTACK--EAST--HIT!!!` then `KILLED--GOLD+1--EXP.+02`) shows the original
 * leaving plain floor. Terrain comes back here, unconditionally.
 */
void u2_monsters_restamp(u2_ctx *ctx, u2_world *w)
{
    if (ctx == NULL || w == NULL || !w->map_loaded)
        return;

    for (int i = 0; i < U2_SECTOR_TILES; i++)
        w->map[i] = w->map_base[i];

    const u2_state *s = &ctx->state;
    for (int i = 0; i < U2_MON_SLOTS; i++) {
        if (s->mon_type[i] == 0)
            continue;                       /* asm/0A74: an empty slot is type 0 */
        /* hp 0 is absent, whatever the type byte says. This is the same occupancy rule
         * u2_monsters_at() uses, and the two must agree or the grid and the game disagree
         * about what is there: the cell renders a creature the attack scan walks past and
         * the player walks through. That state is reachable in play, not theoretical — in
         * fidelity mode asm/2E3D does not kill on dmg == hp, so a creature reduced to
         * exactly 0 keeps its type byte. Observed by the owner as a creature leaving "a copy
         * of him behind". Gated by monsters_check section 5. */
        if (s->mon_hp[i] == 0)
            continue;
        const int cell = (int)s->mon_y[i] * U2_SECTOR_EDGE + (int)s->mon_x[i];
        if (cell < 0 || cell >= U2_SECTOR_TILES)
            continue;
        w->map[cell] = s->mon_type[i];
    }
}

void u2_monsters_store(u2_ctx *ctx, u2_world *w)
{
    if (ctx == NULL || w == NULL || !w->mon_loaded)
        return;

    const u2_state *s = &ctx->state;
    memcpy(w->mon + MON_OFF_X,    s->mon_x,    U2_MON_SLOTS);
    memcpy(w->mon + MON_OFF_Y,    s->mon_y,    U2_MON_SLOTS);
    memcpy(w->mon + MON_OFF_HP,   s->mon_hp,   U2_MON_SLOTS);
    memcpy(w->mon + MON_OFF_TYPE, s->mon_type, U2_MON_SLOTS);
    memcpy(w->mon + MON_OFF_KIND, s->mon_kind, U2_MON_SLOTS);
    memcpy(w->mon + MON_OFF_ROLE, s->mon_role, U2_MON_SLOTS);
    w->mon_dirty = 1;
}

int u2_monsters_at(const u2_ctx *ctx, int x, int y)
{
    if (ctx == NULL)
        return -1;
    for (int i = 0; i < U2_MON_SLOTS; i++) {
        /* hp != 0 is load-bearing, not tidiness. Observed live in
         * captures/spice86/cp5-fight/: two creatures shared one cell, the front one
         * was killed, and the very next attack hit the SECOND one at the same
         * coordinates rather than the corpse. So the original's scan walks past
         * slots with no hit points, and without this test a dead slot stays both
         * attackable and, once W4 landed, a permanent wall.
         *
         * The x||y test is the module's occupancy convention (docs/monster-spawn.md
         * § 2's own note: a slot at (0,0) is unused), kept alongside hp rather than
         * replaced by it because a slot can be occupied and wounded but never
         * occupied with hp unset.
         *
         * Ordering note for anyone re-deriving this: the scan returns the LOWEST
         * slot index at the cell, which is what the live capture showed only if the
         * front creature happened to be the lower slot. Whether the original scans
         * in slot order or in some other order is not established; slot order is the
         * assumption, and it is the one to revisit if a fight ever picks the wrong
         * target among stacked creatures. */
        if (ctx->state.mon_hp[i] == 0)
            continue;
        if ((ctx->state.mon_x[i] || ctx->state.mon_y[i]) &&
            ctx->state.mon_x[i] == (uint8_t)x &&
            ctx->state.mon_y[i] == (uint8_t)y)
            return i;
    }
    return -1;
}

int u2_monsters_nearest(const u2_ctx *ctx, int x, int y)
{
    if (ctx == NULL)
        return -1;

    int best = -1, best_d = 1 << 30;
    for (int i = 0; i < U2_MON_SLOTS; i++) {
        if (!(ctx->state.mon_x[i] || ctx->state.mon_y[i]))
            continue;
        int dx = (int)ctx->state.mon_x[i] - x;
        int dy = (int)ctx->state.mon_y[i] - y;
        int d  = (dx < 0 ? -dx : dx) + (dy < 0 ? -dy : dy);
        if (d < best_d) {
            best_d = d;
            best = i;
        }
    }
    return best;
}

/* ------------------------------------------------------------- the wandering spawn */

/*
 * The nine spawn arms, indexed by the lowest set bit of the selector byte, with a
 * zero byte falling through to the last row. Every column is read off asm/, not
 * chosen: the type and HP immediates come from asm/0D4F (Orc), asm/0D6F (Thief at
 * 0D6F, Daemon at 0D8F), asm/0DAF (sea serpent) and asm/0DC4 (Fighter, Frigate,
 * Devil, Wizard, Balron and the shared reject tail).
 *
 * want_tile is the immediate each arm's `cmp` carries against the slot's terrain
 * byte. The two arms wanting 0x00 are the two sea creatures and the rest want
 * 0x08, which is the strongest single piece of evidence that the compared byte is
 * the terrain of the rolled cell rather than a monster kind — see
 * docs/monster-spawn.md § 15.4, where all nine rows were pinned by forcing the
 * selector and watching which arm ran.
 */
static const struct u2_spawn_arm kSpawnArms[9] = {
    { 0x30, 0x10, 0x08 },   /* bit0  Orc */
    { 0xFC, 0x20, 0x08 },   /* bit1  Thief */
    { 0x34, 0x40, 0x08 },   /* bit2  Daemon */
    { 0x2C, 0x40, 0x00 },   /* bit3  sea serpent — water */
    { 0xF0, 0x80, 0x08 },   /* bit4  Fighter */
    { 0x48, 0xA0, 0x00 },   /* bit5  Frigate — water */
    { 0x38, 0xC0, 0x08 },   /* bit6  Devil */
    { 0xF8, 0xE0, 0x08 },   /* bit7  Wizard */
    { 0x3C, 0xFF, 0x08 },   /* no bits set: Balron */
};

struct u2_spawn_arm u2_spawn_arm_for(uint8_t selector)
{
    for (int bit = 0; bit < 8; bit++)
        if (selector & (1u << bit))
            return kSpawnArms[bit];
    return kSpawnArms[8];
}

int u2_monsters_wander(u2_ctx *ctx, u2_world *w)
{
    if (ctx == NULL || w == NULL || !w->map_loaded)
        return -1;

    u2_state *s = &ctx->state;

    /* asm/0C9C..0CB0. The scan walks 31 down to 1 and takes the first slot whose
     * mon_type is zero — the same emptiness test asm/0A74 uses for the sweep, and
     * slot 0 is unreachable because `dec di ; jne` stops at 1. Taking the highest
     * free slot is what the original does and is observable: a live run filled
     * 1f, 1e, 1d ... in that order.
     *
     * The bytes are `mov ah,[di+0x197] ; or ah,al ; je found`, and that AL is
     * residue from the sweep rather than something this path sets. What it can
     * only ever mean is a second, unexplained condition on the same test; the
     * observed behaviour is the mon_type test alone, so that is what is
     * implemented, and the residue is recorded rather than smoothed over. */
    int slot = -1;
    for (int i = U2_MON_SLOTS - 1; i >= 1; i--) {
        if (s->mon_type[i] == 0) { slot = i; break; }
    }
    if (slot < 0)
        return -1;

    /* asm/0CB6..0CD4: two rolls. The first is the x and must come in under 0x3F;
     * the second is rejected on its sign bit and then masked to 0x3F for y, which
     * is where the overworld's wrap is enforced on the way in. */
    const uint8_t rx = u2_rand_byte(ctx);
    if (rx >= 0x3F)
        return -1;
    const uint8_t ry_raw = u2_rand_byte(ctx);
    if (ry_raw & 0x80u)
        return -1;
    const uint8_t ry = (uint8_t)(ry_raw & 0x3F);

    /* asm/0CC0 and asm/0CDC store the coordinates BEFORE the arm is chosen, so a
     * refused attempt still leaves its coordinates behind. That is not a leak to
     * paper over: live reads found exactly this residue, a slot with x, y and the
     * terrain byte and no type at all. */
    s->mon_x[slot] = rx;
    s->mon_y[slot] = ry;

    const int cell = (int)ry * U2_SECTOR_EDGE + (int)rx;
    if (cell < 0 || cell >= U2_SECTOR_TILES)
        return -1;

    /* asm/0CEB calls asm/50B3_map_tile_ptr, which reads the LIVE grid — so a cell
     * another creature is standing on reads as that creature's type byte, and the
     * terrain test then refuses. asm/0CEE files that byte into the slot. */
    const uint8_t tile = w->map[cell];
    s->mon_kind[slot] = tile;

    s->spawn_selector++;
    const struct u2_spawn_arm arm = u2_spawn_arm_for(s->spawn_selector);
    if (tile != arm.want_tile) {
        /* asm/0DC4's head: `decb 0x60` and out. The selector is rolled back, which
         * is the mechanism behind the measured "it creeps, it does not march". */
        s->spawn_selector--;
        return -1;
    }

    s->mon_type[slot] = arm.type;
    s->mon_hp[slot]   = arm.hp;
    w->map[cell]      = arm.type;   /* the stamp: asm/0D4F's `mov %al,(%bx,%si)` */
    return slot;
}
