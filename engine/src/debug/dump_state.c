/* dump_state.c — screen grid + JSON state dump (see debug/dump_state.h). */
#include <stdio.h>
#include <string.h>
#include "debug/dump_state.h"

#define U2_ENGINE_VERSION "0.0-cp0"

static void json_escape(FILE *out, const char *s)
{
    for (const unsigned char *p = (const unsigned char *)s; *p; p++) {
        switch (*p) {
        case '"':  fputs("\\\"", out); break;
        case '\\': fputs("\\\\", out); break;
        case '\b': fputs("\\b", out); break;
        case '\f': fputs("\\f", out); break;
        case '\n': fputs("\\n", out); break;
        case '\r': fputs("\\r", out); break;
        case '\t': fputs("\\t", out); break;
        default:
            if (*p < 0x20 || *p >= 0x7F)
                fprintf(out, "\\u%04X", *p);
            else
                fputc((int)*p, out);
        }
    }
}

void u2_dump_screen(const u2_ctx *ctx, FILE *out)
{
    char line[U2_COLS + 1];
    /* ASCII only: the grid is parsed by scripts and the MCP play-API. */
    fputc('+', out);
    for (int i = 0; i < U2_COLS; i++) fputc('-', out);
    fputs("+\n", out);
    for (int r = 0; r < U2_ROWS; r++) {
        int n = u2_vram_row_text(&ctx->vram, r, line, (int)sizeof line);
        fprintf(out, "|%s", line);
        for (int i = n; i < U2_COLS; i++) fputc(' ', out);
        fputs("|\n", out);
    }
    fputc('+', out);
    for (int i = 0; i < U2_COLS; i++) fputc('-', out);
    fputs("+\n", out);
}

void u2_dump_state_json(const u2_ctx *ctx, FILE *out)
{
    const u2_state *s = &ctx->state;

    fprintf(out, "{\n");
    fprintf(out, "  \"engine\": \"");
    json_escape(out, U2_ENGINE_VERSION);
    fprintf(out, "\",\n");
    fprintf(out, "  \"mode\": \"%s\",\n", ctx->mode == U2_MODE_HEADLESS ? "headless" : "term");
    fprintf(out, "  \"platform\": {\"renderer\": \"%s\", \"input\": \"%s\", "
                 "\"audio\": \"%s\", \"clock\": \"%s\"},\n",
            ctx->renderer->name, ctx->input->name, ctx->audio->name, ctx->clock->name);
    fprintf(out, "  \"screen\": {\"cols\": %d, \"rows\": %d, \"cells_written\": %llu, "
                 "\"cursor\": {\"row\": %d, \"col\": %d, \"visible\": %d}},\n",
            U2_COLS, U2_ROWS, (unsigned long long)ctx->vram.writes,
            ctx->vram.row, ctx->vram.col, ctx->vram.visible);
    /* One entry per DS offset the engine models today; the list grows with
     * each checkpoint and every field cites its asm function in core/state.h. */
    fprintf(out, "  \"state\": {\n");
    fprintf(out, "    \"player_x\": %u,\n", s->player_x);
    fprintf(out, "    \"player_y\": %u,\n", s->player_y);
    fprintf(out, "    \"cursor\": {\"row\": %u, \"col\": %u},\n", s->cursor_row, s->cursor_col);
    fprintf(out, "    \"margins\": {\"left\": %u, \"right\": %u},\n", s->left_margin, s->right_margin);
    fprintf(out, "    \"text_attr\": %u,\n", s->text_attr);
    fprintf(out, "    \"story_flag\": %u,\n", s->story_flag);
    fprintf(out, "    \"last_key\": %u,\n", s->last_key);
    fprintf(out, "    \"gold_bcd\": [%u, %u],\n", s->gold_lo, s->gold_hi);
    fprintf(out, "    \"gold\": %d,\n", u2_bcd16(s->gold_lo, s->gold_hi));
    fprintf(out, "    \"spell_pick\": %u,\n", s->spell_pick);
    fprintf(out, "    \"ticks\": [%u, %u, %u],\n", s->tick_a, s->tick_b, s->tick_c);
    fprintf(out, "    \"map_base\": %u\n", s->map_base);
    fprintf(out, "  },\n");
    fprintf(out, "  \"content\": \"");
    json_escape(out, ctx->content_source ? ctx->content_source : "none");
    fprintf(out, "\"\n");
    fprintf(out, "}\n");
}
