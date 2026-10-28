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
   handler does. That is now observed rather than inferred.

   And it is intentional. The owner reports the official manual describing J as letting the
   character "jump up and down", a way to release frustration, with no effect on obstacles,
   terrain or any mechanic. The bytes agree, and go further: a handler with three instructions
   and no write cannot touch a mechanic. So the emptiness is the feature, not a stub waiting to
   be finished -- do not "fix" it by implementing a jump. Recorded in docs/third-party-claims.md. */
static u2_cmd_result cmd_J(u2_ctx *ctx, u2_overworld *ow, uint8_t letter)
{
    (void)ow; (void)letter;
    seam_str_out(ctx, U2_S_JUMP_WHEE);
    cmd_done(ctx);
    return U2_CMD_DONE;
}

/* CAPTURE-CONFIRMED: cmd_Q saves. asm/3DE4 refuses indoors with ONLY OUTDOORS! and asm/3DFA
   saves outdoors echoing ONE MOMENT PLEASE!; both live in u2_overworld_save(), which owns the
   printing, so this handler adds nothing and must not: the original's Q arm prints no CR and
   no prompt of its own, which is why it does not call cmd_done().

   The only thing chosen here is the policy: original mode runs all three guards, enhanced mode
   drops them and saves anywhere (owner, 2026-10-29). Gate: tests/save_gate.py. */
static u2_cmd_result cmd_Q(u2_ctx *ctx, u2_overworld *ow, uint8_t letter)
{
    (void)letter;
    const u2_save_policy *pol = (ctx->fidelity == U2_FIDELITY_ENHANCED)
                                    ? &U2_SAVE_POLICY_ENHANCED
                                    : &U2_SAVE_POLICY_ORIGINAL;
    (void)u2_overworld_save(ctx, ow, pol);
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

    /* Z is an OVERLAY, not an edit of the screen.
     *
     * The page is drawn into the persistent text grid, which is also what the overworld compositor
     * reads back for the status band and the CMD prompt. So the page has to be taken out again
     * rather than painted over, and the way to take it out is to never have changed anything the
     * game still needs: snapshot the grid, draw the page, and put the snapshot back on dismissal.
     * The map and the command band are then untainted by construction, not by reconstruction --
     * nothing has to be redrawn correctly, because nothing was written.
     *
     * u2_vram is a plain struct (fixed cell array plus cursor and flags), so the copy is the whole
     * state. `writes` is a diagnostic counter of cells actually written, and the page really did
     * write them, so it is kept rather than rolled back.
     */
    const u2_vram saved = ctx->vram;
    const uint64_t writes = ctx->vram.writes;
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
    const int got_key = seam_key_wait(ctx, &dismiss);

    /* The original BLOCKS here: no timeout, no path out without a keypress. So the page is on
     * screen until a key actually arrives, and only then does it come down. seam_key_wait
     * returning 0 means "scripted input exhausted", which has no counterpart in the original --
     * tearing the page down on that condition made it vanish in the same command that drew it,
     * and left the CP5 gates reading a screen that had already been restored.
     *
     * Restoring the snapshot is the whole teardown. The cursor goes back with it, so the CMD
     * prompt resumes at the column it was interrupted at.
     */
    if (got_key) {
        ctx->vram = saved;
        ctx->vram.writes = writes;
    }
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

/* asm/44D4 cmd_X: X-IT, the dismount — the other half of the boarding rule the vehicle handoff
   could not find. BOARD consumes the tile and sets DS:13; X-IT writes 2*[DS:13] back through
   the same cell pointer and returns the player to foot, so the tile was never destroyed, only
   carried. The guard order is the byte order: on foot there is nothing to destroy (" WHAT?"),
   then the cell under the player decides — grass anywhere, or water if and only if it is the
   ship, since the ship may only be dropped afloat. Anything else is "-NOT HERE!".

   The restored stamp is 0x78 + 2*pclass, not the constant 0x78: every capture shows 0x78
   because every capture so far was a fighter. See asm/44D4_cmd_X.asm and G41.

   Not observed end to end: the three harvests that ran cmd_X pressed every letter on a foot
   character in a grass sector, so they exercised the " WHAT?" arm only. The dismount arms are
   byte-proven and unplayed; the "-NOT HERE!" arm is not even reachable from a foot start (it
   needs a non-ship vehicle standing on water, i.e. a plane flown over the sea, which is G43
   territory), so it is covered at unit level in tests/site_check.c. Gate: vehicle_dismount.py. */
static u2_cmd_result cmd_X(u2_ctx *ctx, u2_overworld *ow, uint8_t letter)
{
    (void)letter;
    seam_str_out(ctx, U2_S_XIT);

    const uint8_t stamp = ctx->state.player_stamp;
    const uint8_t mode_a = (uint8_t)(u2_world_tile_at(&ow->world, ow->x, ow->y) >> 1);

    switch (u2_dismount_rule(stamp, mode_a)) {
    case U2_DISMOUNT_ON_FOOT:
        seam_str_out(ctx, U2_S_XIT_WHAT);
        break;
    case U2_DISMOUNT_NOT_HERE:
        seam_str_out(ctx, U2_S_XIT_NOT_HERE);
        break;
    default:
        /* A terrain write, same reasoning as BOARD: the tile has to survive the creature turn
         * that follows, or the vehicle vanishes the moment anything moves. */
        u2_world_terrain_put(&ow->world, ow->x, ow->y, u2_dismount_tile(stamp));
        ctx->state.player_stamp = u2_foot_stamp(ctx->state.pclass);
        break;
    }

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

/* ---- the vehicles -------------------------------------------------------- */

/* asm/2F6F cmd_B: print "BOARD", then asm/2FAD dispatches on [DS:14], which is the map
 * byte under the player shifted right once — the same quantity the passability ladder
 * tests, and NOT the art index.
 *
 * The dispatch, in the original's order, with what each arm actually does:
 *
 *   0x22 horse   " HORSE", mode := 0x22, the cell becomes grass. No gate.
 *   0x24 ship    gated on DS:E2. With it: " FRIGATE", mode := 0x24, the cell becomes
 *                water. Without it: " SHIP" / "THE CREW OF THIS SHIP" / "WILL NOT LET
 *                YOU BOARD!" and nothing changes. So the thing you can board is the
 *                FRIGATE, and asm/3038 is not a fifth vehicle — it is the ship arm's
 *                success path. § 6 of the handoff had it as untested; the gate byte names it.
 *   0x26 plane   gated on DS:DF (SKULL KEY): " PLANE" either way, and "STRANGE YOU CAN'T
 *                GET IN!" without it.
 *   0x28 rocket  " ROCKET" first, then the DS:DD (ANKH) gate: "A METALIC VOICE
 *                COMMANDS:" / "YOU MUST HAVE AN ANKH!" without it.
 *   anything else  the tail at asm/2FB8, which prints " WHAT?" — so the whole line reads
 *                "BOARD WHAT?". That is the original's own refusal and nothing is invented here.
 *
 * The gate bytes are item slots, not flags: DS:DD/DF/E1/E2/E5 are items_held[7/9/11/12/15],
 * and the slot names are already recorded in docs/spice86-live-findings.md § 11 — ANKH, SKULL
 * KEY, BRASS BUTTON, BLUE TASSLE, TRI-LITHIUM. Each refusal message names its own item, which
 * corroborates that pairing from the message side; see the block comment in overworld.h.
 *
 * Boarding does not move the player, and it consumes the tile: each arm writes a ground byte
 * through the cell pointer DS:06 (grass for the three land vehicles, water for the ship).
 * The live sample is captures/spice86/ship-port-boniface, where [DS:14] went 0x24 -> 0x00 on
 * the BOARD with the position unchanged. Whether the consumed tile comes back is answered by
 * asm/44D4 (X-IT), which writes 2*[DS:13] back into the cell and returns the player to foot —
 * that is the dismount the handoff could not find, and it is a separate letter.
 *
 * NOT modelled, because the pointer it writes through is not modelled: the original writes to
 * [[DS:6]], the cached cell pointer asm/50B3 maintains, and which cell that holds at the moment
 * BOARD runs is inferred (the player's own) rather than traced. The live [DS:14] change is what
 * makes the inference worth shipping; if a capture ever shows the write landing on a different
 * cell, this is the line that changes.
 */
static void board_vehicle(u2_ctx *ctx, u2_overworld *ow, uint8_t mode, uint8_t leaves)
{
    ctx->state.player_stamp = mode;
    /* A terrain write, not a stamp: the tile is gone from the world, and the creature
     * restamp rebuilds the live grid from the pristine copy on every redraw. See
     * u2_world_terrain_put's note in core/world.h — without this the boarded tile is
     * back the next time anything moves, which the live capture rules out.
     */
    u2_world_terrain_put(&ow->world, ow->x, ow->y, leaves);
}

static u2_cmd_result cmd_B(u2_ctx *ctx, u2_overworld *ow, uint8_t letter)
{
    (void)letter;

    seam_str_out(ctx, U2_S_BOARD);

    switch (u2_world_tile_at(&ow->world, ow->x, ow->y) >> 1) {
    case U2_MODE_HORSE:
        seam_str_out(ctx, U2_S_BOARD_HORSE);
        board_vehicle(ctx, ow, U2_MODE_HORSE, U2_TILE_AFTER_BOARD_LAND);
        break;

    case U2_MODE_SHIP:
        if (ctx->state.items_held[U2_ITEM_BLUE_TASSLE] == 0) {
            /* One str_out call in the original, with the newline glyph mid-string; the
             * engine emits the breaks itself, the same convention cmd_V's helm line uses. */
            seam_char_print(ctx, '\r');
            seam_str_out(ctx, U2_S_BOARD_SHIP_A);
            seam_char_print(ctx, '\r');
            seam_str_out(ctx, U2_S_BOARD_SHIP_B);
            seam_char_print(ctx, '\r');
            seam_str_out(ctx, U2_S_BOARD_SHIP_C);
        } else {
            seam_str_out(ctx, U2_S_BOARD_FRIGATE);
            board_vehicle(ctx, ow, U2_MODE_SHIP, U2_TILE_AFTER_BOARD_WATER);
        }
        break;

    case U2_MODE_PLANE:
        if (ctx->state.items_held[U2_ITEM_SKULL_KEY] == 0) {
            seam_char_print(ctx, '\r');
            seam_str_out(ctx, U2_S_BOARD_PLANE_REF_A);
            seam_char_print(ctx, '\r');
            seam_str_out(ctx, U2_S_BOARD_PLANE_REF_B);
        } else {
            seam_str_out(ctx, U2_S_BOARD_PLANE);
            board_vehicle(ctx, ow, U2_MODE_PLANE, U2_TILE_AFTER_BOARD_LAND);
        }
        break;

    case U2_MODE_ROCKET:
        seam_str_out(ctx, U2_S_BOARD_ROCKET);
        if (ctx->state.items_held[U2_ITEM_ANKH] == 0) {
            seam_char_print(ctx, '\r');
            seam_str_out(ctx, U2_S_BOARD_ROCKET_REF_A);
            seam_char_print(ctx, '\r');
            seam_str_out(ctx, U2_S_BOARD_ROCKET_REF_B);
        } else {
            board_vehicle(ctx, ow, U2_MODE_ROCKET, U2_TILE_AFTER_BOARD_LAND);
        }
        break;

    default:
        seam_str_out(ctx, U2_S_BOARD_WHAT);
        break;
    }

    cmd_done(ctx);
    return U2_CMD_DONE;
}

/* The flight lines all end the same way: the word, the game's newline, a fresh prompt.
 * asm/38B0 stores it as ONE string ("NORTH",0x0d,"CMD: ") and the engine composes it from
 * the two pool entries rather than carrying a third copy of the text. */
static void flight_line(u2_ctx *ctx, const char *word)
{
    if (word) seam_str_out(ctx, word);
    seam_char_print(ctx, '\r');
    seam_str_out(ctx, U2_S_CMD_PROMPT);
}

/* asm/38B0's plane branch, runtime 0x3BFA.
 *
 *   "LAUNCH--PLANE" prints BEFORE the gate, so a plane without a BRASS BUTTON says both
 *   words and then explains: "FUNNY THIS PLANE IS" / "MISSING A BRASS BUTTON!".
 *
 *   Launched, the original enters a loop of its own (0x3C5F..0x3CB2) that is NOT the walk
 *   loop: it polls the key non-blocking, applies a heading delta of its own (DS:21/DS:22,
 *   initialised to north), masks both coordinates with and 0x3F, and redraws — one cell of
 *   travel per iteration, whether or not a key arrived. Arrows change the heading and echo
 *   the direction word; 'L' tries to land; any other key does nothing except let the
 *   iteration run. It consults no passability routine and charges no food, which is why
 *   airborne flight is a mode of the handler and not a mode of DS:13's ladder: DS:13 stays
 *   0x26 the whole time, and what the ladder at asm/2604 governs is the PLANE walked on the
 *   ground after landing.
 *
 *   Landing is accepted on tile 0x08 (grass) and nowhere else: "LAND PLANE." versus
 *   "LAND--NOT HERE!!!!!", and the refusal does not stop the plane — the bytes fall into
 *   the same delta apply as everything else. Both branches executed in
 *   captures/spice86/flight-launched-live (runtime 0x3B5A and 0x3B72 per the asm header),
 *   so this is observed flow, not inferred flow.
 *
 * The engine's scripted input has one poll per WAIT token, so a script drives the plane one
 * cell per WAIT and one cell per key — which is the original's cadence expressed in the only
 * clock a headless run has. When the script runs out the loop ends: the original has no such
 * exit, it flies until it lands or leaves the sector, and inventing one would be a guess about
 * what exhaustion means. That is a harness limit, not a behaviour.
 *
 * Not modelled, both named rather than hidden: the site-edge exit at 0x3CCD (crossing x==0 or
 * y==0 inside a site jumps to the sector reload at asm/243E, and the engine's sector-exit
 * plumbing is site_leave(), which this loop has no proven route into), and the redraw call at
 * asm/5CB1, which the engine's own draw replaces.
 */
static u2_cmd_result launch_plane(u2_ctx *ctx, u2_overworld *ow)
{
    seam_str_out(ctx, U2_S_LAUNCH_PLANE);

    if (ctx->state.items_held[U2_ITEM_BRASS_BUTTON] == 0) {
        seam_char_print(ctx, '\r');
        seam_str_out(ctx, U2_S_LAUNCH_PLANE_REF_A);
        seam_char_print(ctx, '\r');
        seam_str_out(ctx, U2_S_LAUNCH_PLANE_REF_B);
        cmd_done(ctx);
        return U2_CMD_DONE;
    }

    /* DS:21 = 0, DS:22 = 0xFF: the heading the original initialises to, which is north. */
    int dx = 0, dy = -1;
    flight_line(ctx, NULL);

    for (;;) {
        u2_key k;
        const int r = seam_key_poll(ctx, &k);
        if (r < 0) break;                       /* input exhausted: no original counterpart */

        if (r) {
            switch (k.ch) {
            case U2_KEY_UP:    dx = 0;  dy = -1; flight_line(ctx, U2_S_DIR_NORTH); break;
            case U2_KEY_DOWN:  dx = 0;  dy =  1; flight_line(ctx, U2_S_DIR_SOUTH); break;
            case U2_KEY_RIGHT: dx =  1; dy =  0; flight_line(ctx, U2_S_DIR_EAST);  break;
            case U2_KEY_LEFT:  dx = -1; dy =  0; flight_line(ctx, U2_S_DIR_WEST);  break;
            case 'L': case 'l':
                /* asm/3D47: the tile under the player, compared to 0x08 after and 0x7F. */
                if ((u2_world_tile_at(&ow->world, ow->x, ow->y) & 0x7F) == 0x08) {
                    seam_str_out(ctx, U2_S_LAND_PLANE);
                    cmd_done(ctx);
                    return U2_CMD_DONE;
                }
                flight_line(ctx, U2_S_LAND_NOT_HERE);
                break;
            default:
                break;                          /* any other key: the plane keeps going */
            }
        }

        /* asm/3C9B: x += dx, y += dy, both masked, with the carry chain intact so a
         * negative delta is the byte 0xFF and wraps the same way it does on the 8088. */
        ow->x = (int)(((uint8_t)ow->x + (uint8_t)dx) & 0x3Fu);
        ow->y = (int)(((uint8_t)ow->y + (uint8_t)dy) & 0x3Fu);
        u2_overworld_draw(ctx, ow);
    }

    cmd_done(ctx);
    return U2_CMD_DONE;
}

/* asm/38B0's rocket branch, runtime 0x3AD2.
 *
 * "LAUNCH--ROCKET", then the DS:E5 (TRI-LITHIUM) gate — without it, "A METALLIC VOICE
 * SAYS:" / "SHIP INCAPABLE OF LAUNCH!". Note the spelling differs from cmd_B's metallic
 * voice on purpose: the binary has "A METALIC VOICE COMMANDS:" in asm/3048 and "A METALLIC
 * VOICE SAYS:" here, and they are two strings, not one that drifted.
 *
 * Launched, the rocket is nothing like the plane. It prints "PREPARE FOR LAUNCH!", puts the
 * player at (0,0), sets the view mode byte DS:12 to 0xFF, prints "(PRESS ANY KEY)" and then
 * flies SOUTH TWO CELLS PER ITERATION on its own, stepping one cell east every time the y
 * coordinate lands on a multiple of 8 (asm/3B94: `adc $0x2,%al` then `and $7,%al; jne`). No
 * heading is steerable; the only input is the key that stops it. Where it stops is the
 * verdict: tile 0x08 grass and it survives, anything else and the handler jumps to
 * runtime 0x0E62, which is the death tail. So a rocket is a one-way trip you aim by
 * timing, and the engine reproduces exactly that.
 *
 * Not modelled, and deliberately so rather than guessed:
 *   * the return-point triple DS:69/DS:6A/DS:6B and the save call at asm/24FD. Those bytes
 *     are not in state.h, DS:6D (the guard on the whole block) is the world byte — Earth 0,
 *     planets 1..9, deep space 0x0A — and the pair belongs to the planet subsystem CP7 has
 *     not started. Writing an invented equivalent would be worse than leaving the gap.
 *   * the two 256-byte table clears at DS:272/DS:372 and the calls at asm/6B99 / asm/2490.
 *     asm/437E (cmd_V) clears the same two tables and the source of the continent art it
 *     goes with is unidentified, per that handler's own note.
 */
static u2_cmd_result launch_rocket(u2_ctx *ctx, u2_overworld *ow)
{
    seam_str_out(ctx, U2_S_LAUNCH_ROCKET);

    if (ctx->state.items_held[U2_ITEM_TRI_LITHIUM] == 0) {
        seam_char_print(ctx, '\r');
        seam_str_out(ctx, U2_S_LAUNCH_ROCKET_REF_A);
        seam_char_print(ctx, '\r');
        seam_str_out(ctx, U2_S_LAUNCH_ROCKET_REF_B);
        cmd_done(ctx);
        return U2_CMD_DONE;
    }

    seam_char_print(ctx, '\r');
    seam_str_out(ctx, U2_S_LAUNCH_ROCKET_GO);

    /* asm/3B74..0x3B7E: position to (0,0) and DS:12 to the world-map view mode. The
     * sector reload at asm/2490 that runs just before this is not modelled — it re-reads
     * MAPXFF, and the engine's sector store is owned by the world module, not by a command
     * handler. Note also that "(PRESS ANY KEY)" carries NO leading 0x8d glyph, so in the
     * original it continues the line "PREPARE FOR LAUNCH!" rather than starting one; the
     * engine does not add a newline the bytes do not have. */
    ow->x = 0;
    ow->y = 0;
    ctx->state.view_mode = 0xFF;

    seam_str_out(ctx, U2_S_PRESS_ANY_KEY);

    for (;;) {
        /* asm/3B94: y += 2 always; x += 1 whenever the new y is a multiple of 8. */
        ow->y = (int)(((uint8_t)ow->y + 2u) & 0x3Fu);
        if ((ow->y & 7) == 0)
            ow->x = (int)(((uint8_t)ow->x + 1u) & 0x3Fu);

        u2_overworld_draw(ctx, ow);

        u2_key k;
        const int r = seam_key_poll(ctx, &k);
        if (r < 0) break;                       /* input exhausted: the original blocks here */
        if (r) {
            /* asm/3BCE: the tile it stopped on decides everything. */
            if ((u2_world_tile_at(&ow->world, ow->x, ow->y) & 0x7F) != 0x08) {
                u2_death(ctx);
            }
            cmd_done(ctx);
            return U2_CMD_DONE;
        }
    }

    cmd_done(ctx);
    return U2_CMD_DONE;
}

/* asm/38B0 cmd_L: LAUNCH. The handler dispatches on DS:13 alone — plane at 0x26, rocket at
 * 0x28, and "LAUNCH WHAT?" for everything else, including the horse and the ship, which have
 * no launch arm at all. */
static u2_cmd_result cmd_L(u2_ctx *ctx, u2_overworld *ow, uint8_t letter)
{
    (void)letter;

    if (ctx->state.player_stamp == U2_MODE_PLANE)
        return launch_plane(ctx, ow);
    if (ctx->state.player_stamp == U2_MODE_ROCKET)
        return launch_rocket(ctx, ow);

    seam_str_out(ctx, U2_S_LAUNCH_WHAT);
    cmd_done(ctx);
    return U2_CMD_DONE;
}

/* asm/4542 cmd_Y, together with the input loop it falls into at asm/4551..asm/4567.
 *
 * That fall-through was recorded as unresolved for as long as the loop lay cut into seven
 * bulk-wave fragments, each headed "behavior not yet reviewed". Read as one address-ordered
 * stream it is a complete routine, and it is the freeform line input the owner remembered from
 * the manual: type anything, it echoes, Enter ends it. The bytes agree with the recollection,
 * and they say something stronger than "no gameplay effect" — nothing in the whole range
 * writes memory, so the yell is display-only and the text evaporates.
 *
 *   4551  L_004751: call key_poll         ; asm/4F4D, the seam that arrow-maps and upper-cases
 *   4554          cmp $0xff,%ah           ; AH=0xFF is the seam's "a key was consumed"
 *                 jne L_004751            ; nothing typed: spin, no turn advances
 *   4559          cmp $0xd,%al            ; Enter
 *                 je  L_004762
 *   455D          call char_print_wrap    ; echo the character
 *   4560          jmp L_004751
 *   4562  L_004762: call char_print_wrap  ; AL still holds 0x0D, so the Enter prints too
 *   4565          jmp L_000c33            ; cmd_done
 *
 * Two mappings, both stated rather than assumed. `seam_key_wait` stands for the spin loop,
 * because a spin on a key seam is a blocking read; it returns 0 only when a scripted input has
 * run dry, a condition the original cannot reach, and that exit is shared with cmd_M. And the
 * seam's upper-casing is NOT applied here: it belongs to asm/4F4D, which the engine does not
 * model engine-wide, and putting it in one handler would make a seam behaviour look like a
 * command's own.
 *
 * This is also the explanation for a capture we had misread. The 2026-10-25 letter run found
 * that after `YELL WHAT?` later letters accumulated on the CMD line and never dispatched, and
 * logged it as the command not returning to the prompt. It does return — on Enter. Those
 * letters were the yell being echoed.
 */
static u2_cmd_result cmd_Y(u2_ctx *ctx, u2_overworld *ow, uint8_t letter)
{
    (void)ow; (void)letter;
    seam_str_out(ctx, U2_S_YELL_WHAT);
    seam_char_print(ctx, '\r');          /* the 0x8d newline glyph in its db line */

    for (;;) {
        u2_key k;
        if (seam_key_wait(ctx, &k) == 0)
            break;                        /* input exhausted: no original counterpart */
        if (k.ch == '\r') {
            seam_char_print(ctx, '\r');   /* asm/4562 prints the Enter itself */
            break;
        }
        seam_char_print(ctx, (char)k.ch); /* asm/455D: echo one character */
    }
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
 *   C  the gates are decoded and cheap (see asm/3139_cast_spell_flow.asm: spell name from
 *      pool[0x24+DS:63], the DS:D7+DS:D8 wand/staff test, the DS:B6[pick] count and its
 *      packed-decimal decrement, and the DS:4A >= 4 rule that makes casting a tower-and-
 *      dungeon thing). What is missing is every EFFECT, and every effect is dungeon-side in
 *      a subsystem AGENTS.md § 3 parks. DS:D7/DS:D8 are not even in state.h yet. TODO once
 *      dungeons open: wire the gates, then the LIGHT / DOWN LADDER / UP LADDER branches.
 *      CAPTURE-CONFIRMED 2026-10-29 (captures/spice86/cmd-c-cast-tower), and one ordering rule
 *      there is easy to get wrong: the count is decremented BEFORE the location gate, so a cast
 *      that fails with -FAILED! outside a tower or dungeon still spends the spell. Check the
 *      stock, spend, then fail — not check, fail, spend.
 *   D  asm/334D prints DESCEND and falls into a key-code test whose meaning is recorded as
 *      unresolved in its own header, and dungeons are parked (AGENTS.md section 3).
 *   F  FIRE is the combat/attack arm.
 *   G  GET needs ground items.
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
 *   X  implemented 2026-10-29 as the dismount (asm/44D4); it was listed here as "destroy item"
 *      from the string alone, which was the wrong reading of the letter.
 *   Y  implemented 2026-10-29: asm/4542 falls into asm/4551..4567, which is a freeform echo
 *      loop terminated by Enter, not an unresolved tail. See cmd_Y. The 0x8d on the prompt's
 *      db line is the game's newline glyph, not a mystery glyph, so the CP9 note about it is
 *      retired as well.
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
    cmd_B, /* B  board vehicle: asm/2F6F -> asm/2FAD, gated on the item the refusal names */
    NULL,  /* C  see the note above */
    NULL,  /* D  see the note above */
    cmd_E, /* E  enter site: asm/3389, body in u2_overworld_enter() */
    NULL,  /* F  not implemented: FIRE is the combat/attack arm */
    NULL,  /* G  not implemented: GET needs ground items */
    cmd_H,
    NULL,  /* I  not implemented */
    cmd_J,
    NULL,  /* K  not implemented */
    cmd_L, /* L  launch plane/rocket: asm/38B0, its own flight loops, gated on the item named */
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
    cmd_X, /* X  X-IT dismount: asm/44D4, returns the tile and the class-dependent foot stamp */
    cmd_Y, /* Y  yell: asm/4542 + its echo loop asm/4551..4567, display-only */
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
