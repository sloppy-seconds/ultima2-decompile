#ifndef U2_FLASH_H
#define U2_FLASH_H

#include "core/ctx.h"

/* The wound flash — E1, owed to ORIGINAL mode: the original has this effect and
 * the engine did not. The ring XORs into the presented frame, blocks on the
 * tone, and XORs back (XOR is its own inverse), exactly like asm/5255 ->
 * asm/4C1E called twice with asm/5EF2 between. See
 * captures/spice86/wound-flash-20261102 for what it looks like and how long it
 * lasts, and asm/5255's header for the both-directions rule: the ring marks the
 * HIT UNIT'S cell, so callers pass the victim's screen cell.
 *
 * The CGA bank interleave is deliberately NOT reproduced: the original's segment
 * table dance exists because CGA splits even/odd scanlines, and the engine's
 * frame is linear. Same observable effect, translated mechanism — the engine is
 * a reimplementation, not a byte-match. */
void u2_flash_cell(u2_ctx *ctx, int col, int row);

#endif /* U2_FLASH_H */
