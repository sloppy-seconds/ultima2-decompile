/*
 * overworld.c — the CP4 screen, assembled from the four proven pieces.
 *
 * Sector + tiles + viewport + framebuffer. The composition order mirrors the
 * original: stage the tile IDs (asm/5AE1), then flush them to a frame
 * (asm/4ABB), honouring the do-not-draw flag rather than drawing tile 0.
 */

#include <stdio.h>
#include <string.h>

#include "game/overworld.h"
#include "game/status.h"
#include "core/font.h"
#include "core/save.h"
#include "core/seam.h"
#include "core/tiles.h"
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

/* Shared loader: everything after the spawn fields are set. */
static int overworld_open(u2_ctx *ctx, u2_overworld *ow)
{
    /* Tiles first: without art there is nothing to draw, and the reason the
     * player needs to hear is specific (no --data-dir vs a corrupt cache). */
    u2_tiles_result tr = u2_tiles_open(ctx, &ow->tiles, NULL, 0, NULL, 0);
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

    /* The status band and the command prompt, printed once on entering the
     * world (CP4b task 1). The four value lines go through the proven status
     * sites (asm/50F9..5175, packed BCD); the prompt is asm/087D's "CMD: "
     * at row 23 col 0, leaving the cursor at col 5 where the next echo
     * lands — the same position the fresh-state screenshot shows. */
    u2_status_draw(ctx);
    seam_goto(ctx, 0, U2_MSG_BOTTOM);
    seam_str_out(ctx, U2_S_CMD_PROMPT);

    snprintf(ow->note, sizeof ow->note,
             "sector %d%d via %s, %s%s",
             ow->sector_hi, ow->sector_lo,
             ow->world.found_prefix ? ow->world.found_prefix : "?",
             ow->tiles.from_cache ? "tiles from cache" : "tiles extracted",
             ow->tiles.unverified ? " (unverified)" : "");
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

int u2_overworld_loop(u2_ctx *ctx, u2_overworld *ow)
{
    ctx->frame = &ow->frame;

    for (;;) {
        u2_overworld_draw(ctx, ow);
        if (seam_present_frame(ctx)) break;      /* window closed */

        u2_key k;
        const int r = seam_key_poll(ctx, &k);
        if (r < 0) break;
        if (r == 0) { seam_wait_ms(ctx, 16); continue; }   /* ~60 fps cadence */
        if (k.ch == 0x1B) break;                           /* ESC leaves */

        int dx = 0, dy = 0;
        const char *word = NULL;
        switch (k.ch) {
        case U2_KEY_UP:    dy = -1; word = U2_S_DIR_NORTH; break;
        case U2_KEY_DOWN:  dy =  1; word = U2_S_DIR_SOUTH; break;
        case U2_KEY_RIGHT: dx =  1; word = U2_S_DIR_EAST;  break;
        case U2_KEY_LEFT:  dx = -1; word = U2_S_DIR_WEST;  break;
        case 'Q':
            u2_overworld_save(ctx, ow, &U2_SAVE_POLICY_ORIGINAL);
            continue;
        default: continue;                                  /* not a move key */
        }

        const int nx = ow->x + dx, ny = ow->y + dy;
        if (nx < 0 || nx >= U2_SECTOR_EDGE || ny < 0 || ny >= U2_SECTOR_EDGE) {
            /* See the header: the reload semantics are unproven, so refuse
             * rather than guess. The step is not applied, exactly as the
             * original refuses an invalid move. */
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
