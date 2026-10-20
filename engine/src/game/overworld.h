#ifndef U2_OVERWORLD_H
#define U2_OVERWORLD_H

/*
 * Overworld — the CP4 screen: a sector, a position, and the map window.
 *
 * This module is the first consumer of all four CP4 pieces together: the sector
 * loader (core/world), the tile cache (core/tiles), the viewport mapping
 * (core/view) and the framebuffer (core/frame). Nothing here knows what a
 * terminal or an SDL window is; it produces a u2_frame and a backend presents
 * it, which is what lets the same code drive a file dump, a window, or a test.
 */

#include "core/ctx.h"
#include "core/frame.h"
#include "core/tiles.h"
#include "core/view.h"
#include "core/world.h"

/* The probe start state. These are the values read out of the live data-segment
 * capture (captures/spice86/live-ds-4f4d.bin: sector digits 3 and 0, position
 * x=33 y=23), so the dump shows a real sector the original was actually
 * standing in. They are a probe's starting point, NOT an assertion about where
 * a new game begins — that is CP5+ territory and comes from the player record. */
#define U2_OVERWORLD_PROBE_SECTOR_HI 3
#define U2_OVERWORLD_PROBE_SECTOR_LO 0
#define U2_OVERWORLD_PROBE_X 33
#define U2_OVERWORLD_PROBE_Y 23

/* Art record the original draws for the player, derived from the live DS
 * capture: the staging byte at the player's cell is 0x78, and 0x78 >> 1 == 60,
 * a humanoid figure. The player is stamped in after the terrain fill, which is
 * why that cell holds a value no map byte can produce. */
#define U2_OVERWORLD_PLAYER_ART 60

typedef struct u2_overworld {
    u2_world world;
    u2_tiles tiles;
    u2_view  view;
    u2_frame frame;
    int      x, y;                 /* position inside the sector, DS:00/01 */
    uint8_t  off_map_tile;         /* the DS:12 analogue */
    int      sector_hi, sector_lo;
    char     note[160];            /* what happened on load, for the caller */
} u2_overworld;

/*
 * Load the tiles and a sector, then composite one frame.
 *
 * Returns 0 on success. On failure `ow->note` explains why in terms the player
 * can act on — a missing content directory and a corrupt tile cache need
 * different advice, and the engine must not draw an invented world either way.
 *
 * The status band and the CMD prompt are printed into the vram grid here, once,
 * exactly as the original prints them once on entering the world: the status
 * block through the proven status sites, then "CMD: " (asm/087D) at row 23
 * col 0, leaving the cursor at col 5 where the next echo lands.
 */
int u2_overworld_init(u2_ctx *ctx, u2_overworld *ow);

/*
 * Spawn from the loaded player record instead of the probe: sector digits
 * [DS:49][DS:4A] and entry pair [DS:5A]/[DS:5B], the 'P' contract proven at
 * file 0x09E6..0x0A7F. Call after u2_save_load succeeded.
 */
int u2_overworld_init_state(u2_ctx *ctx, u2_overworld *ow);

/* The present/poll/move loop for an already-opened overworld. Returns
 * non-zero when the display asked to quit. */
int u2_overworld_loop(u2_ctx *ctx, u2_overworld *ow);

/* Recomposite the frame from the current position: map window (pixel rows
 * 0..159) then the text rows 20..24 of the vram grid — status block, CMD
 * prompt and message history, one composited framebuffer. */
void u2_overworld_draw(u2_ctx *ctx, u2_overworld *ow);

/*
 * Render one frame of the probe sector and write it to `path` as PPM. This is
 * the zero-dependency way to see the real extracted tiles, and it is also what
 * the screenshot test drives, since a headless CI has no display for SDL.
 * Returns 0 on success.
 */
int u2_overworld_dump(u2_ctx *ctx, const char *path);

/*
 * Interactive play: draw, present, read a key, move. Returns 0 on a clean exit.
 *
 * Movement is in-sector only, and that limit is deliberate rather than an
 * oversight. Crossing a sector edge is handled by asm/242D / asm/2434 / asm/243E,
 * and what those routines set on reload — in particular which sector digit moves
 * and in which direction — is not yet established by the asm. Walking the player
 * into a neighbouring sector on a guess would produce a map that is subtly wrong
 * in a way that looks like a rendering bug, so the edge is reported and the step
 * refused until the trace is done.
 */
int u2_overworld_run(u2_ctx *ctx, u2_overworld *ow);

#endif /* U2_OVERWORLD_H */
