/*
 * time_posix.c — wall clock for the interactive build.
 *
 * seam: clock_int1a sites. The original reads the 8253 timer, whose BIOS
 * jiffy rate is 1193180/65536 = 18.2065 Hz; the engine reports the same unit
 * so anything that counts ticks in the asm counts the same order of magnitude
 * here. Delays are nanosleep, not cycle burning.
 */
#define _POSIX_C_SOURCE 200809L
#include <time.h>
#include "core/ctx.h"

/* PIT ticks per second, times 1000 for integer maths. */
#define PIT_TPS_x1000 18206u

static uint64_t posix_tick(u2_ctx *ctx)
{
    struct timespec ts;
    (void)ctx;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0)
        return 0;
    uint64_t us = (uint64_t)ts.tv_sec * 1000000u + (uint64_t)ts.tv_nsec / 1000u;
    return us * PIT_TPS_x1000 / 1000000000u;
}

static void posix_sleep_ms(u2_ctx *ctx, uint32_t ms)
{
    struct timespec ts;
    (void)ctx;
    ts.tv_sec = ms / 1000u;
    ts.tv_nsec = (long)(ms % 1000u) * 1000000L;
    while (nanosleep(&ts, &ts) == -1) { /* EINTR: resume the remainder */ }
}

const u2_clock u2_clock_posix = {
    .name = "posix",
    .tick = posix_tick,
    .sleep_ms = posix_sleep_ms,
};
