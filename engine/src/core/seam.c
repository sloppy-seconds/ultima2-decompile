/*
 * seam.c — the seam layer (see core/seam.h).
 *
 * Every function here is the engine's counterpart of one named routine in the
 * byte-proven asm tree. Game logic calls these; nothing in src/game/ may call
 * a renderer, an input backend, sleep(), or a terminal escape directly. Each
 * call traces with its asm citation so a --trace log lines up with asm/.
 *
 * The text printer reproduces char_print's control flow byte for byte:
 *
 *   asm/5003_char_print.asm  and $0x7f,%al ; cmp $0xd ; je  cr
 *   asm/500D_sub_500d.asm cr: al = DS:0x54F (left margin) ; DS:0x2E = al ; jmp nl
 *   asm/5016_sub_5016.asm    cmp $0xa ; jne emit
 *   asm/501A_sub_501a.asm nl: incb DS:0x2F ; cmpb $0x18,DS:0x2F ; jne sync
 *   asm/5025_sub_5025.asm      INT 10h AH=06h scroll rows 0x14..0x17, cols 0..DS:0x31
 *   asm/5036_sub_5036.asm      decb DS:0x2F ; jmp sync
 *   asm/503D_sub_503d.asm emit: INT 10h AH=09h, AL=char, BL=DS:0x23E (attribute)
 *   asm/504A_sub_504a.asm      incb DS:0x2E ; if DS:0x31 < DS:0x2E goto cr
 *   asm/5057_sub_5057.asm sync: call str_out_core (INT 10h AH=02h cursor)
 */
#include <string.h>
#include "core/seam.h"
#include "core/rng.h"
#include "core/timer.h"
#include "debug/trace.h"

static void text_sync_cursor(u2_ctx *ctx)
{
    /* str_out_core (asm/51FD) is the cursor sync at the end of char_print. */
    u2_vram_goto(&ctx->vram, ctx->state.cursor_row, ctx->state.cursor_col);
}

/* asm/501A_sub_501a.asm: the row advance shared by CR, LF and line wrap. */
static void text_next_row(u2_ctx *ctx, int reset_col)
{
    u2_state *s = &ctx->state;

    if (reset_col)
        s->cursor_col = s->left_margin;          /* asm/500D: al = DS:0x54F */
    s->cursor_row = (uint8_t)(s->cursor_row + 1); /* asm/501A: incb 0x2f */
    if (s->cursor_row >= U2_SCROLL_ROW) {         /* asm/501A: cmpb $0x18 */
        /* asm/5025: INT 10h AH=06h, AL=1 line, CH=0x14 DH=0x17, CL=0 DL=DS:0x31 */
        u2_vram_scroll_window(&ctx->vram, U2_MSG_TOP, U2_MSG_BOTTOM, 0,
                              s->right_margin, s->text_attr);
        s->cursor_row = (uint8_t)(s->cursor_row - 1); /* asm/5036: decb 0x2f */
    }
    text_sync_cursor(ctx);
}

void seam_char_print(u2_ctx *ctx, uint8_t ch)
{
    u2_state *s = &ctx->state;

    ch &= 0x7F;                                   /* asm/5003: and $0x7f,%al */
    u2_trace(ctx, "char_print", "5003", "ch=0x%02X", ch);
    if (ch == '\r') {                             /* asm/5003: cmp $0xd */
        text_next_row(ctx, 1);
        return;
    }
    if (ch == '\n') {                             /* asm/5016: cmp $0xa */
        text_next_row(ctx, 0);
        return;
    }
    /* asm/503D: INT 10h AH=09h — write char+attribute at the cursor. */
    u2_vram_poke(&ctx->vram, s->cursor_row, s->cursor_col, ch, s->text_attr);
    s->cursor_col = (uint8_t)(s->cursor_col + 1); /* asm/504A: incb 0x2e */
    if ((uint8_t)s->right_margin < s->cursor_col) {/* asm/504A: cmp 0x2e,%al; jb */
        text_next_row(ctx, 1);
        return;
    }
    text_sync_cursor(ctx);                        /* asm/5057 -> asm/51FD */
}

void seam_char_out(u2_ctx *ctx, uint8_t ch)
{
    u2_trace(ctx, "char_out", "4A1C", "ch=0x%02X", ch);
    u2_vram_put(&ctx->vram, ch, ctx->state.text_attr);
}

void seam_str_out(u2_ctx *ctx, const char *s)
{
    u2_trace(ctx, "str_out", "4FDF", "len=%zu", strlen(s));
    /* str_out's loop (asm/4FF0..asm/4FFE) calls char_print per byte. */
    for (const char *p = s; *p; p++)
        seam_char_print(ctx, (uint8_t)*p);
}

void seam_goto(u2_ctx *ctx, int col, int row)
{
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

/* asm/53A0_sub_53a0.asm: col=0, print 0x20 forty times. */
void seam_clear_row(u2_ctx *ctx, int row)
{
    seam_goto(ctx, 0, row);
    for (int i = 0; i < U2_COLS; i++)
        seam_char_print(ctx, ' ');
}

int seam_key_poll(u2_ctx *ctx, u2_key *out)
{
    int got = ctx->input->poll(ctx, out);
    if (got > 0) {
        /* asm/4F4D is bigger than the function boundary Phase 3 drew: the
         * routine consumes the key (INT 16h AH=00h), maps a few control bytes
         * to NUL, and at asm/4FD3.. folds a-z to A-Z with `and $0xdf`. The
         * command dispatch therefore only ever sees uppercase. */
        if (out->ch >= 'a' && out->ch <= 'z')
            out->ch = (uint8_t)(out->ch & 0xDF);
        ctx->state.last_key = out->ch;
        u2_trace(ctx, "key_poll", "4F4D", "ready=1 ch=0x%02X", out->ch);
    } else {
        /* "input finished for good" is the scripted stand-in for a player who
         * walked away; "no key right now" (a WAIT) is not. */
        if (got < 0)
            ctx->input_exhausted = 1;
        u2_trace(ctx, "key_poll", "4F4D", got < 0 ? "ready=end" : "ready=0");
    }
    return got > 0;
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
    ctx->state.rand_last = r;                     /* asm/5217: mov %al,0x23f */
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
