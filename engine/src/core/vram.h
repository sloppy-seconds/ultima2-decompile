#ifndef U2_VRAM_H
#define U2_VRAM_H

/*
 * Character-cell screen model.
 *
 * The grid is 40x25, not the 80x25 the plan assumed. Evidence: the row-clear
 * loop prints 0x28 = 40 spaces (asm/53A0_sub_53a0.asm), the printable right
 * margin is 0x26/0x28 (asm/456B_sub_456b.asm, asm/48A7_sub_48a7.asm), and the
 * scroll window spans columns 0..right margin (asm/5025_sub_5025.asm).
 *
 * The original drives the screen three ways and the engine models each:
 *   1. its own text printer — char_print (asm/5003_char_print.asm) writes with
 *      INT 10h AH=09h at the cursor in DS:0x2E (column) / DS:0x2F (row), using
 *      the attribute in DS:0x23E, wrapping at DS:0x31 and scrolling the
 *      message window when the row reaches 24;
 *   2. teletype — char_out (asm/4A1C_char_out.asm) is INT 10h AH=01h;
 *   3. direct video-memory pokes — routines that point DS at 0xB800 and read
 *      raw disk sectors into VRAM (asm/5351_sub_5351.asm + asm/535A_sub_535a.asm)
 *      are the picture path; the engine's bitmap side of it is CP9.
 *
 * Cursor position is applied with INT 10h AH=02h in str_out_core
 * (asm/51FD_str_out_core.asm). NB: docs/phase4-plan.md §1 lists DS:0x2E/0x2F
 * as "cursor page/col"; the bytes load DL from 0x2E and DH from 0x2F with
 * BH=0, i.e. 0x2E = column, 0x2F = row.
 */

#include <stdint.h>
#include "platform/platform.h"

/* The message window the original scrolls, from asm/5025_sub_5025.asm:
 * INT 10h AH=06h with CH=0x14, DH=0x17. */
#define U2_MSG_TOP     20
#define U2_MSG_BOTTOM  23
/* char_print scrolls when the row counter reaches this (cmpb $0x18,0x2f). */
#define U2_SCROLL_ROW  24

typedef struct u2_cell {
    uint8_t ch;
    uint8_t attr;
} u2_cell;

typedef struct u2_vram {
    u2_cell cell[U2_ROWS][U2_COLS];
    int row;        /* cursor row    <- DS:0x2F */
    int col;        /* cursor column <- DS:0x2E */
    int visible;    /* cursor drawn */
    int dirty;      /* cells changed since last flush */
    uint64_t writes;/* total cells written (trace/diagnostics) */
} u2_vram;

void u2_vram_init(u2_vram *v);
void u2_vram_clear(u2_vram *v, uint8_t attr);
void u2_vram_goto(u2_vram *v, int row, int col);
/* Write one cell at the cursor and advance it (teletype semantics). */
void u2_vram_put(u2_vram *v, uint8_t ch, uint8_t attr);
/* Write one cell anywhere (direct VRAM poke semantics, no cursor move). */
void u2_vram_poke(u2_vram *v, int row, int col, uint8_t ch, uint8_t attr);
/* Scroll a rectangle up one line, blanking the bottom row (INT 10h AH=06h). */
void u2_vram_scroll_window(u2_vram *v, int top, int bottom, int left, int right,
                           uint8_t attr);
/* Render the grid through the active renderer and clear the dirty flag. */
void u2_vram_flush(u2_vram *v, u2_ctx *ctx);
/* Plain-text row, NUL-terminated, trailing spaces trimmed. Returns length. */
int  u2_vram_row_text(const u2_vram *v, int row, char *out, int outsz);

#endif /* U2_VRAM_H */
