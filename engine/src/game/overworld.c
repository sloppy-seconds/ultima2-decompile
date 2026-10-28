/*
 * overworld.c — the CP4 screen, assembled from the four proven pieces.
 *
 * Sector + tiles + viewport + framebuffer. The composition order mirrors the
 * original: stage the tile IDs (asm/5AE1), then flush them to a frame
 * (asm/4ABB), honouring the do-not-draw flag rather than drawing tile 0.
 */

#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "game/commands.h"
#include "game/overworld.h"
#include "game/ai.h"           /* u2_ai_creature_turn: the monsters' turn */
#include "game/combat.h"      /* u2_combat_attack, u2_attack */
#include "game/monsters.h"    /* u2_monsters_at: who is standing there */
#include "core/rng.h"         /* u2_rand_byte: asm/0BDB's damage randomiser */
#include "game/status.h"
#include "core/font.h"
#include "core/save.h"
#include "core/seam.h"
#include "core/tiles.h"
#include "core/tiles_builtin.h"
#include "core/view.h"
#include "core/world.h"
#include "gen_content.h"
#include "debug/turnlog.h"

/*
 * The underlay buffer (the DS:0x372 analogue) has no identified producer in the
 * asm yet, so it is passed as NULL: no underlay layer, nothing suppressed.
 *
 * Passing a plausible-looking background instead would have made the map look
 * more "finished" while hiding the gap, and a hidden gap is how a wrong
 * assumption becomes a rendering bug three modules away. The live capture's
 * DS:54E is 0x00, i.e. the empty gate is clear, which is what the original had
 * in memory at the moment it was captured; with no underlay the gate is moot,
 * but the value is kept faithful rather than convenient.
 */
#define U2_OVERWORLD_EMPTY_GATE 0

const u2_save_policy U2_SAVE_POLICY_ORIGINAL = { 0, 0, 0 };

/* Echo one message through the CMD window: the word lands after the waiting
 * prompt, the game's newline scrolls it up, a fresh prompt prints below —
 * the same compound print the original uses for direction echoes
 * ("NORTH\rCMD: ", asm/38B0 file 0x3ce5). */
static void echo_cmd(u2_ctx *ctx, const char *word)
{
    seam_str_out(ctx, word);
    seam_char_print(ctx, '\r');
    seam_str_out(ctx, U2_S_CMD_PROMPT);
}

/* Defined below with the food arithmetic. creature_turn needs it to apply the
 * melee pool with the same BCD idiom rather than a second, subtly different one. */
static int bcd_sbb(unsigned a, unsigned sub, int borrow_in, unsigned *out);

/*
 * One creature turn, after whatever the player just did.
 *
 * The original advances the monsters once per elapsed turn, and a turn is any
 * accepted action or an expiry — which is why this sits behind the move, the
 * PASS, the auto-PASS and the attack rather than behind a timer of its own.
 * asm/0A6D..0AB5 and asm/2122..2260 are the two passes; ai.c owns them.
 *
 * The grid is re-stamped whenever anything moved, because the renderer and the
 * passability test both read the stamped grid (CP5 W2), and a creature that
 * walked but left its type byte behind would become a wall on its old cell.
 * The frame itself needs no redraw here: the loop composites at the top of each
 * iteration.
 */
/* asm/0C33. One decrement per non-zero counter. Called from creature_turn() AND from the refused
 * step path, because the original reaches the tick on a refused input as well as on a turn — see
 * the long note in creature_turn(). Kept separate so both call sites share one body. */
static void status_tick(u2_ctx *ctx)
{
    if (ctx->state.paral_legs)  ctx->state.paral_legs--;
    if (ctx->state.paral_arms)  ctx->state.paral_arms--;
    if (ctx->state.paral_sleep) ctx->state.paral_sleep--;
}

static void creature_turn(u2_ctx *ctx, u2_overworld *ow)
{
    ow->turns++;   /* one resolved turn; --debug cli keys off this */

    /* asm/0C33: the status counters tick once per HANDLED INPUT EVENT, not once per turn.
     * Measured two ways against the original, and the second measurement refuted the first.
     *
     * (1) A multi-shot breakpoint on the tick while the game sat idle showed food -10 at every
     *     stop. Read alone that looks like one tick per turn, because an idle game auto-passes and
     *     a pass spends 10 food. It is not proof of turn-coupling; it is a coincidence of cause.
     * (2) Forcing DS:26B=15 and then pressing a direction key repeatedly, sampling the counter and
     *     the food odometer together: 15 decrements, EVERY ONE of them with food UNCHANGED, and the
     *     same force with no input gave 15 held. A refused step is not a turn and does not spend
     *     food, and it still ticks. Capture: /var/tmp/para runs, recorded in
     *     captures/spice86/paralysis-two-arm/readings.md.
     *
     * So the tick sits on the input-handling path, reached whether the input moved, was refused,
     * or passed. The engine's refused steps `continue` without creature_turn(), so the tick is
     * called here as well as in creature_turn(); see status_tick(). asm/0C33 skips a counter that
     * is already zero, which is why sleeping does not go negative. */
    status_tick(ctx);

    const u2_ai_report rep = u2_ai_creature_turn(ctx, &ow->world, ow->x, ow->y);
    if (rep.moved)
        u2_monsters_restamp(ctx, &ow->world);
    if (rep.moved || rep.stolen)
        u2_monsters_store(ctx, &ow->world);

    /* The wandering spawn, once per completed command, on the world map only.
     *
     * asm/0A38 gates the whole post-command sweep on the sector's second decimal
     * digit, and asm/0CEE's own header records that the spawner is that sweep's
     * tail rather than a separate timer — so one attempt per command here is the
     * cadence, not a guess about one. Indoors (digit non-zero) nothing spawns, and
     * that is the same gate that keeps the creature sweep off interiors.
     *
     * The frame needs no redraw: the loop composites at the top of each iteration,
     * and the stamp this writes into the grid is what the renderer reads. */
    if (ow->sector_lo == 0 && u2_monsters_wander(ctx, &ow->world) >= 0)
        u2_monsters_store(ctx, &ow->world);

    /* asm/0BD1/asm/0BDB: the pooled melee damage is applied ONCE after the loop,
     * and a zero pool means no damage at all rather than a damage of 1. The amount
     * actually taken is `((rand & pool) & 0x77) + 1`, so the pool is a mask and the
     * blow is randomised up to it. */
    if (rep.damage_pool == 0)
        return;

    u2_state *st = &ctx->state;
    const unsigned dmg = ((u2_rand_byte(ctx) & rep.damage_pool) & 0x77u) + 1u;

    /* The house BCD subtract: low byte DS:52, then the high byte DS:51 with the
     * borrow, `das` after each, and the trailing `cmc` re-exposes the borrow for the
     * `jae <death>` that follows. Underflow is death, and asm/0C62 zeroes the stats
     * anyway, so the store is skipped in that case rather than writing a negative
     * nibble first. */
    unsigned lo = 0, hi = 0;
    const int borrow1 = bcd_sbb(st->unk_52, dmg & 0xFFu, 0, &lo);
    const int borrow2 = bcd_sbb(st->hp, 0, borrow1, &hi);
    if (borrow2) {
        u2_death(ctx);
        return;
    }
    st->unk_52 = (uint8_t)lo;
    st->hp     = (uint8_t)hi;
    u2_status_draw(ctx);
    /* NO TEXT IS PRINTED HERE, AND THAT IS NOW ESTABLISHED RATHER THAN ASSUMED.
     * The original's feedback for a wound is a tone plus a screen flash:
     *   - the wound loop is runtime 0x0BB2..0x0BCF, driven by DS:20 (contacts) and DS:21 (hits),
     *     both set upstream at 0x0B4D and 0x0B79;
     *   - per iteration it calls 0x5EAC (a tone, divisor 0x300, about 1.5 kHz) and, while hits
     *     remain, asm/5255 twice with 0x5EF2 (a tone, divisor 0x800, about 580 Hz) between them;
     *   - asm/5255 -> asm/4C1E XORs a pattern table into CGA video (the segment table holds
     *     0xB8C8, 0xBAC8, 0xB8CD ... all inside 0xB800). XOR is its own inverse, which is why it
     *     is called twice -- the second call restores the screen. That is a flash.
     * So the silence is faithful. What the engine is missing is the tone and the flash, not a
     * message. Owner ruled 2026-10-26 that a sound substitutes for a message, so wiring the tone
     * satisfies the rule; the flash is the nicer half and can follow.
     * Provenance of this comment: two earlier versions were wrong and are gone. One claimed the
     * loop's callees printed a message; another claimed asm/5255 was the tone. Neither was true --
     * 0x5255 is the video XOR and the tones are 0x5EAC/0x5EF2 via asm/5DA9. The arithmetic
     * (asm/0B62 hit roll, asm/0B79 damage pool scaling on the creature's own remaining HP) was
     * never in doubt and the port above is unchanged. */
}

/*
 * Site transitions — asm/33A6..33FF (the `E` dispatch) and asm/341E..3524 (the
 * entry routines). Written up in docs/sector-rulesets.md § 6.
 *
 * The gate is the tile under the player, not a hidden trigger cell: cmd_E reads
 * [DS:14] >> 1, and DS:14 is `map_byte >> 1` (CP5 ticket C7), so the site is
 * chosen by tile >> 2. That prediction was checked against the content on
 * 2026-10-27 and every one of the 21 gate cells in the eight world sectors names
 * a sector file that exists — and the dungeon gate in mapx30 is the same cell the
 * live capture walked into when it moved DS:49/4A from 3,0 to 3,5.
 *
 * The digit is not the same thing as the shift: 7 means a tower (digit 4) and 8
 * means a castle (digit 3), which is why the table below is a table and not an
 * arithmetic expression.
 */
static int site_for_tile(uint8_t tile, const char **label, int *ax, int *ay)
{
    *label = NULL;
    *ax = 0x1f; *ay = 0x3e;            /* the street arrival cell, asm/342A */
    switch (tile >> 2) {
    case 5:  return 1;                                       /* village */
    case 6:  *label = U2_S_SITE_TOWN;   return 2;            /* town    */
    case 7:  *label = U2_S_SITE_TOWER;  *ax = 5; *ay = 5; return 4;
    case 8:  *label = U2_S_SITE_CASTLE; return 3;            /* castle  */
    case 9:  *label = U2_S_SITE_DUNGEON; *ax = 5; *ay = 5; return 5;
    default: return 0;
    }
}

int u2_site_for_tile(uint8_t tile, const char **label, int *ax, int *ay)
{
    return site_for_tile(tile, label, ax, ay);
}

/* Clear the six creature arrays before a load, so a sector that authors no
 * monsters cannot inherit the last sector's table. */
static void monsters_clear(u2_ctx *ctx)
{
    u2_state *s = &ctx->state;
    memset(s->mon_x,    0, sizeof s->mon_x);
    memset(s->mon_y,    0, sizeof s->mon_y);
    memset(s->mon_hp,   0, sizeof s->mon_hp);
    memset(s->mon_type, 0, sizeof s->mon_type);
    memset(s->mon_kind, 0, sizeof s->mon_kind);
    memset(s->mon_role, 0, sizeof s->mon_role);
}

/*
 * Load the sector now named by ow->sector_hi/lo, after the pattern of the entry
 * routines: asm/2290 for the map, asm/22D5 for the monsters, then DS:12 = 4.
 * Returns -1 and leaves the note filled when the map file is not there.
 */
static int site_reload(u2_ctx *ctx, u2_overworld *ow)
{
    u2_sector_id id = { (uint8_t)ow->sector_hi, (uint8_t)ow->sector_lo };

    const u2_world_result r = u2_world_load(ctx, &ow->world, 1, id);
    if (r != U2_WORLD_OK) {
        snprintf(ow->note, sizeof ow->note, "sector %d%d: %s",
                 ow->sector_hi, ow->sector_lo, u2_world_result_text(r));
        return -1;
    }

    monsters_clear(ctx);
    const u2_world_result mr = u2_world_load(ctx, &ow->world, 0, id);
    const int creatures = (mr == U2_WORLD_OK) ? u2_monsters_spawn(ctx, &ow->world) : 0;
    if (mr == U2_WORLD_OK)
        u2_monsters_clear_spawn_cells(ctx, &ow->world);

    /* asm/343F tail, reached by every arm: `mov $0x4,%al; mov %al,0x12`. */
    ctx->state.view_mode = 4;
    ow->view_mode = 4;
    u2_status_draw(ctx);
    /* Rewritten on success, not only on failure: the caller prints this, and a
     * stale note from the opening load would describe the sector we left. */
    snprintf(ow->note, sizeof ow->note,
             "sector %d%d via %s, %d creature%s%s",
             ow->sector_hi, ow->sector_lo,
             ow->world.map_prefix ? ow->world.map_prefix : "?",
             creatures, creatures == 1 ? "" : "s",
             mr == U2_WORLD_OK ? "" : " (no monx file)");
    /* Same reason the open path prints its note unconditionally: on a transition
     * "sector 71 ... 32 creatures" is the difference between a silent no-op and a
     * diagnosable one. */
    fprintf(stderr, "site: %s\n", ow->note);
    return 0;
}

static void site_enter(u2_ctx *ctx, u2_overworld *ow, int digit,
                       int ax, int ay)
{
    /* asm/341E: the cell you pressed E on becomes the return point. */
    ctx->state.entry_x = (uint8_t)ow->x;
    ctx->state.entry_y = (uint8_t)ow->y;

    /* Sync the creature table into the world buffer so a later save sees current state.
     * Do NOT write the sector: the original writes no sector file on a transition. The
     * comment here used to read "asm/22FD stores the sector being left" and flushed both
     * files, but asm/22FD is `mov 0x6d,%al ; or %al,%al ; je` — a boots gate with no I/O —
     * and the real store is asm/2305, reached from the save path below. Measured 2026-10-29:
     * mapx31/monx31/mapx30/monx30 byte-identical to pristine after several town entries and
     * exits, only `player` written. Gate: tests/site_state.py. */
    u2_monsters_store(ctx, &ow->world);
    if (ctx->keep_site_state) {
        if (ow->world.map_dirty) (void)u2_world_store(ctx, &ow->world, 1);
        if (ow->world.mon_dirty) (void)u2_world_store(ctx, &ow->world, 0);
    }

    ow->sector_lo = digit;
    ctx->state.sector_second = (uint8_t)digit;
    ow->x = ax;
    ow->y = ay;
    (void)site_reload(ctx, ow);
}

/*
 * asm/242D/2434/243E: leaving is the sector-edge test, run on the UNMASKED
 * coordinate before the wrap -- and it only applies inside a site.
 *
 * Measured 2026-10-28, walking off an edge with the save's entry point set by
 * tools/u2_edit.py setpos away from that edge, so "returned to the entry cell" and
 * "wrapped to the far side" could be told apart:
 *
 *   sector 31 (digit 1), east,  entry (63,35): digits 3,1 -> 3,0, player at the entry,
 *           DS:12 4 -> 0xFF.
 *   sector 31 (digit 1), west,  entry (1,35):  digits 3,1 -> 3,0, player back at
 *           (1,35) from x=0, DS:12 4 -> 0xFF. The next Left then wrapped normally.
 *   sector 31 (digit 1), south, entry (0,63):  digits 3,1 -> 3,0, player at the entry,
 *           DS:12 4 -> 0xFF.
 *   sector 23 (digit 3), east,  entry (62,2):  digits 2,3 -> 2,0, player at (62,2).
 *   sector 20 (digit 0): the edge WRAPS and the sector does not change -- the
 *           511/512 result against the discriminating rows of mapx20/mapx30.
 *
 * So the second digit is not a compass axis and the edge is not a sector border in
 * the overworld: crossing it leaves the SITE and returns you to the cell you
 * entered on, in the sector whose second digit is 0. That is what site_leave()
 * does, and it is why the call is gated on u2_site_edge_crossed() rather than run
 * unconditionally. The earlier engine behaviour -- leaving on any edge crossing --
 * turned the overworld's torus wrap into a teleport to the entry cell, which is a
 * defect that looked like the seam work being wrong rather than this.
 *
 * What is NOT established: the NORTH edge. Sector 31 has no column where both the top
 * and bottom cells are walkable, so it could not be reached by walking, and the three
 * edges that were measured (east, west, south) all behaved identically -- which is the
 * reason the old "only the high edge leaves, west and north wrap" claim in this comment
 * was replaced rather than refined. If the north edge turns out to differ, it differs
 * from three measurements and not from one.
 */
int u2_site_edge_crossed(int sector_second, int raw_x, int raw_y)
{
    /* A sector whose second digit is 0 is the world map: the edge wraps there. */
    if (sector_second == 0)
        return 0;
    /* Both directions, not the high edge alone: east, west and south were each
     * measured leaving, and the engine previously tested only the high side. */
    return raw_x < 0 || raw_x >= U2_SECTOR_EDGE ||
           raw_y < 0 || raw_y >= U2_SECTOR_EDGE;
}

static void site_leave(u2_ctx *ctx, u2_overworld *ow)
{
    ow->x = ctx->state.entry_x;
    ow->y = ctx->state.entry_y;
    ow->sector_lo = 0;
    ctx->state.sector_second = 0;

    /* Same rule as site_enter(): sync in memory, write nothing unless the enhanced
     * knob asked for it. Leaving a site re-reads the pristine sector, which is what
     * closes an opened door and heals a wounded guard in the original. */
    u2_monsters_store(ctx, &ow->world);
    if (ctx->keep_site_state) {
        if (ow->world.map_dirty) (void)u2_world_store(ctx, &ow->world, 1);
        if (ow->world.mon_dirty) (void)u2_world_store(ctx, &ow->world, 0);
    }

    (void)site_reload(ctx, ow);
}

/*
 * One packed-decimal `sbb`/`das` step, exactly as the original writes it.
 *
 * The original's idiom is `stc; cmc; sbb $imm,al; das; cmc; mov [..],al; jb
 * death`. Two things about it are easy to get wrong and are the reason this is
 * a named helper rather than inline arithmetic:
 *
 *   * `das` corrects on the **low nibble** too (the half-borrow the 8086 keeps
 *     in AF, which `cmc` alone does not reproduce). Subtracting 0x0A from 0x00
 *     gives 0xF6, and `das` turns that into 0x90 with a borrow — not 0xF6.
 *     Skipping the AF term is how a food counter drifts into non-decimal bytes.
 *   * the borrow the following `jb` tests is the byte borrow out, taken after
 *     the correction.
 *
 * Verified against a reference model of the three-byte chain before it was
 * ported: a fresh character (DS:53=04, DS:54=00, DS:55=00) dies on exactly the
 * 4001st PASS, and the displayed pair DS:53/DS:54 reads 0399 after the first.
 *
 * Returns the corrected byte in *out and yields the borrow (1 = underflow).
 */
static int bcd_sbb(unsigned a, unsigned sub, int borrow_in, unsigned *out)
{
    int af = ((a & 0x0Fu) < (sub & 0x0Fu) + (unsigned)borrow_in) ? 1 : 0;
    int d = (int)a - (int)sub - borrow_in;
    int cf = (d < 0) ? 1 : 0;
    d &= 0xFF;
    if ((d & 0x0Fu) > 9u || af) d = (d - 6) & 0xFF;
    if (cf || (unsigned)d > 0x99u) d = (d - 0x60) & 0xFF;
    *out = (unsigned)d;
    return cf;
}

/*
 * Death — asm/0C62..0C99, and it only reads as one routine when the four
 * bulk-wave fragments are laid end to end. Each alone looks like nothing; in
 * address order they are the only death announcement in the binary:
 *
 *   0C62  al := 0 ; DS:51..DS:59 := al ; call L_0052f9
 *   0C82  call str_out  db 0x8d,0x8d,0x8d,0        (three newlines)
 *   0C89  call L_00527a   -> asm/507A: bx := 0, then print DS:36+bx until a NUL
 *   0C8C  call str_out  db " IS DEAD!",0x8d,0
 *
 * Every site that can kill jumps here rather than calling, which is why this is
 * one function and not three lines inside food_spend: the food borrow-outs
 * (`jae` at asm/0BDB and asm/0C09), the force field (asm/24B5), Minax's attack
 * (asm/0F8E), dungeon events (asm/12DB, three sites), asm/228D, asm/2495,
 * asm/277B and cmd_L (asm/38B0).
 *
 * The on-screen result is on record, so none of this is inferred:
 * `captures/spice86/cp5-weak-fight/death1.png` reads `G23MAX IS DEAD!` on the
 * bottom row with H.P., FOOD, EXP and GOLD all at 0000.
 *
 * Two deliberate widths, named rather than hidden:
 *
 *   - asm/0C62 calls only L_0052f9, which is the H.P. line (asm/50F9). The
 *     captured frame has all four fields repainted, so the whole band is redrawn
 *     here. The frame is the observation; the narrower call is what the bytes
 *     show. If a later capture ever shows FOOD still at its old value at the
 *     moment of death, this line is the one to revisit.
 *   - No `CMD: ` prompt follows. The prompt is not printed before a read; it
 *     travels with the previous command's compound echo ("NORTH\rCMD: ",
 *     asm/38B0), and the death tail has no prompt of its own. The capture agrees:
 *     the announcement is the last thing on the log and the bottom row is bare.
 *
 * What the original does next is NOT proven. The capture ends at the frame
 * above, and the engine currently returns to the walk loop with a dead
 * character that can still walk and still be charged food. That is a guess by
 * omission, and it is on docs/needs-gameplay.md as an agent-drivable capture:
 * seed a weak character, get killed, keep sending keys, and see whether the
 * game accepts anything at all afterwards.
 */
void u2_death(u2_ctx *ctx)
{
    u2_state *st = &ctx->state;

    /* asm/0C62: nine stores, DS:51..DS:59. DS:55 is food_lo, the third byte of
     * the FOOD triple (see the food comment below), not a tenth field. */
    st->hp = 0; st->unk_52 = 0;
    st->food = 0; st->food_hi = 0; st->food_lo = 0;
    st->exp_lo = 0; st->exp_hi = 0;
    st->gold_lo = 0; st->gold_hi = 0;
    u2_status_draw(ctx);

    /* asm/0C82: three newlines, so the announcement owns the bottom of the log
     * whatever was on it. */
    for (int i = 0; i < 3; i++)
        seam_char_print(ctx, '\r');

    /* asm/0C89 -> asm/507A: the name, from DS:36, up to its NUL. No prompt and
     * no leading space: the space is inside the next string (" IS DEAD!"). */
    for (unsigned i = 0; i < sizeof st->name && st->name[i] != 0; i++)
        seam_char_print(ctx, (char)st->name[i]);

    /* asm/0C8C: " IS DEAD!" then the game's newline (the 0x8d in its db). */
    seam_str_out(ctx, U2_S_IS_DEAD);
    seam_char_print(ctx, '\r');
}

/*
 * Time passes: one action, one BCD subtraction from the food triple.
 *
 * Proven shape (file 0x0B0D..0x0B33, the PASS arm of the walk loop): the
 * original subtracts from DS:55 first and borrows upward through DS:54 and
 * DS:53, each step followed by `das`, and a borrow out of the top jumps to
 * runtime 0x0E62. PASS subtracts $0x0a; asm/2599 and asm/2626 subtract
 * $0x19. The three bytes are one 6-digit packed-decimal number with the low
 * byte at DS:55, while the status band prints only DS:53/DS:54 — the top four
 * digits. That is why a fresh character's `FOOD=0400` is really 4000 units and
 * one PASS moves the display only every tenth pass: the bytes say the last
 * digit is real but invisible, so the engine keeps it rather than rounding it
 * away.
 *
 * The borrow-out target is the whole of the "starvation" rule the bytes
 * support: it jumps to 0x0E62 (asm/0C62), which is `u2_death` below. There is
 * no separate "food at zero drains HP a little at a time" step anywhere in the
 * tree; the owner's model said there would be, and the bytes disagree, so the
 * bytes win and the disagreement is recorded rather than implemented.
 *
 * Returns 1 when the subtraction underflowed (the character just died). The
 * caller's job is to hand that to u2_death; this function only subtracts.
 *
 * SILENCE IS FAITHFUL HERE, and it is now evidenced rather than assumed. The original prints
 * nothing when a step costs food: one `Down` took the food triple 996452 -> 996433 and the
 * command log showed only `CMD: SOUTH`, with no mention of the cost -- see
 * captures/spice86/food-drain-message/readings.md. So this function emits no message on purpose,
 * which is what AGENTS.md § 3 requires of a silent effect: cite the bytes or the capture, or do
 * not be silent. Scope of that claim: one step on foot, and it says nothing about food reaching
 * zero, which is the death path below and does announce.
 */
static int food_spend(u2_ctx *ctx, unsigned bcd_sub)
{
    u2_state *st = &ctx->state;
    unsigned lo, mid, hi;
    int borrow;

    borrow = bcd_sbb(st->food_lo, bcd_sub & 0xFF, 0, &lo);
    borrow = bcd_sbb(st->food_hi, (bcd_sub >> 8) & 0xFF, borrow, &mid);
    borrow = bcd_sbb(st->food,    (bcd_sub >> 16) & 0xFF, borrow, &hi);

    st->food_lo = (uint8_t)lo;
    st->food_hi = (uint8_t)mid;
    st->food    = (uint8_t)hi;

    return borrow;
}

int u2_overworld_save(u2_ctx *ctx, u2_overworld *ow, const u2_save_policy *pol)
{
    echo_cmd(ctx, U2_S_Q_PROMPT);

    /* The three location guards (asm/3DE4/3DFA). Only the outdoors gate has
     * live state yet: the engine has no planets until CP7 (DS:6D) and no
     * vehicles until CP6 (DS:13), so those two pass trivially — the policy
     * hooks exist so CP11 can open all three without touching this loop. */
    if (!pol->allow_indoors && ow->sector_lo != 0) {
        echo_cmd(ctx, U2_S_Q_OUTDOORS);
        return 1;
    }
    if (!pol->allow_off_earth) { /* DS:6D == 0: always Earth until CP7 */ }
    if (!pol->allow_in_vehicle) { /* DS:13 >= 0x78: always on foot until CP6 */ }

    echo_cmd(ctx, U2_S_Q_MOMENT);

    /* The save body, file 0x24FD: the entry pair takes the live position
     * (0x2520..0x2529) so the next 'P' restores exactly where the player
     * stood, then the sector and the record go to disk. */
    ctx->state.entry_x       = (uint8_t)ow->x;
    ctx->state.entry_y       = (uint8_t)ow->y;
    ctx->state.sector_first  = (uint8_t)ow->sector_hi;
    ctx->state.sector_second = (uint8_t)ow->sector_lo;

    /* The original rewrites the sector unconditionally; the engine's contract
     * is to store only dirty sectors (world.h), and nothing dirties tiles
     * until combat and town visits exist. The creature block is the other half of
     * that write — asm/2305 names MONXFF as well as MAPXFF — so a kill has to
     * reach the file here and not only on a sector transition. */
    if (ow->world.map_dirty)
        u2_world_store(ctx, &ow->world, 1);
    if (ow->world.mon_dirty)
        u2_world_store(ctx, &ow->world, 0);

    if (u2_save_store(ctx) != U2_SAVE_OK)
        return 1;
    return 0;
}

/* The food a PASS costs. Proven at file 0x0B11: `sbb $0x0a,%al` on the low
 * byte of the food triple, with `das` — ten, in packed decimal.
 * The constants below are the raw `sbb` immediates, NOT decimal counts: the
 * argument of food_spend() goes straight into a packed-decimal subtract. Writing
 * 10 here is safe only because 10 decimal and 0x0A are the same byte; the move
 * cost is not, which is how asm/2599's $0x19 once got ported as `19u` and
 * silently charged thirteen. */
#define U2_FOOD_PER_PASS 0x0Au

/* The food a step attempt costs, accepted or refused. Proven twice, inline in
 * the passability routine at runtime 0x2599 and 0x2626: `sbb $0x19` then `das`
 * on the food triple — nineteen in packed decimal, i.e. the byte 0x19.
 * Measured live 2026-10-25: 997904 -> 997885 for one arrow, accepted or blocked.
 * Both the accept and the reject arms carry it, so the drain belongs to movement
 * itself and not to any one travel mode — and horse and plane pay it twice over
 * (asm/2626_food_drain_mounted).
 * evidence: runtime 0x2599, 0x2626; live:stepcost — confidence: proven */
#define U2_FOOD_PER_MOVE 0x19u

/* The overworld is a torus. The accept path of the passability routine masks
 * both coordinates rather than bounds-checking them: runtime 0x2664 is
 * `and byte ptr DS:[0],0x3F` / `and byte ptr DS:[1],0x3F` then `mov al,0; ret`.
 * Confirmed live twice over: the player crossed x=63->0, and a monster wrapped
 * 63->0->1->2 while the player stood still.
 * evidence: runtime 0x2664; live wrap sightings 2026-10-21 — confidence: proven
 */
#define U2_SECTOR_MASK (U2_SECTOR_EDGE - 1)

/* How many idle input polls the original waits before it auto-PASSes.
 *
 * Mechanism proven, threshold not. The overworld wait loop polls the keyboard
 * with `call key_poll` (runtime 0x08CE), tests `cmp $0xff,%ah` for "no key"
 * (0x08D1), and advances a byte counter with `incb DS:21; jne <loop>` (0x08D6)
 * and a second one at 0x08F9. `incb` then `jne` is the iterate-until-wrap idiom,
 * so the timeout is a poll count, not a clock. There is no `INT 1Ah` anywhere in
 * the corpus and the only read of the BIOS tick at 0x40:6C is the startup RNG
 * seed in asm/0100, which rules out a hardware timer as the driver.
 *
 * The measured wall-clock figure was ~7.6 s at `--Cycles 3000`, which is an
 * artifact of that emulator setting and deliberately NOT encoded here.
 *
 * 256 is the width of the counter the original actually uses, chosen because it
 * is the one number the bytes support. It is a placeholder to be tuned against
 * feel once the engine is playable, not a recovered constant. Do not cite it as
 * proven. `DS:21` and `DS:22` also serve as damage-amount and direction-delta
 * scratch elsewhere, so the loop nesting at 0x0AC8..0x0B40 needs a proper
 * re-decode before a real threshold can be claimed.
 *
 * evidence: runtime 0x08CE, 0x08D1, 0x08D6, 0x08F9; PASS print 0x08FF/0x0940;
 *           -10 food at 0x090D — confidence: mechanism proven, threshold not
 */
#define U2_AUTO_PASS_POLLS 256

/* Which tile ids this file has actually measured, as a bitmask over 0..63.
 * Anything outside it is unmeasured: the engine still lets you step on it, but
 * it records the id here so a test or a capture run can see that the engine
 * guessed. A permissive default that announces itself beats a permissive
 * default that hides, which is the mistake this loop used to make. */
static uint64_t g_unmeasured_tiles;

uint64_t u2_overworld_unmeasured_tiles(void)
{
    return g_unmeasured_tiles;
}

/* On-foot passability, keyed on the ART INDEX of the destination cell.
 *
 * art = map_byte >> 2, established in docs/passability-findings.md F12 and used by
 * the renderer through u2_view_index(). Keying on art rather than the raw map byte
 * is what makes one rule cover the whole letter range: F13's letters A-Z are art
 * 0x20..0x39, which is map bytes 0x80..0xE4, and a per-map-byte table would need
 * 26 separate rows saying the same thing.
 *
 * THE DEFAULT IS DENY. The previous version of this function returned 1 for anything
 * it had not measured, and that single permissive line is why the owner could walk
 * through building walls, shop signs, doors and standing people. It was the wrong
 * way round: docs/passability-findings.md F13 measured that only three map bytes
 * (0x00, 0x08, 0x0C) appear in 25 or more of the 33 sector maps, so the overwhelming
 * majority of the 64 art entries are not ground at all — they are structures,
 * fixtures, borders and creatures. A world where the default is "walkable" turns
 * every one of those into a hole. Default-deny fails in the safe direction: an
 * unclassified tile stops the player and gets reported, instead of letting them walk
 * into a mountain and looking like a working game.
 *
 * Evidence grade per row is stated inline. `proven` = a blocked or accepted step
 * observed live; `owner` = the owner's report of the original, which outranks an
 * agent inference (AGENTS.md § 5) but is not a byte; `art-shape` = inferred from
 * what the bitmap depicts, the weakest grade here and marked so.
 */
/* asm/24B5_force_field_event — the cost of walking through a force field.
 *
 * The gate is `mov al,[ds:d6]; cmp al,0; je <damage>`: DS:D6 is items_held[0], the RING slot.
 * Non-zero prints "RING PROTECTS FROM FIELD!" and does nothing else. Zero takes the damage path,
 * which flashes and sounds and then subtracts with `stc; sbb al,0x10; das` on [DS:51] — the high
 * byte of the 4-digit packed-BCD HP at DS:51/52 — which is exactly minus 1000 in decimal. If that
 * subtract borrows (fewer than 1000 HP) the branch at file 0x271B goes to the death handler, so
 * this tile kills a weak character outright.
 *
 * Measured twice, independently: the g29-field capture (9999 -> 8999 -> 7999 -> 6999 -> 5999 ->
 * 4999 -> 3999, six crossings, and nothing with DS:D6 = 01) and fight-20261021-castle03 turn 2909
 * (HP_hi 0x88 -> 0x78 with DS:D6 = 0).
 *
 * The subtract is done in decimal rather than by replaying `das`. The engine is a reimplementation,
 * not a byte match, and the measured contract is "minus 1000, and death if that goes below zero".
 * Both branches print, so the owner's rule that every effect on the player announces itself holds.
 */
static void u2_force_field(u2_ctx *ctx)
{
    u2_state *st = &ctx->state;

    if (st->items_held[0] != 0) {
        seam_str_out(ctx, U2_S_FIELD_RING_PROTECTS);
        return;
    }

    seam_str_out(ctx, U2_S_FIELD_DAMAGE);

    /* BCD: the high byte holds the hundreds and thousands digits, so -0x10 there is -1000. A
     * borrow out of it is the original's death branch. */
    if (st->hp < 0x10u) {
        u2_death(ctx);
        return;
    }
    st->hp = (uint8_t)(st->hp - 0x10u);
}

/* On-foot passability — asm/2423's ladder, transcribed rather than re-derived.
 *
 * THE GATE VARIABLE IS `map_byte >> 1`, not the art index. asm/2FAD_vehicle_board_dispatch
 * recorded this as resolved on 2026-10-21 ([DS:14] = map_byte >> 1, measured on 53 of 54 walk
 * samples: 0x0C->0x06, 0x5C->0x2E, 0x70->0x38, 0x08->0x04), and the ladder at asm/25C0..25F6 tests
 * [DS:29] & 0x7F in exactly that space. The engine used to classify on `map_byte >> 2`, a third
 * quantity, and that mismatch is the root of every passability regression this project has had:
 * a per-tile deny table cannot express a rule that is "everything below a threshold, except two
 * bytes, plus a short list". Full write-up: docs/passability-findings.md F14.
 *
 * The ladder, in byte order (asm/25C0, 25CC, 25D0, 25D4..25F0, 25F4):
 *
 *   al = DS:29 & 0x7F
 *   al == 0x60            -> asm/2677 (stamp path; NOT a verdict, see the note below)
 *   al == 0x00, 0x08      -> reject          map 0x00 water, 0x10 mountain
 *   al in 22,24,26,28,
 *          2A,2C,2E,38    -> accept          map 0x44 horse, 0x48 ship, 0x4C PLANE, 0x50 rocket,
 *                                            0x54, 0x58, 0x5C force field, 0x70 town paving
 *   al >= 0x16            -> reject
 *   else                  -> accept          every map byte below 0x2C
 *
 * What this changes against the table it replaces, and why each one is an improvement rather than a
 * risk: it UNBLOCKS the four vehicle tiles (0x44/0x48/0x4C/0x50), the dungeon mouth and the
 * monument, all of which the old table refused on art-shape reasoning — the weakest grade in that
 * function. A vehicle tile you cannot stand on is a vehicle you cannot board, so those rows were
 * blocking content, not scenery. It KEEPS every blocker that was proven by walking or by bytes:
 * water, mountain, the A-Z sign letters (map 0x80..0xE4 all land at mode >= 0x40), the building
 * walls (0x74, 0x78), the humanoid figures (0x30..0x40, 0x60..0x6C) and the closed door 0xA0
 * (mode 0x50, rejected by the threshold — no special case needed any more).
 *
 * The 0x60 divert is deliberately NOT modelled. asm/2677 is unreviewed bulk-wave output whose only
 * call is map_tile_ptr; it is a stamp write, not an accept or a reject, and map 0xC0 is art 0x30,
 * one of the sign letters, which the old table also refused. Falling through to the threshold
 * reproduces that verdict. If asm/2677 is ever reviewed and turns out to accept, this is the line
 * that changes.
 *
 * Modes other than foot have their own arms (asm/2557 horse, asm/2619 ship, asm/2604 plane,
 * asm/2542 rocket) and are NOT handled here — see u2_mode_passable() below, and
 * docs/passability-findings.md F14 for the corrected reading of those arms.
 */
static int foot_ladder(unsigned mode)
{
    /* The two named rejections, both proven by walking: open sea (22 live rejects) and mountain
     * (blocked at (11,20)). Note these are map 0x00 and 0x10 — the ladder sees them shifted. */
    if (mode == 0x00u || mode == 0x08u)
        return 0;

    /* The eight named acceptances. Seven of them are the reason this rewrite exists: four vehicle
     * tiles, the dungeon mouth, and town paving, all of which must admit the player. */
    switch (mode) {
    case 0x22u: case 0x24u: case 0x26u: case 0x28u:   /* horse, ship, PLANE, rocket tiles */
    case 0x2Au: case 0x2Cu:                           /* map 0x54, 0x58                   */
    case 0x2Eu:                                       /* map 0x5C — the force field       */
    case 0x38u:                                       /* map 0x70 — town paving           */
        return 1;
    default:
        break;
    }

    return mode < 0x16u;      /* asm/25F4: `cmp $0x16,%al; jae reject`, else accept */
}

static int u2_tile_passable(const u2_world *w, int x, int y)
{
    return foot_ladder((u2_world_tile_at(w, x, y) >> 1) & 0x7Fu);
}

/* ---- the travel-mode arms of asm/2423 -------------------------------------
 *
 * asm/253B reads [DS:13] and branches, in address order, 0x28 rocket, 0x26 plane,
 * 0x24 ship, 0x22 horse, everything else foot. Each arm is a separate routine and the
 * bodies disagree with the summary they were first given, so what follows is a
 * transcription of the four bodies, not of the table in docs/passability-findings.md
 * F14 — which this corrects in two places, both recorded there.
 *
 *   asm/2542 (rocket)  `jmp L_0027fb`, and L_0027fb is `call L_0027ff; ret` where
 *                      L_0027ff is the reject return (`mov $0xff,%al; ret`). The rocket
 *                      REJECTS EVERY STEP and pays nothing. It is not the accept the
 *                      filename asm/25F8 suggested: file 0x25F8 is the foot ladder's own
 *                      default-accept fall-through, three instructions before the reject
 *                      return the rocket arm jumps into.
 *   asm/2619 (ship)    accept iff [DS:29] == 0x00. The second compare, `cmp $0x80` in
 *                      asm/2620, is unreachable: DS:29 is map_byte >> 1 and the largest
 *                      value that can reach it is 0xFC >> 1 = 0x7E. Water only, proven
 *                      live in captures/spice86/ship-port-boniface — the ship refused its
 *                      own dock tile and refused grass.
 *   asm/2557 (horse)   a delay loop, then `jmp L_002826` = asm/2626.
 *   asm/2604 (plane)   `call L_002826` = asm/2626, then its own forest reject.
 *   asm/2626 (mounted) subtract 19, `call L_002775` — which is the FOOT tail, so the
 *                      whole ladder runs — then reject mode 0x02 (map 0x04, shallows)
 *                      and 0x60 (the stamp divert) and accept everything else.
 *
 * So horse and plane are the foot ladder MINUS shallow water, and the plane is that
 * again MINUS forest. Not "the same ladder as foot", and not "flies over anything".
 * The shallows rejection is the new finding here: it is in asm/2626's body at
 * runtime 0x2855..0x285c and nobody had read it as a tile rule, because the file is
 * named for its food drain.
 *
 * Grade: bytes for every comparison above; measured for the ship (live capture) and for
 * the -38 that rides along with the mounted arms; inferred for the horse and the plane,
 * because neither was ever seen to walk in a capture — the two samples that set the mode
 * were forced pokes to DS:13 (asm/2626's caveat) or a BOARD that preceded a LAUNCH.
 */
int u2_mode_passable(const u2_world *w, int x, int y, uint8_t stamp)
{
    const unsigned raw = u2_world_tile_at(w, x, y) >> 1;
    const unsigned mode = raw & 0x7Fu;

    switch (stamp) {
    case U2_MODE_ROCKET:
        return 0;                       /* asm/2542 -> asm/25FB: unconditional reject */

    case U2_MODE_SHIP:
        return raw == 0x00u;            /* asm/2619: no mask, and 0x80 cannot happen */

    case U2_MODE_HORSE:
    case U2_MODE_PLANE:
        /* asm/2626 calls the foot tail, so the ladder is the first gate... */
        if (!foot_ladder(mode))
            return 0;
        /* ...and then adds two of its own. 0x60 is already refused by the threshold above
         * (0x60 >= 0x16), but the bytes test it explicitly ahead of the ladder's divert, so
         * this does too rather than relying on the coincidence. */
        if (mode == 0x02u || mode == 0x60u)
            return 0;
        /* asm/2604: the plane's own reject, and the only tile it adds. */
        if (stamp == U2_MODE_PLANE && mode == 0x06u)
            return 0;
        return 1;

    default:
        return foot_ladder(mode);        /* foot, and any stamp value the dispatch misses */
    }
}

/* Public test surface for the passability verdict on a raw map byte.
 *
 * u2_tile_passable() is static because nothing outside this file should decide
 * movement — but the gate rule regressed on 2026-10-27 (the default-deny rewrite
 * blocked arts 0x06/0x07/0x09, sealing every town in the game) and nothing in the
 * suite could see it, because the verdict was unreachable from a test. A rule that
 * broke by being argued in a comment needs a probe that can actually be asserted.
 */
int u2_tile_walkable_byte(uint8_t map_byte)
{
    /* The static helper reads the world grid, so drive it through a one-cell world
     * rather than duplicating its logic here — a copy would drift, which is the
     * whole failure mode this project keeps recording. */
    static u2_world w;
    w.map_loaded = 1;
    memset(w.map, 0, sizeof w.map);
    w.map[0] = map_byte;
    return u2_tile_passable(&w, 0, 0);
}

/* Doors. asm/433E_sub_433e.asm + asm/435E_sub_435e.asm, in order:
 *   mov 0x65,%al ; or %al,%al ; jne  ->  no keys prints "NO KEYS THAT FIT!"
 *   stc ; sbb $0x1,%al ; das ; cmc ; mov %al,0x65
 *                                    ->  consumes exactly one key, BCD subtract
 *   mov 0x14,%al ; add %al,%al ; ... ; mov %al,(%bx)
 *                                    ->  overwrites the map cell with a new tile,
 *                                       which is how the door stays open
 * The engine has no OPEN command yet, so nothing calls this. It is here because the
 * rule is proven and the surface is not; wiring it is a separate ticket. The written
 * tile byte is now NAMED, not invented: DS:14 is the tile under the player >> 1, so
 * DS:14*2 paves the door with the ground you are standing on (two live reads agree:
 * sector 32 on 0x08 gave DS:14=4, sector 20 on 0x0C gave DS:14=6). The write goes
 * through the cell pointer asm/50B3_map_tile_ptr caches at DS:06, i.e. into the live
 * sector grid. See docs/needs-gameplay.md G30 and asm/435E_open_write_tile.asm.
 * One structural constraint the engine must reproduce: UNLOCK is horizontal-only.
 * asm/4309 refuses when DS:19 == 0 and asm/4326 computes (x + DS:19, y) with no Y
 * term, so a north or south aim can never open anything. Doors are currently just
 * impassable, which is the honest half of the behaviour rather than the whole of it.
 */

/* The UNLOCK verdict, as a pure function so a test can drive every branch without a
 * world. asm/4309 -> 4310/4326 -> 433A -> 433E -> 4345/435E, in that order:
 *   no sideways aim  -> "NO DOOR THERE!"   (DS:19 == 0 falls straight through)
 *   cell != 0xA0     -> "NO DOOR THERE!"
 *   keys == 0        -> "NO KEYS THAT FIT!"
 *   otherwise        -> one key spent, cell paved
 * The first case is not a nicety: asm/4326 computes (x + DS:19, y) and never touches a
 * Y delta, so a north or south aim has no target to test and the original answers
 * "NO DOOR THERE!" before looking at anything. */
int u2_unlock_rule(int dx, uint8_t target_tile, int keys)
{
    if (dx == 0)
        return U2_UNLOCK_NO_AIM;
    if (target_tile != 0xA0)
        return U2_UNLOCK_NO_DOOR;
    if (keys <= 0)
        return U2_UNLOCK_NO_KEYS;
    return U2_UNLOCK_OPENED;
}

/* asm/435E: `mov 0x14,%al ; add %al,%al`, and DS:14 is the tile under the player >> 1
 * (two live reads: sector 32 on 0x08 gave DS:14 = 4, sector 20 on 0x0C gave DS:14 = 6).
 * So the door is paved with the ground the unlocker is standing on, low bit cleared. */
uint8_t u2_unlock_replacement(uint8_t ground_tile)
{
    return (uint8_t)((ground_tile >> 1) << 1);
}

/* asm/435E's key spend: `stc ; mov 0x65,%al ; cmc ; sbb $0x1,%al ; das ; cmc`. The
 * stc/cmc pair only clears carry before the subtract -- it is a BCD minus one, not a
 * minus two, which is the reading a careless pass on those five bytes produces. */
uint8_t u2_unlock_spend_key(uint8_t keys)
{
    unsigned out = 0;
    (void)bcd_sbb(keys, 1, 0, &out);
    return (uint8_t)out;
}


/* Public wrapper over the same subtraction the PASS arm uses, so a test can
 * drive it directly. Returns 1 when the subtraction underflowed (death), and
 * runs the death tail in that case, because that is what the borrow-out does.
 * `bcd_sub` is the packed-decimal immediate the original feeds `sbb`: 0x0A for a
 * PASS, 0x19 for a step. Not a decimal count. */
int u2_overworld_spend_food(u2_ctx *ctx, unsigned bcd_sub)
{
    if (!food_spend(ctx, bcd_sub))
        return 0;
    u2_death(ctx);
    return 1;
}

/* How many 19-food charges one step attempt costs in the mode the player is in.
 * asm/253B's dispatch: the foot tail and the mounted tail are the two that reach a
 * drain, and asm/2626 reaches it twice because it subtracts once and then calls the
 * foot tail, which subtracts again. The ship and rocket arms never get there. */
static int step_charges(uint8_t stamp)
{
    switch (stamp) {
    case U2_MODE_SHIP:
    case U2_MODE_ROCKET:
        return 0;
    case U2_MODE_HORSE:
    case U2_MODE_PLANE:
        return 2;
    default:
        return 1;
    }
}

/* The step charge, as the original orders it: charge first, verdict afterwards, so a
 * refused step pays and a step that starves never prints its complaint. Two subtracts
 * rather than one of 38 because that is the shape of asm/2626 — and the shape matters
 * at the bottom of the tank, where the first borrow goes to the starvation tail and
 * the second subtract never runs. */
int u2_overworld_step_food(u2_ctx *ctx)
{
    for (int i = 0; i < step_charges(ctx->state.player_stamp); i++) {
        if (food_spend(ctx, U2_FOOD_PER_MOVE)) {
            u2_death(ctx);
            return 1;
        }
    }
    return 0;
}

/*
 * One PASS: the echo, the 10-food charge, and the sweep.
 *
 * Three call sites in the engine, and they are three sites in the original too, which is
 * why this is a function and not a copy:
 *
 *   the walk loop's own first arm — asm/0936's `cmp $0x20,%al` at file 0x0B3C, the space
 *   bar, which is NOT a command letter and never touches the jump table;
 *   asm/3DBC_cmd_P — PASS as a command letter, reached by `jmp *%bx` through cs:0730;
 *   the idle auto-PASS at asm/08FF, which prints the same word and falls into the same
 *   10-food subtract at asm/090D.
 *
 * All three end at asm/0A33_cmd_done, so all three get the CR and the fresh prompt, and
 * echo_cmd() supplies that here rather than each caller repeating it.
 *
 * evidence: file 0x0B3C, asm/3DBC, runtime 0x08FF/0x090D — confidence: mechanism proven;
 *           the threshold that decides WHEN the idle arm fires is not (see
 *           U2_AUTO_PASS_POLLS).
 */
void u2_overworld_pass(u2_ctx *ctx, u2_overworld *ow)
{
    echo_cmd(ctx, U2_S_PASS);
    if (food_spend(ctx, U2_FOOD_PER_PASS))
        u2_death(ctx);
    creature_turn(ctx, ow);
}

/*
 * asm/3389 cmd_E: enter the site standing on this cell.
 *
 * Three refusals and one transition, in the original's order:
 *
 *   inside a site ([DS:4A] != 0) — the answer is " WHAT?"; doors are a world-map thing.
 *   not on foot ([DS:13] < 0x78) — ONLY ON FOOT!, from asm/33A6, where [DS:13] is the
 *      sprite stamped into the cell. The engine has no vehicles yet, so the stamp is 0x78
 *      at open and this gate cannot fire; it is here so a vehicle implementation finds it
 *      already in place rather than inventing one.
 *   nothing on this cell — " WHAT?" again, via the tile-to-sector-digit table.
 *   otherwise — the label if the site has one, then the transition.
 *
 * No food and no creature sweep on any path: entering is not a step and not a turn. That is
 * the reading the walk loop already had, moved here unchanged.
 *
 * evidence: asm/3389 (the handler), asm/33A6 (the on-foot test), asm/341E (the entry point
 *           stored by site_enter), asm/342A (the street arrival cell) — confidence: the
 *           refusals are read off the handler, the transition is the CP4 site work.
 */
void u2_overworld_enter(u2_ctx *ctx, u2_overworld *ow)
{
    seam_str_out(ctx, U2_S_ENTER);
    if (ctx->state.sector_second != 0) {
        seam_str_out(ctx, U2_S_ENTER_WHAT);
        seam_char_print(ctx, '\r');
        seam_str_out(ctx, U2_S_CMD_PROMPT);
        return;
    }
    if (ctx->state.player_stamp < 0x78) {
        seam_str_out(ctx, U2_S_ONLY_ON_FOOT);
        seam_char_print(ctx, '\r');
        seam_str_out(ctx, U2_S_CMD_PROMPT);
        return;
    }
    const char *label = NULL;
    int ax = 0, ay = 0;
    const int digit = site_for_tile(u2_world_tile_at(&ow->world, ow->x, ow->y),
                                    &label, &ax, &ay);
    if (digit == 0) {
        seam_str_out(ctx, U2_S_ENTER_WHAT);
        seam_char_print(ctx, '\r');
        seam_str_out(ctx, U2_S_CMD_PROMPT);
        return;
    }
    if (label) seam_str_out(ctx, label);
    seam_char_print(ctx, '\r');
    site_enter(ctx, ow, digit, ax, ay);
    seam_str_out(ctx, U2_S_CMD_PROMPT);
}

/* Shared loader: everything after the spawn fields are set. */
static int overworld_open(u2_ctx *ctx, u2_overworld *ow)
{
    /* Tiles first: without art there is nothing to draw, and the reason the
     * player needs to hear is specific (no --data-dir vs a corrupt cache). */
    u2_tiles_result tr;
    if (ctx->cleanroom) {
        /* Opt-in substitute art, and announced: the source string names it and
         * the notice goes to stderr, so a screen drawn with substitute tiles can
         * never be mistaken for one drawn with the player's own. */
        tr = u2_tiles_builtin(&ow->tiles);
        if (tr == U2_TILES_OK) {
            fprintf(stderr, "u2: cleanroom assets: tiles from %s\n",
                    ow->tiles.source);
        }
    } else {
        tr = u2_tiles_open(ctx, &ow->tiles, NULL, 0, NULL, 0);
    }
    if (tr != U2_TILES_OK) {
        snprintf(ow->note, sizeof ow->note, "tiles: %s", u2_tiles_result_text(tr));
        return -1;
    }

    u2_world_result wr = u2_world_open(ctx);
    if (wr != U2_WORLD_OK) {
        snprintf(ow->note, sizeof ow->note, "content directory: %s",
                 u2_world_result_text(wr));
        return -1;
    }

    u2_sector_id id = { (uint8_t)ow->sector_hi, (uint8_t)ow->sector_lo };
    wr = u2_world_load(ctx, &ow->world, 1, id);
    if (wr != U2_WORLD_OK) {
        snprintf(ow->note, sizeof ow->note, "sector %d%d: %s",
                 ow->sector_hi, ow->sector_lo, u2_world_result_text(wr));
        return -1;
    }

    /* The two bytes the original carries into the world and the engine never set
     * until site entry needed them: DS:13 is the sprite stamped into the map cell
     * (0x78 on foot, constant across every in-world capture) and DS:12 is the view
     * mode, 0xFF in-world and 4 inside a site. cmd_E's on-foot gate reads the
     * first, so without this it would answer "-ONLY ON FOOT!".
     * The overworld already carried 0xFF locally in ow->view_mode; now the
     * state block agrees with it. */
    ctx->state.player_stamp   = 0x78;
    ctx->state.view_mode      = ow->view_mode;

    /* CP5 W1 wiring: the creature table. asm/22D5 reads 256 bytes of monxNN into
     * DS:137 on the same sector load that reads the map, and u2_monsters_spawn
     * copies those six arrays into the state block the attack and (later) the
     * alarm read from.
     *
     * A missing monx is NOT fatal and says so in the note rather than emptying the
     * world silently: 17 of the 33 sectors author no monsters at all
     * (docs/monster-spawn.md § 6), and the original's own FCB open would simply
     * find nothing there. */
    const u2_world_result mr = u2_world_load(ctx, &ow->world, 0, id);
    const int creatures = (mr == U2_WORLD_OK) ? u2_monsters_spawn(ctx, &ow->world) : 0;
    if (mr == U2_WORLD_OK)
        u2_monsters_clear_spawn_cells(ctx, &ow->world);

    /* The status band and the command prompt, printed once on entering the
     * world (CP4b task 1). The four value lines go through the proven status
     * sites (asm/50F9..5175, packed BCD); the prompt is asm/087D's "CMD: "
     * at row 23 col 0, leaving the cursor at col 5 where the next echo
     * lands — the same position the fresh-state screenshot shows. */
    u2_status_draw(ctx);
    seam_goto(ctx, 0, U2_MSG_BOTTOM);
    seam_str_out(ctx, U2_S_CMD_PROMPT);

    snprintf(ow->note, sizeof ow->note,
             "sector %d%d via %s, %s%s, %d creature%s%s",
             ow->sector_hi, ow->sector_lo,
             ow->world.map_prefix ? ow->world.map_prefix : "?",
             strncmp(ow->tiles.source, "builtin:", 8) == 0
                 ? "cleanroom tiles"          /* substitute art, named as such */
                 : (ow->tiles.from_cache ? "tiles from cache" : "tiles extracted"),
             ow->tiles.unverified && strncmp(ow->tiles.source, "builtin:", 8) != 0
                 ? " (unverified)" : "",
             creatures, creatures == 1 ? "" : "s",
             mr == U2_WORLD_OK ? "" : " (no monx file)");
    return 0;
}

/* Apply a --load-ds checkpoint after everything that would overwrite it has run.
 *
 * The save load places the persisted 256 bytes, and overworld_open then loads mapx and monx and
 * positions the player from entry_x/entry_y. Together those clobber the player position, the
 * creature arrays and the RNG register — exactly the fields a mid-session checkpoint carries and
 * the save does not. So the checkpoint has to land after all of it, and then re-sync the
 * overworld's own copies: the draw path mirrors ow->x/ow->y back into DS:00/01 every frame, so a
 * resumed position left only in the state would be erased on the first frame. That is not
 * hypothetical — loading before overworld_open produced exactly that, a checkpoint that read back
 * correct and then silently reverted to the entry point.
 *
 * The grid is rebuilt from the resumed arrays as well, because it was stamped from the freshly
 * loaded monx; without the restamp the first frame draws the world as it was at load rather than
 * as the checkpoint left it.
 */
static int overworld_resume(u2_ctx *ctx, u2_overworld *ow)
{
    if (!ctx->load_ds_path)
        return 0;

    const int sec_hi = ow->sector_hi, sec_lo = ow->sector_lo;
    if (u2_state_load_ds(&ctx->state, ctx->load_ds_path) != 0)
        return -1;
    if ((int)ctx->state.sector_first != sec_hi || (int)ctx->state.sector_second != sec_lo) {
        fprintf(stderr, "u2: checkpoint names sector %u%u but the world loaded %u%u; "
                        "point --data-dir at the sector the recording used\n",
                ctx->state.sector_first, ctx->state.sector_second, sec_hi, sec_lo);
        return -1;
    }
    ow->x = ctx->state.sector_x;
    ow->y = ctx->state.sector_y;
    u2_monsters_restamp(ctx, &ow->world);
    return 0;
}

int u2_overworld_init(u2_ctx *ctx, u2_overworld *ow)
{
    if (!ctx || !ow) return -1;
    memset(ow, 0, sizeof *ow);
    ow->x = U2_OVERWORLD_PROBE_X;
    ow->y = U2_OVERWORLD_PROBE_Y;
    ow->sector_hi = U2_OVERWORLD_PROBE_SECTOR_HI;
    ow->sector_lo = U2_OVERWORLD_PROBE_SECTOR_LO;
    ow->view_mode = 0xFF;         /* DS:12 in the live capture */
    if (overworld_open(ctx, ow) != 0) return -1;
    return overworld_resume(ctx, ow);
}

/*
 * Spawn from the loaded player record — the 'P' path, proven in the re-decode
 * of file 0x09E6..0x0A7F: the game reads PLAYER, reads MONSTERS, reads the
 * sector named by [DS:49][DS:4A], sets mode 4, then copies [DS:5A]->[DS:00]
 * and [DS:5B]->[DS:01] and stamps DS:12 = 0xFF (the view mode, matching
 * the live capture). The sector digits and the entry pair all come from the
 * record, so a loaded character stands where the save left it.
 *
 * The second digit is read from state.sector_second immediately after the
 * load; the overworld captures the digits into ow at open time.
 */
int u2_overworld_init_state(u2_ctx *ctx, u2_overworld *ow)
{
    if (!ctx || !ow) return -1;
    memset(ow, 0, sizeof *ow);
    ow->x = ctx->state.entry_x;
    ow->y = ctx->state.entry_y;
    ow->sector_hi = ctx->state.sector_first;
    ow->sector_lo = ctx->state.sector_second;
    ow->view_mode = 0xFF;         /* file 0x0A67: mov $0xff,[0x12] */
    if (overworld_open(ctx, ow) != 0) return -1;
    return overworld_resume(ctx, ow);
}

void u2_overworld_draw(u2_ctx *ctx, u2_overworld *ow)
{
    /* Keep the original's own position mirror current. DS:00/01 is the player position in the
     * captured segment — it read back as the seeded entry point in every live capture — and the
     * engine kept the live coordinate only in ow->x/ow->y, so every turn log reported a position of
     * 0,0 and a recording could not answer "where was the player standing". Mirroring here rather
     * than at each movement site means the log and the frame are taken from the same instant.
     */
    ctx->state.sector_x = (uint8_t)ow->x;
    ctx->state.sector_y = (uint8_t)ow->y;
    /* The last argument is DS:12 -- a mode byte, not a tile. The fill loop only
     * reaches for it when no sector is resident; see core/view.c. */
    u2_view_fill(&ow->view, &ow->world, ow->x, ow->y,
                 ow->view_mode, NULL, U2_OVERWORLD_EMPTY_GATE);

    u2_frame_clear(&ow->frame, U2_CGA_BLACK);
    /* The player is not terrain: the game's own staging buffer holds 0x78 at the
     * player's cell, which halves to art 60, a humanoid figure. That is evidence
     * from the captured DS rather than a guess, so the real sprite is drawn. */
    u2_frame_draw_view(&ow->frame, &ow->view, &ow->tiles,
                       U2_OVERWORLD_PLAYER_ART,
                       U2_VIEW_PLAYER_COL, U2_VIEW_PLAYER_ROW);

    /* One framebuffer, per the CP4b decision: the map window owns pixel rows
     * 0..159 and the text grid owns rows 20..24 — status block, CMD prompt
     * and message history. The grid is the same storage the terminal renderer
     * paints, so both backends show identical text with no second model. */
    u2_font_draw_vram_rows(&ow->frame, &ctx->vram, U2_MSG_TOP, U2_ROWS - 1);

    /* Dumped here rather than at the command sites because this is the one place
     * the frame is known to be composed: a log written before the draw would show
     * the state *before* the turn it is labelled with, which is an off-by-one that
     * looks exactly like working output. */
    if (ow->turns != ow->logged_turn) {
        ow->logged_turn = ow->turns;
        /* Refreshed here because this is the one place the composed frame, the grid and the
         * creature arrays are all known to be current, for the same reason the log itself is
         * written here: measured anywhere earlier it would describe the turn before it is
         * labelled with. */
        ctx->diag_ghosts = u2_monsters_ghost_cells(ctx, &ow->world);
        u2_turnlog(ctx, &ow->frame, ow->turns);
    }
}

int u2_overworld_run(u2_ctx *ctx, u2_overworld *ow)
{
    if (u2_overworld_init(ctx, ow) != 0) {
        fprintf(stderr, "overworld: %s\n", ow->note);
        return -1;
    }
    return u2_overworld_loop(ctx, ow);
}

/*
 * The ATTACK command, once its direction has arrived. Order follows the original's
 * chain: asm/2B8F_cmd_A prints "ATTACK--" and falls into asm/2B9B (a site-kind
 * gate), then asm/2BA5_attack_arms_gate, then the roll at asm/2BD7/2BDA, then
 * asm/2BEC ("--HIT!!!") or asm/2E09 ("--MISS"); a kill adds asm/2E3D's reward
 * line. The direction word is printed WITHOUT a CR because "ATTACK--" is already
 * sitting on the line — the live frame reads `CMD: ATTACK--EAST--HIT!!!`.
 *
 * Not modelled, and said out loud rather than guessed:
 *   - the site-kind gate (asm/2B9B tests [DS:4A] against 4). The engine has
 *     u2_site_kind but the branch's two destinations are unreviewed, so no
 *     refusal is invented here;
 *   - any food cost for swinging. The proven action costs are $0A for PASS and
 *     $19 for a move (asm/2599, asm/2626); neither is shown to cover ATTACK;
 *   - the map-cell stamp clear on a kill (asm/2E3D file 0x30F4). The engine
 *     draws creatures from the arrays rather than stamping them into the map, so
 *     there is no stamp to remove.
 */
static void attack_dir(u2_ctx *ctx, u2_overworld *ow, const char *word, int dx, int dy)
{
    seam_str_out(ctx, word);                  /* continues the ATTACK-- line */

    /* asm/2BA5_attack_arms_gate: [DS:26C] non-zero refuses the swing before any
     * roll, and says so. This is the byte proof that arms paralysis stops you
     * fighting while legs paralysis stops you moving — two counters, two gates,
     * two commands, which no single boolean flag can express. */
    if (ctx->state.paral_arms != 0) {
        seam_str_out(ctx, U2_S_PARALYZED);
        seam_char_print(ctx, '\r');
        seam_str_out(ctx, U2_S_CMD_PROMPT);
        return;
    }

    const int tx = (ow->x + dx) & U2_SECTOR_MASK;
    const int ty = (ow->y + dy) & U2_SECTOR_MASK;
    const int slot = u2_monsters_at(ctx, tx, ty);

    u2_attack a;
    memset(&a, 0, sizeof a);
    const int r = (slot >= 0) ? u2_combat_attack(ctx, slot, &a) : 0;

    /* An empty cell is a miss, not a refusal: the original's target scan walks all
     * 32 slots and falls through to the MISS printer when nothing matches
     * (asm/2E3D file 0x307A -> 0x3164). INFERRED, not proven: that scan compares
     * [DS:23]/[DS:24]/[DS:25] and the code filling them for an attack is untraced,
     * so "the adjacent cell in the direction" is what the captures show rather
     * than what the bytes have yet said. */
    if (r == 0) {
        seam_str_out(ctx, U2_S_MISS);
        seam_char_print(ctx, '\r');
        seam_str_out(ctx, U2_S_CMD_PROMPT);
        return;
    }

    seam_str_out(ctx, U2_S_HIT);

    /* asm/2BE9 is three bytes: `call L_00133a`, then it falls into the "--HIT!!!"
     * printer at asm/2BEC. So the alarm rings before the player is told they
     * landed, and a miss never reaches it — which is exactly what § 16 measured
     * (a landed blow alerts the sector, a missed swing alerts nothing). */
    u2_ai_alarm(ctx);

    /* asm/0C33: the status counters tick here, on the damage path.
     * THE SITE GATE THAT USED TO WRAP THIS WAS WRONG, and it stranded the player.
     * An earlier reading of asm/0C1F took `cmp [DS:4A],0 ; jne L_000e33` as a gate on the tick,
     * so the engine only decremented inside a village/town/castle/tower/dungeon. On the open
     * world -- sector ones digit 0, which is where the noVNC build drops you -- a 0..15 turn
     * paralysis then never expired. The owner caught it by playing, not by reading.
     * The branch is the opposite of a gate. Read the layout:
     *     c29  jne 0xc33          ; in a site: jump OVER the world-map block, LAND ON the tick
     *     c2b  mov al,0xff ; mov [DS:12],al
     *     c30  call 0x26f9        ; world-map-only work
     *     c33  <tick>             ; <-- BOTH paths arrive here, one by jump, one by fall-through
     * The DS:4A test only picks DS:12 = 4 versus 0xFF and whether 0x26f9 runs. Every path reaches
     * the tick, so the counters always decay.
     * Still not proven: how many times one turn enters this path. One entry is one decrement, and
     * the only measurement ever taken saw 15 decrements in ~0.7 s inside a castle, which is
     * consistent with repeated entries per turn. The engine ticks once per wound and says so.
     * asm/0C33 skips a counter that is already zero, which is why sleeping does not go negative. */
    /* (the status counters used to tick here, once per wound. They live in creature_turn() now:
     * a breakpoint on asm/0C33 shows one tick per turn, food -10 each time, so a wound is not the
     * trigger. See the note there.) */
    /* The reward lands on its OWN line, prompt and all — live frame reads
     *   CMD: ATTACK--EAST--HIT!!!
     *   CMD: KILLED--GOLD+1--EXP.+02
     * so the HIT line is closed before the reward line opens. asm/2E3D prints
     * "HIT!" and the reward strings from one routine, and the line breaks come
     * from the same str_out/CR compound the rest of the CMD window uses.
     * The gains are printed, not the totals, and the two fields print
     * differently: gold unpadded, exp two digits. */
    seam_char_print(ctx, '\r');
    seam_str_out(ctx, U2_S_CMD_PROMPT);
    if (r == 2) {
        char num[8];
        /* The dead creature's cell goes back to terrain. asm/2E3D clears the
         * record — hp, type and kind — and the grid is a derived view (map_base
         * plus the live stamps), so re-stamping after the clear is what puts the
         * floor back. This used to write 0x80 into the cell instead, on the
         * strength of `movb $0x80,(%bx,%si)` at file 0x30F4. That byte is a
         * staging-space flag, not a map byte: in map space the renderer's >>2
         * turns it into art 32, the first letter glyph, so the engine left a
         * letter A on the grass for the rest of the visit.
         * captures/spice86/cp5-fight/screen3.png -> screen4.png (sector 31, a
         * town) shows the original leaving plain floor. */
        u2_monsters_restamp(ctx, &ow->world);
        /* And the cleared record has to reach the sector buffer, or a save writes
         * the monster back out alive. asm/2305 carries both FCB names — MAPXFF at
         * file 0x2538 and MONXFF at 0x2548 — so the original rewrites the creature
         * block as well as the map (docs/phase4-implementation.md, the asm/2305
         * row). */
        u2_monsters_store(ctx, &ow->world);
        seam_str_out(ctx, U2_S_KILLED);
        snprintf(num, sizeof num, "%u", (unsigned)a.gold);
        seam_str_out(ctx, num);
        seam_str_out(ctx, U2_S_EXP_PLUS);
        snprintf(num, sizeof num, "%02u", (unsigned)a.exp);
        seam_str_out(ctx, num);
        u2_status_draw(ctx);          /* gold and exp moved */
        seam_char_print(ctx, '\r');
        seam_str_out(ctx, U2_S_CMD_PROMPT);
    }
}

int u2_overworld_loop(u2_ctx *ctx, u2_overworld *ow)
{
    ctx->frame = &ow->frame;

    int idle_polls = 0;     /* polls since the last key, for the auto-PASS */

    for (;;) {
        u2_overworld_draw(ctx, ow);
        if (seam_present_frame(ctx)) break;      /* window closed */

        u2_key k;
        const int r = seam_key_poll(ctx, &k);
        if (r < 0) break;
        if (r == 0) {
            /* A window close (SDL_QUIT) or an exhausted script sets exit_code /
             * input_exhausted without returning a key; seam_key_poll collapses
             * both to 0, so the flag test is the only place the overworld can
             * see them. The title flow does the same via flow_stopped()
             * (title.c); without this the loop spun forever after the player
             * closed the window mid-game. */
            if (ctx->exit_code || ctx->input_exhausted) break;

            /* Idle auto-PASS. The original advances time while the player
             * thinks: after enough polls with no input it performs a PASS,
             * costing food and letting monsters step. Headless runs are exempt
             * on purpose — scripted input must stay byte-exact against the CP2
             * baseline, and a poll-count timeout would make test outcomes depend
             * on how fast the harness spins the loop. */
            if (ctx->mode != U2_MODE_HEADLESS) {
                const int limit = ctx->auto_pass_polls == 0
                                ? (int)U2_AUTO_PASS_POLLS
                                : ctx->auto_pass_polls;
                if (limit > 0 && ++idle_polls >= limit) {
                    idle_polls = 0;
                    /* If a command is half-typed, the PASS closes that same line:
                     * `CMD: ATTACK--PASS`, exactly as the live capture shows. */
                    ow->pending_cmd = 0;
                    u2_overworld_pass(ctx, ow);
                    /* Not modelled: the original also steps every monster on
                     * this tick, observed live as one cell per auto-PASS while
                     * the player stood still. That is now what creature_turn
                     * does — the observed one cell is the diagonal step at
                     * asm/212e, two cells of Manhattan distance in one turn. */
                    continue;
                }
            }
            seam_wait_ms(ctx, 16); continue;               /* ~60 fps cadence */
        }
        idle_polls = 0;                                    /* any key resets it */
        /* No quit key by default. The original has none anywhere in the overworld -- nothing
         * in asm/ compares against 0x1b -- and this line was a development convenience that
         * read as fidelity. --dev is the sanctioned home for that, and Ctrl-Q is the byte:
         * nothing in asm/ compares against 0x11 either, so it cannot collide with play. The
         * check lives in the loop and not in a command handler, which is the exact mistake
         * being undone. */
        if (ctx->dev && k.ch == 0x11) break;

        int dx = 0, dy = 0;
        const char *word = NULL;
        switch (k.ch) {
        case U2_KEY_UP:    dy = -1; word = U2_S_DIR_NORTH; break;
        case U2_KEY_DOWN:  dy =  1; word = U2_S_DIR_SOUTH; break;
        case U2_KEY_RIGHT: dx =  1; word = U2_S_DIR_EAST;  break;
        case U2_KEY_LEFT:  dx = -1; word = U2_S_DIR_WEST;  break;
        case ' ':
            /* Space is PASS from the walk loop's own first arm (cmp $0x20 at file
             * 0x0B3C). 'P' is PASS too, but from the command jump table (asm/3DBC_cmd_P,
             * cs:0730 entry P) and it is handled in commands.c as cmd_P — the two are
             * separate sites in the original and only one of them is a command letter,
             * so they no longer share an arm here. Both reach u2_overworld_pass(). */
            u2_overworld_pass(ctx, ow);
            continue;
        default:
            /* The command jump table. asm/0A1F is the only route to the 26 handlers and it
             * is reached for every letter key, so the engine routes letters through the same
             * shape rather than growing this switch: range test, table index, dispatch, and
             * the shared cmd_done epilogue lives in commands.c with the handlers.
             *
             * U2_CMD_UNKNOWN deliberately does NOT print anything yet. The original's
             * out-of-range arm is asm/0A1C -> L_002475, and the illegal-command message is a
             * different site again; neither is wired, and printing a guess here would be the
             * invention the project's rules exist to stop. Falling through is the honest
             * no-op: the key is consumed, nothing happens, no turn passes. */
            {
                const u2_cmd_result cr = u2_cmd_dispatch(ctx, ow, k.ch);
                if (cr == U2_CMD_AWAIT)
                    continue;
                if (cr == U2_CMD_DONE) {
                    /* The handler printed its message and the CR + prompt. Whether the
                     * post-command sweep runs here is per-handler and unproven for these
                     * two, so no creature_turn() -- see the note in commands.c. */
                    continue;
                }
                continue;
            }
        }

        /* A direction arriving while UNLOCK DIRECTION- is on the line answers the
         * unlock and is not a step. asm/4310 and asm/4345 both end at jmp L_000c30 and
         * asm/435E at jmp L_000c33, and every one of those reaches cmd_done, so the
         * post-command sweep runs on the refusal as well as on the success -- the same
         * consequence § 15.2 of docs/monster-spawn.md derives for the command path in
         * general. The player does not move. */
        if (ow->pending_cmd == 'U' && word != NULL) {
            ow->pending_cmd = 0;
            const int tx = ow->x + dx;
            const int ty = ow->y;
            const int off = tx < 0 || tx >= U2_SECTOR_EDGE || ty < 0 || ty >= U2_SECTOR_EDGE;
            const uint8_t target = off ? 0 : u2_world_tile_at(&ow->world, tx, ty);
            switch (u2_unlock_rule(dx, target, ctx->state.keys)) {
            case U2_UNLOCK_NO_AIM:
            case U2_UNLOCK_NO_DOOR:
                /* One print, not two: the original has a single NO DOOR THERE! site
                 * (asm/4310) and reaches it from both causes. */
                seam_str_out(ctx, U2_S_NO_DOOR_THERE);
                break;
            case U2_UNLOCK_NO_KEYS:
                seam_str_out(ctx, U2_S_NO_KEYS_FIT);
                break;
            default: {
                /* asm/435E: spend one key, then pave the cell with the ground the
                 * player is standing on. */
                ctx->state.keys = u2_unlock_spend_key(ctx->state.keys);
                const uint8_t ground = u2_world_tile_at(&ow->world, ow->x, ow->y);
                u2_world_tile_put(&ow->world, tx, ty, u2_unlock_replacement(ground));
                break;
            }
            }
            seam_char_print(ctx, '\r');
            seam_str_out(ctx, U2_S_CMD_PROMPT);
            creature_turn(ctx, ow);
            continue;
        }

        /* A direction arriving while ATTACK-- is on the line is the attack's
         * direction, not a step: the original consumed it inside the cmd_A chain
         * and never moved the player. Live: `ATTACK--EAST--HIT!!!` with the
         * player standing still. */
        if (ow->pending_cmd == 'A' && word != NULL) {
            ow->pending_cmd = 0;
            attack_dir(ctx, ow, word, dx, dy);
            /* The swing is the turn: the original's monsters advance on the
             * expiry of a half-typed `A` too (`ATTACK--PASS`), so an attack that
             * was actually completed cannot sensibly advance nothing.
             *
             * And the ARMS-PARALYSIS REFUSAL is a turn as well. This used to be
             * `if (ctx->state.paral_arms == 0) creature_turn(...)`, which made arm
             * paralysis permanent for anyone who kept trying to swing - the same stranding
             * the owner had already reported for legs. Two independent proofs, both found
             * without a new capture:
             *
             * BYTES: the refusal is asm/2BAD, whose whole tail is `jmp L_000c30`. That is
             * asm/0A30, the 3-byte stub that falls through to asm/0A33_cmd_done and so to
             * asm/0A38_post_command_tail - the IDENTICAL target of asm/0A15, the terrain
             * refusal whose tick was proven by forced-poke. Same jump, same tail, same tick.
             * asm/2052, asm/228A and asm/277B refuse their way to the same address too.
             *
             * CORPUS: captures/spice86/fight-20261021-castle03/turns, 3000 per-turn DS dumps.
             * DS:26C fell 6 times, every one of them with the food odometer UNCHANGED, and
             * zero times with food changed. A counter that only decremented on spent turns
             * would show the opposite. Legs in the same corpus: 91 decrements, all same-food.
             *
             * So the guard is gone: a completed ATTACK command always reaches the tail. */
            creature_turn(ctx, ow);
            continue;
        }

        /* The original does not refuse the edge, it wraps: the accept path
         * masks the coordinates (see U2_SECTOR_MASK). The previous code here
         * refused out-of-range steps and cited that as faithful to the
         * original's refusal of an invalid move; that was a guess, and the
         * live capture disproved it. */
        const int raw_x = ow->x + dx;
        const int raw_y = ow->y + dy;

        /* asm/242D/2434: the edge test runs on the unmasked coordinate, and it
         * only leaves anywhere when the sector is a site. On the world map the
         * same crossing is the torus wrap below. Measured east, west and south:
         * every one of them leaves, so the out-of-range test is both directions,
         * not the high edge alone. See site_leave(). */
        if (u2_site_edge_crossed(ow->sector_lo, raw_x, raw_y)) {
            site_leave(ctx, ow);
            continue;
        }

        const int nx = raw_x & U2_SECTOR_MASK;
        const int ny = raw_y & U2_SECTOR_MASK;

        /* CP5 W4: a creature standing there blocks the step.
         *
         * Observed, not inferred: in captures/spice86/cp5-fight/ stepping into an
         * occupied cell printed the same `--INVALID MOVE!` as a mountain and the
         * player stayed put. The engine did not do this until measured against: with
         * a patched monx31 placing a creature at (1,0), EAST was ACCEPTED while
         * ATTACK--EAST hit that same creature in the same build. Stamping the type
         * byte into the grid does not block anything on its own, because
         * u2_tile_passable defaults every unmeasured tile id to passable — the
         * "one grid, one truth" hope for W2 and W4 sharing a mechanism was wrong.
         *
         * The mechanism is still open, and this is deliberately the weaker claim.
         * asm/2423 has two distinct reject returns (0x2538 and 0x25FF), so the
         * original may block an occupied cell through the tile table — the stamped
         * type byte simply not being a walkable tile — or through a separate
         * occupancy test. The discriminator is cheap and is worth running: put a
         * creature on terrain already measured passable in a live run and see which
         * return fires. Until then the behaviour matches what was seen and the code
         * path is ours, which is the honest state of this branch.
         *
         * A creature-blocked step costs food like any other refusal: the charge is
         * inside asm/2423 upstream of the verdict (see the blocked branch below), so
         * whatever rejects, the 19 is already gone. G2, closed 2026-10-25. */
        const int blocked_by_creature = u2_monsters_at(ctx, nx, ny) >= 0;

        /* CP5 C3: legs paralysis is a movement rejection, not a combat overlay.
         *
         * asm/2520 is inside the passability routine: `mov al,[0x26b] ; cmp al,0 ;
         * je continue`, and on the set path it prints "--PARALIZED!" and falls into the
         * SAME reject return at runtime 0x2538 that an impassable tile uses. So a
         * paralysed step is not a special mode, it is the ordinary refusal with a
         * different word — which is also what the owner's recollection said the status
         * effect does (legs stop you moving, arms stop you fighting).
         *
         * It is checked BEFORE the terrain test because that is the address order inside
         * the routine (2520 precedes the mode ladder at 25C0). Consequence, inferred from
         * that order and not yet observed live: a paralysed player facing a mountain gets
         * --PARALIZED!, not --INVALID MOVE!. If a capture ever shows the terrain word
         * winning, the two branches swap and nothing else here changes.
         *
         * No food is spent, and that is an address fact rather than a convention:
         * asm/2520 returns 0xFF from the passability routine ahead of the mode
         * dispatch at asm/253B, which is where the per-step charge lives. The tick fires
         * here (proven), the sweep is NOT proven for this path and is deliberately not
         * called — see the note below. */
        if (ctx->state.paral_legs != 0) {
            seam_str_out(ctx, word);                  /* no CR: same line */
            seam_str_out(ctx, U2_S_MOVE_PARALYZED);
            seam_char_print(ctx, '\r');
            seam_str_out(ctx, U2_S_CMD_PROMPT);
            /* The original ticks here, and only the tick is proven. With DS:26B forced to 15,
             * pressing a direction key repeatedly drove the counter to 0 while food never moved,
             * so a refused step reaches the tick without spending food. Without this line a player
             * who keeps pressing directions is stranded forever — the bug the owner reported by
             * playing, not by reading.
             *
             * NOT called here: creature_turn(). The byte-level chain that puts the sweep on a
             * refused step runs through asm/0A02_invalid_move_msg, which is the TERRAIN reject. The
             * paralysis reject prints a different string and its route to asm/0A33_cmd_done has
             * never been traced, so promoting it to a full world turn would be exactly the
             * inference AGENTS.md § 5 forbids. If a capture ever shows the paralysis path reaching
             * the tail, this line becomes creature_turn() and nothing else changes. */
            status_tick(ctx);
            continue;
        }

        if (blocked_by_creature || !u2_mode_passable(&ow->world, nx, ny,
                                                     ctx->state.player_stamp)) {
            /* Blocked. The direction word and the complaint share a line:
             * "CMD: WEST--INVALID MOVE!" then a fresh prompt below.
             *
             * Evidence, not inference this time. asm/0A02_invalid_move_msg.asm is
             * call str_out + the literal "--INVALID MOVE!" + jmp, and the bytes
             * at file 0x0C05 confirm the string carries no CR and no direction
             * word of its own. So the word must already be on the line when the
             * complaint prints, which means the word is echoed WITHOUT the CR that
             * echo_cmd appends. echo_cmd twice was wrong: it put the two on
             * separate prompt lines.
             */
            seam_str_out(ctx, word);                  /* no CR: same line */

            /* A refused step pays the food. This is the G2 answer, and it is an
             * ordering fact about asm/2423 rather than a guess about intent: the
             * subtract at asm/2599 (and asm/2626) sits ahead of the tile verdict, so
             * the charge lands whether the step is allowed or not. Measured on the
             * maxed seed in sector 31, one arrow, reads back to back: DS:00/01
             * unchanged, food 997904 -> 997885, screen `CMD: WEST--INVALID MOVE!`.
             * u2_overworld_step_food runs the starvation tail on underflow, and the
             * original jumps there from inside the call — so the complaint never
             * prints on a step that kills. How many charges a step is, is the travel
             * mode's (asm/253B): one on foot, two mounted, none aboard the ship or the
             * rocket — and the rocket refuses every step, so it has to be launched out
             * of, not walked out of. */
            if (u2_overworld_step_food(ctx))
                break;

            seam_str_out(ctx, U2_S_INVALID_MOVE);
            seam_char_print(ctx, '\r');               /* the game's newline */
            seam_str_out(ctx, U2_S_CMD_PROMPT);
            /* The world still takes its turn. asm/0A02 (this complaint) falls through to
             * asm/0A15_invalid_move_to_cmd_done, which jumps to asm/0A30 and thence into
             * asm/0A33_cmd_done and asm/0A38_post_command_tail — so a bump into a mountain is a
             * completed command, the creature sweep runs, and a wandering spawn is attempted.
             * Proven from bytes on 2026-10-26 and corroborated live: in sector 03, 16 of 19
             * direction keys were refused and creature coordinates changed on 12 of them.
             * Skipping this is what made our creatures freeze against a wall while the original's
             * kept closing on the player. */
            creature_turn(ctx, ow);
            continue;
        }

        ow->x = nx;
        ow->y = ny;

        /* The echo, reproduced as the original prints it: one compound string
         * "NORTH\rCMD: " (asm/38B0, file 0x3ce5 — direction word, CR, prompt).
         * The word lands after the waiting prompt at col 5, the CR is the
         * game's newline (col := left margin, row++, scroll rows 20..23 at
         * row 24 — asm/500D/501A/5025), and the fresh prompt prints on the
         * blank bottom row. That is the owner's model of the block: bottom
         * row always current, completed commands stacked above it. */
        echo_cmd(ctx, word);

        /* The charge is inside asm/2423, which the original calls after echoing the
         * direction word and before anything else — so the word is on the line when
         * the subtraction kills, and the death tail prints three newlines so the
         * announcement lands below it (`death1.png`). On foot the cost is 19; horse
         * and plane pay it twice (asm/2626_food_drain_mounted); the ship and the rocket
         * reach no drain at all. The wrapper owns the starvation tail, so the result is
         * deliberately not tested here: the world turn runs afterwards exactly as it does
         * for a step that starves, which is what the refused arm above already does. */
        (void)u2_overworld_step_food(ctx);

        /* The force field fires on the tile you have just stepped onto, after the direction word
         * is on the line and after the food charge — same neighbourhood inside asm/2423. It can
         * kill, and u2_death owns the tail, so the world turn still runs afterwards exactly as it
         * does for a step that starves. */
        if (u2_world_tile_at(&ow->world, ow->x, ow->y) == 0x5C)
            u2_force_field(ctx);

        creature_turn(ctx, ow);
    }
    ctx->frame = NULL;
    return 0;
}

int u2_overworld_dump(u2_ctx *ctx, const char *path)
{
    u2_overworld ow;
    if (u2_overworld_init(ctx, &ow) != 0) {
        fprintf(stderr, "overworld: %s\n", ow.note);
        return -1;
    }
    u2_overworld_draw(ctx, &ow);

    uint8_t pal[4][3];
    u2_frame_palette(pal);
    if (u2_frame_write_ppm(&ow.frame, path, pal) != 0) {
        fprintf(stderr, "overworld: could not write %s\n", path);
        return -1;
    }
    fprintf(stderr, "overworld: %s -> %s\n", ow.note, path);
    return 0;
}
