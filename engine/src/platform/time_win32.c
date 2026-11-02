/*
 * time_win32.c — wall clock for the native Windows build.
 *
 * seam: clock_int1a sites. The unit is the same one time_posix.c reports: BIOS
 * PIT jiffies at 18.2065 Hz (1193180/65536), so anything that counts ticks the
 * way the asm does counts the same order of magnitude here.
 *
 * Why a separate backend and not an #ifdef inside time_posix.c: mingw-w64
 * *declares* clock_gettime and nanosleep, so the POSIX file compiles clean, and
 * then fails at LINK because the msvcrt it links against has no such symbols.
 * That is the worst shape of portability bug — every machine that never
 * cross-built saw it pass, and it was the release workflow that found it.
 * QueryPerformanceCounter is the monotonic source Windows actually guarantees,
 * and Sleep() is the delay primitive that exists there.
 *
 * Granularity, stated because it is behaviour and not a detail: Sleep()'s
 * resolution is the system timer tick (10-16 ms by default, and this build does
 * not raise it with timeBeginPeriod). The engine's speed model counts PIT
 * jiffies, 54.9 ms each, so a one-jiffy delay already exceeds the tick and lands
 * in the right place; anything shorter rounds up, never down. A sleep is only
 * ever a floor on the wait, which is also true on POSIX.
 */
#include <windows.h>

#include <stdint.h>

#include "core/ctx.h"

/* PIT ticks per second, times 1000 for integer maths. */
#define PIT_TPS_x1000 18206u

static uint64_t win32_tick(u2_ctx *ctx)
{
    LARGE_INTEGER now, freq;
    uint64_t sec, rem, us;

    (void)ctx;
    if (!QueryPerformanceFrequency(&freq) || freq.QuadPart <= 0) return 0;
    if (!QueryPerformanceCounter(&now) || now.QuadPart < 0) return 0;

    /* Split before scaling: `now * 1000000` overflows a uint64 after about
     * three weeks on a 10 MHz counter, which is a boot session away from
     * somebody leaving the game running. */
    sec = (uint64_t)now.QuadPart / (uint64_t)freq.QuadPart;
    rem = (uint64_t)now.QuadPart % (uint64_t)freq.QuadPart;
    us  = sec * 1000000u + rem * 1000000u / (uint64_t)freq.QuadPart;
    return us * PIT_TPS_x1000 / 1000000000u;
}

static void win32_sleep_ms(u2_ctx *ctx, uint32_t ms)
{
    (void)ctx;
    if (!ms) return;
    Sleep((DWORD)ms);      /* no early return to resume: nothing interrupts it */
}

const u2_clock u2_clock_win32 = {
    .name     = "win32",
    .tick     = win32_tick,
    .sleep_ms = win32_sleep_ms,
};
