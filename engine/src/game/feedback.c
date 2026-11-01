/* feedback.c — the enhanced-mode announcement seam. See feedback.h. */
#include "game/feedback.h"

#include "core/seam.h"

void u2_feedback(u2_ctx *ctx, const char *msg)
{
    /* Original mode: the seam resolves to nothing, and the effect's silence
     * stays cited at its own mutation site (AGENTS.md § 3). */
    if (ctx->fidelity != U2_FIDELITY_ENHANCED)
        return;

    seam_str_out(ctx, msg);
    seam_char_print(ctx, '\r');     /* the game's newline, same convention as every line */
}
