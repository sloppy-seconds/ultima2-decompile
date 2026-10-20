/* audio_null.c — silent audio backend (headless default). */
#include "core/ctx.h"

static int null_init(u2_ctx *ctx) { (void)ctx; return 0; }
static void null_tone(u2_ctx *ctx, uint16_t d, uint32_t ms)
{
    (void)ctx; (void)d; (void)ms;
}
static void null_shutdown(u2_ctx *ctx) { (void)ctx; }

const u2_audio u2_audio_null = {
    .name = "null",
    .init = null_init,
    .tone = null_tone,
    .shutdown = null_shutdown,
};
