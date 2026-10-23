/*
 * tests/site_check.c — the world-map gate table: which tile enters which site.
 *
 * asm/3389_cmd_E prints ENTER and asm/33A6..33FF dispatches on [DS:14] >> 1, and
 * DS:14 is map_byte >> 1 (CP5 ticket C7), so the gate is tile >> 2. The mapping
 * below is that shift, and the digit column is NOT the shift: 7 is a tower, which
 * is sector digit 4, and 8 is a castle, which is digit 3. Anyone who "simplifies"
 * that will produce towns that load tower files, quietly.
 *
 * The second half is the check that matters, and it is the one that can only be
 * made against the player's own content: every gate cell in every world sector
 * must name a sector file that exists. On the 2026-10-27 content set that is 21
 * gate cells and 21 existing files, and the dungeon gate in mapx30 is the cell the
 * live capture walked into when DS:49/4A went from 3,0 to 3,5.
 *
 * argv[1] is the content directory; without it the data half SKIPs (a missing
 * --data-dir is not a test failure, same rule as world_check.c).
 *
 * Build and run by tests/run_cp5.sh.
 */
#include <stdio.h>
#include <string.h>

#include "core/ctx.h"
#include "core/world.h"
#include "game/overworld.h"
#include "gen_content.h"

static int fails, checks, skipped;
#define CHECK(cond, ...) do { checks++; if (!(cond)) { fails++; \
    printf("  FAIL  " __VA_ARGS__); printf("\n"); } } while (0)

int main(int argc, char **argv)
{
    const char *label;
    int ax, ay;

    /* --- the table itself, from asm/33C3..33FF ------------------------------ */
    struct { uint8_t tile; int digit; const char *name; int ax, ay; } want[] = {
        { 0x14, 1, "village",  0x1f, 0x3e },
        { 0x18, 2, "town",     0x1f, 0x3e },
        { 0x1c, 4, "tower",    0x05, 0x05 },
        { 0x20, 3, "castle",   0x1f, 0x3e },
        { 0x24, 5, "dungeon",  0x05, 0x05 },
    };
    for (unsigned i = 0; i < sizeof want / sizeof want[0]; i++) {
        const int d = u2_site_for_tile(want[i].tile, &label, &ax, &ay);
        CHECK(d == want[i].digit, "%s: tile 0x%02x -> digit %d, expected %d",
              want[i].name, want[i].tile, d, want[i].digit);
        CHECK(ax == want[i].ax && ay == want[i].ay,
              "%s: arrival cell (%d,%d), expected (%d,%d)",
              want[i].name, ax, ay, want[i].ax, want[i].ay);
    }

    /* The village arm has no announcement: asm/341E saves the entry pair and
     * loads, with no str_out in front of it. Every other arm prints one. */
    (void)u2_site_for_tile(0x14, &label, &ax, &ay);
    CHECK(label == NULL, "village announces nothing (asm/341E has no string)");
    (void)u2_site_for_tile(0x18, &label, &ax, &ay);
    CHECK(label != NULL && strcmp(label, U2_S_SITE_TOWN) == 0,
          "town announces -TOWN (asm/343F)");

    /* --- the controls: ordinary terrain is not a door ----------------------- */
    /* Without these, a table that matched on every byte would pass the five
       positive checks above and turn every grass tile in the world into a gate. */
    uint8_t plain[] = { 0x00, 0x04, 0x08, 0x0c, 0x10, 0x40, 0x44, 0x4c, 0x50, 0x78 };
    int refusals = 0;
    for (unsigned i = 0; i < sizeof plain; i++) {
        const int d = u2_site_for_tile(plain[i], &label, &ax, &ay);
        if (d == 0) refusals++;
        else printf("  note  tile 0x%02x is a gate (digit %d) — check asm/33C3\n",
                    plain[i], d);
    }
    CHECK(refusals == (int)sizeof plain,
          "control: water, forest, mountain, the player stamp and the four vehicle "
          "tiles are not doors");

    /* --- the data half: every gate cell names a sector that exists ---------- */
    if (argc < 2) {
        skipped++;
        printf("  SKIP  gate-cell cross-check (no content directory given)\n");
    } else {
        u2_ctx ctx;
        memset(&ctx, 0, sizeof ctx);
        ctx.data_dir = argv[1];
        u2_world w;

        int gates = 0, missing = 0;
        for (int hi = 0; hi <= 9; hi++) {
            u2_sector_id id = { (uint8_t)hi, 0 };
            memset(&w, 0, sizeof w);
            if (u2_world_load(&ctx, &w, 1, id) != U2_WORLD_OK)
                continue;                       /* this world sector is not in the pack */

            for (int cell = 0; cell < U2_SECTOR_TILES; cell++) {
                const uint8_t t = w.map[cell];
                const int digit = u2_site_for_tile(t, &label, &ax, &ay);
                if (digit == 0) continue;
                gates++;
                u2_world probe;
                memset(&probe, 0, sizeof probe);
                u2_sector_id sid = { (uint8_t)hi, (uint8_t)digit };
                if (u2_world_load(&ctx, &probe, 1, sid) != U2_WORLD_OK) {
                    missing++;
                    printf("  FAIL  mapx%d%d tile 0x%02x at (%d,%d) names a gate to "
                           "mapx%d%d, which is not there\n",
                           hi, 0, t, cell % U2_SECTOR_EDGE, cell / U2_SECTOR_EDGE,
                           hi, digit);
                }
            }
        }
        CHECK(gates > 0, "the pack has gate cells to check (found %d)", gates);
        CHECK(missing == 0, "every gate cell in every world sector names a sector "
                            "file that exists (%d gates checked)", gates);
    }

    /* --- gates must admit the player, or `E` can never fire -----------------
     * `E` dispatches on the tile the player is STANDING on, so a gate that refuses
     * entry is a town that cannot be entered. The default-deny passability rewrite
     * of 2026-10-27 blocked arts 0x06/0x07/0x09 as "solid structures" on art-shape
     * reasoning and sealed every town in the game; the suite stayed green because
     * nothing asserted the walkability half of the gate rule. These checks are the
     * reason that cannot happen quietly again. */
    static const struct { int kind; const char *name; } gatek[] = {
        { 5, "village" }, { 6, "town" }, { 7, "tower" },
        { 8, "castle" },  { 9, "dungeon" }
    };
    for (size_t i = 0; i < sizeof gatek / sizeof gatek[0]; i++) {
        const uint8_t mb = (uint8_t)(gatek[i].kind << 2);
        CHECK(u2_tile_walkable_byte(mb),
              "%s gate (tile >> 2 == %d, map byte 0x%02X) is walkable, so E can fire "
              "on it", gatek[i].name, gatek[i].kind, mb);
    }

    /* The four verdicts that were proven by actually walking, kept as a fence around
     * the permissive side of the table: if someone re-widens the default, these go
     * red instead of the world quietly becoming walkable. */
    CHECK(!u2_tile_walkable_byte(0x00), "water 0x00 stays impassable on foot");
    CHECK(!u2_tile_walkable_byte(0x10), "mountain 0x10 stays impassable on foot");
    CHECK(u2_tile_walkable_byte(0x08),  "grass 0x08 stays passable");
    CHECK(u2_tile_walkable_byte(0x0C),  "forest 0x0C stays passable");
    CHECK(!u2_tile_walkable_byte(0xA0), "door 0xA0 stays impassable until unlocked");
    CHECK(!u2_tile_walkable_byte(0x78), "solid-white wall 0x78 stays impassable");
    CHECK(!u2_tile_walkable_byte(0x80), "letter A 0x80 stays impassable");
    /* Town paving (art 0x1C). Blocked by default-deny until the owner, standing in
     * a town, reported the cobblestone around them should be walkable. */
    CHECK(u2_tile_walkable_byte(0x70),
          "town paving 0x70 is passable: it is the ground between the buildings, "
          "12889 cells across 15 sectors");

    printf("site_check: %d checks, %d failures%s\n", checks, fails,
           skipped ? " (data cross-check skipped)" : "");
    return fails != 0;
}
