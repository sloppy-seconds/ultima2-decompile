#ifndef U2_FEEDBACK_H
#define U2_FEEDBACK_H

#include "core/ctx.h"

/* The enhanced-mode announcement seam — the single audit point designed in
 * docs/phase4-state.md E3: every engine-authored "something happened to you"
 * line goes through this one function, called at the effect site, and it
 * resolves to NOTHING in original mode. That single-seam rule is what keeps
 * the two fidelities from diverging in twenty places and keeps the CP2
 * differential meaningful: original mode prints exactly what the original
 * printed, and every invented line is greppable to one call site.
 *
 * The wording is invented and must stay visibly engine-authored (E3's own
 * rule): bracketed, lower-case, amount-first — never dressed up as game text,
 * never added to the generated U2_S_ pool, never uppercase-with-an-exclamation
 * in the game's voice. */
void u2_feedback(u2_ctx *ctx, const char *msg);

#endif /* U2_FEEDBACK_H */
