/*
 * input_term.c — interactive keyboard via termios.
 *
 * seam: key_poll (asm/4F4D_key_poll.asm, INT 16h AH=01h) and the blocking
 * INT 16h AH=00h sites. The original polled the BIOS key queue; here poll()
 * is a non-blocking read of stdin and wait() is a blocking one.
 */
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <termios.h>
#include <unistd.h>
#include "core/ctx.h"

typedef struct term_input {
    struct termios saved;
    int  raw;
    int  nonblock;
} term_input;

static int term_set_raw(u2_ctx *ctx, int on)
{
    term_input *ti = ctx->be_input;
    struct termios t;

    if (!isatty(STDIN_FILENO))
        return -1;
    if (!on) {
        if (ti->raw)
            tcsetattr(STDIN_FILENO, TCSADRAIN, &ti->saved);
        ti->raw = 0;
        return 0;
    }
    if (tcgetattr(STDIN_FILENO, &ti->saved) != 0)
        return -1;
    t = ti->saved;
    t.c_lflag &= (tcflag_t)~(ICANON | ECHO);
    t.c_cc[VMIN] = 0;
    t.c_cc[VTIME] = 0;
    if (tcsetattr(STDIN_FILENO, TCSANOW, &t) != 0)
        return -1;
    ti->raw = 1;
    return 0;
}

static int term_input_init(u2_ctx *ctx)
{
    term_input *ti = calloc(1, sizeof *ti);
    if (!ti) return -1;
    ctx->be_input = ti;
    if (term_set_raw(ctx, 1) != 0) {
        /* Not a tty (piped input): fall back to plain non-blocking reads. */
        int fl = fcntl(STDIN_FILENO, F_GETFL);
        if (fl >= 0) fcntl(STDIN_FILENO, F_SETFL, fl | O_NONBLOCK);
        ti->nonblock = 1;
    }
    return 0;
}

static int term_read(u2_ctx *ctx, u2_key *out, int block)
{
    term_input *ti = ctx->be_input;
    int fl = fcntl(STDIN_FILENO, F_GETFL);

    if (block && ti->nonblock)
        fcntl(STDIN_FILENO, F_SETFL, fl & ~O_NONBLOCK);
    if (!block && !(fl & O_NONBLOCK) && !ti->raw)
        fcntl(STDIN_FILENO, F_SETFL, fl | O_NONBLOCK);

    unsigned char c = 0;
    ssize_t n = read(STDIN_FILENO, &c, 1);

    if (block && ti->nonblock)
        fcntl(STDIN_FILENO, F_SETFL, fl);

    if (n == 1) {
        out->ch = c;
        out->scan = 0;
        return 1;
    }
    if (n == 0) {
        ctx->exit_code = 0; /* stdin closed */
        return 0;
    }
    return 0;
}

static int term_input_poll(u2_ctx *ctx, u2_key *out)
{
    return term_read(ctx, out, 0);
}

static int term_input_wait(u2_ctx *ctx, u2_key *out)
{
    return term_read(ctx, out, 1);
}

static void term_input_shutdown(u2_ctx *ctx)
{
    term_input *ti = ctx->be_input;
    if (ti) {
        term_set_raw(ctx, 0);
        free(ti);
    }
    ctx->be_input = NULL;
}

const u2_input u2_input_term = {
    .name = "term",
    .init = term_input_init,
    .poll = term_input_poll,
    .wait = term_input_wait,
    .shutdown = term_input_shutdown,
};
