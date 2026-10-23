/*
 * ai.h — the creature turn: pursuit, movement, and the special-attack gate.
 *
 * CP5 W6/W6b. Two passes over the 32 creature slots, both of them proven in the
 * bytes and both written up in docs/monster-spawn.md § 13:
 *
 *   asm/0A6D..0AB5  per slot: skip empty, compute the pursuit vector
 *                   (asm/4F36), and if |dx| < 3 and |dy| < 3 roll 1/8 for one of
 *                   the four specials (asm/0AAA gate, asm/0AD3 dispatch).
 *   asm/2122..2260  per slot: regenerate below 16 HP, then try to step along the
 *                   pursuit vector — diagonal first, then y-only, then x-only —
 *                   where each candidate must pass a per-species tile test.
 *
 * There is no "attack the player on contact" in the original. A creature whose
 * candidate cell is the player's cell does not move, and a thief in that
 * position attempts a steal (asm/0B4D -> asm/0FCD). Everything else about being
 * next to a monster is the player's problem, not the monster's.
 */
#ifndef U2_GAME_AI_H
#define U2_GAME_AI_H

#include "core/ctx.h"
#include "core/world.h"

typedef struct u2_ai_report {
    int examined;   /* non-empty slots the pass looked at                       */
    int moved;      /* slots that changed cell                                 */
    int gates;      /* times the asm/0AAA proximity test passed and the roll ran */
    int landed;     /* specials that were not resisted                          */
    int stolen;     /* successful thefts (asm/0FCD)                             */
    int retreated;  /* slots whose pursuit vector was negated (asm/0B0F)        */
} u2_ai_report;

/*
 * One creature turn. Call it once per elapsed turn, after whatever the player
 * did. `px`/`py` are the player's cell in sector coordinates.
 *
 * Prints the effect messages the original prints from inside these routines
 * ("LEGS PARALIZED!", "SAVED BY MAGICAL BOOTS!", "A THIEF STOLE SOMETHING!" and
 * the rest) into the message window, because in the original the print lives
 * inside the effect routine and not in a caller.
 *
 * Returns the report above. The caller is responsible for u2_monsters_store()
 * when rep.moved is non-zero.
 */
u2_ai_report u2_ai_creature_turn(u2_ctx *ctx, u2_world *w, int px, int py);

#endif /* U2_GAME_AI_H */
