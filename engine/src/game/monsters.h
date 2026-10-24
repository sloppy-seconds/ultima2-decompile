/*
 * monsters.h — the creature table: load it, look things up in it, write it back.
 *
 * CP5 W1. The six parallel arrays live in `u2_state` at their proven DS offsets
 * (mon_x 0x137, mon_y 0x157, mon_hp 0x177, mon_type 0x197, mon_kind 0x1B7,
 * mon_role 0x1D7), each pinned by a _Static_assert in state.h. This module owns
 * only the movement of those bytes between the sector buffer and the state
 * block, plus the lookups the combat and movement code needs. It deliberately
 * contains no combat rules and no monster AI.
 */
#ifndef U2_MONSTERS_H
#define U2_MONSTERS_H

#include "core/state.h"
#include "core/world.h"

#define U2_MON_SLOTS 32

/*
 * Place the sector's creatures into the state block.
 *
 * `w->mon` is the 256-byte monxNN image already read by u2_world_load(). asm/22D5
 * reads it with CX=0x100, and the six arrays occupy the first 192 bytes in the
 * order below — measured against four live sectors in docs/monster-spawn.md § 6,
 * where `type` matched 32/32 in every sector and `hp` in 31-32 of 32.
 *
 * Slots with x == 0 && y == 0 are treated as empty, matching asm/102B, which
 * tests the role byte for zero rather than the coordinates; both readings agree
 * on every capture in the corpus.
 *
 * Returns the number of occupied slots, for callers that want to say so.
 *
 * CP5 W2: this also STAMPS each creature's type byte into the sector grid, so it
 * takes the world non-const on purpose. The renderer draws the grid, not the
 * monster record — docs/art-index.md proved that on the one slot in the corpus
 * where the two disagree — and the original's spawner mutates the in-memory map
 * the same way. The same stamped cell is what passability reads, which is why a
 * creature blocks movement without any extra check.
 */
int u2_monsters_spawn(u2_ctx *ctx, u2_world *w);

/*
 * The wandering spawn: one attempt, exactly as asm/0C9C..0D05 does it.
 *
 * Called once per completed command, and only in a sector whose second decimal
 * digit is 0 (the world map), because that is the gate asm/0A38 puts on the whole
 * post-command sweep and the spawner is that sweep's tail. Returns the slot it
 * filled, or -1 for any of the four ways an attempt can come to nothing: no free
 * slot, either coordinate roll failing, or the selector's arm refusing the terrain
 * it landed on. The last of those rolls the selector byte back, which is the whole
 * reason `spawn_selector` creeps instead of marching.
 *
 * docs/monster-spawn.md § 15.4 is the evidence; every constant here is read off
 * asm/, not chosen.
 */
int u2_monsters_wander(u2_ctx *ctx, u2_world *w);

/* The arm the selector picks: the lowest set bit of `selector`, and a zero byte
 * falls through to the Balron arm. Exposed for the test, which asserts the table
 * rather than trusting the loop that walks it. */
struct u2_spawn_arm {
    uint8_t type;      /* what goes into mon_type and is stamped into the grid */
    uint8_t hp;        /* what goes into mon_hp */
    uint8_t want_tile; /* the terrain byte the cell must carry, else the arm refuses */
};
struct u2_spawn_arm u2_spawn_arm_for(uint8_t selector);

/*
 * Copy the live creature arrays back into the sector buffer and mark it dirty,
 * which is the engine's side of the original's 256-byte write from DS:137 on
 * save. Only call it when the creatures actually changed; the sector store is
 * dirty-gated by design (see world.h).
 */
void u2_monsters_store(u2_ctx *ctx, u2_world *w);

/*
 * Re-stamp the sector grid from the creature arrays, restoring the terrain under
 * any cell a creature has left. Call it whenever the arrays move (a creature
 * turn, a kill) and before anything reads the grid for passability or drawing.
 * Rebuilds from `world.map_base`, so it is idempotent, and nothing is exempt:
 * a cell carrying 0x80 is terrain like any other, which is what keeps a killed
 * creature from staying on screen as a letter (see the comment in monsters.c).
 */
void u2_monsters_restamp(u2_ctx *ctx, u2_world *w);

/* The slot occupying sector cell (x,y), or -1 for none. A creature occupies a
 * cell the same way a mountain does: the step is rejected, not fatal. Observed
 * live 2026-10-23 — stepping onto an adjacent creature printed
 * `EAST--INVALID MOVE!` over a tile the player was standing on the value of. */
int u2_monsters_at(const u2_ctx *ctx, int x, int y);

/* The nearest occupied slot to (x,y) in manhattan distance, or -1 if the sector
 * holds nothing. Used by the attack command's "nothing there" path and by tests. */
int u2_monsters_nearest(const u2_ctx *ctx, int x, int y);

#endif /* U2_MONSTERS_H */
