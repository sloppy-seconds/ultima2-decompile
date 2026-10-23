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
 */
int u2_monsters_spawn(u2_ctx *ctx, const u2_world *w);

/*
 * Copy the live creature arrays back into the sector buffer and mark it dirty,
 * which is the engine's side of the original's 256-byte write from DS:137 on
 * save. Only call it when the creatures actually changed; the sector store is
 * dirty-gated by design (see world.h).
 */
void u2_monsters_store(u2_ctx *ctx, u2_world *w);

/* The slot occupying sector cell (x,y), or -1 for none. A creature occupies a
 * cell the same way a mountain does: the step is rejected, not fatal. Observed
 * live 2026-10-23 — stepping onto an adjacent creature printed
 * `EAST--INVALID MOVE!` over a tile the player was standing on the value of. */
int u2_monsters_at(const u2_ctx *ctx, int x, int y);

/* The nearest occupied slot to (x,y) in manhattan distance, or -1 if the sector
 * holds nothing. Used by the attack command's "nothing there" path and by tests. */
int u2_monsters_nearest(const u2_ctx *ctx, int x, int y);

#endif /* U2_MONSTERS_H */
