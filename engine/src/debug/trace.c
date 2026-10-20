/* trace.c — seam call log (see debug/trace.h). */
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include "debug/trace.h"

int u2_trace_open(u2_ctx *ctx, const char *out)
{
    if (!out || !*out || out[0] == '-') {
        ctx->trace.out = stderr;
    } else {
        FILE *f = fopen(out, "w");
        if (!f) return -1;
        ctx->trace.out = f;
    }
    ctx->trace.enabled = 1;
    return 0;
}

void u2_trace_close(u2_ctx *ctx)
{
    if (ctx->trace.out && ctx->trace.out != stderr)
        fclose(ctx->trace.out);
    ctx->trace.out = NULL;
    ctx->trace.enabled = 0;
}

void u2_trace(u2_ctx *ctx, const char *seam, const char *asmref,
              const char *fmt, ...)
{
    if (!ctx->trace.enabled || !ctx->trace.out)
        return;
    fprintf(ctx->trace.out, "trace: seam=%s asm=%s", seam, asmref);
    va_list ap;
    va_start(ap, fmt);
    if (fmt && *fmt) {
        fputc(' ', ctx->trace.out);
        vfprintf(ctx->trace.out, fmt, ap);
    }
    va_end(ap);
    fputc('\n', ctx->trace.out);
}
