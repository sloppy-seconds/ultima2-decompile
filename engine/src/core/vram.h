#ifndef U2_VRAM_H
#define U2_VRAM_H

/*
 * Character-cell screen model.
 *
 * The original drives the screen two ways, and the engine must model both:
 *   1. teletype — char_out (asm/4A1C_char_out.asm) is INT 10h AH=01h, which
 *      writes at the hardware cursor and advances it, scrolling on overflow;
 *      char_print (asm/5003_char_print.asm) adds the CR special case.
 *   2. direct cell writes — some routines load DS with 0xB800
 *      (asm/5351_sub_5351.asm, asm/4B26_sub_4b26.asm, asm/4B4E_sub_4b4e.asm)
 *      and poke cells straight into video memory.
 * Cursor position is kept in DS:0x2E (column) and DS:0x2F (row) and applied
 * with INT 10h AH=02h in str_out_core (asm/51FD_str_out_core.asm).
 * NB: docs/phase4-plan.md §1 lists these as "cursor page/col"; the bytes say
 * DL=DS:0x2E and DH=DS:0x2F with BH=0, i.e. 0x2E = column, 0x2F = row.
 */

#include <stdint.h>
#include "platform/platform.h"

typedef struct u2_cell {
    uint8_t ch;
    uint8_t attr;
} u2_cell;

typedef struct u2_vram {
    u2_cell cell[U2_ROWS][U2_COLS];
    int row;        /* hardware cursor row   <- DS:0x2F */
    int col;        /* hardware cursor column <- DS:0x2E */
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
/* Render the grid through the active renderer and clear the dirty flag. */
void u2_vram_flush(u2_vram *v, u2_ctx *ctx);
/* Plain-text row, NUL-terminated, trailing spaces trimmed. Returns length. */
int  u2_vram_row_text(const u2_vram *v, int row, char *out, int outsz);

#endif /* U2_VRAM_H */
