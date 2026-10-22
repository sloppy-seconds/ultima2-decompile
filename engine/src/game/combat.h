#ifndef U2_GAME_COMBAT_H
#define U2_GAME_COMBAT_H
/*
 * CP5 — combat specials and theft. Contract owned by tests/combat_check.c;
 * these prototypes exist so combat.c compiles under -Wmissing-prototypes.
 *
 * Everything is keyed by the DS offset it mirrors rather than by a field name,
 * so the offsets are the contract and the storage stays the implementation's
 * choice (see the header comment of tests/combat_check.c).
 */
#include <stdint.h>
#include "core/ctx.h"

/* Run one special-effect event against `counter_ds` (0x26B legs, 0x26C arms,
 * 0x26D sleep). Returns 1 if the effect landed and the counter was set, 0 if it
 * was resisted. spec: asm/0E70, asm/0EC2, asm/0F48 */
int u2_combat_special(u2_ctx *ctx, uint16_t counter_ds);

uint8_t u2_combat_counter(const u2_ctx *ctx, uint16_t counter_ds);
void    u2_combat_set_counter(u2_ctx *ctx, uint16_t counter_ds, uint8_t value);

/* Live inventory accessors over state.items_held (DS:D6..DS:E5). */
uint8_t u2_combat_item(const u2_ctx *ctx, uint16_t item_ds);
void    u2_combat_set_item(u2_ctx *ctx, uint16_t item_ds, uint8_t count);

/* One thief steal attempt. Returns the DS offset of the slot emptied, or 0 when
 * nothing was taken. spec: asm/0FCD */
uint16_t u2_combat_thief_steal(u2_ctx *ctx);

#endif /* U2_GAME_COMBAT_H */
