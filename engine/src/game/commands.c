/*
 * commands.c -- the command-letter dispatch table, in the shape asm/0A1F has it.
 *
 * See commands.h for why this is a table rather than a switch, and for the two
 * structural facts the bytes force: the A-Z range test happens before dispatch (asm/09FB
 * then asm/0A18), and every handler ends by jumping to asm/0A33_cmd_done, which prints CR
 * and falls into the post-command tail. The epilogue is therefore owned here.
 *
 * Content policy: every word printed here comes from the extractor's table, which reads it
 * out of the user's own copy at build time. Nothing in this file hard-codes game text.
 */
#include "game/commands.h"

#include <string.h>

#include "core/seam.h"
#include "game/overworld.h"

/* Generated at build time from the user's copy (engine/tools/extract/extractor.py). */
#include "gen_content.h"

/* The letters the original's jump table covers, in table order. cs:0730 holds 26 words and
 * `sbb $0x41,%al` indexes them, so A is entry 0 and Z is entry 25. */
#define CMD_COUNT 26

/*
 * A handler. Returns what the loop should do next; see u2_cmd_result.
 *
 * `letter` is passed so a shared helper can name which command it was reached from, which
 * matters because several handlers differ only in the word they print before falling into
 * the same aim gate (cmd_U, cmd_S, cmd_C, cmd_O, cmd_T all do this in the original).
 */
typedef u2_cmd_result (*cmd_fn)(u2_ctx *ctx, u2_overworld *ow, uint8_t letter);

/* ---- the epilogue every handler shares ------------------------------------ */

/*
 * asm/0A33_cmd_done: load 0x0D and call char_print, then FALL THROUGH to
 * asm/0A38_post_command_tail. The fall-through is not a return -- there is no `ret` in the
 * routine -- and the tail it reaches is what runs the creature sweep, which is the measured
 * answer to "what triggers a wandering spawn" (docs/monster-spawn.md section 15.2: not a
 * step and not a clock tick, but the end of a command).
 *
 * The engine's sweep lives in overworld.c as creature_turn(), and the loop already runs it
 * on the arms-paralysis rule, so this function prints the CR and the prompt and leaves the
 * sweep to the caller. That split is deliberate rather than tidy: whether the sweep runs
 * after a command that did nothing is NOT established for every arm, and asm/0A38's own
 * dispatch on the sector's low digit (docs/monster-spawn.md) means "after every command"
 * is an over-claim. Encoding it here would make an unproven claim structural.
 */
static void cmd_done(u2_ctx *ctx)
{
    seam_char_print(ctx, '\r');
    seam_str_out(ctx, U2_S_CMD_PROMPT);
}

/* ---- handlers ------------------------------------------------------------- */

/* CAPTURE-CONFIRMED 2026-10-25 (was UNPROVEN): cmd_H was never observed running until
   captures/spice86/cmd-letters-20261025, where the CMD log reads `HYPER WHAT?` and
   ExecutedInstructions contains 3782. The marker is removed because the marker gate's R2
   treats a stale UNPROVEN as a lie in the other direction -- it would tell the next agent that
   a captured handler still needs capturing. Body is unchanged: asm/3782 is `call str_out` on
   the literal then `jmp L_000c33`. */
static u2_cmd_result cmd_H(u2_ctx *ctx, u2_overworld *ow, uint8_t letter)
{
    (void)ow; (void)letter;
    seam_str_out(ctx, U2_S_HYPER_WHAT);
    cmd_done(ctx);
    return U2_CMD_DONE;
}

/* CAPTURE-CONFIRMED 2026-10-25 (was UNPROVEN): cmd_J ran in
   captures/spice86/cmd-letters-20261025 and printed `JUMP...WHEE...`. The observation the
   capture settled is the one this comment used to flag as suspicious: the message promises a
   jump the body never performs, and the body really is only print-and-return -- there is no
   tail-call hiding the action. So the original ships a message that overstates what the
   handler does. That is now observed rather than inferred. */
static u2_cmd_result cmd_J(u2_ctx *ctx, u2_overworld *ow, uint8_t letter)
{
    (void)ow; (void)letter;
    seam_str_out(ctx, U2_S_JUMP_WHEE);
    cmd_done(ctx);
    return U2_CMD_DONE;
}

/* CAPTURE-CONFIRMED: cmd_Q saves. It was one of the six letters implemented inside
   u2_overworld_loop, and it moves here first because it is the only one of the six whose
   whole body is a call to something already public — so the migration tests the dispatch
   rather than the behaviour. asm/3DE4 refuses indoors with ONLY OUTDOORS! and asm/3DFA saves
   outdoors echoing ONE MOMENT PLEASE!; both live in u2_overworld_save(), which owns the
   printing, so this handler adds nothing and must not: the original's Q arm prints no CR and
   no prompt of its own, which is why it does not call cmd_done(). */
static u2_cmd_result cmd_Q(u2_ctx *ctx, u2_overworld *ow, uint8_t letter)
{
    (void)letter;
    (void)u2_overworld_save(ctx, ow, &U2_SAVE_POLICY_ORIGINAL);
    return U2_CMD_DONE;
}

/* asm/3DBC_cmd_P: PASS as a command letter, reached through cs:0730 entry P. It is a
   different site from the walk loop's space bar (asm/0936's `cmp $0x20,%al` at file
   0x0B3C) even though both print the word and both charge 10 food at asm/090D, and the
   engine keeps them apart for the reason that matters: only one of them is in the jump
   table, so only one of them belongs in this file's table. The body lives in overworld.c
   as u2_overworld_pass(), because the food charge and the sweep are that file's
   primitives; what belongs here is the fact that P is a letter the table answers.
   Like cmd_Q it does not call cmd_done(): echo_cmd already emits the CR and the prompt. */
static u2_cmd_result cmd_P(u2_ctx *ctx, u2_overworld *ow, uint8_t letter)
{
    (void)letter;
    u2_overworld_pass(ctx, ow);
    return U2_CMD_DONE;
}

/* ---- the table ----------------------------------------------------------- */

/*
 * One entry per jump-table slot. A NULL entry means "this letter is not implemented", which
 * is a different state from a handler that runs and declines to act, and is reported
 * separately by u2_cmd_implemented() so the marker gate can count what is really there.
 *
 * The letters that are still NULL each lack something specific, and the something is named
 * here rather than left as a gap. Note the correction of 2026-10-25: C, M, O, S and T are no
 * longer evidence-blocked -- G31 captured them and they now show execution evidence -- so what
 * stops each one below is a missing engine subsystem, not a missing capture.
 *
 *   C  cast_spell_flow needs a spell list and a mana/spell-ready state; asm/310B tail-jumps
 *      to 0x3353 for the direction and the flow is asm/3139, neither wired yet.
 *   D  asm/334D prints DESCEND and falls into a key-code test whose meaning is recorded as
 *      unresolved in its own header, and dungeons are parked (AGENTS.md section 3).
 *   M  "MAGIC SPELL READY #" needs the same spell state as C.
 *   N  asm/3BCE prints NEGATE TIME and falls through into asm/3BDD (`mov 0xe3,%al`), which
 *      is not cmd_done. Where that fragment ends is not established; guessing a time effect
 *      from the word "NEGATE" is the invention this project's rules exist to stop.
 *   O  the offer flow (asm/3C2E: OFFER GOLD DIRECT- / OFFER TO WHOM? / HOW MUCH (*100))
 *      needs town NPCs, which is CP6.
 *   S  asm/3F25 prints STEAL DIRECT- and falls into the aim gate; the effect is
 *      asm/3F5D_steal_attempt, modelled in combat.c for CP5 ticket C6 but not wired to a
 *      world-map direction.
 *   T  asm/4050 TRANSACT aims a ray and needs the street-merchant tables (asm/412C,
 *      asm/41D9), which is CP6.
 *   V  "VIEW WHAT?" and the helm view need an inventory view; the Z screen has the lists but
 *      not the per-item selection cmd_V walks.
 *   W  the armour menu needs armour ownership and the strength gate; asm/43F3's menu is read
 *      but the ownership bytes are not modelled.
 *   Y  asm/4542 prints "YELL WHAT?" plus one 0x8d glyph and falls through; like N, the
 *      continuation is unresolved, and the 0x8d glyph mapping is a CP9 decision.
 *
 * Four observed letters (A, E, U, Z) are still implemented inside
 * u2_overworld_loop, with their evidence in place there. They migrate here one at a time
 * under the existing tests, not in one sweep; Q and P have already made the trip.
 */
static const cmd_fn cmd_table[CMD_COUNT] = {
    NULL,  /* A  in overworld.c pending migration */
    NULL,  /* B  not implemented: BOARD needs vehicles */
    NULL,  /* C  see the note above */
    NULL,  /* D  see the note above */
    NULL,  /* E  in overworld.c pending migration */
    NULL,  /* F  not implemented: FIRE is the combat/attack arm */
    NULL,  /* G  not implemented: GET needs ground items */
    cmd_H,
    NULL,  /* I  in overworld.c pending migration (see the loop) */
    cmd_J,
    NULL,  /* K  not implemented */
    NULL,  /* L  in overworld.c pending migration: launch */
    NULL,  /* M  see the note above */
    NULL,  /* N  see the note above */
    NULL,  /* O  see the note above */
    cmd_P, /* P  PASS: asm/3DBC. The space bar is a different site, in overworld.c */
    cmd_Q, /* Q  save: asm/3DE4 refuses indoors, asm/3DFA saves outdoors */
    NULL,  /* R  not implemented: ready weapon */
    NULL,  /* S  see the note above */
    NULL,  /* T  see the note above */
    NULL,  /* U  in overworld.c pending migration: unlock */
    NULL,  /* V  see the note above */
    NULL,  /* W  see the note above */
    NULL,  /* X  not implemented: destroy item */
    NULL,  /* Y  see the note above */
    NULL,  /* Z  in overworld.c pending migration: status screen */
};

u2_cmd_result u2_cmd_dispatch(u2_ctx *ctx, u2_overworld *ow, uint8_t letter)
{
    /* asm/09FB `cmp $0x41,%al ; jae` then asm/0A18 `cmp $0x5a,%al ; jbe`. Both bounds,
     * before the table is touched. Anything else is the asm/0A1C arm, and the caller owns
     * what that prints -- the illegal-command path is a different site (asm/277B region)
     * and is not this function's claim to make. */
    if (letter < 'A' || letter > 'Z')
        return U2_CMD_UNKNOWN;

    const cmd_fn fn = cmd_table[letter - 'A'];
    if (!fn)
        return U2_CMD_UNKNOWN;

    return fn(ctx, ow, letter);
}

int u2_cmd_implemented(char *out, int cap)
{
    int n = 0;
    for (int i = 0; i < CMD_COUNT; ++i) {
        if (!cmd_table[i])
            continue;
        if (out && n + 1 < cap)
            out[n] = (char)('A' + i);
        n++;
    }
    if (out && n < cap)
        out[n] = '\0';
    return n;
}
