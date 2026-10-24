#ifndef U2_SEAM_H
#define U2_SEAM_H

/*
 * Seam layer — the engine's display / input / audio / time entry points, one
 * per named seam in the asm tree. Game logic calls these and nothing else
 * that touches the outside world. Every call is traced with the asm function
 * it stands in for, which is what makes a --trace log auditable against asm/.
 * One exception: char_out has no located asm counterpart and traces asm=-.
 */

#include <stdint.h>
#include "core/ctx.h"

/* One glyph at the cursor: no CR handling, no margin policy of its own.
 * Engine primitive — the asm/4A1C it used to cite is INT 10h AH=00 AL=01, a video-mode
 * set, and the real INT 10h AH=0E teletype site has never been located in this binary. */
void seam_char_out(u2_ctx *ctx, uint8_t ch);
/* seam: char_print (asm/5003_char_print.asm) — teletype with CR handling. */
void seam_char_print(u2_ctx *ctx, uint8_t ch);
/* seam: char_print_wrap (asm/53F4_char_print_wrap.asm) — wrap at 80 columns. */
void seam_str_out(u2_ctx *ctx, const char *s);
/* seam: str_out_at (asm/51EB_str_out_at.asm) — place cursor, then print. */
void seam_str_out_at(u2_ctx *ctx, int col, int row, const char *s);
/* cursor placement alone (INT 10h AH=02 half of asm/51FD_str_out_core.asm). */
void seam_goto(u2_ctx *ctx, int col, int row);
/* blank one text row (asm/53A0_sub_53a0.asm: 40 spaces at column 0). */
void seam_clear_row(u2_ctx *ctx, int row);
/* clear the whole screen and home the cursor (asm/4C1C). */
void seam_clear_screen(u2_ctx *ctx);
/* seam: key_poll (asm/4F4D_key_poll.asm) — non-blocking key check. */
int  seam_key_poll(u2_ctx *ctx, u2_key *out);
/* blocking key read (INT 16h AH=00 sites). */
int  seam_key_wait(u2_ctx *ctx, u2_key *out);
/* seam: rand_byte (asm/5217_rand_byte.asm). */
uint8_t seam_rand_byte(u2_ctx *ctx);
/* seam: timed_wait (asm/52CA_timed_wait.asm). */
void seam_wait_ms(u2_ctx *ctx, uint32_t ms);
/* seam: speaker_freq (asm/5CD2_speaker_freq.asm) — 8253 latch divisor. */
void seam_tone(u2_ctx *ctx, uint16_t divisor, uint32_t ms);
/* paint the grid to the active renderer (call at frame boundaries). */
void seam_present(u2_ctx *ctx);
/* Present the pixel framebuffer. Returns non-zero when the display asked to
 * quit (window closed). A no-op returning 0 on cell-only backends, so callers
 * do not need to know which kind of renderer they were given. */
int  seam_present_frame(u2_ctx *ctx);

#endif /* U2_SEAM_H */
