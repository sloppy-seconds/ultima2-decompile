#ifndef U2_VERSION_H
#define U2_VERSION_H

/*
 * version.h — a binary has to be able to say what it is.
 *
 * This exists because of docs/sdl2-vs-sdl3.md: a dev build on a Bazzite or Arch
 * host links sdl2-compat, which is the SDL2 API implemented over SDL3, while the
 * release links pinned real SDL2 statically. Both compile, both run, and until
 * now nothing in the running binary could tell them apart. Every argument in that
 * document would have been a one-line answer with this in place.
 *
 * The compile-time half comes from -D flags the Makefile passes (see the STAMP
 * block there). The runtime half is asked of the SDL backend through the seam,
 * because core may not call SDL directly — that rule is what keeps a backend swap
 * a backend swap — and the two halves disagreeing is itself a useful signal: a
 * binary stamped sdl2 whose runtime says something else is holding a shim.
 */

#include <stddef.h>

/* Write a single-line description of this build into `out` (at most n-1 chars,
 * always NUL-terminated). Returns the number of characters written, excluding the
 * terminator, or 0 if the buffer was too small to hold anything useful. */
int u2_build_info(char *out, size_t n);

#endif /* U2_VERSION_H */
