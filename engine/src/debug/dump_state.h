#ifndef U2_DUMP_STATE_H
#define U2_DUMP_STATE_H

/*
 * State dump — the automation substrate.
 *
 * --dump-state prints the screen grid as plain text and the game state as JSON
 * on stdout, which is what a playthrough harness parses. No third-party JSON
 * writer: the schema is small and hand-rolled, and the escaping is explicit so
 * a stray quote cannot corrupt a transcript.
 *
 * The text builders return the same bytes the printers emit, so core/replay.c
 * digests exactly what an agent sees.
 */

#include <stdio.h>
#include "core/ctx.h"

#define U2_ENGINE_VERSION "0.1-cp2"
#define U2_STATE_JSON_MAX 1024

void u2_dump_screen(const u2_ctx *ctx, FILE *out);
void u2_dump_state_json(const u2_ctx *ctx, FILE *out);
int  u2_screen_text(const u2_ctx *ctx, char *out, int outsz);
int  u2_state_json(const u2_ctx *ctx, char *out, int outsz);
void u2_engine_version(char *out, int outsz);

#endif /* U2_DUMP_STATE_H */
