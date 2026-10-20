/*
 * audio_beep.c — PC speaker stand-in.
 *
 * seam: speaker_freq (asm/5CD2_speaker_freq.asm) — the asm latches PIT channel
 * 2 with two out-immediates to port 0x42; the engine receives the same 16-bit
 * divisor. Real hardware access (KIOCSOUND) needs root and is not an option,
 * so this backend records the tone and emits the terminal bell as an
 * approximation. Sampled speaker output arrives with the SDL2 backend at CP9.
 */
#include <stdio.h>
#include <stdlib.h>
#include "core/ctx.h"

typedef struct beep_audio {
    uint16_t last_divisor;
    uint32_t last_ms;
    unsigned tones;
    int      audible; /* terminal bell; off in headless mode */
} beep_audio;

static int beep_init(u2_ctx *ctx)
{
    beep_audio *ba = calloc(1, sizeof *ba);
    if (!ba) return -1;
    ba->audible = ctx->mode == U2_MODE_TERM;
    ctx->be_audio = ba;
    return 0;
}

static void beep_tone(u2_ctx *ctx, uint16_t divisor, uint32_t ms)
{
    beep_audio *ba = ctx->be_audio;
    if (!ba) return;
    ba->last_divisor = divisor;
    ba->last_ms = ms;
    ba->tones++;
    if (ba->audible && divisor)
        fputc('\a', stderr);
    fflush(stderr);
}

static void beep_shutdown(u2_ctx *ctx)
{
    free(ctx->be_audio);
    ctx->be_audio = NULL;
}

const u2_audio u2_audio_beep = {
    .name = "beep",
    .init = beep_init,
    .tone = beep_tone,
    .shutdown = beep_shutdown,
};
