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
static void creature_turn(u2_ctx *ctx, u2_overworld *ow)
{
    ow->turns++;   /* one resolved turn; --debug cli keys off this */

    const u2_ai_report rep = u2_ai_creature_turn(ctx, &ow->world, ow->x, ow->y);
    if (rep.moved)
        u2_monsters_restamp(ctx, &ow->world);
    if (rep.moved || rep.stolen)
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
    /* Nothing is printed for a melee wound. asm/0BB2..0BCF runs a loop over the
     * contact count calling asm/5455, asm/60AC and asm/60F2, which is almost
     * certainly the message, and none of it has been read. Silence here is a known
     * gap, not a decision that the original says nothing. */
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

    /* asm/343F tail, reached by every arm: `mov $0x4,%al; mov %al,0x12`. */
    ctx->state.tile_offsector = 4;
    ow->off_map_tile = 4;
    u2_status_draw(ctx);
    /* Rewritten on success, not only on failure: the caller prints this, and a
     * stale note from the opening load would describe the sector we left. */
    snprintf(ow->note, sizeof ow->note,
             "sector %d%d via %s, %d creature%s%s",
             ow->sector_hi, ow->sector_lo,
             ow->world.found_prefix ? ow->world.found_prefix : "?",
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

    /* asm/22FD stores the sector being left. The engine stores only what is
     * dirty, which is the same set: the grid and the creature table are written
     * by the stamp and the creature turn, and nothing else mutates them. */
    u2_monsters_store(ctx, &ow->world);
    if (ow->world.map_dirty) (void)u2_world_store(ctx, &ow->world, 1);
    if (ow->world.mon_dirty) (void)u2_world_store(ctx, &ow->world, 0);

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

    u2_monsters_store(ctx, &ow->world);
    if (ow->world.map_dirty) (void)u2_world_store(ctx, &ow->world, 1);
    if (ow->world.mon_dirty) (void)u2_world_store(ctx, &ow->world, 0);

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
 */
static int food_spend(u2_ctx *ctx, unsigned amount)
{
    u2_state *st = &ctx->state;
    unsigned lo, mid, hi;
    int borrow;

    borrow = bcd_sbb(st->food_lo, amount & 0xFF, 0, &lo);
    borrow = bcd_sbb(st->food_hi, (amount >> 8) & 0xFF, borrow, &mid);
    borrow = bcd_sbb(st->food,    (amount >> 16) & 0xFF, borrow, &hi);

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
     * until combat and town visits exist. */
    if (ow->world.map_dirty)
        u2_world_store(ctx, &ow->world, 1);

    if (u2_save_store(ctx) != U2_SAVE_OK)
        return 1;
    return 0;
}

/* The food a PASS costs. Proven at file 0x0B11: `sbb $0x0a,%al` on the low
 * byte of the food triple, with `das` — ten, in packed decimal. */
#define U2_FOOD_PER_PASS 10u

/* The food an accepted move costs. Proven twice, inline in the passability
 * routine at runtime 0x2599 and 0x2626: `sbb $0x19` then `das` on the food
 * triple — nineteen, packed decimal. Both the accept arms carry it, so the
 * drain belongs to movement itself and not to any one travel mode.
 * evidence: runtime 0x2599, 0x2626 — confidence: proven */
#define U2_FOOD_PER_MOVE 19u

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
static int u2_tile_passable(const u2_world *w, int x, int y)
{
    const uint8_t t = u2_world_tile_at(w, x, y);
    const int art = (t >> 2) & 0x7F;

    /* --- ground: the only entries proven walkable by an actual step --- */
    if (art == 0x02) return 1;   /* map 0x08 grass    — proven: walked across, F11 */
    if (art == 0x03) return 1;   /* map 0x0C forest   — proven: five steps, F11     */
    /* Town paving. Owner report 2026-10-27, standing in a town: "the terrain I'm not
     * standing on (cobblestone) should be passable". The tile is art 0x1C, map byte
     * 0x70, and the census makes the case better than the description does: 12889
     * cells across 15 of 33 sectors, the second most common byte in the entire pack,
     * and inside a town sector it is what the ground between the buildings IS
     * (mapx22: 873 cells, mapx92: 1118). A default-deny table that blocks the second
     * most common tile in the world is blocking ground, not scenery. Grade: owner. */
    if (art == 0x1C) return 1;

    /* --- proven blockers --- */
    if (art == 0x00) return 0;   /* map 0x00 water    — proven: 22 live rejects, F11 */
    if (art == 0x04) return 0;   /* map 0x10 mountain — proven: blocked at (11,20), F11 */
    /* asm/433A_sub_433a.asm: `cmp $0xa0,%al; jne open_no_door` — the open-door path
     * accepts only map byte 0xA0 as a door, so 0xA0 is a door and it is solid until
     * opened (art 0x28, the letter I). proven by bytes, not by walking. */
    if (t == 0xA0) return 0;

    /* --- owner-reported blockers, 2026-10-27 --- */
    /* Letters A-Z: shop signs and solid fixtures. F13 records the same report and
     * notes T (talk) still works through them, so "impassable" is not "inert" —
     * see the note at the foot of this function. */
    if (art >= 0x20 && art <= 0x39) return 0;
    /* Building walls. art 0x1E is solid white, 256 of 256 px (disasm/tile-art.tsv,
     * colour counts computed from the bytes) and map 0x78 carries it 6997 times
     * across 16 sectors — the volume a wall needs. art 0x1D is its solid-black
     * twin; blocked on the same reasoning, and marked art-shape grade. */
    if (art == 0x1E || art == 0x1D) return 0;
    /* Humanoid figures drawn from the map. The owner's report: walking through
     * people is wrong. These are real map bytes, not stamped creatures — measured
     * occurrence: map 0x40 (art 0x10) 878x/9 sectors, 0x60 (0x18) 126x/15,
     * 0x68 (0x1A) 78x/15, 0x30 (0x0C) 68x/11. Stamped creatures block by a
     * different route (monsters.c overwrites the cell), so this is additive. */
    if (art >= 0x0C && art <= 0x11) return 0;   /* Orc, Daemon, Devil, Balron, Minax, horse */
    if (art >= 0x18 && art <= 0x1B) return 0;   /* Guard, Jester, Merchant, King            */

    /* --- site gates: you must STAND ON these to enter, so they walk through ---
     * `E` dispatches on the tile under the player (`site_kind`, tile >> 2: 5
     * village, 6 town, 7 tower, 8 castle, 9 dungeon), so a gate that does not
     * admit the player is a town that cannot be entered at all. Blocking these
     * was a regression introduced on 2026-10-27 by the default-deny rewrite, which
     * filed art 0x06/0x07/0x09 under "structures depicted as solid" on art-shape
     * reasoning — the weakest grade in that function — and it took the owner walking
     * into Linde's gate to disprove it. Census across the pack: 7 village, 4 town,
     * 2 tower, 121 castle, 4 dungeon cells. The 121 for castle is art 0x08, the gate
     * frame, and it matches the map-byte 0x20 count exactly, which is the one
     * cross-check that should have made me suspicious of blocking any of them. */
    if (art >= 0x05 && art <= 0x09) return 1;

    /* --- structures depicted as solid: art-shape grade, the weakest rows here --- */
    if (art == 0x0A || art == 0x0B ||
        art == 0x13 || art == 0x14 || art == 0x15)
        return 0;                /* monument, doorway, plane, rocket, dungeon mouth */

    /* Unclassified: refuse, and record it so the gap is visible rather than felt.
     * A stop is a bug report; a free pass is a silent wrong game. */
    if (art < 64)
        g_unmeasured_tiles |= (uint64_t)1 << art;
    return 0;
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
 * rule is proven and the surface is not; wiring it is a separate ticket, and the
 * written tile byte (DS:14 doubled) is still an open question — naming that is
 * better than inventing a value for it. The owner reports the door "disappears"
 * and does not recall what is underneath, so the underneath byte is a capture
 * question, not a guess: see docs/needs-gameplay.md.
 *
 * Not wired: the engine has no UNLOCK command yet. Nothing calls this and the door
 * is therefore impassable in every direction for now, which is the honest half of
 * the behaviour rather than the whole of it.
 */


/* Public wrapper over the same subtraction the PASS arm uses, so a test can
 * drive it directly. Returns 1 when the subtraction underflowed (death), and
 * runs the death tail in that case, because that is what the borrow-out does. */
int u2_overworld_spend_food(u2_ctx *ctx, unsigned amount)
{
    if (!food_spend(ctx, amount))
        return 0;
    u2_death(ctx);
    return 1;
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
     * (0x78 on foot, constant across every in-world capture) and DS:12 is the
     * off-sector tile marker, 0xFF in-world and 4 inside a site. cmd_E's on-foot
     * gate reads the first, so without this it would answer "-ONLY ON FOOT!".
     * The overworld already carried 0xFF locally in ow->off_map_tile; now the
     * state block agrees with it. */
    ctx->state.player_stamp   = 0x78;
    ctx->state.tile_offsector = ow->off_map_tile;

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
             ow->world.found_prefix ? ow->world.found_prefix : "?",
             strncmp(ow->tiles.source, "builtin:", 8) == 0
                 ? "cleanroom tiles"          /* substitute art, named as such */
                 : (ow->tiles.from_cache ? "tiles from cache" : "tiles extracted"),
             ow->tiles.unverified && strncmp(ow->tiles.source, "builtin:", 8) != 0
                 ? " (unverified)" : "",
             creatures, creatures == 1 ? "" : "s",
             mr == U2_WORLD_OK ? "" : " (no monx file)");
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
    ow->off_map_tile = 0xFF;      /* DS:12 in the live capture */
    return overworld_open(ctx, ow);
}

/*
 * Spawn from the loaded player record — the 'P' path, proven in the re-decode
 * of file 0x09E6..0x0A7F: the game reads PLAYER, reads MONSTERS, reads the
 * sector named by [DS:49][DS:4A], sets mode 4, then copies [DS:5A]->[DS:00]
 * and [DS:5B]->[DS:01] and stamps DS:12 = 0xFF (the off-map tile, matching
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
    ow->off_map_tile = 0xFF;      /* file 0x0A67: mov $0xff,[0x12] */
    return overworld_open(ctx, ow);
}

void u2_overworld_draw(u2_ctx *ctx, u2_overworld *ow)
{
    u2_view_fill(&ow->view, &ow->world, ow->x, ow->y,
                 ow->off_map_tile, NULL, U2_OVERWORLD_EMPTY_GATE);

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

    /* asm/0C1F: the status counters tick on the damage path, and only inside a
     * site. This is the caller CP5 had been calling undiscovered — the search had
     * looked for L_000c33, which is cmd_done, when the tick's label is L_000e33.
     * How many times one turn reaches it is NOT proven, so the engine ticks each
     * counter exactly once per wound and says so: a per-turn decrement wired on
     * this note alone would be a promotion past the evidence. asm/0C33 skips a
     * counter that is already zero, which is why sleeping does not go negative. */
    if (ctx->state.sector_second != 0) {
        if (ctx->state.paral_legs)  ctx->state.paral_legs--;
        if (ctx->state.paral_arms)  ctx->state.paral_arms--;
        if (ctx->state.paral_sleep) ctx->state.paral_sleep--;
    }
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
        /* asm/2E3D file 0x30F4: movb $0x80, (%bx,%si) — the dead creature's cell
         * is stamped with the view's "do not draw" bit, not restored to the
         * terrain underneath. That is what the bytes show, so it is what happens;
         * whether the original ever puts terrain back is a separate unproven
         * question and inventing a restore would be worse than the blank. */
        const int cell = ty * U2_SECTOR_EDGE + tx;
        if (cell >= 0 && cell < U2_SECTOR_TILES)
            ow->world.map[cell] = 0x80;
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
    int pending_cmd = 0;    /* 'A' printed ATTACK-- and is awaiting a direction */

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
                    pending_cmd = 0;
                    echo_cmd(ctx, U2_S_PASS);
                    if (food_spend(ctx, U2_FOOD_PER_PASS))
                        u2_death(ctx);
                    creature_turn(ctx, ow);
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
        if (k.ch == 0x1B) break;                           /* ESC leaves */

        int dx = 0, dy = 0;
        const char *word = NULL;
        switch (k.ch) {
        case U2_KEY_UP:    dy = -1; word = U2_S_DIR_NORTH; break;
        case U2_KEY_DOWN:  dy =  1; word = U2_S_DIR_SOUTH; break;
        case U2_KEY_RIGHT: dx =  1; word = U2_S_DIR_EAST;  break;
        case U2_KEY_LEFT:  dx = -1; word = U2_S_DIR_WEST;  break;
        case 'A':
            /* asm/2B8F_cmd_A: print "ATTACK--" with no CR and fall into the gate
             * chain, whose last step reads a direction. If the turn expires first
             * the waiting PASS lands on this same line, which is exactly the live
             * `CMD: ATTACK--PASS` (docs/spice86-live-findings.md § 18). */
            seam_str_out(ctx, U2_S_ATTACK);
            pending_cmd = 'A';
            continue;
        case 'E': {
            /* asm/3389 cmd_E. Inside a site the answer is " WHAT?"; the doors
             * only work from the world map, which is [DS:4A] == 0. */
            seam_str_out(ctx, U2_S_ENTER);
            if (ctx->state.sector_second != 0) {
                seam_str_out(ctx, U2_S_ENTER_WHAT);
                seam_char_print(ctx, '\r');
                seam_str_out(ctx, U2_S_CMD_PROMPT);
                continue;
            }
            /* asm/33A6: [DS:13] is the sprite stamped into the map cell and the
             * test is `>= 0x78`, i.e. on foot. The engine has no vehicles yet, so
             * the stamp is set to 0x78 at open and this arm cannot fire; it is
             * here so a vehicle implementation finds the gate already in place. */
            if (ctx->state.player_stamp < 0x78) {
                seam_str_out(ctx, U2_S_ONLY_ON_FOOT);
                seam_char_print(ctx, '\r');
                seam_str_out(ctx, U2_S_CMD_PROMPT);
                continue;
            }
            const char *label = NULL;
            int ax = 0, ay = 0;
            const int digit = site_for_tile(u2_world_tile_at(&ow->world, ow->x, ow->y),
                                            &label, &ax, &ay);
            if (digit == 0) {
                seam_str_out(ctx, U2_S_ENTER_WHAT);
                seam_char_print(ctx, '\r');
                seam_str_out(ctx, U2_S_CMD_PROMPT);
                continue;
            }
            if (label) seam_str_out(ctx, label);
            seam_char_print(ctx, '\r');
            site_enter(ctx, ow, digit, ax, ay);
            seam_str_out(ctx, U2_S_CMD_PROMPT);
            continue;
        }
        case 'Q':
            u2_overworld_save(ctx, ow, &U2_SAVE_POLICY_ORIGINAL);
            continue;
        case ' ':
        case 'P':
            /* Space is PASS from the walk loop's own first arm (cmp $0x20 at file
             * 0x0B3C). 'P' is PASS from the command jump table: asm/3DBC_cmd_P
             * prints PASS, reached by `jmp *%bx` through cs:0730 entry P. The two
             * are separate sites in the original and both reach the same result,
             * so the engine accepts both. It prints PASS, then spends 10 food
             * (file 0x0B0D..0x0B33). Underflow is death (asm/0C62). The idle
             * auto-PASS above reaches the same cost through the same print site. */
            echo_cmd(ctx, U2_S_PASS);
            if (food_spend(ctx, U2_FOOD_PER_PASS))
                u2_death(ctx);
            creature_turn(ctx, ow);
            continue;
        default: continue;                                  /* not a move key */
        }

        /* A direction arriving while ATTACK-- is on the line is the attack's
         * direction, not a step: the original consumed it inside the cmd_A chain
         * and never moved the player. Live: `ATTACK--EAST--HIT!!!` with the
         * player standing still. */
        if (pending_cmd == 'A' && word != NULL) {
            pending_cmd = 0;
            attack_dir(ctx, ow, word, dx, dy);
            /* The swing is the turn: the original's monsters advance on the
             * expiry of a half-typed `A` too (`ATTACK--PASS`), so an attack that
             * was actually completed cannot sensibly advance nothing. Whether the
             * arms-paralysis refusal inside attack_dir costs a turn is NOT
             * proven; the engine advances on both the miss and the hit and not on
             * the refusal. */
            if (ctx->state.paral_arms == 0)
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
         * Food cost of a creature-blocked step is unknown — G2 covers blocked steps
         * generally and is still open — so nothing is charged, same as the terrain
         * reject. */
        const int blocked_by_creature = u2_monsters_at(ctx, nx, ny) >= 0;

        if (blocked_by_creature || !u2_tile_passable(&ow->world, nx, ny)) {
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
            seam_str_out(ctx, U2_S_INVALID_MOVE);
            seam_char_print(ctx, '\r');               /* the game's newline */
            seam_str_out(ctx, U2_S_CMD_PROMPT);
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

        /* The food charge comes after the echo, and that ordering is a choice,
         * not a byte. Nothing observable moves unless the subtraction kills: the
         * death tail prints three newlines precisely so the announcement is the
         * last line on the log, and `death1.png` shows it there. Charging first
         * would print `CMD: NORTH` underneath a dead character's name. */
        if (food_spend(ctx, U2_FOOD_PER_MOVE))
            u2_death(ctx);
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
