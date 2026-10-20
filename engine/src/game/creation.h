#ifndef U2_CREATION_H
#define U2_CREATION_H

/*
 * Character creation.
 * spec: asm/5400_sub_5400.asm (file 0x5600..0x5C66) — read via
 *       disasm/redecoded/5400_sub_5400.txt, our decode of the region Phase 3
 *       left as byte-proven but unreviewed db blobs.
 *
 * Shape of the flow, all of it proven by the code rather than assumed:
 *
 *   - Stats are BOUGHT, not rolled. asm/53B0 reads two typed digits and packs
 *     them as nibbles ((d1<<4)|d2); DS:29 holds a 90-point budget in the same
 *     packed form, set at file 0x56E6. asm/5C66 rejects a stat below 0x0a and
 *     rejects an overspend, and both rejections jump to 0x5698 — the whole
 *     generation restarts. That is harsh, and it is what the bytes do.
 *   - Sex, race and class each apply one BCD bonus to one stat (see the table
 *     in creation.c). STAMINA gets none from any of them.
 *   - Race and class are both converted with `sub $0x31` to 0..3; sex is stored
 *     as the typed 'M'/'F'.
 *   - After the record is written the original prints INSERT PROGRAM MASTER
 *     and restarts itself, because the player had to swap disks. The engine has
 *     no disk to swap, so it returns to the title menu instead. That is a
 *     documented deviation, not an oversight.
 *
 * Returns 1 when a character was created, 0 when the player bailed or input ran
 * out, and -1 when the save could not be written.
 */

#include "core/ctx.h"

int u2_creation_flow(u2_ctx *ctx);

#endif /* U2_CREATION_H */
