/*
 * version.c — see version.h.
 *
 * Every macro below has a fallback definition, because the test harnesses compile
 * single translation units with plain cc and no -D flags. A stamp that only
 * exists when the Makefile supplied it would make those builds fail to compile,
 * and a build that cannot compile is indistinguishable from a stamp that was
 * wrong, which defeats the purpose.
 */

#include "core/version.h"

#include <stdio.h>
#include <string.h>

#ifdef U2_HAVE_SDL
#  include "platform/platform.h"   /* u2_sdl_runtime_info, behind the same guard */
#endif

#ifndef U2_VERSION
#define U2_VERSION "unstamped"
#endif
#ifndef U2_BUILD_TARGET
#define U2_BUILD_TARGET "unstamped"
#endif
#ifndef U2_SDL_IMPL
#define U2_SDL_IMPL "none"
#endif
#ifndef U2_SDL_LINKAGE
#define U2_SDL_LINKAGE "none"
#endif
#ifndef U2_SDL_VERSION
#define U2_SDL_VERSION ""
#endif
#ifndef U2_ARTIFACT
#define U2_ARTIFACT "unknown"
#endif

int u2_build_info(char *out, size_t n)
{
    if (!out || n == 0) return 0;
    out[0] = '\0';

    int k = snprintf(out, n,
                     "u2 engine %s build=%s sdl=%s linkage=%s artifact=%s",
                     U2_VERSION, U2_BUILD_TARGET, U2_SDL_IMPL,
                     U2_SDL_LINKAGE, U2_ARTIFACT);
    if (k < 0 || (size_t)k >= n) return (k < 0) ? 0 : (int)n - 1;

    if (*U2_SDL_VERSION) {
        int j = snprintf(out + k, n - (size_t)k, " sdl_version=%s", U2_SDL_VERSION);
        if (j > 0 && (size_t)j < n - (size_t)k) k += j;
    }

#ifdef U2_HAVE_SDL
    /* Ask the backend what SDL is actually loaded, rather than trusting the
     * stamp. If the two disagree the binary is holding a compatibility layer,
     * and that is the whole reason this function exists. */
    char rt[64] = { 0 };
    u2_sdl_runtime_info(rt, sizeof rt);
    if (rt[0]) {
        int j = snprintf(out + k, n - (size_t)k, " runtime_sdl=%s", rt);
        if (j > 0 && (size_t)j < n - (size_t)k) k += j;
    }
#endif

    return k;
}
