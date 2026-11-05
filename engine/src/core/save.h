#ifndef U2_SAVE_H
#define U2_SAVE_H

/*
 * Player save record — byte-compatible with the original's PLAYER file.
 *
 * What the original actually does (all of this is proven in
 * docs/phase4-implementation.md § CP2.5, from disasm/redecoded/5400_sub_5400.txt
 * and asm/3823_sub_3823.asm):
 *
 *   - Disk I/O goes through the DOS wrapper at asm/52CA, which takes the DOS
 *     function number in AH from its caller. Player I/O is FCB random access:
 *     AH=27h read, AH=28h write, CX=0x100, DX=0x36, FCB name "PLAYER  "
 *     (blank extension) copied out of the caller's own code stream.
 *   - So the saved record is the 256 bytes at DS:36..135. Not 384 — 384 is the
 *     size of the *file* shipped on the blank disk.
 *   - The wrapper validates the drive with AH=0Fh (select drive) and, on
 *     failure, prints its inline "(INSERT ... DISK)" prompt and waits for ESC
 *     forever. That retry loop is the whole "insert a disk to save onto"
 *     experience; there is no disk-swap API. The FCB drive byte is 0, i.e. the
 *     default drive, so the game plays in whatever directory it was started in.
 *
 * Engine mapping (owner-approved, docs/phase4-plan.md § CP3 design):
 *
 *   - "default drive" becomes a save directory (--save-dir, default "saves"), and
 *     inside it one directory per save game: the record lives at
 *     `saves/<slot>/PLAYER` and only the sectors that save has changed share the
 *     directory with it (docs/save-scoped-worlds.md). The slot is created when the
 *     engine first needs one, never in advance.
 *   - A missing PLAYER file is seeded from the blank template below, which is
 *     byte-identical to the pristine shipped disk image. A blank record has
 *     DS:36 == 0, which is exactly the original's own "generate a character"
 *     test (asm/5400: `cmp byte [0x36],0`), so being faithful and being
 *     pragmatic are the same code path here.
 *   - Only the 256 record bytes are written; the 128-byte tail is preserved so
 *     saves stay interchangeable with the original in both directions.
 *   - A directory that exists but cannot be used returns U2_SAVE_NOT_READY, the
 *     honest modern analogue of a drive that is not ready. The game then shows
 *     the INSERT prompt instead of inventing a place to write.
 *
 * DEFERRED (owner decision 2026-10-27, docs/phase4-state.md § Deferred
 * decisions): the PRNG state at DS:23F..244 is deliberately NOT saved, because
 * it is outside the 256-byte record and saving it would break byte-compatibility
 * with the original. If some future checkpoint genuinely needs persisted state
 * that cannot fit the record, the agreed fallback is a separate sidecar file
 * next to PLAYER — never a change to this layout, and only with a strong
 * reason. Quicksaves and slots are also deferred: they are a filename layer over
 * this same record format, so they need no format change and no migration.
 */

#include <stddef.h>
#include <stdint.h>
#include "core/ctx.h"

/* The record, as the game writes it. */
#define U2_PLAYER_RECORD_DS   0x36   /* DS offset of the saved record base */
#define U2_PLAYER_RECORD_SIZE 256    /* CX at every read/write site */
/* The shipped file, which is larger than the record. */
#define U2_PLAYER_FILE_SIZE   384
/* The one non-zero byte of the pristine blank disk, at file offset 0x100.
 * What it means is an open question (see the impl log); it is reproduced
 * verbatim because it is what a real blank PLAYER file contains, not because
 * the engine understands it. */
#define U2_PLAYER_BLANK_MARK_OFF  0x100
#define U2_PLAYER_BLANK_MARK_BYTE 0x1A

#define U2_PLAYER_FCB_NAME "PLAYER  "   /* 8 bytes, blank extension */

typedef enum u2_save_result {
    U2_SAVE_OK = 0,     /* a record was read / written */
    U2_SAVE_BLANK,      /* no record present: the game should generate one */
    U2_SAVE_NOT_READY,  /* save path unusable: the "insert disk" analogue */
    U2_SAVE_ERROR       /* unexpected I/O failure */
} u2_save_result;

/* Record base pointer inside a state mirror (writable and read-only forms;
 * the engine builds with -Werror, so the const path is spelled out). */
#define U2_REC(state)   ((uint8_t *)(void *)(state) + U2_PLAYER_RECORD_DS)
#define U2_REC_RO(state) ((const uint8_t *)(const void *)(state) + U2_PLAYER_RECORD_DS)

/* Fill buf with the pristine blank PLAYER file (384 bytes). */
void u2_save_blank_template(uint8_t *buf);

/* Resolve the save path for this context into buf ("<dir>/PLAYER"). */
void u2_save_path(const u2_ctx *ctx, char *buf, size_t bufsz);

/* Make the save directory if needed and seed a blank PLAYER file if absent.
 * Returns U2_SAVE_NOT_READY when the path exists but is unusable. */
u2_save_result u2_save_ensure(u2_ctx *ctx);

/* Read the record into the state mirror. U2_SAVE_BLANK when the first record
 * byte is zero, which is the original's own test for "no character yet". */
u2_save_result u2_save_load(u2_ctx *ctx);

/* Write the 256 record bytes from the state mirror, preserving the tail. */
u2_save_result u2_save_store(const u2_ctx *ctx);

/* True when the in-memory record looks like a character (DS:36 != 0). */
int u2_save_record_present(const u2_ctx *ctx);

#endif /* U2_SAVE_H */
