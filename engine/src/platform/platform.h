#ifndef U2_PLATFORM_H
#define U2_PLATFORM_H

/*
 * Platform abstraction — the only surface game logic may touch.
 *
 * This is the Phase 3 seam discipline carried over: every routine in the
 * byte-proven asm tree that reaches the hardware goes through one of these
 * four vtables, and nothing in src/game/ may call a terminal escape, an SDL
 * call, clock(), or read(2) directly.
 *
 * Seam map (asm -> API):
 *   char_out        asm/4A1C_char_out.asm   -> seam_char_out   -> renderer->cell
 *   char_print      asm/5003_char_print.asm -> seam_char_print
 *   str_out         asm/4FDF_str_out.asm    -> seam_str_out   -> renderer->cell
 *   str_out_at      asm/51EB_str_out_at.asm -> seam_goto      -> renderer->cursor
 *   str_out_core    asm/51FD_str_out_core.asm (INT 10h AH=02 cursor set)
 *   key_poll        asm/4F4D_key_poll.asm   -> seam_key_poll  -> input->poll
 *   rand_byte       asm/5217_rand_byte.asm  -> seam_rand_byte -> clock->tick
 *   timed_wait      asm/52CA_timed_wait.asm -> seam_wait_ms   -> clock->sleep_ms
 *   speaker_freq    asm/5CD2_speaker_freq.asm -> seam_tone    -> audio->tone
 *   video_int10 / key_int16 / clock_int1a / dos_int21 / speaker_tone
 *                   — the raw INT seams labelled throughout asm/; each one
 *                     lands on exactly one of the four vtables below.
 */

#include <stdint.h>

#define U2_COLS 80
#define U2_ROWS 25

typedef struct u2_ctx u2_ctx;

/* One keyboard event. The original reads the BIOS key queue (INT 16h):
 * AL = character, AH = scancode. Scancode is carried so arrow-key-era
 * additions stay possible without changing the API. */
typedef struct u2_key {
    uint8_t ch;
    uint8_t scan;
} u2_key;

/* Character-cell display. The engine owns the 80x25 grid (core/vram.h);
 * renderers only paint it. */
typedef struct u2_renderer {
    const char *name;
    int  (*init)(u2_ctx *ctx);
    void (*cell)(u2_ctx *ctx, int row, int col, uint8_t ch, uint8_t attr);
    void (*cursor)(u2_ctx *ctx, int row, int col, int visible);
    void (*flush)(u2_ctx *ctx);
    void (*shutdown)(u2_ctx *ctx);
} u2_renderer;

typedef struct u2_input {
    const char *name;
    int  (*init)(u2_ctx *ctx);
    /* poll: non-blocking, mirrors key_poll (INT 16h AH=01 then AH=00).
     * Returns 1 and fills *out when a key is available, else 0. */
    int  (*poll)(u2_ctx *ctx, u2_key *out);
    /* wait: blocking read (INT 16h AH=00). Returns 0 on end-of-input. */
    int  (*wait)(u2_ctx *ctx, u2_key *out);
    void (*shutdown)(u2_ctx *ctx);
} u2_input;

/* PC speaker. divisor is the 8253 latch value the asm wrote with
 * out 0x42 (asm/5CD2_speaker_freq.asm); ms is how long to hold it. */
typedef struct u2_audio {
    const char *name;
    int  (*init)(u2_ctx *ctx);          /* optional */
    void (*tone)(u2_ctx *ctx, uint16_t divisor, uint32_t ms);
    void (*shutdown)(u2_ctx *ctx);      /* optional */
} u2_audio;

/* The original keeps its own tick counters in the DS segment (DS:0x23F..0x244,
 * seeded at asm/0100_sub_0100.asm) and mixes them for randomness. tick()
 * supplies the monotonic source; sleep() is the wall-clock delay. */
typedef struct u2_clock {
    const char *name;
    int      (*init)(u2_ctx *ctx);      /* optional */
    uint64_t (*tick)(u2_ctx *ctx);
    void     (*sleep_ms)(u2_ctx *ctx, uint32_t ms);
    void     (*shutdown)(u2_ctx *ctx);  /* optional */
} u2_clock;

/* Backends (selected in main.c by mode; never by game logic). */
extern const u2_renderer u2_renderer_term;
extern const u2_renderer u2_renderer_null;
extern const u2_input    u2_input_term;
extern const u2_input    u2_input_script;
extern const u2_audio    u2_audio_beep;
extern const u2_audio    u2_audio_null;
extern const u2_clock    u2_clock_posix;
extern const u2_clock    u2_clock_script;

#endif /* U2_PLATFORM_H */
