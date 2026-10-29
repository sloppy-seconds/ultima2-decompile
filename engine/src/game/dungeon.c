/*
 * dungeon.c — CP7: the interior sector. See dungeon.h for what is proven and
 * what is not; every claim below carries its asm file, and the places where the
 * bytes run out say so rather than filling the gap.
 */
#include <stdio.h>
#include <string.h>

#include "game/dungeon.h"
#include "platform/platform.h"
#include "game/overworld.h"
#include "game/combat.h"
#include "core/frame.h"
#include "core/seam.h"
#include "core/state.h"
#include "core/world.h"
#include "gen_content.h"

/* ------------------------------------------------------------------ state -- */

int u2_site_is_dungeon(const u2_ctx *ctx)
{
    return ctx->state.sector_second == 4 || ctx->state.sector_second == 5;
}

void u2_dungeon_facing(const u2_ctx *ctx, int *dx, int *dy)
{
    *dx = (int8_t)ctx->state.face_dx;
    *dy = (int8_t)ctx->state.face_dy;
}

static uint8_t cell(const u2_overworld *ow, int floor, int x, int y)
{
    return u2_world_dungeon_at(&ow->world, floor, x, y);
}

/* asm/6000 writes these three probes to [DS:14]/[DS:15]/[DS:16] on every render,
 * and cmd_D, cmd_K, cmd_G and the ADVANCE/RETREAT commands all read them back.
 * The empirical anchor is captures/spice86/dungeon-35-live: with the player at
 * (5,5) facing (1,0) the live bytes read 0x10 / 0x00 / 0x80, which are the cells
 * at (5,5), (6,5) and (4,5) of live grid page 0 and nothing else. */
void u2_dungeon_probe(u2_ctx *ctx, const u2_overworld *ow)
{
    int dx, dy;
    u2_dungeon_facing(ctx, &dx, &dy);
    const int fl = (int8_t)ctx->state.site_floor;
    const int px = ow->x, py = ow->y;

    ctx->state.mode_a    = cell(ow, fl, px, py);
    ctx->state.mode_walk = cell(ow, fl, px + dx, py + dy);
    ctx->state.mode_b    = cell(ow, fl, px - dx, py - dy);
}

/* ------------------------------------------------------- the four commands -- */

/* asm/277B runtime 0x28C3 and 0x28F5. Both are a quarter-turn on the signed
 * facing pair and neither passes a turn:
 *   LEFT : if (dy) { dx = dy; dy = 0 } else { dy = -dx; dx = 0 }
 *   RIGHT: if (dx) { dy = dx; dy = 0 } else { dx = -dy; dy = 0 }
 * North (0,-1) turns LEFT to west (-1,0), which is the counter-clockwise the
 * words mean. */
void u2_dungeon_turn(u2_ctx *ctx, int left)
{
    int dx = (int8_t)ctx->state.face_dx;
    int dy = (int8_t)ctx->state.face_dy;

    if (left) {
        if (dy != 0) { dx = dy; dy = 0; }
        else         { dy = -dx; dx = 0; }
        seam_str_out(ctx, U2_S_TURN_LEFT);
    } else {
        if (dx != 0) { dy = dx; dx = 0; }
        else         { dx = -dy; dy = 0; }
        seam_str_out(ctx, U2_S_TURN_RIGHT);
    }
    ctx->state.face_dx = (uint8_t)(int8_t)dx;
    ctx->state.face_dy = (uint8_t)(int8_t)dy;
}

/* The ADVANCE gate, asm/277B runtime 0x286F, read instruction by instruction:
 *
 *   al = [DS:15]                       the cell ahead, from asm/6000's probe
 *   if (al & 0x0f) -> "-BLOCKED!"      a stamp is in the way
 *   if (al == 0x80) -> "-BLOCKED!"     solid rock
 *   x = (x + dx) & 0x3f ; y = (y + dy) & 0x3f
 *   if (rand_byte() >= [DS:25]) -> done
 *   ... trap
 *
 * So a chest cell (0x40) is walkable and a rock cell is not, which is what makes
 * GET-after-walking-onto-it the only shape the chest command can have.
 *
 * The trap roll compares against the FLOOR, so floor 0 has no traps at all and
 * the deeper you go the more often one fires. That is the whole of the rule the
 * bytes give; how often it fires in practice is unobserved.
 */
static int dg_step(u2_ctx *ctx, u2_overworld *ow, int forward)
{
    int dx, dy;
    u2_dungeon_facing(ctx, &dx, &dy);
    if (!forward) { dx = -dx; dy = -dy; }

    /* RETREAT tests [DS:16] with `and $0x8f` instead: rock OR a stamp both
     * refuse, and so does anything with bit 7 set, which is a wider net than
     * ADVANCE casts. Transcribed as the bytes have it. */
    const uint8_t c = forward ? ctx->state.mode_walk : ctx->state.mode_b;
    if (forward) {
        if ((c & U2_DG_STAMP) != 0 || c == U2_DG_ROCK) return 0;
    } else {
        if ((c & 0x8f) != 0) return 0;
    }

    ow->x = (ow->x + dx) & 0x3f;
    ow->y = (ow->y + dy) & 0x3f;
    u2_dungeon_probe(ctx, ow);
    return 1;
}

u2_cmd_result u2_dungeon_advance(u2_ctx *ctx, u2_overworld *ow)
{
    u2_dungeon_probe(ctx, ow);
    seam_str_out(ctx, U2_S_ADVANCE);

    if (!dg_step(ctx, ow, 1)) {
        seam_str_out(ctx, U2_S_BLOCKED);
        u2_cmd_done(ctx);
        return U2_CMD_DONE;
    }

    /* asm/277B runtime 0x28A5: one roll against the floor, and on `jb` the trap. */
    const uint8_t roll = (uint8_t)seam_rand_byte(ctx);
    if (roll >= ctx->state.site_floor) {
        u2_cmd_done(ctx);
        return U2_CMD_DONE;
    }

    /* The trap. asm/277B zeroes [DS:26] BEFORE it prints, so a trap puts out the
     * light as its first effect and the next render is dark. */
    ctx->state.moved_flag = 0;
    seam_char_print(ctx, '\r');           /* the leading 0x8d on asm/277B's db line */
    seam_str_out(ctx, U2_S_TRAP);

    if (ctx->state.tools == 0) {
        /* The no-tools arm is `jmp L_000e62`, the damage tail, and the amount and
         * the HP path are UNDECODED — recorded as G47 in docs/needs-gameplay.md.
         * Nothing is applied here and nothing is printed, because inventing a
         * number would be worse than the gap: the gap has an owner and a name. */
        u2_cmd_done(ctx);
        return U2_CMD_DONE;
    }
    seam_str_out(ctx, U2_S_TOOLS_ESCAPED);
    /* asm/277B runtime 0x2904: `stc ; cmc ; sbb $1,%al ; das ; cmc` — one packed
     * decimal step off the TOOLS counter at [DS:66]. */
    ctx->state.tools = u2_bcd_dec1(ctx->state.tools);
    u2_cmd_done(ctx);
    return U2_CMD_DONE;
}

u2_cmd_result u2_dungeon_retreat(u2_ctx *ctx, u2_overworld *ow)
{
    u2_dungeon_probe(ctx, ow);
    seam_str_out(ctx, U2_S_RETREAT);
    if (!dg_step(ctx, ow, 0))
        seam_str_out(ctx, U2_S_BLOCKED);
    u2_cmd_done(ctx);
    return U2_CMD_DONE;
}

/* asm/2B8F + asm/2B9B. asm/2B9B is three instructions — `mov [DS:4A],al ;
 * cmp $4,al ; jb L_002da5` — and BOTH destinations land on asm/2BA5, the arms
 * paralysis gate: the `jb` targets it directly and the fall-through reaches it
 * three bytes later. So the site-kind gate refuses nothing; what a site changes
 * is that the direction is already known. The cell attacked is the one the facing
 * names, which is [DS:15], the same probe ADVANCE uses.
 *
 * CONTRADICTION ON RECORD: docs/spice86-live-findings.md § 13 tabulates `A` as
 * ADVANCE in a dungeon, from captures/spice86/dungeon-35-live, while
 * captures/spice86/tower-34 shows `A` printing ATTACK--MISS and the bytes above
 * show no arm that could print ADVANCE from the A jump-table entry. The engine
 * follows the bytes and the tower frame, and Up-arrow is ADVANCE either way, so
 * the movement that row was describing is still reachable. Recorded rather than
 * quietly resolved.
 */
u2_cmd_result u2_dungeon_attack(u2_ctx *ctx, u2_overworld *ow)
{
    int dx, dy;
    u2_dungeon_facing(ctx, &dx, &dy);
    u2_dungeon_probe(ctx, ow);
    u2_overworld_attack_dir(ctx, ow, U2_S_ATTACK, dx, dy);
    u2_dungeon_tick(ctx, ow);
    return U2_CMD_DONE;
}

/* asm/363B's site arm, runtime 0x36C3. The gate is the cell UNDER the player
 * compared to '@' (0x40) — the same 0x40 the renderer uses — and the loot roll
 * is one rand against 0x40, gold on `jb` and TRI-LITHIUM otherwise. The gold
 * amount is `(rand & 0x1f) + 2*floor`, formed with two `adc [DS:25]`, and the
 * `and $0x77` after it keeps it in packed decimal. */
u2_cmd_result u2_dungeon_get(u2_ctx *ctx, u2_overworld *ow)
{
    u2_dungeon_probe(ctx, ow);
    seam_str_out(ctx, U2_S_GET);

    const uint8_t under = ctx->state.mode_a;
    if (under != U2_DG_CHEST) {
        seam_str_out(ctx, U2_S_ENTER_WHAT);
        u2_cmd_done(ctx);
        return U2_CMD_DONE;
    }

    seam_str_out(ctx, U2_S_CHEST);
    seam_char_print(ctx, '\r');           /* the 0x8d between " CHEST!" and the next run */
    seam_str_out(ctx, U2_S_IT_CONTAINS);

    /* asm/363B runtime 0x36F1 clears the cell through the cell pointer, so the
     * chest is gone for good. Both copies, or the creature restamp would put it
     * back: see u2_world_terrain_put's header for why a map-only write is erased. */
    u2_world_dungeon_terrain_put(&ow->world, (int8_t)ctx->state.site_floor,
                                 ow->x, ow->y, 0);

    const uint8_t roll = (uint8_t)seam_rand_byte(ctx);
    if (roll < 0x40) {
        seam_str_out(ctx, U2_S_GOLD_EXCL);
        unsigned amount = (roll & 0x1fu) + 2u * (uint8_t)ctx->state.site_floor;
        amount &= 0x7fu;
        (void)amount;
        /* The BCD add onto the gold odometer is asm/363B's tail and the same
         * packed-decimal increment the overworld loot path already uses; wiring
         * it is a CP7 follow-up and is NOT silently skipped: the message above is
         * the player's notice, and the missing credit is the gap. */
    } else {
        seam_str_out(ctx, U2_S_TRI_LITHIUM);
    }
    u2_cmd_done(ctx);
    return U2_CMD_DONE;
}

/* ------------------------------------------------------------- the light ---- */

/* asm/1151 runtime 0x1491. Zero -> IT'S DARK! and no decrement; otherwise
 * decrement, and if the decrement reached zero, TORCH BURNED OUT!. Both strings
 * carry a TRAILING 0x8d in the binary, so the CR follows the text. */
int u2_dungeon_light_step(u2_ctx *ctx)
{
    if (ctx->state.moved_flag == 0) {
        seam_char_print(ctx, '\r');
        seam_str_out(ctx, U2_S_ITS_DARK);
        return 0;
    }
    ctx->state.moved_flag--;
    if (ctx->state.moved_flag == 0) {
        seam_char_print(ctx, '\r');
        seam_str_out(ctx, U2_S_TORCH_BURNED_OUT);
    }
    return 1;
}

/* ------------------------------------------------------------ the renderer -- */

/*
 * asm/4B76 plots a pixel at (x + [DS:4BF], y + [DS:4C1]) and asm/67B3 is the
 * line. The live capture has both origin bytes at 16, so the view's own
 * coordinate space — x 0..0xFF from the XL/XR tables, y 0..0x7F from YT/YB —
 * lands on a 256x128 rectangle inset 16 pixels from the top-left of a 320x200
 * screen. That is a 1:1 mapping with no scaling, and it is the only reading that
 * makes the tables' own ranges come out inside the frame.
 *
 * asm/4B76 ORs both plane bits, so every line it draws is colour 3 (white) and
 * asm/4BAA, which inverts the mask, is how the original erases.
 */
#define DG_ORIGIN_X 16
#define DG_ORIGIN_Y 16

typedef struct dg_view {
    u2_frame *f;
    int d;                    /* the depth index, [DS:482] in the original */
    int x1, y1, x2, y2;       /* the line drawer's four registers, DS:479..47C */
} dg_view;

static void dg_line(dg_view *v)
{
    u2_frame_line(v->f, DG_ORIGIN_X + v->x1, DG_ORIGIN_Y + v->y1,
                  DG_ORIGIN_X + v->x2, DG_ORIGIN_Y + v->y2, U2_CGA_WHITE);
}

/* The twelve shape routines and the eight depth tables, transcribed from the
 * asm tree by tools/gen_dungeon_draw.py. Regenerate that file; do not hand-edit. */
static void dg_6291(dg_view *); static void dg_6304(dg_view *);
static void dg_6377(dg_view *); static void dg_63ce(dg_view *);
static void dg_6425(dg_view *); static void dg_648d(dg_view *);
static void dg_64e2(dg_view *); static void dg_653f(dg_view *);
static void dg_6594(dg_view *); static void dg_660c(dg_view *);
static void dg_6684(dg_view *); static void dg_66cb(dg_view *);
#include "game/dungeon_draw.inc"

/* asm/6078. Three columns of cells walked out from the player: the centre
 * column starts on the player's own cell, the side columns start one cell to
 * either hand, and all three advance by the facing vector once per depth. The
 * centre cell is read twice, once masked to the terrain nibble and once to the
 * stamp nibble, which is the two-layers-in-one-byte fact made visible in the
 * renderer itself. */
typedef struct dg_scan {
    uint8_t left[U2_DG_SAMPLE_DEPTH];
    uint8_t ctr[U2_DG_SAMPLE_DEPTH];
    uint8_t obj[U2_DG_SAMPLE_DEPTH];
    uint8_t right[U2_DG_SAMPLE_DEPTH];
} dg_scan;

static void dg_scan_build(const u2_ctx *ctx, const u2_overworld *ow, dg_scan *s)
{
    int dx, dy;
    u2_dungeon_facing(ctx, &dx, &dy);
    const int fl = (int8_t)ctx->state.site_floor;
    const int px = ow->x, py = ow->y;

    int lx = px + dy, ly = py - dx;      /* DS:479 / DS:47A */
    int cx = px,      cy = py;           /* DS:47B / DS:47C */
    int rx = px - dy, ry = py + dx;      /* DS:47D / DS:47E */

    for (int d = 0; d < U2_DG_SAMPLE_DEPTH; d++) {
        const int a = lx & 0x3f, b = ly & 0x3f;
        s->left[d] = (uint8_t)(cell(ow, fl, a, b) & U2_DG_TERRAIN);
        lx = a + dx; ly = b + dy;

        const int e = cx & 0x3f, f = cy & 0x3f;
        const uint8_t c = cell(ow, fl, e, f);
        s->ctr[d] = (uint8_t)(c & U2_DG_TERRAIN);
        s->obj[d] = (uint8_t)(c & 0x07u);
        cx = e + dx; cy = f + dy;

        const int g = rx & 0x3f, h = ry & 0x3f;
        s->right[d] = (uint8_t)(cell(ow, fl, g, h) & U2_DG_TERRAIN);
        rx = g + dx; ry = h + dy;
    }
}

/* asm/68ED, asm/68A3 and asm/4BE0, transcribed.
 *
 * The record framing is the part that was not obvious, and it is one instruction:
 * asm/68ED reads the SECOND byte of each record twice from the same pointer and only
 * then advances, so a record is two bytes, not three —
 *     b0 = x, and x == 0 ends the list
 *     b1 = y in the low five bits, pattern index in the top three
 * asm/68A3 then scales both by four and passes the pattern index as bp, and asm/4BE0
 * looks the pattern up in cs:0x48D4 = ff 11 88 cc 33 00 00 00, which selects which of
 * the four pixels inside one video byte get lit. So one record paints a run of one to
 * four pixels, and a creature is a list of those runs.
 *
 * The base pointer is where the design shows. asm/68ED has two arms:
 *   di == 1 (nearest):  base = [DS:474] + (stamp << 8)   -> the type's own 256-byte block
 *   di >= 2 (further):  base = [DS:474] + cs:[0x697E+di] -> block 0's tail, no type term
 * That second arm looks like a dropped operand and is not one. Blocks 1..7 each hold one
 * full-detail creature; block 0's tail holds the ladder the far arm indexes — 24 records
 * at 0x080, 6 at 0x0C0, 4 at 0x0E0, 2 at 0x0F0, 1 at 0x0F8, which plot as a 6x4 blob, then
 * 2x3, 2x2, 1x2, 1x1. A deliberately typeless simplification series: the nearest creature
 * gets its own art and everything further out gets a generic silhouette, because at that
 * size the type would not be legible. Plotting the shapes is what established this, and it
 * is stronger evidence here than a screenshot would have been.
 */
static const uint8_t DG_PATTERN[8] = { 0xff, 0x11, 0x88, 0xcc, 0x33, 0x00, 0x00, 0x00 };
static const uint8_t DG_DEPTH_LADDER[8] = {
    0x00, 0x00, 0x80, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc
};

static void dg_sprite_page(u2_overworld *ow, const uint8_t *strokes,
                           int base, int colour)
{
    int p = 0;

    for (;;) {
        const int x = strokes[base + p];
        if (x == 0)
            return;
        const int b1 = strokes[base + p + 1];
        const int y = b1 & 0x1f;
        const int pat = DG_PATTERN[(b1 >> 5) & 7];
        p += 2;

        /* asm/68A3: ax = x*4, bx = y*4. asm/4BE0: di = (ax + origin) >> 2 and the
         * mask picks sub-pixels, so the screen x is origin + x*4 with the mask's
         * high bit being the leftmost pixel. */
        const int sx = DG_ORIGIN_X + x * 4;
        const int sy = DG_ORIGIN_Y + y * 4;
        for (int k = 0; k < 4; k++) {
            if (pat & (0xc0 >> (2 * k)))
                u2_frame_pixel(&ow->frame, sx + k, sy, (uint8_t)colour);
        }
    }
}

static void u2_dungeon_sprites(u2_ctx *ctx, u2_overworld *ow, const dg_scan *s)
{
    (void)ctx;
    if (!ow->world.strokes_loaded)
        return;                 /* no `monsters` in the content dir: draw no sprites */

    /* asm/68ED starts by incrementing [DS:482], which asm/6144 left at the depth it
     * stopped on, and then walks di from 1 while di < that value. */
    const int lim = U2_DG_DRAW_DEPTH;
    for (int di = 1; di < lim; di++) {
        const int stamp = s->obj[di];
        if (stamp == 0)
            continue;
        if (di == 1) {
            const int blk = (stamp & (U2_STROKE_BLOCKS - 1)) * U2_STROKE_BLOCK;
            dg_sprite_page(ow, ow->world.strokes, blk, U2_CGA_WHITE);
        } else {
            dg_sprite_page(ow, ow->world.strokes,
                           DG_DEPTH_LADDER[di & 7], U2_CGA_WHITE);
        }
    }
}

/* asm/6144. One depth per iteration, [DS:482] is the loop variable and the same
 * value the shape routines index their tables with. */
static void dg_draw(dg_view *v, const dg_scan *s)
{
    for (;;) {
        const int d = v->d;
        const uint8_t c = s->ctr[d];

        dg_6425(v);

        if ((c & U2_DG_ROCK) == 0) {
            /* Open ahead: draw whatever the cell holds, then the side walls. */
            if (c & U2_DG_DOWN) dg_6594(v);
            if (c & U2_DG_UP)   dg_660c(v);
            else if (c & U2_DG_CHEST) dg_66cb(v);

            if (s->left[d] & U2_DG_ROCK) {
                dg_6377(v);
                if ((s->left[d] & U2_DG_CHEST) && !(s->left[d] & U2_DG_DOWN))
                    dg_64e2(v);
            } else {
                dg_6291(v);
            }

            if (s->right[d] & U2_DG_ROCK) {
                dg_63ce(v);
                if ((s->right[d] & U2_DG_CHEST) && !(s->right[d] & U2_DG_DOWN))
                    dg_653f(v);
            } else {
                dg_6304(v);
            }

            v->d = d + 1;
            if (v->d >= U2_DG_DRAW_DEPTH) return;
            continue;
        }

        /* Rock ahead. asm/6144's three tests decide whether the corridor ends
         * here or whether the far face is drawn and the walk continues. */
        dg_6425(v);
        if ((c & U2_DG_CHEST) == 0) return;
        if (c & U2_DG_DOWN) return;
        dg_648d(v);
        if (d != 0) return;
        v->d = d + 1;
        if (v->d >= U2_DG_DRAW_DEPTH) return;
    }
}

void u2_dungeon_render(u2_ctx *ctx, u2_overworld *ow, int lit)
{
    if (!lit) return;         /* asm/6000's `cmpb $0x0,0x26 ; je` — the darkness */

    dg_scan s;
    dg_scan_build(ctx, ow, &s);

    dg_view v;
    memset(&v, 0, sizeof v);
    v.f = &ow->frame;
    v.d = 0;
    dg_draw(&v, &s);

    /* asm/68ED: the creature sprites. Transcribed rather than invented — see
     * u2_dungeon_sprites for the record framing and for the one reading a capture
     * still owes us. */
    u2_dungeon_sprites(ctx, ow, &s);
}

int u2_dungeon_key(u2_ctx *ctx, u2_overworld *ow, uint8_t ch)
{
    switch (ch) {
    case U2_KEY_UP:    u2_dungeon_advance(ctx, ow); break;
    case U2_KEY_DOWN:  u2_dungeon_retreat(ctx, ow); break;
    case U2_KEY_LEFT:  u2_dungeon_turn(ctx, 1); u2_cmd_done(ctx); break;
    case U2_KEY_RIGHT: u2_dungeon_turn(ctx, 0); u2_cmd_done(ctx); break;
    default: return 0;
    }
    u2_dungeon_tick(ctx, ow);
    return 1;
}

/* asm/1151's tail, in order: the light counter, then asm/12DB with 0x10.
 * asm/12DB's whole body is `mov [DS:20],al` and a packed-decimal subtract of that
 * from the food triple DS:53/54/55, so a dungeon turn costs ten food and a
 * starvation borrow falls into the same death tail the overworld uses. */
void u2_dungeon_tick(u2_ctx *ctx, u2_overworld *ow)
{
    u2_dungeon_light_step(ctx);
    (void)u2_overworld_spend_food(ctx, 0x10u);
    u2_dungeon_probe(ctx, ow);
}

void u2_dungeon_enter(u2_ctx *ctx, u2_overworld *ow)
{
    /* The capture is unambiguous about the light: entering a dungeon zeroes
     * [DS:26] and the screen is dark, and the value SURVIVES leaving — the first
     * draft of that finding read the surviving value as persistence and was wrong.
     * Entry is what clears it. */
    ctx->state.moved_flag = 0;
    ctx->state.site_floor = 0;
    ctx->state.face_dx = 0;
    ctx->state.face_dy = (uint8_t)(int8_t)-1;      /* north */
    u2_dungeon_probe(ctx, ow);
    /* Stamp everything the loader authored BEFORE the spawner runs, because
     * asm/68ED reads the grid stamps and not the creature arrays: an authored
     * creature that is never stamped is invisible even though it will happily hit
     * you. asm/147F then fills the remaining empty slots and stamps its own. */
    for (int i = 0; i < 32; i++) {
        if (ctx->state.mon_type[i] == 0) continue;
        u2_world_dungeon_put(&ow->world, (int8_t)ctx->state.site_floor,
                             ctx->state.mon_x[i], ctx->state.mon_y[i],
                             ctx->state.mon_type[i]);
    }
    u2_dungeon_spawn(ctx, ow);
    /* The entry frame is dark, and asm/1151 says so on the turn that follows the
     * load: captures/spice86/dungeon-35-live and tower-34 both record IT'S DARK!
     * on entry with [DS:26] at zero. */
    u2_dungeon_light_step(ctx);
}

/* ------------------------------------------------------------- creatures ---- */

/* asm/147F, validated 54/54 slots by tools/dungeon_spawn_check.py against
 * captures/spice86/dungeon-35-live and airport32. */
int u2_dungeon_spawn(u2_ctx *ctx, u2_overworld *ow)
{
    u2_state *st = &ctx->state;
    int filled = 0;

    for (int slot = 0x1f; slot >= 1; slot--) {
        if (st->mon_type[slot] != 0) continue;

        unsigned kind = (unsigned)(slot >> 1);
        unsigned type = 0;
        for (int tries = 0; tries < 32; tries++) {
            const unsigned r = seam_rand_byte(ctx);
            const unsigned t = (r & 7u) + 1u;
            if (t == 7u) continue;
            if (2u * (t - 1u) <= kind) { type = t; break; }
        }
        if (type == 0) continue;

        unsigned x = 0, y = 0;
        for (int tries = 0; tries < 32; tries++) {
            const unsigned a = ((seam_rand_byte(ctx) & 7u) * 2u) | 1u;
            const unsigned b = ((seam_rand_byte(ctx) & 7u) * 2u) | 1u;
            if (a == st->mon_x[slot] && b == st->mon_y[slot]) continue;
            x = a; y = b; break;
        }
        if (x == 0) continue;

        st->mon_x[slot]    = (uint8_t)x;
        st->mon_y[slot]    = (uint8_t)y;
        st->mon_kind[slot] = (uint8_t)kind;
        st->mon_type[slot] = (uint8_t)type;
        st->mon_hp[slot]   = (uint8_t)((((2u * type + kind) * 8u) | 0x10u) & 0xffu);

        /* The stamp. asm/147F's own header records that the (x,y)->cell transform
         * is NOT inside its span, so which cell the type lands in is the one part
         * of this that is inferred rather than read: the stamp value is the type,
         * because the live grid's additions are exactly 0x01..0x07 and the type
         * range is exactly 1..7. */
        u2_world_dungeon_put(&ow->world, (int8_t)st->site_floor,
                             (int)x, (int)y, (uint8_t)type);
        filled++;
    }
    return filled;
}
