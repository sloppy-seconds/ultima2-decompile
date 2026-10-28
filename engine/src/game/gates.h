#ifndef U2_GATES_H
#define U2_GATES_H

/*
 * Time doors (moongates) — the overworld era transit.
 *
 * Everything in this header is a live observation from 2026-10-29, graded in
 * docs/moongates.md. Read that file before changing anything here: the mechanic was
 * refuted by an earlier document in this repo on a census that looked only at stores
 * of the byte, and it is easy to re-introduce that mistake.
 *
 * SCOPE, and it is deliberate. The table is decoded for all five eras, but only two
 * gate indices have an OBSERVED partner era: index 1 pairs eras 1 and 2, index 2 pairs
 * eras 2 and 3. Indices 0 and 3 are unobserved, so u2_gate_partner_era() reports them
 * as unknown and no transit is offered there. A door that opens onto a guessed era is
 * worse than no door: it reads as finished and is silently wrong, which is the failure
 * mode AGENTS.md § 3 was written against.
 *
 * Also deliberately NOT modelled: stamping 0xC0 into the resident sector. Two reasons,
 * both recorded in docs/moongates.md § 7. The substitute art for that byte is under
 * cleanroom control, and writing into the resident grid marks the sector dirty — while
 * whether the original persists a stamped gate into mapxNN on a save is untested.
 */

#include "core/ctx.h"

struct u2_overworld;

/* Reload value for the countdown. asm/2744 does `mov $0x8,%al ; mov %al,0x6f`, and the
 * live run reloaded to exactly 8 on every rotation. */
#define U2_GATE_COUNTDOWN_RELOAD 8

/* Gate indices are byte offsets 0, 2, 4, 6 into an 8-byte era row. */
#define U2_GATE_SLOTS 4

/* The era row stride in the table, in bytes: asm/2708 computes DS:1F = DS:49 * 8. */
#define U2_GATE_ERA_STRIDE 8

/*
 * The gate cell for an era and a slot index (0..3), from the table at file 0x2998 —
 * the runtime displacement %cs:0x2798 plus the 0x200 file/runtime offset, which is the
 * OPPOSITE direction to the label mapping and is what hid this table for a day.
 *
 * Returns 1 and writes x and y for a known era and slot, 0 otherwise.
 */
int u2_gate_cell(int era, int slot, int *x, int *y);

/*
 * The era a door leads to, or -1 when the pairing has never been observed.
 * Observed live, both directions for index 1 and both for index 2:
 *   era1 slot1 (47,28) <-> era2 slot1 (48,24)
 *   era2 slot2 (42,24) <-> era3 slot2 (33,23)
 * The destination is always the SAME SLOT in the partner era; only the era changes.
 */
int u2_gate_partner_era(int era, int slot);

/* The slot index currently active, derived from the DS:6E analogue. DS:6E steps by 2
 * and is masked to 3 bits, so the slot is DS:6E / 2. */
int u2_gate_slot(uint8_t gate_index);

/*
 * One world turn of the rotation: the countdown falls by one, and on reaching zero it
 * reloads to U2_GATE_COUNTDOWN_RELOAD and the index advances by 2 mod 8.
 *
 * The unit is the honest weak point. Measured live, DS:6F fell by one about every 4.2 s
 * with the player standing still, so the original's unit is TIME, not turns — the
 * recalled "every 8 steps" is wrong in the unit even though the 8 is right. The engine
 * is turn-driven, so this counts turns and not seconds; the mapping between the two is
 * inferred from the idle auto-PASS advancing turns, and is NOT proven. Anyone wiring
 * this to a real-time backend should revisit it.
 */
void u2_gate_turn(u2_ctx *ctx);

/*
 * If the player is standing on the active gate cell and that slot has an observed
 * partner, perform the transit: the era digit changes, the position becomes the same
 * slot in the partner era, and the rotation advances as it did live (countdown reloaded,
 * index +2 mod 8).
 *
 * Returns 1 when a transit happened. There is no prompt and no key: the original
 * consumed the player within one tick of the step onto the cell, which is the opposite
 * of a town or tower gate and is why this is called from the move path and not from
 * cmd_E.
 */
int u2_gate_transit(u2_ctx *ctx, struct u2_overworld *ow);

#endif
