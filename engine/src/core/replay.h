#ifndef U2_REPLAY_H
#define U2_REPLAY_H

/*
 * Playthrough report — the verifiable evidence artefact (CP2).
 *
 * A key log on its own only claims "I pressed these keys". The report also
 * records, for every frame the engine presented, a digest of the screen and of
 * the state, so a later run can be *proved* to reproduce the same game rather
 * than assumed to. That is the objective check CP8's end-to-end playthrough
 * depends on, and it is what makes the CLI contract worth building an MCP
 * wrapper on later.
 *
 * Content policy: the report holds digests and numbers, never game text, so it
 * is safe to commit. See engine/README.md.
 *
 * Verification lives in engine/tools/playlog.py (tooling, like the extractor);
 * the engine only emits.
 */

#include "core/ctx.h"

#define U2_REPLAY_MAX_STEPS 4096
#define U2_REPLAY_MAX_KEYS  1024

typedef struct u2_replay {
    int    n;
    int    keys_at[U2_REPLAY_MAX_STEPS];
    char   screen_sha[U2_REPLAY_MAX_STEPS][65];
    char   state_sha[U2_REPLAY_MAX_STEPS][65];
    uint32_t rolls[U2_REPLAY_MAX_STEPS];
    /* the key script, recorded verbatim so the report is self-describing */
    int    n_keys;
    char   keys[U2_REPLAY_MAX_KEYS][16];
    int    truncated;
} u2_replay;

/* Start recording frames into ctx->replay. */
void u2_replay_begin(u2_ctx *ctx);
/* Called from seam_present after a real screen change. */
void u2_replay_record(u2_ctx *ctx);
/* Record the key script (one token per line of the script file). */
void u2_replay_set_keys(u2_ctx *ctx, const char *path);
/* Write the report; returns 0 on success. */
int  u2_replay_write(u2_ctx *ctx, const char *path);

#endif /* U2_REPLAY_H */
