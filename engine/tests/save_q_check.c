/*
 * save_q_check.c — CP4b: the Q save round trip.
 *
 * The owner's test, automated: create a character, move somewhere, save with
 * Q, quit, start again, press P — and land where you saved. The bytes say it
 * works because the save routine copies the live position into the entry
 * pair before writing (file 0x2520..0x2529: [0x5A]:=[0x00], [0x5B]:=[0x01]),
 * and the P path restores from that pair (file 0x0A26..0x0A2F). This test
 * proves the engine reproduces both halves, plus the location guard and the
 * CP11 extension point (the policy struct a "save anywhere" community patch
 * will flip).
 */
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

#include "core/ctx.h"
#include "core/save.h"
#include "core/seam.h"
#include "core/state.h"
#include "core/vram.h"
#include "core/world.h"
#include "game/overworld.h"
#include "game/monsters.h"
#include "gen_content.h"

static int fails;
static void ok(int cond, const char *what)
{
    printf("  %s  %s\n", cond ? "ok  " : "FAIL", what);
    if (!cond) fails++;
}

static int vram_contains(u2_ctx *ctx, const char *needle)
{
    char row[64];
    for (int r = 0; r < U2_ROWS; r++) {
        u2_vram_row_text(&ctx->vram, r, row, sizeof row);
        if (strstr(row, needle)) return 1;
    }
    return 0;
}

/* A synthetic sector file: 4096 tile bytes + the 128-byte tail. */
static void make_sector(const char *dir, const char *name)
{
    char path[256];
    snprintf(path, sizeof path, "%s/%s", dir, name);
    FILE *f = fopen(path, "wb");
    if (!f) return;
    unsigned char buf[64];
    memset(buf, 0x04, sizeof buf);
    for (int i = 0; i < 64; i++) fwrite(buf, 1, 64, f);   /* 4096 tiles */
    memset(buf, 0, sizeof buf);
    for (int i = 0; i < 2; i++) fwrite(buf, 1, 64, f);    /* 128 tail   */
    fclose(f);
}

/* The creature block is a separate file with a separate size: 256 bytes read at
 * asm/22D5 with CX=0x100, and the same block written back at asm/2305. */
static void make_mon_sector(const char *dir, const char *name)
{
    char path[256];
    snprintf(path, sizeof path, "%s/%s", dir, name);
    FILE *f = fopen(path, "wb");
    if (!f) return;
    unsigned char buf[256];
    memset(buf, 0, sizeof buf);
    fwrite(buf, 1, sizeof buf, f);
    fclose(f);
}

/* Open a synthetic overworld: sector 2/0, no tiles (the save path never
 * touches art, and the tile cache would need the player's executable). */
static void open_world(u2_ctx *ctx, u2_overworld *ow)
{
    memset(ow, 0, sizeof *ow);
    u2_world_open(ctx);
    u2_sector_id id = { 2, 0 };
    u2_world_load(ctx, &ow->world, 1, id);
    ow->x = 30; ow->y = 40;
    ow->sector_hi = 2; ow->sector_lo = 0;
}

int main(int argc, char **argv)
{
    const char *tmp = argc > 1 ? argv[1] : "/var/tmp/u2-saveq";
    char data[256], saves[256], saves_path[300];
    snprintf(data, sizeof data, "%s/data", tmp);
    snprintf(saves, sizeof saves, "%s/saves", tmp);
    snprintf(saves_path, sizeof saves_path, "%s/PLAYER", saves);
    mkdir(tmp, 0755); mkdir(data, 0755); mkdir(saves, 0755);
    make_sector(data, "mapx20");
    make_mon_sector(data, "monx20");

    /* --- run one: a fresh character walks and saves ---------------------- */
    u2_ctx a;
    memset(&a, 0, sizeof a);
    a.data_dir = data;
    a.save_dir = saves;
    u2_vram_init(&a.vram);
    u2_state_init(&a.state);
    memcpy(a.state.name, "TESTER", 6);          /* a named record */
    u2_save_ensure(&a);

    u2_overworld ow;
    open_world(&a, &ow);
    seam_goto(&a, 0, U2_MSG_BOTTOM);
    seam_str_out(&a, U2_S_CMD_PROMPT);

    /* Guard: indoors refuses, and nothing was written. */
    u2_overworld inside = ow;
    inside.sector_lo = 2;
    ok(u2_overworld_save(&a, &inside, &U2_SAVE_POLICY_ORIGINAL) == 1 &&
       vram_contains(&a, U2_S_Q_OUTDOORS),
       "Q indoors refuses with ONLY OUTDOORS! (asm/3DE4)");
    {
        /* Read the record file directly: entry_x/entry_y are record offsets
         * 0x24/0x25 (DS:5A/5B minus the DS:36 record base). */
        unsigned char rec[256];
        FILE *rf = fopen(saves_path, "rb");
        int read_ok = rf && fread(rec, 1, 256, rf) == 256;
        if (rf) fclose(rf);
        ok(read_ok && rec[0x24] == 0 && rec[0x25] == 0,
           "the refusal left the record untouched");
    }

    /* The faithful save at the walked-to position. */
    ok(u2_overworld_save(&a, &ow, &U2_SAVE_POLICY_ORIGINAL) == 0 &&
       vram_contains(&a, U2_S_Q_MOMENT),
       "Q outdoors saves, echoing ONE MOMENT PLEASE! (asm/3DFA)");
    ok(ow.world.map_dirty == 0,
       "clean sectors are not rewritten (dirty-only store contract)");

    /* --- the creature block is the other half of the save write -------------
     * asm/2305 names MONXFF (file 0x2548) as well as MAPXFF (0x2538), so the
     * original rewrites the creature block on the same path. Q used to write only
     * the map: a kill cleared the arrays, the file kept the monster alive, and it
     * came back on reload. */
    {
        char monpath[300];
        snprintf(monpath, sizeof monpath, "%s/monx20", data);
        u2_sector_id id = { 2, 0 };
        if (u2_world_load(&a, &ow.world, 0, id) != U2_WORLD_OK) {
            ok(0, "the synthetic monx20 did not load");
        } else {
            a.state.mon_x[3] = 10; a.state.mon_y[3] = 10;
            a.state.mon_hp[3] = 40; a.state.mon_type[3] = 0x30;
            u2_monsters_store(&a, &ow.world);
            ok(ow.world.mon_dirty == 1,
               "copying the arrays out dirties the creature block");
            ok(u2_overworld_save(&a, &ow, &U2_SAVE_POLICY_ORIGINAL) == 0,
               "Q saves with a dirty creature block");
            unsigned char mb[256];
            FILE *mf = fopen(monpath, "rb");
            int got = mf ? (int)fread(mb, 1, 256, mf) : 0;
            if (mf) fclose(mf);
            ok(got == 256 && mb[96 + 3] == 0x30,
               "Q writes the creature block, not only the map (asm/2305 names MONXFF)");
            ok(ow.world.mon_dirty == 0,
               "and the dirty flag clears, so a clean save rewrites nothing");

            /* The kill: three fields cleared, as asm/2E3D leaves them. */
            a.state.mon_hp[3] = 0; a.state.mon_type[3] = 0; a.state.mon_kind[3] = 0;
            u2_monsters_store(&a, &ow.world);
            u2_overworld_save(&a, &ow, &U2_SAVE_POLICY_ORIGINAL);
            mf = fopen(monpath, "rb"); got = mf ? (int)fread(mb, 1, 256, mf) : 0;
            if (mf) fclose(mf);
            ok(got == 256 && mb[96 + 3] == 0,
               "a killed creature is gone from the file too, so it does not revive on reload");
        }
    }

    /* The CP11 extension point: same guard, policy flipped, saves anyway. */
    u2_save_policy mod = { 1, 1, 1 };
    ok(u2_overworld_save(&a, &inside, &mod) == 0,
       "policy allow_indoors saves anyway (community-patch hook, CP11)");
    /* restore the faithful save as the final state of run one */
    u2_overworld_save(&a, &ow, &U2_SAVE_POLICY_ORIGINAL);

    /* --- run two: quit, restart, P loads the record ---------------------- */
    u2_ctx b;
    memset(&b, 0, sizeof b);
    b.data_dir = data;
    b.save_dir = saves;
    u2_vram_init(&b.vram);
    u2_state_init(&b.state);
    ok(u2_save_load(&b) == U2_SAVE_OK, "P finds the saved record");
    ok(b.state.entry_x == 30 && b.state.entry_y == 40,
       "the record carries the saved position, not the sector spawn");
    ok(b.state.sector_first == 2 && b.state.sector_second == 0,
       "and the sector it was saved in");
    ok(b.state.name[0] == 'T' && b.state.name[5] == 'R',
       "name survived the round trip");
    /* u2_overworld_init_state consumes exactly these four fields as the
     * spawn; asserting them here is the P contract without needing the
     * tile art (which only a real executable can supply). */

    printf("save_q_check: %s\n", fails ? "FAIL" : "PASS");
    return fails ? 1 : 0;
}
