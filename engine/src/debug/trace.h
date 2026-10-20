#ifndef U2_TRACE_H
#define U2_TRACE_H

/*
 * Seam trace — every seam call is logged with the asm function it stands in
 * for, so a --trace log can be read side by side with asm/<SEG>_*.asm.
 * Format is one line per call:
 *   trace: seam=str_out asm=4FDF len=12 at=30,21
 */

#include "core/ctx.h"

/* out: NULL or "-" for stderr, a path for a file, "" to disable. */
int  u2_trace_open(u2_ctx *ctx, const char *out);
void u2_trace_close(u2_ctx *ctx);
void u2_trace(u2_ctx *ctx, const char *seam, const char *asmref,
              const char *fmt, ...);

#endif /* U2_TRACE_H */
