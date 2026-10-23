#ifndef U2_TURNLOG_H
#define U2_TURNLOG_H

/*
 * Per-turn debug log — `--debug cli`.
 *
 * After every player turn the engine writes two files into a directory:
 *
 *   turn-00042.ppm   the frame that was just composed, as the player sees it
 *   turn-00042.json  the state dump, same bytes --dump-state prints on exit
 *
 * This exists because the CLI contract has no way to observe a RUNNING game.
 * --dump-screen takes one frame and exits; --dump-state only prints at the end
 * of a run. Neither can answer "what is on screen right now" about a session a
 * person is playing in a browser, which is the gap that let a stale binary be
 * reported as deployed twice on 2026-10-27: every check available to an agent
 * was a startup check, and a startup check passes identically for the old build
 * and the new one.
 *
 * Files, not a socket. The engine stays a single-process program with no server,
 * which is the CP2 decision and still the right one for tests; an outside reader
 * just opens the newest file. That also means it works across a container
 * boundary with a bind mount, where a port would need publishing.
 *
 * The default directory is /tmp because this is a portable C11 program and that
 * is the portable convention. Callers on a specific host should override it with
 * --debug-path: on the project's own machine /tmp is tmpfs, so a long run would
 * take every frame out of RAM, and /var/tmp is the disk-backed scratch area.
 */

#include "core/ctx.h"
#include "core/frame.h"

#define U2_TURNLOG_DEFAULT_DIR "/tmp"

/* Write the pair for `turn`. Silently does nothing when logging is off. A write
 * failure is reported once on stderr and then stops being reported, because a
 * full or read-only directory must not take the game down with it. */
void u2_turnlog(const u2_ctx *ctx, const u2_frame *frame, unsigned turn);

#endif /* U2_TURNLOG_H */
