/*
 * speed.c — the game speed variable and its rescale loop.
 *
 * spec: asm/06ED_speed_rescale (the loop), asm/4FA5_speed_faster_f7,
 *       asm/4F8E_speed_slower_f8, asm/0711_speed_delay_lookup.
 *
 * Every line here mirrors a byte sequence, and the arithmetic was checked against a
 * live memory dump before it was written: with speed = 14,871 and baseline = 1,674 the
 * formula reproduces all 20 measured slots exactly (tests/speed_check.c carries that
 * table as its control). Model only — see speed.h for why nothing calls it yet.
 */
#include "game/speed.h"
#include "core/state.h"

/* asm/06ED..0710. The original's loop is `mov $0x26,%bx` down to 0 in steps of 2, so
 * %bx is a BYTE offset into the word tables and the slot index is bx/2. The direction
 * of iteration is irrelevant to the result — every slot is independent — but it is
 * kept descending so a reader can walk the two side by side.
 *
 * The bytes, in order:
 *     mov 0x74,%ax / sub 0x554,%ax / jae scale     -> CF set means speed < baseline
 *     mov $0x0,%ax / jmp store                    -> that slot becomes 0
 *     mulw 0x558(%bx)                             -> DX:AX = AX * mult (32-bit)
 *     divw 0x554                                  -> AX = DX:AX / baseline
 *     mov %ax,0x580(%bx)                          -> store the slot
 */
int u2_speed_rescale(u2_ctx *ctx)
{
    u2_state *s = &ctx->state;
    const uint16_t baseline = s->speed_baseline;
    int faults = 0;

    /* DIVW by zero raises #DE on a real 8086. The measured baseline is 1674 and no
     * writer is known, so a zero here means the caller never initialised the table --
     * say so rather than inventing a value. */
    if (baseline == 0)
        return -1;

    for (int i = U2_SPEED_SLOTS - 1; i >= 0; i--) {
        uint16_t ax = s->speed;
        if (ax < baseline) {                 /* jae not taken -> mov $0x0,%ax */
            s->speed_delay[i] = 0;
            continue;
        }
        ax = (uint16_t)(ax - baseline);
        uint32_t prod = (uint32_t)ax * (uint32_t)s->speed_mult[i];   /* mulw: 32-bit */
        uint32_t q    = prod / baseline;                             /* divw         */
        if (q > 0xFFFFu) {
            /* A 16-bit DIV with an oversized quotient faults on the real CPU. The
             * measured set never reaches it (max 64,581); recorded, not hidden. */
            faults++;
            q = 0xFFFFu;
        }
        s->speed_delay[i] = (uint16_t)q;
    }
    return faults;
}

/* asm/4FA5_speed_faster_f7: `mov 0x74,%ax ; add $0x200,%ax ; cmp $0x3a00,%ax ;
 * ja <skip> ; mov %ax,0x74` then fall through to asm/4FB3, which rescales.
 * The bound is unsigned and the rescale is skipped when the bound rejects, exactly as
 * the `ja` to asm/4FB6 does. */
int u2_speed_faster(u2_ctx *ctx)
{
    uint16_t next = (uint16_t)(ctx->state.speed + U2_SPEED_STEP);
    if (next > U2_SPEED_CEILING)
        return 0;
    ctx->state.speed = next;
    u2_speed_rescale(ctx);
    return 1;
}

/* asm/4F8E_speed_slower_f8: `mov 0x74,%ax ; sub $0x200,%ax ; cmp 0x554,%ax ;
 * jb <skip> ; mov %ax,0x74` then jmp asm/4FB3 to rescale.
 * Faithful detail: the subtract is 16-bit and unsigned, so a speed below 0x200 wraps
 * to a large value that passes the floor test and gets stored. The original really
 * does that; the floor only ever bites because the startup seed is far above 0x200. */
int u2_speed_slower(u2_ctx *ctx)
{
    uint16_t next = (uint16_t)(ctx->state.speed - U2_SPEED_STEP);
    if (next < ctx->state.speed_baseline)
        return 0;
    ctx->state.speed = next;
    u2_speed_rescale(ctx);
    return 1;
}

/* asm/0711_speed_delay_lookup: `mov 0x580(%bx),%bx`. Callers set %bx to a byte offset
 * (observed 0x00, 0x08, 0x0a, 0x14, 0x16, 0x18), so the index is bx/2. */
uint16_t u2_speed_delay(const u2_ctx *ctx, unsigned index)
{
    if (index >= U2_SPEED_SLOTS)
        return 0;
    return ctx->state.speed_delay[index];
}
