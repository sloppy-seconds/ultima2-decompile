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
    uint8_t  view_mode;            /* the DS:12 analogue: 0xFF in-world, 4 in a site */
    int      sector_hi, sector_lo;
    /* Turn counter for --debug cli. `turns` advances once per resolved player
     * turn (it is bumped inside creature_turn, the one place every turn passes);
     * `logged_turn` remembers which turn was last written, so the dump happens
     * once per turn from the draw path and not once per frame at 60 Hz. */
    unsigned turns;
    unsigned logged_turn;
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

/*
 * Save-gate policy — the single decision point for Q's location checks.
 *
 * The faithful defaults reproduce the original's three gates (asm/3DC7 with
 * the guards asm/3DE4/asm/3DFA): save only outdoors (DS:4A == 0), only on
 * Earth (DS:6D == 0), only on foot (DS:13 >= 0x78). A common community patch
 * lets the player save anywhere; CP11's enhanced rules surface will override
 * this struct rather than edit the loop, so the loop must consult only the
 * policy and never the raw gates.
 */
typedef struct u2_save_policy {
    int allow_indoors;    /* skip the outdoors gate (DS:4A) */
    int allow_off_earth;  /* skip the Earth gate (DS:6D)   */
    int allow_in_vehicle; /* skip the on-foot gate (DS:13) */
} u2_save_policy;

extern const u2_save_policy U2_SAVE_POLICY_ORIGINAL;

/*
 * The Q handler. Echoes the prompt and any gate refusal into the CMD window,
 * then performs the save the original performs at file 0x24FD: entry pair
 * [DS:5A]/[DS:5B] := live position, write the sector back, write the player
 * record. Returns 0 when saved, 1 when a gate refused (the refusal message
 * is already echoed). The monsters write (256 B from DS:137) is not lifted:
 * the engine does not load monsters until CP5.
 */
int u2_overworld_save(u2_ctx *ctx, u2_overworld *ow, const u2_save_policy *pol);

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

/*
 * The tile -> site table from asm/33C3..33FF, exposed so it can be tested against
 * real sector files. Returns the site digit for [DS:4A] (0 = not a gate), writes
 * the announcement string to *label (NULL for the village, which has none) and the
 * arrival cell to ax and ay.
 *
 * The gate is tile >> 2 because cmd_E dispatches on [DS:14] >> 1 and DS:14 is
 * map_byte >> 1 (CP5 ticket C7).
 */
int u2_site_for_tile(uint8_t tile, const char **label, int *ax, int *ay);

/*
 * Spend `bcd_sub` food from the packed-decimal triple DS:53/54/55 and return 1
 * if the subtraction underflowed, which is the original's death condition
 * (file 0x0B2E jumps to runtime 0x0E62 on a borrow). On that borrow it runs
 * u2_death, because the borrow-out is a jump into the death tail, not a flag.
 * `bcd_sub` is the raw immediate the original hands `sbb` — 0x0A for a PASS, 0x19
 * for a step — not a decimal count.
 * Exposed for tests; the PASS and move arms of the loop are its in-game callers.
 */
int u2_overworld_spend_food(u2_ctx *ctx, unsigned bcd_sub);

/*
 * The death tail: asm/0C62..0C99 as one span. Zeroes DS:51..DS:59, repaints the
 * status band, scrolls the log and prints `<NAME> IS DEAD!` with no `CMD: `
 * prompt after it. Every kill site in the binary jumps here — the food
 * borrow-outs, the force field, Minax, dungeon events and cmd_L — so anything
 * new that can kill calls this rather than zeroing HP on its own.
 */
void u2_death(u2_ctx *ctx);

/* Bitmask over tile ids 0..63 that the engine stepped onto without a measured
 * passability verdict. Zero means every tile the player entered had evidence
 * behind it; non-zero names exactly which ids still need a live sample.
 * Tests assert on this so a permissive default can never pass unnoticed. */
uint64_t u2_overworld_unmeasured_tiles(void);

/* Passability verdict for a raw map byte, exposed for tests only. See the comment
 * at its definition: the gate rule regressed once precisely because nothing could
 * assert on it. */
int u2_tile_walkable_byte(uint8_t map_byte);

/* Public test surface for the sector-edge rule, same reasoning as
 * u2_tile_walkable_byte above: the rule lives in the walk loop and was argued in a
 * comment for as long as it was wrong. Says whether a step to the UNMASKED
 * (raw_x, raw_y) leaves the sector. It leaves only from a site (second digit non-zero)
 * and on any edge, not just the high one -- measured east, west and south 2026-10-28.
 * See the comment on site_leave() in overworld.c. */
int u2_site_edge_crossed(int sector_second, int raw_x, int raw_y);

/* The UNLOCK rule (asm/4309..435E), split out so a test can drive every branch.
 * Returns one of the verdicts below. */
#define U2_UNLOCK_NO_AIM   0   /* no sideways aim: asm/4309 falls through to NO DOOR */
#define U2_UNLOCK_NO_DOOR  1   /* target cell is not map byte 0xA0 */
#define U2_UNLOCK_NO_KEYS  2   /* door present, DS:65 empty */
#define U2_UNLOCK_OPENED   3   /* key spent, cell paved */
int u2_unlock_rule(int dx, uint8_t target_tile, int keys);
/* The byte written over the door: the ground under the player, low bit cleared. */
uint8_t u2_unlock_replacement(uint8_t ground_tile);
/* One packed-decimal key spent (asm/435E's stc/mov/cmc/sbb/das/cmc). */
uint8_t u2_unlock_spend_key(uint8_t keys);

#endif /* U2_OVERWORLD_H */
