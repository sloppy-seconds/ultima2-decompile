/*
 * creation.c — character generation, the form, and the save.
 *
 * spec: asm/5400_sub_5400.asm, file 0x5600..0x5C66. Citations in the comments
 * are FILE offsets into original/ultimaii.exe, readable in
 * disasm/redecoded/5400_sub_5400.txt.
 *
 * All display text comes from the generated content header; nothing here is a
 * hardcoded game string.
 */

#include <string.h>
#include "game/creation.h"
    /* unused include removed: 'C' now returns to the menu instead of drawing
     * the status block (owner acceptance, CP3). */
#include "core/save.h"
#include "core/seam.h"
#include "gen_content.h"

/* asm/53B0 reads two digits and returns (d1<<4)|d2; the value is printed back
 * with asm/55B5, which splits the same nibbles. So the working unit is a packed
 * decimal byte, and additions to it use DAA. */
#define STAT_COL      26          /* every stat value prints at column 26 */
#define STAT_ROW_FIRST 4          /* rows 4..9, one per stat */
#define PROMPT_ROW    11          /* M/F at row 11 col 20 (file 0x593F) */
#define PROMPT_COL    20
#define BUDGET_ROW    2           /* remaining points at row 2 col 33 (0x5C7D) */
#define BUDGET_COL    33
#define BUDGET_START  0x90        /* packed 90, set at file 0x56E6 */
#define STAT_MIN      0x0A        /* asm/5C69: below this, restart generation */
#define NAME_ROW      14
#define NAME_COL      20
#define NAME_MAX      16          /* [0x36..0x45] */

/* The three axes of modifiers. Each is `mov al,[stat]; add al,$NN; daa;
 * mov [stat],al` — a BCD add, which is why the constants are packed decimal.
 *   MALE   +05 STR  (file 0x5960)      HUMAN  +05 INT  (0x59CF)
 *   FEMALE +10 CHA  (file 0x598F)      ELF    +05 AGI  (0x59FB)
 *   FIGHTER +15 STR (file 0x5AA6)      DWARF  +05 STR  (0x5A29)
 *   CLERIC +10 WIS  (file 0x5AD5)      HOBBIT +10 WIS  (0x5A5B)
 *   WIZARD +10 INT  (file 0x5B04)      THIEF  +10 AGI  (0x5B35)
 * STAMINA is never modified by sex, race or class. */

static int bcd_add(int a, int b)
{
    int v = (a & 0x0F) + (b & 0x0F);
    int t = ((a >> 4) & 0x0F) + ((b >> 4) & 0x0F) + (v / 10);
    v %= 10; t %= 16;
    return (uint8_t)((t << 4) | v);
}

static int bcd_sub(int a, int b)   /* returns -1 when it borrows (overspend) */
{
    int av = (a & 0x0F), bv = (b & 0x0F);
    int at = (a >> 4) & 0x0F, bt = (b >> 4) & 0x0F;
    int borrow = 0;
    if (av < bv) { av += 10; borrow = 1; }
    av -= bv;
    if (at < bt + borrow) return -1;      /* asm/5C75 `das; jb` */
    at -= bt + borrow;
    return (at << 4) | av;
}

/* ---- input helpers ------------------------------------------------------ */

static int wait_key(u2_ctx *ctx)
{
    u2_key k;
    if (!seam_key_wait(ctx, &k)) return -1;   /* input exhausted: the player left */
    return k.ch;
}

/* asm/53B0: wait for a digit, echo it, return 0..9. */
static int read_digit(u2_ctx *ctx)
{
    for (;;) {
        int c = wait_key(ctx);
        if (c < 0) return -1;
        if (c >= '0' && c <= '9') { seam_char_out(ctx, (uint8_t)c); return c - '0'; }
    }
}

/* asm/53B0 in full: two digits packed as nibbles. */
static int read_pair(u2_ctx *ctx)
{
    int hi = read_digit(ctx);
    int lo;
    if (hi < 0) return -1;
    lo = read_digit(ctx);
    if (lo < 0) return -1;
    return (hi << 4) | lo;
}

/* asm/55B5: print a packed decimal byte as its two digits. */
static void print_pair(u2_ctx *ctx, int v)
{
    char b[3];
    b[0] = (char)('0' + ((v >> 4) & 0x0F));
    b[1] = (char)('0' + (v & 0x0F));
    b[2] = '\0';
    seam_str_out(ctx, b);
}

/* asm/55D0: wait for any key and echo it (file 0x55D0 + asm/5203). */
static int read_any(u2_ctx *ctx)
{
    int c = wait_key(ctx);
    if (c >= 0) seam_char_out(ctx, (uint8_t)c);
    return c;
}

/* ---- the form ----------------------------------------------------------- */

static int generate(u2_ctx *ctx)
{
    u2_state *st = &ctx->state;
    uint8_t *stats[6];
    int budget = BUDGET_START, i;

    stats[0] = &st->stat_str; stats[1] = &st->stat_agi; stats[2] = &st->stat_sta;
    stats[3] = &st->stat_cha; stats[4] = &st->stat_wis; stats[5] = &st->stat_int;

    /* file 0x56E6: budget, then the form as one str_out (CR/LF carry the
     * layout, which is exactly what seam_char_print implements).
     *
     * seam_present() matters here and after every field below: the original
     * writes straight to video memory so every character is visible at once,
     * while this engine only pushes the grid to the renderer on present.
     * Without it the whole form is drawn into the vram and never shown, which
     * is invisible to headless tests (they read the grid directly) and looks
     * exactly like "press C, nothing happens" in a terminal. */
    seam_goto(ctx, 0, 0);
    print_pair(ctx, budget);
    seam_str_out(ctx, U2_S_CREATE_FORM);
    seam_present(ctx);

    for (i = 0; i < 6; i++) {
        int v;
        seam_goto(ctx, STAT_COL, STAT_ROW_FIRST + i);
        v = read_pair(ctx);
        if (v < 0) return -1;                       /* input ran out */
        if (v < STAT_MIN) return 1;                 /* asm/5C69 -> restart */
        {
            int left = bcd_sub(budget, v);
            if (left < 0) return 1;                 /* asm/5C75 -> restart */
            budget = left;
        }
        *stats[i] = (uint8_t)v;
        print_pair(ctx, v);
        seam_goto(ctx, BUDGET_COL, BUDGET_ROW);
        print_pair(ctx, budget);
        seam_present(ctx);
    }

    /* Sex: file 0x594E. Loops until M or F; stored as typed. */
    for (;;) {
        seam_goto(ctx, PROMPT_COL, PROMPT_ROW);
        int c = read_any(ctx);
        if (c < 0) return -1;
        if (c == 'M') { seam_str_out(ctx, U2_S_SEX_MALE);   st->sex = 'M';
                        st->stat_str = bcd_add(st->stat_str, 0x05);
                        seam_present(ctx); break; }
        if (c == 'F') { seam_str_out(ctx, U2_S_SEX_FEMALE); st->sex = 'F';
                        st->stat_cha = bcd_add(st->stat_cha, 0x10);
                        seam_present(ctx); break; }
    }

    /* Race: file 0x59AD. '1'..'4', one BCD bonus each, stored 0..3. */
    for (;;) {
        seam_goto(ctx, PROMPT_COL, PROMPT_ROW + 1);
        int c = read_any(ctx);
        if (c < 0) return -1;
        if (c < '1' || c > '4') continue;
        st->race = (uint8_t)(c - '1');
        switch (c) {
        case '1': seam_str_out(ctx, U2_S_RACE_HUMAN);
                  st->stat_int = bcd_add(st->stat_int, 0x05); break;
        case '2': seam_str_out(ctx, U2_S_RACE_ELF);
                  st->stat_agi = bcd_add(st->stat_agi, 0x05); break;
        case '3': seam_str_out(ctx, U2_S_RACE_DWARF);
                  st->stat_str = bcd_add(st->stat_str, 0x05); break;
        default:  seam_str_out(ctx, U2_S_RACE_HOBBIT);
                  st->stat_wis = bcd_add(st->stat_wis, 0x10); break;
        }
        seam_present(ctx);
        break;
    }

    /* Class: file 0x5A8C. '1'..'4', one BCD bonus each, stored 0..3. */
    for (;;) {
        seam_goto(ctx, PROMPT_COL, PROMPT_ROW + 2);
        int c = read_any(ctx);
        if (c < 0) return -1;
        if (c < '1' || c > '4') continue;
        st->pclass = (uint8_t)(c - '1');
        switch (c) {
        case '1': seam_str_out(ctx, U2_S_CLASS_FIGHTER);
                  st->stat_str = bcd_add(st->stat_str, 0x15); break;
        case '2': seam_str_out(ctx, U2_S_CLASS_CLERIC);
                  st->stat_wis = bcd_add(st->stat_wis, 0x10); break;
        case '3': seam_str_out(ctx, U2_S_CLASS_WIZARD);
                  st->stat_int = bcd_add(st->stat_int, 0x10); break;
        default:  seam_str_out(ctx, U2_S_CLASS_THIEF);
                  st->stat_agi = bcd_add(st->stat_agi, 0x10); break;
        }
        seam_present(ctx);
        break;
    }

    /* Name: file 0x5B5C. Field cleared, typed into [0x36..]; backspace restarts
     * the whole field, CR ends it (asm/5BA5 / asm/5BA9). */
    memset(st->name, 0, sizeof st->name);
    seam_goto(ctx, NAME_COL, NAME_ROW);
    seam_str_out(ctx, "                ");
    seam_present(ctx);
    {
        int n = 0;
        for (;;) {
            seam_goto(ctx, NAME_COL, NAME_ROW);
            int c = wait_key(ctx);
            if (c < 0) return -1;
            if (c == '\b') {                       /* asm/5BA5 -> restart field */
                n = 0;
                memset(st->name, 0, sizeof st->name);
                seam_goto(ctx, NAME_COL, NAME_ROW);
                seam_str_out(ctx, "                ");
                continue;
            }
            if (c == '\r' || c == '\n') break;
            if (n < NAME_MAX) {
                st->name[n++] = (uint8_t)c;
                seam_char_out(ctx, (uint8_t)c);
                seam_present(ctx);
            }
        }
    }

    /* SATISFACTORY (Y/N): file 0x5BBC. N restarts generation, anything else
     * re-prompts. */
    for (;;) {
        seam_goto(ctx, 29, 16);
        int c = read_any(ctx);
        if (c < 0) return -1;
        if (c == 'N') return 1;                    /* asm/5BD5 -> 0x5698 */
        if (c == 'Y') break;
    }

    /* Starting values, file 0x5BDC..0x5BF3. */
    st->unk_5A = 20;
    st->unk_5B = 20;
    st->unk_49 = 2;
    st->hp = 4;
    st->food = 4;
    st->gold_lo = 4;
    st->gold_hi = 0;
    return 0;
}

int u2_creation_flow(u2_ctx *ctx)
{
    int restarts = 0;

    if (u2_save_ensure(ctx) == U2_SAVE_NOT_READY) {
        /* The honest analogue of a drive that is not ready: say so and stop,
         * rather than inventing somewhere to write. */
        seam_str_out_at(ctx, 1, 24, U2_S_CREATE_BLANK);
        return -1;
    }

    for (;;) {
        int r;
        seam_clear_screen(ctx);
        seam_str_out_at(ctx, 0, 0, U2_S_CREATE_GENERATION);
        r = generate(ctx);
        if (r == 0) break;
        if (r < 0) return 0;                       /* player bailed */
        if (++restarts > 64) return 0;             /* script loop guard */
    }

    if (u2_save_store(ctx) != U2_SAVE_OK) return -1;

    /* Owner acceptance for CP3: completing the form writes the save and goes
     * back to the main menu, which is what the caller does with this return
     * value. The original instead prints INSERT PROGRAM MASTER and restarts,
     * because the player had to put the program disk back; there is no disk to
     * swap here, so returning to the menu is the faithful equivalent. The new
     * character is visible through 'P', which loads it from disk. */
    return 1;
}
