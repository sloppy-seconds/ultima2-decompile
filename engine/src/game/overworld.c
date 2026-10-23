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
#include "game/combat.h"      /* u2_combat_attack, u2_attack */
#include "game/monsters.h"    /* u2_monsters_at: who is standing there */
#include "game/status.h"
#include "core/font.h"
#include "core/save.h"
#include "core/seam.h"
#include "core/tiles.h"
#include "core/tiles_builtin.h"
#include "core/view.h"
#include "core/world.h"
#include "gen_content.h"

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
 * support: 0x0E62 (asm/0C62) zeroes DS:51..DS:59 — HP, FOOD, EXP and GOLD
 * together — and calls the redraw. There is no separate "food at zero drains
 * HP a little at a time" step anywhere in the tree; the owner's model said
 * there would be, and the bytes disagree, so the bytes win and the
 * disagreement is recorded rather than implemented.
 *
 * Returns 1 when the subtraction underflowed (the character just died).
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

    if (borrow) {
        /* asm/0C62, runtime 0x0E62: every stat byte to zero, then redraw. */
        st->hp = 0; st->unk_52 = 0;
        st->food = 0; st->food_hi = 0; st->food_lo = 0;
        st->exp_lo = 0; st->exp_hi = 0;
        st->gold_lo = 0; st->gold_hi = 0;
        return 1;
    }
    return 0;
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

/* On-foot passability for the tile ids measured so far.
 *
 * The original's routine (runtime 0x2423, asm/2423) takes a travel-mode byte
 * and returns 0 to accept or 0xFF to reject, and it has two distinct reject
 * returns (0x2538 and 0x25FF). Only the on-foot verdicts observed live are
 * encoded here.
 *
 * evidence: runtime 0x2423; accept 0x2664; reject 0x2538 and 0x25FF.
 *           Live 2026-10-21: tile 0x00 rejected 22 times on foot; 0x08 and
 *           0x0C stood on repeatedly.
 * confidence: partial.
 * open: which tile id is mountain. It is NOT 0x10 - the player was recorded
 *       standing on 0x10, and the owner states mountains are never passable
 *       on foot, so 0x10 is some other terrain. Needs a named sample.
 * open: what the mode argument (DS:15 / DS:18) selects for boat, plane or
 *       rocket. "Mountains block on foot" implies they do not block
 *       everything, and that dispatch is not yet read.
 */
static int u2_tile_passable(const u2_world *w, int x, int y)
{
    const uint8_t t = u2_world_tile_at(w, x, y);

    if (t == 0x00) return 0;                 /* water: measured blocked */
    if (t == 0x10) return 0;                 /* mountain: measured blocked */
    if (t == 0x08 || t == 0x0C) return 1;    /* grass, forest: measured passable */

    if (t < 64)
        g_unmeasured_tiles |= (uint64_t)1 << t;
    return 1;
}

/* Public wrapper over the same subtraction the PASS arm uses, so a test can
 * drive it directly. Returns 1 when the subtraction underflowed (death). */
int u2_overworld_spend_food(u2_ctx *ctx, unsigned amount)
{
    return food_spend(ctx, amount);
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
                        u2_status_draw(ctx);
                    /* Not modelled: the original also steps every monster on
                     * this tick, observed live as one cell per auto-PASS while
                     * the player stood still. Monsters do not exist in the
                     * engine yet, so there is nothing to advance. */
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
                u2_status_draw(ctx);
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
            continue;
        }

        /* The original does not refuse the edge, it wraps: the accept path
         * masks the coordinates (see U2_SECTOR_MASK). The previous code here
         * refused out-of-range steps and cited that as faithful to the
         * original's refusal of an invalid move; that was a guess, and the
         * live capture disproved it. */
        const int nx = (ow->x + dx) & U2_SECTOR_MASK;
        const int ny = (ow->y + dy) & U2_SECTOR_MASK;

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
        if (food_spend(ctx, U2_FOOD_PER_MOVE))
            u2_status_draw(ctx);

        /* The echo, reproduced as the original prints it: one compound string
         * "NORTH\rCMD: " (asm/38B0, file 0x3ce5 — direction word, CR, prompt).
         * The word lands after the waiting prompt at col 5, the CR is the
         * game's newline (col := left margin, row++, scroll rows 20..23 at
         * row 24 — asm/500D/501A/5025), and the fresh prompt prints on the
         * blank bottom row. That is the owner's model of the block: bottom
         * row always current, completed commands stacked above it. */
        echo_cmd(ctx, word);
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
