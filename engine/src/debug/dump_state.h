#ifndef U2_DUMP_STATE_H
#define U2_DUMP_STATE_H

/*
 * State dump — the automation substrate.
 *
 * --dump-state prints the screen grid as plain text and the game state as
 * JSON on stdout, which is what the CP2 MCP play-API parses. No third-party
 * JSON writer: the schema is small and hand-rolled, and the escaping is
 * explicit so a stray quote cannot corrupt a transcript.
 */

#include <stdio.h>
#include "core/ctx.h"

void u2_dump_screen(const u2_ctx *ctx, FILE *out);
void u2_dump_state_json(const u2_ctx *ctx, FILE *out);

#endif /* U2_DUMP_STATE_H */
