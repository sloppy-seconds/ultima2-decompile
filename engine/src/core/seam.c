/*
 * seam.c — the seam layer (see core/seam.h).
 *
 * Every function here is the engine's counterpart of one named routine in the
 * byte-proven asm tree. Game logic calls these; nothing in src/game/ may call
 * a renderer, an input backend, sleep(), or a terminal escape directly. Each
 * call traces with its asm citation so a --trace log lines up with asm/.
 */
#include <string.h>
#include "core/seam.h"
#include "core/rng.h"
#include "core/timer.h"
#include "debug/trace.h"

void seam_char_out(u2_ctx *ctx, uint8_t ch)
{
    u2_trace(ctx, "char_out", "4A1C", "ch=0x%02X", ch);
    u2_vram_put(&ctx->vram, ch, 0x07);
}

void seam_char_print(u2_ctx *ctx, uint8_t ch)
{
    /* asm/5003_char_print.asm masks the high bit and special-cases CR. */
    u2_trace(ctx, "char_print", "5003", "ch=0x%02X", ch);
    u2_vram_put(&ctx->vram, ch, 0x07);
}

void seam_str_out(u2_ctx *ctx, const char *s)
{
    u2_trace(ctx, "str_out", "4FDF", "len=%zu", strlen(s));
    for (const char *p = s; *p; p++)
        u2_vram_put(&ctx->vram, (uint8_t)*p, 0x07);
}

void seam_goto(u2_ctx *ctx, int col, int row)
{
    /* str_out_core (asm/51FD) loads DL from DS:0x2E (column) and DH from
     * DS:0x2F (row) before INT 10h AH=02h — keep the state mirror in sync. */
    ctx->state.cursor_col = (uint8_t)col;
    ctx->state.cursor_row = (uint8_t)row;
    u2_vram_goto(&ctx->vram, row, col);
    u2_trace(ctx, "goto", "51FD", "col=%d row=%d", col, row);
}

void seam_str_out_at(u2_ctx *ctx, int col, int row, const char *s)
{
    u2_trace(ctx, "str_out_at", "51EB", "col=%d row=%d len=%zu", col, row, strlen(s));
    seam_goto(ctx, col, row);
    seam_str_out(ctx, s);
}

int seam_key_poll(u2_ctx *ctx, u2_key *out)
{
    int got = ctx->input->poll(ctx, out);
    if (got) {
        ctx->state.last_key = out->ch;
        u2_trace(ctx, "key_poll", "4F4D", "ready=1 ch=0x%02X", out->ch);
    } else {
        u2_trace(ctx, "key_poll", "4F4D", "ready=0");
    }
    return got;
}

int seam_key_wait(u2_ctx *ctx, u2_key *out)
{
    int got = ctx->input->wait(ctx, out);
    u2_trace(ctx, "key_wait", "4F4D", "got=%d", got);
    if (got)
        ctx->state.last_key = out->ch;
    return got;
}

uint8_t seam_rand_byte(u2_ctx *ctx)
{
    uint8_t r = u2_rand_byte(ctx);
    u2_trace(ctx, "rand_byte", "5217", "value=%u", r);
    return r;
}

void seam_wait_ms(u2_ctx *ctx, uint32_t ms)
{
    u2_trace(ctx, "timed_wait", "52CA", "ms=%u", ms);
    u2_wait_ms(ctx, ms);
}

void seam_tone(u2_ctx *ctx, uint16_t divisor, uint32_t ms)
{
    u2_trace(ctx, "speaker_freq", "5CD2", "divisor=%u ms=%u", divisor, ms);
    ctx->audio->tone(ctx, divisor, ms);
}

void seam_present(u2_ctx *ctx)
{
    u2_vram_flush(&ctx->vram, ctx);
}
