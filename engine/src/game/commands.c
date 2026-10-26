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
#include "core/frame.h"
#include "core/font.h"
#include "game/status.h"
#include "game/overworld.h"

/* Generated at build time from the user's copy (engine/tools/extract/extractor.py). */
#include "gen_content.h"

/* The indexed name pool may be absent (CI has no copy of the game), and the degradation is
 * deliberate rather than silent -- same rule and same reason as status.c's Z_NAME. */
#ifdef U2_T_SPELLS_N
#  define SPELL_NAME(i) (((i) >= 0 && (i) < U2_T_SPELLS_N) ? U2_T_SPELLS[(i)] : "")
#else
#  define SPELL_NAME(i) ""
#endif

/* The armour pool, same degradation rule. The WEAR ARMOUR menu number indexes it directly:
 * 0 = SKIN (bare), 1 = CLOTH ... 6 = POWER, and 7 = NONE is the pool's own spare entry. */
#ifdef U2_T_ARMOUR_N
#  define ARMOUR_NAME(i) (((i) >= 0 && (i) < U2_T_ARMOUR_N) ? U2_T_ARMOUR[(i)] : "")
#else
#  define ARMOUR_NAME(i) ""
#endif

/* asm/45B8: `stc ; cmc ; sbb $0x1,%al ; das ; cmc` — a packed-decimal subtract of one, so the
 * nibble borrows in decimal and not in hex: 0x10 becomes 0x09, not 0x0F. Item counts are BCD
 * everywhere in this binary; treating them as binary is the same class of mistake as reading the
 * strength byte as its displayed number. */
static uint8_t bcd_dec1(uint8_t v)
{
    if (v == 0) return 0;
    if ((v & 0x0Fu) == 0) return (uint8_t)(v - 0x07u);
    return (uint8_t)(v - 1u);
}

/* The letters the original's jump table covers, in table order. cs:0730 holds 26 words and
 * `sbb $0x41,%al` indexes them, so A is entry 0 and Z is entry 25. */
#define CMD_COUNT 26

/*
 * A handler. Returns what the loop should do next; see u2_cmd_result.
 *
 * `letter` is passed so a shared helper can name which command it was reached from. That
 * matters more than it sounds: the aim prompt is not one routine the handlers call, it is a
 * family that shares asm/2362, and the callers of that routine are exactly cmd_U (through
 * asm/4307), cmd_S (through asm/3F37), cmd_O and two unnamed sites (asm/2BBE, asm/35EB).
 * cmd_C is NOT one of them -- it takes no direction, which is corrected in its own header --
 * and cmd_T aims by a different mechanism altogether (a cursor initialiser plus a slot scan,
 * asm/23E6), so "the direction commands" is not a set you can treat uniformly.
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

/* asm/4568 cmd_Z: the whole-page status screen, then wait for a key. Migrated out of
   u2_overworld_loop with its evidence where it was: docs/status-screen-z.md section 4
   measured that Z costs no food, moves no creature, does not advance the turn, and that the
   page is a full overwrite rather than an overlay -- which is why the world has to be
   redrawn on the way out. Whether the post-command sweep runs after Z is explicitly
   unmeasured (it needs live monsters on the field), so this handler runs none and does not
   call cmd_done(); inventing either would be exactly the kind of guess the project's rules
   exist to stop.
   Escape is NOT special here, and must not be made special. An earlier revision of this
   handler returned a quit code on Escape as a convenience for the --play-map development
   entry. That was never the original's behaviour -- docs/status-screen-z.md section 4 measured
   that ANY key closes the page -- and a development affordance living inside a command handler
   reads as fidelity when it is not. Removed 2026-10-26 at the owner's direction. Runs end on
   input exhaustion, which is verified to work without it. */
static u2_cmd_result cmd_Z(u2_ctx *ctx, u2_overworld *ow, uint8_t letter)
{
    (void)letter;
    u2_status_draw_full(ctx);

    /* Present the page as a WHOLE-GRID frame, not through the overworld compositor.
     *
     * u2_overworld_draw owns pixel rows 0..159 for the map window and composites only vram rows
     * U2_MSG_TOP..24 into the game frame. That is right for the play screen and completely wrong
     * for a full-screen page: the map was painted over the top twenty rows of the Z page, so in
     * the SDL build the player saw the tile view with the tail of the item list underneath it —
     * the owner's "it still shows the stats in the 4 line cmd section". Headless could never show
     * this, because the null renderer has no map layer to paint over anything.
     *
     * So a full-screen text page composes its own frame: black, all U2_ROWS of the grid, no map.
     * The overworld compositor is restored by the u2_overworld_draw() at the end of this handler.
     */
    if (ctx->frame) {
        u2_frame_clear(ctx->frame, U2_CGA_BLACK);
        u2_font_draw_vram_rows(ctx->frame, &ctx->vram, 0, U2_ROWS - 1);
        seam_present_frame(ctx);
    }

    u2_key dismiss;
    /* seam_key_wait returns NON-ZERO when it has a key (creation.c:159 relies on that). An
     * earlier revision tested `== 0` here and then read `dismiss` uninitialised, so its
     * Escape branch never fired. That branch is gone now; the wait itself is the byte, and
     * which key arrived is deliberately not looked at. */
    /* NOTE: the page is not taken back down here. u2_overworld_draw composites vram rows
     * U2_MSG_TOP..24 and never clears them, so the tail of the Z page stays printed over the
     * status band after dismissal -- reported by the owner from the SDL build. The fix needs a
     * way to observe a screen that exists inside one command, which the engine does not have
     * yet. Tracked in docs/phase4-state.md; the attempted fix is in git history as a patch.
     */
    (void)seam_key_wait(ctx, &dismiss);
    u2_overworld_draw(ctx, ow);
    return U2_CMD_DONE;
}

/* asm/3389 cmd_E: enter the site on this cell. The body is u2_overworld_enter() in
   overworld.c, because entering needs the sector store and the tile-to-digit table and
   those are that file's; what belongs here is that E is a letter the table answers, so
   u2_cmd_implemented() tells the truth about it. No cmd_done(): every path through the
   handler prints its own CR and prompt, including the refusals. */
static u2_cmd_result cmd_E(u2_ctx *ctx, u2_overworld *ow, uint8_t letter)
{
    (void)letter;
    u2_overworld_enter(ctx, ow);
    return U2_CMD_DONE;
}

/* asm/2B8F_cmd_A: print "ATTACK--" with no CR and fall into the gate chain, whose last step
   reads a direction. The direction arrives turns later, so the handler leaves the pending
   command on the overworld and returns U2_CMD_AWAIT: no turn passes and no sweep runs until
   the aim is answered, which is what the loop's direction arms then do. If the turn expires
   first, the waiting PASS lands on this same line -- `CMD: ATTACK--PASS`, captured live
   (docs/spice86-live-findings.md section 18), and that is why the word is printed without a
   CR rather than through echo_cmd. */
static u2_cmd_result cmd_A(u2_ctx *ctx, u2_overworld *ow, uint8_t letter)
{
    (void)letter;
    seam_str_out(ctx, U2_S_ATTACK);
    ow->pending_cmd = 'A';
    return U2_CMD_AWAIT;
}

/* asm/42F1 cmd_U: print "UNLOCK DIRECTION-" and fall into the same kind of aim gate. The
   prompt is answered by a direction key, and only a sideways one can ever work -- see
   u2_unlock_rule and asm/4309_unlock_aim_gate. Same AWAIT shape as cmd_A, and for the same
   reason: the original consumed the next key inside the handler chain, so the engine must
   not treat the letter itself as a completed turn. */
static u2_cmd_result cmd_U(u2_ctx *ctx, u2_overworld *ow, uint8_t letter)
{
    (void)letter;
    seam_str_out(ctx, U2_S_UNLOCK_DIRECTION);
    ow->pending_cmd = 'U';
    return U2_CMD_AWAIT;
}

/* asm/3B92_cmd_M: ready a spell by number. Print "MAGIC SPELL READY #", read ONE decimal
   digit, store it at DS:63 as the readied slot, print "SPELL READY => " and the spell's
   NAME, then cmd_done. The digit reader is asm/2028, which blocks, rejects anything outside
   '0'..'9' by simply reading again, and echoes the digit it accepted.

   The NAME is the part that used to be wrong here. asm/508C is the indexed name pool printer
   and the `adc $0x24,%al` in front of it is the SPELLS group base, not an ASCII digit bias:
   M echoes a WORD (`SPELL READY => UP LADDER`), which is the same constant cmd_C uses to
   print the spell it is about to try. See asm/3B92_cmd_M.asm's correction of 2026-10-25.

   Two things this deliberately does NOT copy, both from that reader's own DOUBT list in
   asm/2028_read_decimal_digit.asm, and both recorded rather than settled:
     * whether a rejected key is consumed or left in the typeahead ring. The engine consumes
       it. If the original leaves it, a stray key here would be seen by whatever runs next.
     * the 0x8D the reader echoes after the digit. 0x8D is this binary's newline glyph, and
       emitting a line break nobody can explain is a worse guess than not emitting one.
   Neither is testable from the engine side; both need the reader stepped through live. */
static u2_cmd_result cmd_M(u2_ctx *ctx, u2_overworld *ow, uint8_t letter)
{
    (void)ow; (void)letter;
    seam_str_out(ctx, U2_S_MAGIC_SPELL_READY);

    int digit = -1;
    while (digit < 0) {
        u2_key k;
        /* seam_key_wait returns NON-ZERO when it got a key and 0 when there is none —
         * same convention creation.c:159 depends on. Getting this backwards is invisible
         * in the dispatch gate, which is why the gate for M reads the echoed digit and not
         * just the prompt. */
        if (seam_key_wait(ctx, &k) == 0)
            break;                       /* input exhausted: no original counterpart */
        if (k.ch >= '0' && k.ch <= '9') {
            digit = k.ch - '0';
            seam_char_print(ctx, (char)('0' + digit));
        }
    }
    if (digit < 0) {
        cmd_done(ctx);
        return U2_CMD_DONE;
    }

    ctx->state.spell_pick = (uint8_t)digit;
    seam_str_out(ctx, U2_S_SPELL_READY_TO);
    seam_str_out(ctx, SPELL_NAME(digit));
    cmd_done(ctx);
    return U2_CMD_DONE;
}

/* asm/43F3_cmd_W: WEAR ARMOUR.
 *
 * The menu is ONE static string printed before anything is read, so the original always shows all
 * six types and only tells you afterwards whether you own one. Verified live 2026-10-26 with
 * DS:97..9C read as all zero — owning nothing — and the full list still on screen
 * (captures/spice86/wonly/). That is why there is no filtered-list logic in fidelity mode: the
 * filtering is in the post-choice refusal branches, not in the menu.
 *
 * Order, straight off the bytes:
 *   print menu
 *   read a digit into DS:1F; 7 or above is forced to 0 (0 = SKIN, going bare)
 *   print the armour NAME from the pool (`adc $0x1d,%al` + the printer at L_00528c), so a
 *     successful line reads "CLOTH READY." — observed on screen, not inferred
 *   ownership: DS:0x96[digit] == 0 and digit != 0  ->  " NOT OWNED!"
 *   strength gate: digit*8 < DS:4B, the PACKED byte, else the refusal
 *   success: " READY." and DS:62 = digit
 * All three exits tail-jump to L_000c33, the status tick.
 *
 * The strength gate is the BCD trap again: agility/strength 40 is stored 0x40 = 64, so digit*8
 * tops out at 48 and a starting character passes every armour. Reading the decimal 40 instead
 * would refuse things the original allows.
 *
 * ENHANCED MODE, owner's call 2026-10-26: list only armour actually owned, keeping each type's
 * original number so the digit still indexes the same table. The point is to stop the player
 * guessing; fidelity mode keeps the guessing because the original does it. Composed from the
 * original's own header and "WHICH? " pieces plus the pool names, not hand-copied text.
 */
static u2_cmd_result cmd_W(u2_ctx *ctx, u2_overworld *ow, uint8_t letter)
{
    (void)ow; (void)letter;

    if (ctx->fidelity == U2_FIDELITY_ENHANCED) {
        seam_str_out(ctx, U2_S_WEAR_HEADER);
        seam_char_print(ctx, '\r');
        int shown = 0;
        for (int n = 1; n <= 6; n++) {
            if (ctx->state.armour_owned[n - 1] == 0) continue;
            char line[24];
            snprintf(line, sizeof line, "%d-%s, ", n, ARMOUR_NAME(n));
            seam_str_out(ctx, line);
            shown++;
        }
        if (shown == 0) {
            /* Nothing to wear. The original never asks this question, so it has no words for it;
             * reuse its own refusal rather than inventing a sentence nobody wrote. */
            seam_str_out(ctx, U2_S_NOT_OWNED);
            cmd_done(ctx);
            return U2_CMD_DONE;
        }
        seam_char_print(ctx, '\r');
        seam_str_out(ctx, U2_S_WHICH);
    } else {
        seam_str_out(ctx, U2_S_WEAR_ARMOUR_MENU);
    }

    int digit = -1;
    while (digit < 0) {
        u2_key k;
        if (seam_key_wait(ctx, &k) == 0)
            break;                       /* input exhausted: no original counterpart */
        if (k.ch >= '0' && k.ch <= '9') {
            digit = k.ch - '0';
            seam_char_print(ctx, (char)('0' + digit));
        }
    }
    if (digit < 0) { cmd_done(ctx); return U2_CMD_DONE; }

    if (digit >= 7) digit = 0;                       /* asm/464B: cmp $0x7 ; jb, else zeroed */
    seam_str_out(ctx, ARMOUR_NAME(digit));           /* the pool echo */

    const int owned = (digit == 0) ||
                      (digit >= 1 && digit <= 6 && ctx->state.armour_owned[digit - 1] != 0);
    if (!owned) {
        seam_str_out(ctx, U2_S_NOT_OWNED);
        cmd_done(ctx);
        return U2_CMD_DONE;
    }

    if ((unsigned)(digit * 8) >= (unsigned)ctx->state.stat_str) {
        seam_str_out(ctx, U2_S_NOT_STRONG_ENOUGH);
        cmd_done(ctx);
        return U2_CMD_DONE;
    }

    seam_str_out(ctx, U2_S_ARMOUR_READY);
    ctx->state.worn_armour = (uint8_t)digit;         /* DS:62 */
    cmd_done(ctx);
    return U2_CMD_DONE;
}

/* asm/437E_cmd_V: VIEW.
 *
 * DS:DB is items_held[5], and U2_T_ITEMS[5] is "HELM" — so the gate is literally "do you hold a
 * HELM", with no inference left in it. Second gate is DS:4A (the sector's second decimal digit)
 * below 4; at or above 4 it prints the same VIEW WHAT? refusal.
 *
 * Observed live 2026-10-26 (captures/spice86/vhelm/): with DS:DB = 01 read BEFORE the press and
 * DS:4A = 00, pressing V replaced the whole play field with a WORLD MAP — continents in white on
 * black — and DS:DB read 00 afterwards, so the view costs one helm. A second press with none left
 * prints VIEW WHAT?.
 *
 * WHAT IS NOT MODELLED, and deliberately not faked: the map itself. The original sets DS:23/24 to
 * 0x20,0x20, calls L_002bd2, waits on L_00514d until AH == 0xFF, then clears two 256-byte tables
 * at 0x272 and 0x372. Where the continent art comes from is unidentified — it is not the sector
 * grid and not the tile atlas — so the engine prints the message and spends the helm, and the
 * overlay is an open gap rather than an invented approximation. Spending the charge without
 * showing the view is a known wrongness of enhanced and fidelity alike; a plausible fake map
 * would be worse, because it would look finished.
 */
static u2_cmd_result cmd_V(u2_ctx *ctx, u2_overworld *ow, uint8_t letter)
{
    (void)ow; (void)letter;

    if (ctx->state.items_held[5] == 0 || ctx->state.sector_second >= 4) {
        seam_str_out(ctx, U2_S_VIEW_WHAT);
        cmd_done(ctx);
        return U2_CMD_DONE;
    }

    seam_str_out(ctx, U2_S_VIEW_HELM_A);
    seam_char_print(ctx, '\r');            /* the original's 0x8d newline glyph */
    seam_str_out(ctx, U2_S_VIEW_HELM_B);
    ctx->state.items_held[5] = bcd_dec1(ctx->state.items_held[5]);
    cmd_done(ctx);
    return U2_CMD_DONE;
}

/* ---- the table ----------------------------------------------------------- */

/*
 * One entry per jump-table slot. A NULL entry means "this letter is not implemented", which
 * is a different state from a handler that runs and declines to act, and is reported
 * separately by u2_cmd_implemented() so the marker gate can count what is really there.
 *
 * The letters that are still NULL each lack something specific, and the something is named
 * here rather than left as a gap. Note the correction of 2026-10-25: C, O, S and T are no
 * longer evidence-blocked -- G31 captured them and they now show execution evidence -- so what
 * stops each one below is a missing engine subsystem, not a missing capture. Listed in letter
 * order, because a list that drifts out of order is how entries get duplicated.
 *
 *   B  BOARD needs vehicles.
 *   C  the gates are decoded and cheap (see asm/3139_cast_spell_flow.asm: spell name from
 *      pool[0x24+DS:63], the DS:D7+DS:D8 wand/staff test, the DS:B6[pick] count and its
 *      packed-decimal decrement, and the DS:4A >= 4 rule that makes casting a tower-and-
 *      dungeon thing). What is missing is every EFFECT, and every effect is dungeon-side in
 *      a subsystem AGENTS.md § 3 parks. DS:D7/DS:D8 are not even in state.h yet. TODO once
 *      dungeons open: wire the gates, then the LIGHT / DOWN LADDER / UP LADDER branches.
 *   D  asm/334D prints DESCEND and falls into a key-code test whose meaning is recorded as
 *      unresolved in its own header, and dungeons are parked (AGENTS.md section 3).
 *   F  FIRE is the combat/attack arm.
 *   G  GET needs ground items.
 *   L  LAUNCH needs vehicles.
 *   N  asm/3BCE prints NEGATE TIME and falls through into asm/3BDD (`mov 0xe3,%al`), which
 *      is not cmd_done. Where that fragment ends is not established; guessing a time effect
 *      from the word "NEGATE" is the invention this project's rules exist to stop.
 *   O  the offer flow (asm/3C2E: OFFER GOLD DIRECT- / OFFER TO WHOM? / HOW MUCH (*100))
 *      needs town NPCs, which is CP6. Owner pointer 2026-10-25, grade `recalled` and not
 *      yet tested: several NPCs accept an offer, Lord British is the easiest target, and his
 *      castle is on the same small island as the Port Boniface entrance.
 *   R  ready weapon.
 *   S  asm/3F25 prints STEAL DIRECT- and falls into the aim gate: asm/3F37 calls asm/2362 and
 *      then computes the target as ([DS:00]+[DS:19], [DS:01]+[DS:1A]) into DS:23/DS:24 -- read
 *      directly, so the aiming is settled. The effect is asm/3F5D_steal_attempt, modelled in
 *      combat.c for CP5 ticket C6 but not wired to a world-map direction. What a thief playtest
 *      still has to say is the TARGET SET, not the aim.
 *   T  asm/4050 TRANSACT does NOT use the asm/2362 aim family -- it seeds a cursor with
 *      asm/23E6 and scans slots, which is a different shape and is why it cannot share the
 *      unlock/steal plumbing. It needs the street-merchant tables (asm/412C, asm/41D9),
 *      which is CP6.
 *   V  "VIEW WHAT?" and the helm view need an inventory view; the Z screen has the lists but
 *      not the per-item selection cmd_V walks.
 *   W  the armour menu needs armour ownership and the strength gate; asm/43F3's menu is read
 *      but the ownership bytes are not modelled.
 *   X  destroy item.
 *   Y  asm/4542 prints "YELL WHAT?" plus one 0x8d glyph and falls through; like N, the
 *      continuation is unresolved, and the 0x8d glyph mapping is a CP9 decision.
 *
 * All six letters that used to live in u2_overworld_loop are here now, and A and U came last
 * on purpose: they leave the loop waiting for a direction key that arrives turns later, so
 * the pending state had to move onto u2_overworld first -- in the original the direction is
 * consumed inside the handler chain, which makes the pending aim the command's business and
 * not the loop's. M joins them as the readying half of the spell story; C above is the
 * spending half, and it is the one still waiting on dungeons.
 */
static const cmd_fn cmd_table[CMD_COUNT] = {
    cmd_A, /* A  attack aim: asm/2B8F, prints ATTACK-- and awaits a direction */
    NULL,  /* B  not implemented: BOARD needs vehicles */
    NULL,  /* C  see the note above */
    NULL,  /* D  see the note above */
    cmd_E, /* E  enter site: asm/3389, body in u2_overworld_enter() */
    NULL,  /* F  not implemented: FIRE is the combat/attack arm */
    NULL,  /* G  not implemented: GET needs ground items */
    cmd_H,
    NULL,  /* I  not implemented */
    cmd_J,
    NULL,  /* K  not implemented */
    NULL,  /* L  not implemented: LAUNCH needs vehicles */
    cmd_M, /* M  ready a spell by number: asm/3B92, echoes the spell NAME */
    NULL,  /* N  see the note above */
    NULL,  /* O  see the note above */
    cmd_P, /* P  PASS: asm/3DBC. The space bar is a different site, in overworld.c */
    cmd_Q, /* Q  save: asm/3DE4 refuses indoors, asm/3DFA saves outdoors */
    NULL,  /* R  not implemented: ready weapon */
    NULL,  /* S  see the note above */
    NULL,  /* T  see the note above */
    cmd_U, /* U  unlock aim: asm/42F1, prints UNLOCK DIRECTION- and awaits a direction */
    cmd_V, /* V  view: asm/437E, needs a HELM held and sector digit < 4; the map overlay is NOT modelled */
    cmd_W, /* W  wear armour: asm/43F3, full menu then digit then ownership and strength gates */
    NULL,  /* X  not implemented: destroy item */
    NULL,  /* Y  see the note above */
    cmd_Z, /* Z  status screen: asm/4568, a full-page overwrite, no turn passes */
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
