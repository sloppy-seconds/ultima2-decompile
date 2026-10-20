/*
 * dump_state.c — screen grid + JSON state dump (see debug/dump_state.h).
 *
 * The text builders (u2_screen_text, u2_state_json) are separate from the
 * printers so core/replay.c can digest exactly what a human sees, without a
 * FILE in the way.
 */
#include <stdio.h>
#include <string.h>
#include "debug/dump_state.h"

void u2_engine_version(char *out, int outsz)
{
    snprintf(out, outsz, "%s", U2_ENGINE_VERSION);
}

void u2_dump_screen(const u2_ctx *ctx, FILE *out)
{
    char line[U2_COLS + 1];
    /* ASCII only: the grid is parsed by scripts and by the replay digests. */
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

int u2_screen_text(const u2_ctx *ctx, char *out, int outsz)
{
    char line[U2_COLS + 1];
    int used = 0;

    for (int r = 0; r < U2_ROWS && used < outsz - 1; r++) {
        int n = u2_vram_row_text(&ctx->vram, r, line, (int)sizeof line);
        int written = snprintf(out + used, (size_t)(outsz - used), "%s%s",
                               line, r + 1 < U2_ROWS ? "\n" : "");
        if (written < 0) break;
        used += written;
        (void)n;
    }
    return used;
}

int u2_state_json(const u2_ctx *ctx, char *out, int outsz)
{
    const u2_state *s = &ctx->state;
    char ver[32];

    u2_engine_version(ver, (int)sizeof ver);
    return snprintf(out, (size_t)outsz,
        "{\"engine\":\"%s\",\"mode\":\"%s\","
        "\"platform\":{\"renderer\":\"%s\",\"input\":\"%s\",\"audio\":\"%s\",\"clock\":\"%s\"},"
        "\"screen\":{\"cols\":%d,\"rows\":%d,\"cells_written\":%llu,"
        "\"cursor\":{\"row\":%d,\"col\":%d,\"visible\":%d}},"
        "\"state\":{\"player_x\":%u,\"player_y\":%u,"
        "\"cursor\":{\"row\":%u,\"col\":%u},"
        "\"margins\":{\"left\":%u,\"right\":%u},"
        "\"text_attr\":%u,\"story_flag\":%u,\"sector_second\":%u,"
        "\"gold_bcd\":[%u,%u],\"gold\":%d,\"spell_pick\":%u,"
        "\"rng\":{\"state\":[%u,%u,%u,%u,%u,%u],\"rolls\":%u},"
        "\"map_base\":%u},"
        "\"content\":\"%s\"}",
        ver,
        ctx->mode == U2_MODE_HEADLESS ? "headless" : "term",
        ctx->renderer->name, ctx->input->name, ctx->audio->name, ctx->clock->name,
        U2_COLS, U2_ROWS, (unsigned long long)ctx->vram.writes,
        ctx->vram.row, ctx->vram.col, ctx->vram.visible,
        s->player_x, s->player_y, s->cursor_row, s->cursor_col,
        s->left_margin, s->right_margin, s->text_attr, s->story_flag, s->sector_second,
        s->gold_lo, s->gold_hi, u2_bcd16(s->gold_lo, s->gold_hi), s->spell_pick,
        s->rng_state[0], s->rng_state[1], s->rng_state[2],
        s->rng_state[3], s->rng_state[4], s->rng_state[5],
        ctx->rng_rolls, s->map_base,
        ctx->content_source ? ctx->content_source : "none");
}

void u2_dump_state_json(const u2_ctx *ctx, FILE *out)
{
    char buf[U2_STATE_JSON_MAX];

    u2_state_json(ctx, buf, (int)sizeof buf);
    fputs(buf, out);
    fputc('\n', out);
}
