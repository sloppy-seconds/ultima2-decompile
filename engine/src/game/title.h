#ifndef U2_TITLE_H
#define U2_TITLE_H

/*
 * Presentation intro, title screen, menu and the 'D' demonstration.
 * spec: asm/0133..03AC — see game/title.c for the per-line citations.
 * Returns 0 when input is finished.
 */

#include "core/ctx.h"

int u2_title_flow(u2_ctx *ctx);

#endif /* U2_TITLE_H */
