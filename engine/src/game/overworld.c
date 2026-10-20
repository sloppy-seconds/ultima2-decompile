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
#include "core/tiles.h"
#include "core/view.h"
#include "core/world.h"

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

int u2_overworld_init(u2_ctx *ctx, u2_overworld *ow)
{
    if (!ctx || !ow) return -1;
    memset(ow, 0, sizeof *ow);
    ow->x = U2_OVERWORLD_PROBE_X;
    ow->y = U2_OVERWORLD_PROBE_Y;
    ow->sector_hi = U2_OVERWORLD_PROBE_SECTOR_HI;
    ow->sector_lo = U2_OVERWORLD_PROBE_SECTOR_LO;
    ow->off_map_tile = 0xFF;      /* DS:12 in the live capture */

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

    snprintf(ow->note, sizeof ow->note,
             "sector %d%d via %s, %s%s",
             ow->sector_hi, ow->sector_lo,
             ow->world.found_prefix ? ow->world.found_prefix : "?",
             ow->tiles.from_cache ? "tiles from cache" : "tiles extracted",
             ow->tiles.unverified ? " (unverified)" : "");
    return 0;
}

void u2_overworld_draw(u2_overworld *ow)
{
    u2_view_fill(&ow->view, &ow->world, ow->x, ow->y,
                 ow->off_map_tile, NULL, U2_OVERWORLD_EMPTY_GATE);

    u2_frame_clear(&ow->frame, U2_CGA_BLACK);
    /* No overlay tile: which tile id the original uses for the player is not
     * established by the asm, so the marker below is engine-authored rather
     * than a guess dressed up as a sprite. */
    u2_frame_draw_view(&ow->frame, &ow->view, &ow->tiles, -1, -1, -1);

    /* Engine-authored player marker: four corner pixels of the player's window
     * cell. Deliberately not a tile, so it cannot be mistaken for original art. */
    const int px = U2_VIEW_PLAYER_COL * U2_TILE_W;
    const int py = U2_VIEW_PLAYER_ROW * U2_TILE_H;
    static const int off[4][2] = { {0,0}, {15,0}, {0,15}, {15,15} };
    for (int i = 0; i < 4; i++)
        ow->frame.px[py + off[i][1]][px + off[i][0]] = U2_CGA_WHITE;
}

int u2_overworld_dump(u2_ctx *ctx, const char *path)
{
    u2_overworld ow;
    if (u2_overworld_init(ctx, &ow) != 0) {
        fprintf(stderr, "overworld: %s\n", ow.note);
        return -1;
    }
    u2_overworld_draw(&ow);

    uint8_t pal[4][3];
    u2_frame_palette(pal);
    if (u2_frame_write_ppm(&ow.frame, path, pal) != 0) {
        fprintf(stderr, "overworld: could not write %s\n", path);
        return -1;
    }
    fprintf(stderr, "overworld: %s -> %s\n", ow.note, path);
    return 0;
}
