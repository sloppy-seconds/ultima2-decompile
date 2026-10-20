/*
 * audio_sdl.c — sampled PC-speaker output.
 *
 * seam: speaker_freq (asm/5CD2_speaker_freq.asm). The original latches PIT
 * channel 2 with a 16-bit divisor; the engine hands the same divisor here, so
 * the only translation needed is divisor -> frequency, using the 8253's
 * 1.193182 MHz time base. The speaker was a square wave, so that is what is
 * generated — not a sine, and not a "beep" approximation.
 *
 * SDL_QueueAudio is used rather than a callback: the tone is finite and known in
 * advance, so queueing pre-generated samples avoids a shared-state callback and
 * the locking it would need.
 */

#ifdef U2_HAVE_SDL

#include <SDL.h>
#include <stdio.h>
#include <stdlib.h>

#include "core/ctx.h"

#define PIT_HZ 1193182L
#define AMP    9000          /* keep well inside int16 so overlapping tones clip */

typedef struct sdl_audio {
    int      open;
    int      rate;           /* the rate actually granted by the device */
    long     queued;         /* samples queued so far, for diagnostics */
    unsigned tones;
} sdl_audio;

static int sdl_audio_init(u2_ctx *ctx)
{
    if (SDL_InitSubSystem(SDL_INIT_AUDIO) != 0) {
        /* Silence is a legitimate outcome: a machine with no sound device must
         * not stop the game running, and the original ran fine with no speaker. */
        fprintf(stderr, "sdl audio: %s (continuing silent)\n", SDL_GetError());
        return 0;
    }
    sdl_audio *a = calloc(1, sizeof *a);
    if (!a) return 0;

    SDL_AudioSpec want, have;
    SDL_zero(want);
    want.freq     = 22050;
    want.format   = AUDIO_S16SYS;
    want.channels = 1;
    want.samples  = 1024;
    if (SDL_OpenAudio(&want, &have) != 0) {
        free(a);
        return 0;
    }
    a->open = 1;
    a->rate = have.freq;
    ctx->be_audio = a;
    SDL_PauseAudio(0);
    return 0;
}

static void sdl_audio_tone(u2_ctx *ctx, uint16_t divisor, uint32_t ms)
{
    sdl_audio *a = ctx ? (sdl_audio *)ctx->be_audio : NULL;
    if (!a || !a->open || divisor == 0 || ms == 0) return;

    const long freq = PIT_HZ / (long)divisor;
    if (freq < 30 || freq > 11000) return;        /* outside a usable speaker range */

    long total = (long)a->rate * (long)ms / 1000L;
    if (total <= 0) return;
    if (total > (long)a->rate * 5) total = (long)a->rate * 5;   /* cap at 5 s */

    const long period = (long)a->rate / freq;     /* samples per half-cycle */
    if (period < 2) return;                       /* above the Nyquist limit */

    int16_t *buf = malloc((size_t)total * sizeof(int16_t));
    if (!buf) return;
    for (long i = 0; i < total; i++)
        buf[i] = ((i / period) & 1) ? (int16_t)-AMP : (int16_t)AMP;

    /* Device 1 is the handle SDL_OpenAudio (the legacy API used here) yields. */
    SDL_QueueAudio(1, buf, (Uint32)(total * (long)sizeof(int16_t)));
    free(buf);
    a->queued += total;
    a->tones++;
}

static void sdl_audio_shutdown(u2_ctx *ctx)
{
    sdl_audio *a = ctx ? (sdl_audio *)ctx->be_audio : NULL;
    if (!a) return;
    SDL_CloseAudio();
    SDL_QuitSubSystem(SDL_INIT_AUDIO);
    free(a);
    ctx->be_audio = NULL;
}

const u2_audio u2_audio_sdl = {
    .name = "sdl",
    .init = sdl_audio_init,
    .tone = sdl_audio_tone,
    .shutdown = sdl_audio_shutdown,
};

#endif /* U2_HAVE_SDL */
