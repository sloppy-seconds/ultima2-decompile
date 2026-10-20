/*
 * title.c — presentation intro, title screen, menu, and the 'D' demonstration.
 *
 * spec (asm/ tree, one module per region as planned):
 *   startup flag      asm/0133_sub_0133.asm        (DS:0x239 = 0)
 *   intro screen 1    asm/0142 + asm/014B, asm/0155/0158/015E
 *   timed hold        asm/0688_sub_0688.asm        (polls ESC, jumps to the
 *                                                    title entry at 0x242)
 *   intro screen 2    asm/0180/0184/018D, asm/0198/019B/01A1,
 *                     asm/01BB/01BE/01C4, asm/01E1/01E4/01EA
 *   screen clear      asm/4A3E_sub_4a3e.asm        (INT 10h AH=00h AL=04h)
 *   story gate        asm/0237_sub_0237.asm        (branch on DS:0x239)
 *   title entry       asm/0242_sub_0242.asm        (target of every ESC / bad choice)
 *   title lines       asm/0246, 025E, 0273, 0288, 02A3, 02CC, 02E6,
 *                     02F8, 031F, 034B, 0375
 *   choice wait       asm/0389/038C/038F           (key_poll until AH=0xFF)
 *   choice dispatch   asm/0394..03A6               ('D' jumps ahead; 'P' calls
 *                                                    asm/0764; 'C' calls
 *                                                    asm/5400 then asm/0764;
 *                                                    anything else redraws)
 *   mode set + flag   asm/03B0 -> asm/4A3E, asm/03B3 (DS:0x239 = 1)
 *   demo poem         asm/03AC_sub_03ac.asm        (12 lines, rows 23 and 24)
 *   row clears        asm/53A0_sub_53a0.asm, asm/538F_sub_538f.asm
 *
 * Every string here comes from the generated header, which the extractor
 * produced from the user's own copy. No game text is written in this file: the
 * only engine-authored strings are the CP3 stub notices, and they say so.
 *
 * Two things the original does that this module does not, on purpose:
 *   - it loads PIC picture files during the intro (the FCB names around file
 *     0x419 and the INT 21h sector read at asm/535A_sub_535a.asm). The engine
 *     has no bitmap content pipeline until CP9, so the text screens stand
 *     alone.
 *   - asm/03A9 (create) and the call at asm/03AC's head are character creation
 *     and the play setup; they are CP3 and are stubbed below.
 */
#include <stdio.h>
#include "game/title.h"
#include "core/seam.h"
#include "core/timer.h"
#include "debug/trace.h"
#include "gen_content.h"

/* Positions are read off the code that sets DS:0x2E (column) and DS:0x2F
 * (row) before each str_out; each line below cites the function that sets it. */
typedef struct txt { int col; int row; const char *s; } txt;

static const txt INTRO_1[] = {
    { 16, 10, U2_S_INTRO_ORIGIN },      /* asm/0142: di=0x10 si=0xa */
    { 11, 12, U2_S_INTRO_PROUDLY },     /* asm/0155/0158: di=0xb si=0xc */
};
static const txt INTRO_2[] = {
    { 16,  8, U2_S_INTRO_PART },        /* asm/0184: di=0x10 si=8 */
    {  9, 10, U2_S_INTRO_BESTSELLER },  /* asm/0198/019B: di=9 si=0xa */
    {  7, 12, U2_S_INTRO_GENRE },       /* asm/01BB/01BE: di=7 si=0xc */
    { 12, 14, U2_S_INTRO_AUTHOR },      /* asm/01E1/01E4: di=0xc si=0xe */
};
static const txt TITLE[] = {
    /* Draw order is the order the code sets the cursor and calls str_out:
     * asm/0246, 025E, 0273, 0288, 02A3, 02CC, 02E6, 02F8, 031F, 034B, 0375.
     * The order matters: the choice echo (asm/0394) prints at whatever cursor
     * the last line leaves behind, and CHOICE: is drawn last so the key lands
     * right after it. */
    { 15,  1, U2_S_TITLE_GAME },        /* asm/0246 */
    { 16,  3, U2_S_TITLE_REVENGE },     /* asm/025E */
    { 16,  5, U2_S_TITLE_OF_THE },      /* asm/0273 */
    { 14,  7, U2_S_TITLE_ENCHANTRESS }, /* asm/0288 */
    {  6, 22, U2_S_TITLE_COPYRIGHT },   /* asm/02A3 (inside a mis-decoded run) */
    { 15, 23, U2_S_TITLE_AND_ORIGIN },  /* asm/02CC */
    {  5, 11, U2_S_TITLE_TYPE },        /* asm/02E6 (inside a mis-decoded run) */
    {  6, 13, U2_S_MENU_DEMO },         /* asm/02F8 */
    {  6, 15, U2_S_MENU_PLAY },         /* asm/031F */
    {  6, 17, U2_S_MENU_CREATE },       /* asm/034B */
    {  5, 19, U2_S_MENU_CHOICE },       /* asm/0375 */
};
/* asm/03AC prints each pair into the bottom two rows, waits, then clears them
 * with asm/538F_sub_538f.asm. Columns are the movb $n,0x2e sites. */
static const txt POEM[] = {
    {  0, 23, U2_S_POEM_1A }, {  0, 24, U2_S_POEM_1B },
    {  0, 23, U2_S_POEM_2A }, {  2, 24, U2_S_POEM_2B },
    {  0, 23, U2_S_POEM_3A }, {  4, 24, U2_S_POEM_3B },
    {  0, 23, U2_S_POEM_4A }, {  1, 24, U2_S_POEM_4B },
    {  0, 23, U2_S_POEM_5A }, {  1, 24, U2_S_POEM_5B },
    {  0, 23, U2_S_POEM_6A }, {  8, 24, U2_S_POEM_6B },
};

#define NARR(x) ((int)(sizeof (x) / sizeof (x)[0]))

/* Stop condition for the scripted/headless flow: end of input or a quit. */
static int flow_stopped(const u2_ctx *ctx)
{
    return ctx->exit_code || ctx->input_exhausted;
}

/* The original's intro hold, asm/0688_sub_0688.asm (dx = 0x6000 iterations of
 * an INT 1Ah tick wait). Wall-clock duration on a 1983 machine is unknowable;
 * 1.5 s reads right and is the only number here that is a choice, not a fact. */
#define INTRO_HOLD_MS 1500
#define POEM_HOLD_MS  2000

static void draw_all(u2_ctx *ctx, const txt *lines, int n)
{
    for (int i = 0; i < n; i++) {
        /* With the asm fallback (no exe) the two strings that live inside the
         * mis-decoded regions come out empty; skip them rather than print a
         * placeholder that would look like game text. */
        if (!lines[i].s || !lines[i].s[0])
            continue;
        seam_str_out_at(ctx, lines[i].col, lines[i].row, lines[i].s);
    }
}

/*
 * asm/0688_sub_0688.asm: hold, polling key_poll each pass, and bail to the
 * title entry (asm/0242) the moment ESC arrives.
 *
 * Headless compresses the hold to a single poll. That is deliberate: the point
 * of the poll is "did the player press ESC", and a script must address the
 * menu, not fight 30 swallowed keystrokes. The terminal build polls at a real
 * rate. Both paths consume at most one key per hold.
 */
static int hold_for_esc(u2_ctx *ctx, unsigned ms)
{
    u2_key k;

    if (ctx->mode == U2_MODE_HEADLESS) {
        if (seam_key_poll(ctx, &k) && k.ch == 0x1B)
            return 1;
        return 0;
    }    for (unsigned waited = 0; waited < ms; waited += 50) {
        if (seam_key_poll(ctx, &k)) {
            /* Any key ends the hold; only ESC aborts to the title. The
             * original's poll consumed the key the same way (asm/069C). */
            return k.ch == 0x1B;
        }
        seam_wait_ms(ctx, 50);
    }
    return 0;
}

/* asm/0142..020F: the two presentation screens. Returns 1 if ESC skipped. */
static int present_intro(u2_ctx *ctx)
{
    u2_trace(ctx, "intro", "0142", NULL);
    u2_vram_clear(&ctx->vram, 0x07);
    draw_all(ctx, INTRO_1, NARR(INTRO_1));
    seam_present(ctx);
    if (hold_for_esc(ctx, INTRO_HOLD_MS))
        return 1;

    u2_vram_clear(&ctx->vram, 0x07);
    draw_all(ctx, INTRO_2, NARR(INTRO_2));
    seam_present(ctx);
    if (hold_for_esc(ctx, INTRO_HOLD_MS))
        return 1;
    return 0;
}

/* asm/03AC: the story poem. The path here first sets the video mode and so
 * clears the screen (asm/03B0 -> asm/4A3E_sub_4a3e.asm), sets the story flag
 * (DS:0x239), waits, and then draws one couplet at a time into rows 23 and 24,
 * clearing them with asm/538F_sub_538f.asm between couplets. */
static int present_poem(u2_ctx *ctx)
{
    u2_vram_clear(&ctx->vram, 0x07);              /* asm/03B0 -> asm/4A3E */
    ctx->state.story_flag = 1;                    /* asm/03B3: mov $1,0x239 */
    seam_present(ctx);
    if (hold_for_esc(ctx, 800))
        return 1;

    for (int i = 0; i < NARR(POEM); i += 2) {
        seam_clear_row(ctx, 23);
        seam_clear_row(ctx, 24);
        if (POEM[i].s[0])
            seam_str_out_at(ctx, POEM[i].col, POEM[i].row, POEM[i].s);
        if (i + 1 < NARR(POEM) && POEM[i + 1].s[0])
            seam_str_out_at(ctx, POEM[i + 1].col, POEM[i + 1].row, POEM[i + 1].s);
        seam_present(ctx);
        if (hold_for_esc(ctx, POEM_HOLD_MS) || flow_stopped(ctx))
            return 1;
    }
    return 0;
}

/* asm/0242: draw the title and menu. */
static void draw_title(u2_ctx *ctx)
{
    u2_vram_clear(&ctx->vram, 0x07);
    draw_all(ctx, TITLE, NARR(TITLE));
    seam_present(ctx);
}

/* asm/0389..038F: spin on key_poll until a key arrives (AH=0xFF), then echo it
 * with char_print (asm/0394). Returns -1 when input is finished. */
static int wait_choice(u2_ctx *ctx)
{
    u2_key k;

    while (!seam_key_poll(ctx, &k)) {
        if (ctx->exit_code || ctx->mode == U2_MODE_HEADLESS)
            return -1;
        seam_wait_ms(ctx, 20);
    }    seam_char_print(ctx, k.ch);
    seam_present(ctx);
    return k.ch;
}

/* CP3/CP4 placeholders. Engine-authored on purpose: they must not read like
 * game text, and they name the checkpoint that replaces them. */
static void stub_not_implemented(u2_ctx *ctx, const char *what)
{
    char buf[64];

    snprintf(buf, sizeof buf, "[engine] %s -> CP3+", what);
    seam_clear_row(ctx, 21);
    seam_str_out_at(ctx, 1, 21, buf);
    seam_present(ctx);
    seam_wait_ms(ctx, 600);
}

/* The demo cycle: the poem, then the intro again, until ESC. asm/03AC ends by
 * jumping back to the intro entry at 0x33E, and every ESC lands on the title
 * entry at asm/0242. */
static void run_demo(u2_ctx *ctx)
{
    for (;;) {
        if (present_poem(ctx) || flow_stopped(ctx))
            return;
        if (present_intro(ctx) || flow_stopped(ctx))
            return;
    }
}

int u2_title_flow(u2_ctx *ctx)
{
    ctx->content_source = U2_CONTENT_SOURCE;    /* from the generated header */
    ctx->state.story_flag = 0;                  /* asm/0133_sub_0133.asm */

    /* Opening presentation, then the title (asm/0237 branches to the title
     * while the story flag is still clear). */
    if (!present_intro(ctx) && ctx->state.story_flag != 0 && !flow_stopped(ctx))
        present_poem(ctx);

    for (;;) {
        draw_title(ctx);
        int key = wait_choice(ctx);

        if (key < 0)
            return 0;
        switch (key) {
        case 'D':                               /* asm/039B: jmp 0x3AF */
            run_demo(ctx);
            break;
        case 'P':                               /* asm/03A0 -> asm/03AC */
            /* asm/0764 is a small wrapper: emit the key, print a line at row 10
             * column 0 and wait for a key (asm/0767 + asm/0776). The disk/load
             * path behind it is not lifted yet, so only the wait is missing. */
            stub_not_implemented(ctx, "play prompt (asm/0764)");
            run_demo(ctx);
            break;
        case 'C':                               /* asm/03A4 -> asm/5400 -> 03AC */
            stub_not_implemented(ctx, "create (asm/5400)");
            run_demo(ctx);
            break;
        default:                                /* asm/03A6: redraw */
            break;
        }
    }
}
