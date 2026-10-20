/*
 * creation.c — character generation, the form, and the save.
 *
 * spec: asm/5400_sub_5400.asm, file 0x5600..0x5C66. Citations are FILE offsets
 * into original/ultimaii.exe, readable in disasm/redecoded/5400_sub_5400.txt.
 *
 * What is reproduced exactly (rules and state):
 *   - the form layout and every string on it, from the extracted content header
 *   - stats bought as two typed digits packed as nibbles (asm/53B0), from a
 *     packed-BCD 90 budget (DS:29, set at 0x56E6), each stat >= 0x0a (asm/5C69)
 *   - the ten BCD bonuses for sex / race / class, and that STAMINA gets none
 *   - race and class stored 0..3 after `sub $0x31`; sex stored as the letter
 *   - starting values HP=4 FOOD=4 GOLD=4 and unk_49=2, unk_5A=unk_5B=20
 *   - the 256-byte record written to a byte-compatible PLAYER file
 *
 * What is deliberately improved (docs/phase4-plan.md § 4a, deviations D1-D4):
 *   D1 Tab / arrows move between fields and any field can be re-edited. The
 *      original is strictly sequential (asm/53B0 reads, stores, moves on).
 *   D2 Backspace deletes one character. The original restarts the whole name
 *      field (asm/5BA5).
 *   D3 An illegal entry is refused in place. The original discards the entire
 *      generation and jumps back to asm/5698.
 *   D4 The cursor is shown on the field being edited. The original shows no
 *      cursor, so there is no indication which field is active.
 * None of these change what is achievable or what lands in DS or on disk.
 *
 * All display text comes from the generated content header; nothing here is a
 * hardcoded game string. Engine-authored text is marked "[engine]".
 */

#include <string.h>
#include "game/creation.h"
#include "core/save.h"
#include "core/seam.h"
#include "gen_content.h"

#define STAT_COL       26      /* asm/58B7: every stat value at column 26 */
#define STAT_ROW_FIRST 4       /* rows 4..9, one per stat (asm/58B0 etc.) */
#define PROMPT_COL     20
#define PROMPT_ROW     11      /* M/F row 11, RACE 12, TYPE 13, NAME 14 */
#define BUDGET_ROW     2
#define BUDGET_COL     33      /* asm/5C7D: remaining points printed here */
#define BUDGET_START   0x90    /* packed 90, asm/56E6 */
#define STAT_MIN       0x0A    /* asm/5C69: below this the original restarts */
#define NAME_MAX       16      /* [0x36..0x45] */
#define SAT_ROW        16
#define SAT_COL        29

typedef enum { F_STAT, F_SEX, F_RACE, F_CLASS, F_NAME } field_kind;

typedef struct {
    field_kind kind;
    int row, col;
    int index;                 /* stat index for F_STAT */
} field;

/* Order is the order the original asks in, so Tab walks the form the same way. */
static const field FIELDS[] = {
    { F_STAT,  4, STAT_COL, 0 }, { F_STAT,  5, STAT_COL, 1 },
    { F_STAT,  6, STAT_COL, 2 }, { F_STAT,  7, STAT_COL, 3 },
    { F_STAT,  8, STAT_COL, 4 }, { F_STAT,  9, STAT_COL, 5 },
    { F_SEX,   11, PROMPT_COL, -1 }, { F_RACE,  12, PROMPT_COL, -1 },
    { F_CLASS, 13, PROMPT_COL, -1 }, { F_NAME,  14, PROMPT_COL, -1 },
};
#define NFIELDS ((int)(sizeof FIELDS / sizeof FIELDS[0]))

/* The BCD bonuses. Each is `mov al,[stat]; add al,$NN; daa; mov [stat],al`:
 *   MALE +05 STR (0x5960)     HUMAN  +05 INT (0x59CF)   FIGHTER +15 STR (0x5AA6)
 *   FEMALE +10 CHA (0x598F)   ELF    +05 AGI (0x59FB)   CLERIC  +10 WIS (0x5AD5)
 *                               DWARF  +05 STR (0x5A29)  WIZARD  +10 INT (0x5B04)
 *                               HOBBIT +10 WIS (0x5A5B)  THIEF   +10 AGI (0x5B35)
 * STAMINA is never modified by sex, race or class. */

typedef struct {
    uint8_t bought[6];      /* packed decimal, as typed */
    int     entered[6];
    int     sex;            /* 'M' / 'F' */
    int     race;           /* '1'..'4' */
    int     cls;            /* '1'..'4' */
    char    name[NAME_MAX];
    int     name_len;
    int     sel;            /* index into FIELDS */
    char    note[48];       /* engine-authored status line */
} form;

static int bcd_add(int a, int b)
{
    int v = (a & 0x0F) + (b & 0x0F);
    int t = ((a >> 4) & 0x0F) + ((b >> 4) & 0x0F) + (v / 10);
    return (uint8_t)(((t % 16) << 4) | (v % 10));
}

static int bcd_sub(int a, int b)   /* -1 when it borrows (an overspend) */
{
    int av = a & 0x0F, at = (a >> 4) & 0x0F;
    int bv = b & 0x0F, bt = (b >> 4) & 0x0F;
    int borrow = 0;
    if (av < bv) { av += 10; borrow = 1; }
    av -= bv;
    if (at < bt + borrow) return -1;
    return ((at - bt - borrow) << 4) | av;
}

static int spent(const form *f)
{
    int total = 0;
    for (int i = 0; i < 6; i++)
        if (f->entered[i]) total = bcd_add(total, f->bought[i]);
    return total;
}

static int remaining(const form *f)
{
    int r = bcd_sub(BUDGET_START, spent(f));
    return r < 0 ? 0 : r;
}

/* ---- low-level I/O ------------------------------------------------------ */

static int wait_key(u2_ctx *ctx)
{
    u2_key k;
    if (!seam_key_wait(ctx, &k)) return -1;   /* input exhausted: the player left */
    if (k.ch == 0x11) {                       /* Ctrl-Q quits from anywhere (D5) */
        ctx->exit_code = 0;
        return -1;
    }
    return k.ch;
}

static void print_pair(u2_ctx *ctx, int v)
{
    char b[3];
    b[0] = (char)('0' + ((v >> 4) & 0x0F));
    b[1] = (char)('0' + (v & 0x0F));
    b[2] = '\0';
    seam_str_out(ctx, b);
}

/* ---- drawing ------------------------------------------------------------ */

static void draw_field(u2_ctx *ctx, form *f, int which)
{
    const field *fd = &FIELDS[which];
    switch (fd->kind) {
    case F_STAT:
        seam_goto(ctx, fd->col, fd->row);
        if (f->entered[fd->index]) print_pair(ctx, f->bought[fd->index]);
        else seam_str_out(ctx, "..");
        break;
    case F_SEX:
        seam_goto(ctx, fd->col + 5, fd->row);
        seam_str_out(ctx, f->sex ? (f->sex == 'M' ? U2_S_SEX_MALE : U2_S_SEX_FEMALE)
                                 : "-");
        break;
    case F_RACE:
        seam_goto(ctx, fd->col + 6, fd->row);
        seam_str_out(ctx, f->race ? (f->race == '1' ? U2_S_RACE_HUMAN
                                 : f->race == '2' ? U2_S_RACE_ELF
                                 : f->race == '3' ? U2_S_RACE_DWARF
                                                   : U2_S_RACE_HOBBIT) : "-");
        break;
    case F_CLASS:
        seam_goto(ctx, fd->col + 6, fd->row);
        seam_str_out(ctx, f->cls ? (f->cls == '1' ? U2_S_CLASS_FIGHTER
                                  : f->cls == '2' ? U2_S_CLASS_CLERIC
                                  : f->cls == '3' ? U2_S_CLASS_WIZARD
                                                   : U2_S_CLASS_THIEF) : "-");
        break;
    case F_NAME: {
        seam_goto(ctx, fd->col + 6, fd->row);
        char b[NAME_MAX + 1];
        memcpy(b, f->name, (size_t)f->name_len);
        b[f->name_len] = '\0';
        seam_str_out(ctx, b);
        for (int i = f->name_len; i < NAME_MAX; i++) seam_char_out(ctx, ' ');
        break;
    }
    }
}

static void place_cursor(u2_ctx *ctx, form *f)
{
    const field *fd = &FIELDS[f->sel];
    int col = fd->col, row = fd->row;
    switch (fd->kind) {
    case F_STAT: col += f->entered[fd->index] ? 2 : 0; break;
    case F_SEX:  col += 5; break;
    case F_RACE:
    case F_CLASS: col += 6; break;
    case F_NAME: col += 6 + f->name_len; break;
    }
    /* D4: the original gives no indication of the active field. */
    ctx->vram.visible = 1;
    seam_goto(ctx, col, row);
}

static void draw_form(u2_ctx *ctx, form *f)
{
    seam_clear_screen(ctx);
    /* asm/569E prints the heading and asm/56EB prints the budget right after it,
     * on the same line — not at (0,0), which is what collided before. */
    seam_str_out(ctx, U2_S_CREATE_GENERATION);
    print_pair(ctx, remaining(f));
    /* The blob carries its own layout as CR/LF, and the original addresses the
     * stat prompts at absolute rows 4..9 (asm/58B0 etc.), M/F at 11, RACE 12,
     * TYPE 13, NAME 14, SATISFACTORY 16. Its leading CR LF therefore has to
     * start from row 2 to land the first line on row 4; printing it from row 0
     * shifted every field up two rows and wrote values over the wrong labels. */
    seam_goto(ctx, 0, 2);
    seam_str_out(ctx, U2_S_CREATE_FORM);
    for (int i = 0; i < NFIELDS; i++)
        draw_field(ctx, f, i);
    if (f->note[0]) {
        seam_clear_row(ctx, 23);
        seam_str_out_at(ctx, 1, 23, f->note);
        f->note[0] = '\0';
    }
    place_cursor(ctx, f);
    seam_present(ctx);
}

/* ---- editing ------------------------------------------------------------ */

static int complete(const form *f, char *why, size_t n)
{
    for (int i = 0; i < 6; i++) {
        if (!f->entered[i]) { snprintf(why, n, "[engine] stat %d not entered", i + 1); return 0; }
        if (f->bought[i] < STAT_MIN) { snprintf(why, n, "[engine] each stat must be 10 or more"); return 0; }
    }
    if (!f->sex)   { snprintf(why, n, "[engine] choose M or F"); return 0; }
    if (!f->race)  { snprintf(why, n, "[engine] choose a race"); return 0; }
    if (!f->cls)   { snprintf(why, n, "[engine] choose a type"); return 0; }
    if (!f->name_len) { snprintf(why, n, "[engine] a name is needed"); return 0; }
    return 1;
}

/* Returns 1 to advance to the next field. */
static int edit_field(u2_ctx *ctx, form *f, int c)
{
    const field *fd = &FIELDS[f->sel];
    f->note[0] = '\0';

    switch (fd->kind) {
    case F_STAT: {
        if (c < '0' || c > '9') {
            /* D3: refuse in place rather than discarding the generation. */
            snprintf(f->note, sizeof f->note,
                     "[engine] stat is two digits (00-99)");
            f->entered[fd->index] = 0;
            f->bought[fd->index] = 0;
            draw_field(ctx, f, f->sel);
            return 0;
        }
        /* Build the packed pair digit by digit, like asm/53B0 does. */
        if (!f->entered[fd->index]) { f->bought[fd->index] = (uint8_t)((c - '0') << 4);
                                      f->entered[fd->index] = 1; draw_field(ctx, f, f->sel); return 0; }
        int v = (f->bought[fd->index] & 0xF0) | (c - '0');
        int old = f->bought[fd->index];
        int total_without = 0;
        for (int i = 0; i < 6; i++)
            if (i != fd->index && f->entered[i]) total_without = bcd_add(total_without, f->bought[i]);
        if (bcd_sub(BUDGET_START, bcd_add(total_without, v)) < 0) {
            /* D3: the original restarts everything here (asm/5C75 -> 0x5698). */
            snprintf(f->note, sizeof f->note,
                     "[engine] only %d points left; stat cleared",
                             ((BUDGET_START >> 4) * 10 + (BUDGET_START & 0x0F)) -
                             ((total_without >> 4) * 10 + (total_without & 0x0F)));
            f->entered[fd->index] = 0;
            f->bought[fd->index] = 0;
            draw_field(ctx, f, f->sel);
            return 0;
        }
        (void)old;
        f->bought[fd->index] = (uint8_t)v;
        draw_field(ctx, f, f->sel);
        return 1;
    }
    case F_SEX:
        if (c != 'M' && c != 'F') { snprintf(f->note, sizeof f->note, "[engine] M or F"); return 0; }
        f->sex = c;
        return 1;
    case F_RACE:
        if (c < '1' || c > '4') { snprintf(f->note, sizeof f->note, "[engine] race 1-4"); return 0; }
        f->race = c;
        return 1;
    case F_CLASS:
        if (c < '1' || c > '4') { snprintf(f->note, sizeof f->note, "[engine] type 1-4"); return 0; }
        f->cls = c;
        return 1;
    case F_NAME:
        if (c == '\b') {                          /* D2: delete one char */
            if (f->name_len > 0) f->name_len--;
            draw_field(ctx, f, f->sel);
            return 0;
        }
        if (c >= 0x20 && c < 0x7F && c != '\r' && c != '\n') {
            if (f->name_len < NAME_MAX) f->name[f->name_len++] = (char)c;
            draw_field(ctx, f, f->sel);
        }
        return 0;
    }
    return 0;
}

/* Apply the bonuses and starting values, exactly as the original writes them. */
static void commit(u2_ctx *ctx, form *f)
{
    u2_state *st = &ctx->state;
    uint8_t *stats[6] = { &st->stat_str, &st->stat_agi, &st->stat_sta,
                          &st->stat_cha, &st->stat_wis, &st->stat_int };
    for (int i = 0; i < 6; i++)
        *stats[i] = f->bought[i];

    if (f->sex == 'M') st->stat_str = bcd_add(st->stat_str, 0x05);   /* 0x5960 */
    if (f->sex == 'F') st->stat_cha = bcd_add(st->stat_cha, 0x10);   /* 0x598F */

    switch (f->race) {
    case '1': st->stat_int = bcd_add(st->stat_int, 0x05); break;      /* 0x59CF */
    case '2': st->stat_agi = bcd_add(st->stat_agi, 0x05); break;      /* 0x59FB */
    case '3': st->stat_str = bcd_add(st->stat_str, 0x05); break;      /* 0x5A29 */
    case '4': st->stat_wis = bcd_add(st->stat_wis, 0x10); break;      /* 0x5A5B */
    }
    switch (f->cls) {
    case '1': st->stat_str = bcd_add(st->stat_str, 0x15); break;      /* 0x5AA6 */
    case '2': st->stat_wis = bcd_add(st->stat_wis, 0x10); break;      /* 0x5AD5 */
    case '3': st->stat_int = bcd_add(st->stat_int, 0x10); break;      /* 0x5B04 */
    case '4': st->stat_agi = bcd_add(st->stat_agi, 0x10); break;      /* 0x5B35 */
    }

    st->sex = (uint8_t)f->sex;                 /* stored as the letter */
    st->race = (uint8_t)(f->race - '1');       /* asm/5A7A: sub $0x31 */
    st->pclass = (uint8_t)(f->cls - '1');      /* asm/5B57: sub $0x31 */
    memset(st->name, 0, sizeof st->name);
    memcpy(st->name, f->name, (size_t)f->name_len);

    st->unk_5A = 20; st->unk_5B = 20; st->unk_49 = 2;   /* 0x5BDC..0x5BE8 */
    st->hp = 4; st->food = 4;                          /* 0x5BEB..0x5BF3 */
    st->gold_lo = 4; st->gold_hi = 0;
}

/* SATISFACTORY (Y/N): the original restarts generation on N (asm/5BD5 -> 0x5698)
 * and re-prompts on anything else. Here N clears the form in place (D3). */
static int satisfactory(u2_ctx *ctx, form *f)
{
    for (;;) {
        place_cursor(ctx, f);
        seam_present(ctx);
        int c = wait_key(ctx);
        if (c < 0) return -1;
        if (c == 'N') return 0;
        if (c == 'Y') return 1;
    }
}

int u2_creation_flow(u2_ctx *ctx)
{
    if (u2_save_ensure(ctx) == U2_SAVE_NOT_READY) {
        /* The honest analogue of a drive that is not ready. */
        seam_str_out_at(ctx, 1, 24, U2_S_CREATE_BLANK);
        return -1;
    }

    for (;;) {
        form f;
        memset(&f, 0, sizeof f);
        draw_form(ctx, &f);

        int done = 0;
        while (!done) {
            int c = wait_key(ctx);
            if (c < 0) return 0;                    /* bailed or input ended */

            int adv = 0;
            if (c == '\t' || c == U2_KEY_DOWN || c == U2_KEY_RIGHT) {
                f.sel = (f.sel + 1) % NFIELDS;      /* D1 */
            } else if (c == U2_KEY_UP || c == U2_KEY_LEFT) {
                f.sel = (f.sel + NFIELDS - 1) % NFIELDS;
            } else if (c == '\r' || c == '\n') {
                char why[48];
                if (!complete(&f, why, sizeof why)) {
                    snprintf(f.note, sizeof f.note, "%s", why);
                    draw_form(ctx, &f);
                    continue;
                }
                int ok = satisfactory(ctx, &f);
                if (ok < 0) return 0;
                if (ok == 0) { done = -1; break; }  /* N: rebuild the form */
                commit(ctx, &f);
                done = 1;
            } else {
                adv = edit_field(ctx, &f, c);
                if (adv && f.sel + 1 < NFIELDS) f.sel++;
                if (f.note[0]) draw_form(ctx, &f);
                else place_cursor(ctx, &f), seam_present(ctx);
                continue;
            }
            (void)adv;
            draw_form(ctx, &f);
        }
        if (done == 1) {
            if (u2_save_store(ctx) != U2_SAVE_OK) return -1;
            return 1;
        }
        /* done == -1: the player said not satisfactory; loop rebuilds the form */
    }
}
