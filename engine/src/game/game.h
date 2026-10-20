#ifndef U2_GAME_H
#define U2_GAME_H

/*
 * Game driver.
 *
 * CP0 ships the loop only: init, one frame per iteration, clean shutdown.
 * The title/menu flow lands in CP1 (game/title.c), character creation in
 * CP3, the overworld in CP4, and so on — each as its own module citing the
 * asm functions it implements.
 */

#include "core/ctx.h"

int  u2_game_init(u2_ctx *ctx);
void u2_game_run(u2_ctx *ctx);
void u2_game_shutdown(u2_ctx *ctx);

#endif /* U2_GAME_H */
