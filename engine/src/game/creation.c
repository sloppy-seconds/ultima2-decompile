/*
 * creation.c — character generation, the form, and the save.
 *
 * spec: asm/5400_sub_5400.asm, file 0x5600..0x5C66. Citations are FILE offsets
 * into original/ultimaii.exe, readable in disasm/redecoded/5400_sub_5400.txt.
 *
 * What is reproduced exactly (rules and state):
 *   - the form layout and every string on it, from the extracted content header
 *   - stats bought from a 90-point budget, each stat >= 0x0a (asm/5C69). The
 *     original reads two typed digits packed as nibbles (asm/53B0); the engine
 *     keeps them as decimal 0..99 and packs to BCD only at commit, which is the
 *     same value in a different representation.
 *   - the ten BCD bonuses for sex / race / class, and that STAMINA gets none
 *   - race and class stored 0..3 after `sub $0x31`; sex stored as the letter
 *   - starting values HP=4 FOOD=4 GOLD=4 and sector_first=2, entry_x=entry_y=20
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
 * D6 Stat entry is a two-digit shift register: the field shows 00, typing 5
 *    reads 05, typing 0 then reads 50, backspace shifts back out. The original
 *    takes the first digit as the tens, so typing 5 means 50 and immediately
 *    moves on (asm/53B0) — which reads as a bug to anyone who meant 5.
 * D7 The point budget may go negative while typing; the character is simply not
 *    creatable until it lands on exactly 00. The original refuses an overspend
 *    by throwing the whole generation away (asm/5C66 -> 0x5698).
 * D8 Control characters are refused in the name. The original masks the high bit
 *    off every typed byte (asm/5207 `and al,$0x7f`) and then stores whatever is
 *    left, so a control character really can land in the name field. The mask is
 *    reproduced; the control characters are dropped because they render as
 *    garbage and cannot be typed usefully.
 * D9 The confirm line reads [S]AVE / [R]ESET instead of SATISFACTORY (Y/N), and
 *    it is a pair of fields you Tab to and press Enter on. The original asks
 *    "SATISFACTORY (Y/N)-" (asm/5B6E, in the form blob) and restarts the whole
 *    generation from scratch on N (asm/5BD5 -> 0x5698); "not satisfactory" is
 *    not an instruction a player can guess and does not say what happens next.
 *    These are deliberately not hotkeys: as r/R shortcuts they fired the moment
 *    anyone typed the name BRITISH. This is the one place the engine overwrites
 *    an extracted game string, so it paints over row 16 rather than editing the
 *    blob — the blob stays faithful to the binary and the override is visible as
 *    engine text.
 * D10 Every stat starts at 10, the minimum the original enforces, so the player
 *    distributes the 30 points left over rather than building all 90 from zero.
 *    Same solution set — six stats of at least 10 summing to 90 — but an illegal
 *    value now needs deliberate effort instead of a careless keystroke. The
 *    original starts at 0 and throws the generation away when a stat is under 10
 *    (asm/5C69 `cmp al,$0xa; jb` -> asm/5C96).
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
#define NAME_MAX       12      /* asm/5BB7: `cmp bl,$0xc; jb` caps input at 12.
                                * The field itself is 16 bytes ([0x36..0x45]) so
                                * a full name leaves 4 zero pad bytes, which is
                                * what the original writes and what the save
                                * comparison expects. Typing more is impossible
                                * in the original (it just ends the field), and
                                * 13..16 would be a name the original can never
                                * produce, so the cap is a rule, not UX. */
#define CONFIRM_ROW    16      /* the blob's SATISFACTORY line, overwritten (D9) */
#define CONFIRM_COL    10      /* the original indents that line by 10 spaces */
#define CONFIRM_TEXT   "[S]AVE   [R]ESET"

typedef enum { F_STAT, F_SEX, F_RACE, F_CLASS, F_NAME, F_SAVE, F_RESET } field_kind;

typedef struct {
    field_kind kind;
    int row, col;
    int index;                 /* stat index for F_STAT */
} field;

/* Order is the order the original asks in, so Tab walks the form the same way.
 * SAVE and RESET are the last two stops: they are fields you navigate to and
 * press Enter on, not hotkeys. They started life as r/R shortcuts and that
 * failed the first time anyone typed the name BRITISH. */
static const field FIELDS[] = {
    { F_STAT,  4, STAT_COL, 0 }, { F_STAT,  5, STAT_COL, 1 },
    { F_STAT,  6, STAT_COL, 2 }, { F_STAT,  7, STAT_COL, 3 },
    { F_STAT,  8, STAT_COL, 4 }, { F_STAT,  9, STAT_COL, 5 },
    { F_SEX,   11, PROMPT_COL, -1 }, { F_RACE,  12, PROMPT_COL, -1 },
    { F_CLASS, 13, PROMPT_COL, -1 }, { F_NAME,  14, PROMPT_COL, -1 },
    { F_SAVE,  CONFIRM_ROW, CONFIRM_COL, -1 },
    { F_RESET, CONFIRM_ROW, CONFIRM_COL + 9, -1 },   /* "[S]AVE   " is 9 cols */
};
#define NFIELDS ((int)(sizeof FIELDS / sizeof FIELDS[0]))

/* The BCD bonuses. Each is `mov al,[stat]; add al,$NN; daa; mov [stat],al`:
 *   MALE +05 STR (0x5960)     HUMAN  +05 INT (0x59CF)   FIGHTER +15 STR (0x5AA6)
 *   FEMALE +10 CHA (0x598F)   ELF    +05 AGI (0x59FB)   CLERIC  +10 WIS (0x5AD5)
 *                               DWARF  +05 STR (0x5A29)  WIZARD  +10 INT (0x5B04)
 *                               HOBBIT +10 WIS (0x5A5B)  THIEF   +10 AGI (0x5B35)
 * STAMINA is never modified by sex, race or class. */

typedef struct {
    int     val[6];           /* decimal 0..99; 00 means not yet entered */
    int     typed;            /* digits typed into the focused stat (D6) */
    int     sex;            /* 'M' / 'F' */
    int     race;           /* '1'..'4' */
    int     cls;            /* '1'..'4' */
    char    name[NAME_MAX];
    int     name_len;
    int     sel;            /* index into FIELDS */
    char    note[48];       /* engine-authored status line */
} form;

static int up(int c) { return (c >= 'a' && c <= 'z') ? c - 32 : c; }

static int pack_bcd(int d) { return ((d / 10) << 4) | (d % 10); }
static int unpack_bcd(int p) { return (p >> 4) * 10 + (p & 0x0F); }

static int bcd_add(int a, int b)
{
    int v = (a & 0x0F) + (b & 0x0F);
    int t = ((a >> 4) & 0x0F) + ((b >> 4) & 0x0F) + (v / 10);
    return (uint8_t)(((t % 16) << 4) | (v % 10));
}

static int spent(const form *f)
{
    int total = 0;
    for (int i = 0; i < 6; i++) total += f->val[i];
    return total;
}

static int remaining(const form *f)
{
    /* Allowed to go negative (D7): the check happens at creation time, not here. */
    return unpack_bcd(BUDGET_START) - spent(f);
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

/* The budget can read negative while the player is mid-edit (D7), which the
 * original never shows because it forbids the overspend outright. */
static void print_budget(u2_ctx *ctx, int v)
{
    char b[8];
    int a = v < 0 ? -v : v;
    if (a > 999) a = 999;          /* bounded by 6 stats x 99 against a 90 budget */
    if (v < 0) snprintf(b, sizeof b, "-%02d", a);
    else snprintf(b, sizeof b, "%02d", a);
    seam_str_out(ctx, b);
}

/* ---- drawing ------------------------------------------------------------ */

static void draw_budget_line(u2_ctx *ctx, const form *f)
{
    /* asm/5C7D..5C89: after every stat the original goes to column 33 row 2 and
     * prints the new total there. That is the value slot of the POINTS line. */
    seam_goto(ctx, BUDGET_COL, BUDGET_ROW);
    print_budget(ctx, remaining(f));
}

static void draw_field(u2_ctx *ctx, form *f, int which)
{
    const field *fd = &FIELDS[which];
    switch (fd->kind) {
    case F_STAT:
        seam_goto(ctx, fd->col, fd->row);
        print_pair(ctx, pack_bcd(f->val[fd->index]));
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
        /* Pad the field with the bare primitive, not char_print: the cell is already
         * inside the margin and the field must not wrap or sync the cursor. */
        for (int i = f->name_len; i < NAME_MAX; i++) seam_char_out(ctx, ' ');
        break;
    }
    case F_SAVE:
    case F_RESET:
        break;                          /* static labels, nothing to redraw */
    }
}

static void place_cursor(u2_ctx *ctx, form *f)
{
    const field *fd = &FIELDS[f->sel];
    int col = fd->col, row = fd->row;
    switch (fd->kind) {
    case F_STAT: col += 2; break;
    case F_SEX:  col += 5; break;
    case F_RACE:
    case F_CLASS: col += 6; break;
    case F_NAME: col += 6 + f->name_len; break;
    case F_SAVE:
    case F_RESET: break;               /* cursor sits on the label itself */
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
    /* The GENERATION heading carries no number. asm/56C8 prints "POINTS LEFT TO
     * DISTRIBUTE : " and asm/5C85 addresses the total at column 33 row 2, which
     * is where this 28-character line leaves the cursor when it starts at col 5. */
    seam_goto(ctx, BUDGET_COL - (int)strlen(U2_S_CREATE_POINTS), BUDGET_ROW);
    seam_str_out(ctx, U2_S_CREATE_POINTS);
    print_budget(ctx, remaining(f));
    /* The blob carries its own layout as CR/LF, and the original addresses the
     * stat prompts at absolute rows 4..9 (asm/58B0 etc.), M/F at 11, RACE 12,
     * TYPE 13, NAME 14, SATISFACTORY 16. Its leading CR LF therefore has to
     * start from row 2 to land the first line on row 4; printing it from row 0
     * shifted every field up two rows and wrote values over the wrong labels. */
    seam_goto(ctx, 0, 2);
    seam_str_out(ctx, U2_S_CREATE_FORM);
    /* D9: paint over the blob's "SATISFACTORY (Y/N)-" line. The blob itself is
     * left exactly as extracted — this is a presentation override, not an edit
     * to the content. */
    seam_clear_row(ctx, CONFIRM_ROW);
    seam_str_out_at(ctx, CONFIRM_COL, CONFIRM_ROW, CONFIRM_TEXT);
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
        if (f->val[i] < STAT_MIN) { snprintf(why, n, "[engine] stat %d must be 10 or more", i + 1); return 0; }
    }
    int left = remaining(f);
    if (left > 0) { snprintf(why, n, "[engine] %d point%s left to spend", left, left == 1 ? "" : "s"); return 0; }
    if (left < 0) { snprintf(why, n, "[engine] %d points over budget", -left); return 0; }
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
    /* The original upper-cases the keys it matches on (asm/4F4D `and $0xdf`), so
     * case never matters for a choice. The name is the one field that keeps it. */
    if (fd->kind != F_NAME) c = up(c);

    switch (fd->kind) {
    case F_STAT: {
        if (c == '\b') {
            /* Backspace returns the stat to its minimum. The original has no
             * editing at all — a bad value throws the generation away — so there
             * is no behaviour to match here, only something that makes sense. */
            f->val[fd->index] = STAT_MIN;
            f->typed = 0;
            draw_field(ctx, f, f->sel);
            draw_budget_line(ctx, f);
            return 0;
        }
        if (c < '0' || c > '9') {
            /* D3: refuse in place rather than discarding the generation. */
            snprintf(f->note, sizeof f->note, "[engine] %s is two digits",
                     "that stat");
            return 0;
        }
        /* D6: shift left and take the new digit in the units place, so 5 reads
         * 05 and a following 0 reads 50. The first digit into a field starts a
         * fresh number, so it replaces the prefilled minimum instead of shifting
         * it. The original puts the first digit in the tens place (asm/53B0),
         * which is why typing 5 there means 50. */
        if (f->typed == 0) f->val[fd->index] = 0;
        int nv = (f->val[fd->index] * 10 + (c - '0')) % 100;
        /* No clamp here: a half-typed value like 05 is normal mid-entry. The
         * minimum is enforced in complete(), where it is a useful message. */
        f->val[fd->index] = nv;
        f->typed++;
        draw_field(ctx, f, f->sel);
        draw_budget_line(ctx, f);
        return f->typed >= 2 ? 1 : 0;      /* two digits fills the field */
    }
    case F_SEX:
        if (c != 'M' && c != 'F') { snprintf(f->note, sizeof f->note, "[engine] M or F"); return 0; }
        f->sex = c;
        draw_field(ctx, f, f->sel);
        return 1;
    case F_RACE:
        if (c < '1' || c > '4') { snprintf(f->note, sizeof f->note, "[engine] race 1-4"); return 0; }
        f->race = c;
        draw_field(ctx, f, f->sel);
        return 1;
    case F_CLASS:
        if (c < '1' || c > '4') { snprintf(f->note, sizeof f->note, "[engine] type 1-4"); return 0; }
        f->cls = c;
        draw_field(ctx, f, f->sel);
        return 1;
    case F_NAME:
        if (c == '\b') {                          /* D2: delete one char */
            if (f->name_len > 0) f->name_len--;
            draw_field(ctx, f, f->sel);
            return 0;
        }
        /* asm/5203 masks the high bit off every typed character
         * (`and al,$0x7f`) and otherwise stores whatever arrives, control
         * characters included. The mask is reproduced; the control characters
         * are refused (D8) because a BEL or ESC stored in a name renders as
         * garbage and no player can type one usefully. The original has no
         * length problem to guard against because it stops at 12 by itself. */
        c &= 0x7F;                                /* asm/5207 */
        if (c < 0x20 || c == 0x7F) {
            snprintf(f->note, sizeof f->note, "[engine] printable characters only");
            return 0;
        }
        if (f->name_len < NAME_MAX) f->name[f->name_len++] = (char)c;
        if (f->name_len == NAME_MAX) {
            snprintf(f->note, sizeof f->note, "[engine] 12 characters is the limit");
            return 1;
        }
        draw_field(ctx, f, f->sel);
        return 0;
    case F_SAVE:
    case F_RESET:
        return 0;                       /* activated by Enter, not by typing */
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
        *stats[i] = (uint8_t)pack_bcd(f->val[i]);

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

    st->entry_x = 20; st->entry_y = 20; st->sector_first = 2;  /* 0x5BDC..0x5BE8 */
    /* DS:4A (sector_second) is never written by creation: a fresh segment
     * holds 0 there and the saved record carries it as the overworld digit. */
    st->hp = 4; st->food = 4;                          /* 0x5BEB..0x5BF3 */
    st->gold_lo = 4; st->gold_hi = 0;
}

/* [S]AVE / [R]ESET are standing shortcuts on the confirm line (D9), handled in
 * the main loop rather than as a modal prompt: the original only asks the
 * question once the form is already complete, and a player who presses the key
 * early deserves an answer about what is missing, not a swallowed keystroke. */

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
        /* Every stat starts at the minimum the original enforces (asm/5C69:
         * `cmp al,$0xa; jb` fail). Six stats at 10 consume 60 of the 90, so the
         * player distributes the remaining 30 — the same solution set as "90
         * total, each at least 10", with no way to type an illegal value. */
        for (int i = 0; i < 6; i++) f.val[i] = STAT_MIN;
        draw_form(ctx, &f);

        int done = 0;
        while (!done) {
            int c = wait_key(ctx);
            if (c < 0) return 0;                    /* bailed or input ended */
            if (c == 0x1b) return 0;                /* ESC abandons creation (D11) */

            if (c == '\t' || c == U2_KEY_DOWN || c == U2_KEY_RIGHT) {
                f.sel = (f.sel + 1) % NFIELDS;      /* D1 */
                f.typed = 0;
                draw_form(ctx, &f);
            } else if (c == U2_KEY_UP || c == U2_KEY_LEFT) {
                f.sel = (f.sel + NFIELDS - 1) % NFIELDS;
                f.typed = 0;
                draw_form(ctx, &f);
            } else if (c == '\r' || c == '\n') {
                /* Enter walks the form and activates whatever it lands on. On
                 * SAVE it validates and commits; on RESET it rebuilds. Nothing
                 * else, so no letter you can type into the name is also a
                 * command. */
                if (FIELDS[f.sel].kind == F_RESET) { done = -1; break; }
                if (FIELDS[f.sel].kind == F_SAVE) {
                    char why[48];
                    if (!complete(&f, why, sizeof why)) {
                        snprintf(f.note, sizeof f.note, "%s", why);
                        draw_form(ctx, &f);
                        continue;
                    }
                    commit(ctx, &f);
                    done = 1;
                } else {
                    f.sel = (f.sel + 1) % NFIELDS;
                    f.typed = 0;
                }
            } else {
                int adv = edit_field(ctx, &f, c);
                if (adv) { f.sel = (f.sel + 1) % NFIELDS; f.typed = 0; }
                /* Only repaint the whole screen when something actually changed
                 * up there; a keystroke that just moves the cursor should not
                 * clear and redraw the form. */
                if (f.note[0]) draw_form(ctx, &f);
                else { place_cursor(ctx, &f); seam_present(ctx); }
            }
        }
        if (done == 1) {
            if (u2_save_store(ctx) != U2_SAVE_OK) return -1;
            return 1;
        }
        /* done == -1: RESET was activated; the outer loop rebuilds an empty form */
    }
}
