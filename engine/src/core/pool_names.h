#ifndef U2_POOL_NAMES_H
#define U2_POOL_NAMES_H
/*
 * One way to look an index up in a generated name pool.
 *
 * The enhanced panel and the Z screen each had their own macro for this, identical
 * in body. Identical duplicates are fine until one is edited: the FOOD byte pair and
 * the stat BCD were both "identical until someone needed them to differ", and both
 * turned out to be wrong in only one copy. Same argument as u2_state_bcd_pair and
 * u2_bcd2_str in core/state.h.
 *
 * Out-of-range yields the empty string rather than a guess, which is what both
 * callers already did: a weapon index the pool does not cover should show nothing,
 * not the wrong item's name.
 */

#include "gen_content.h"

#ifdef U2_T_WEAPONS_N
#  define U2_POOL_NAME(tbl, i) (((i) >= 0 && (i) < (tbl##_N)) ? (tbl)[i] : "")
#else
   /* The pools come from the player's own executable, so a build without it has
    * blank names and correct positions. Not a silent degradation. */
static const char *const u2_pool_empty[1] = { "" };
#  define U2_POOL_NAME(tbl, i) u2_pool_empty[0]
#endif

#endif /* U2_POOL_NAMES_H */
