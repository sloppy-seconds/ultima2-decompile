#ifndef U2_COMPAT_H
#define U2_COMPAT_H

/*
 * compat.h — the POSIX shims the Windows cross-build needs, and nothing else.
 *
 * The engine's file handling is deliberately plain POSIX (mkdir/stat/access/
 * rename — see the portability note in save.c). mingw-w64 provides all of it
 * except two details, patched here rather than forked per call site:
 *   * mkdir() takes a mode on POSIX, zero arguments (_mkdir) on the Windows CRT;
 *   * <unistd.h> has no X_OK (Windows has no execute bit for access()).
 * On POSIX hosts this header expands to nothing.
 */

#ifdef _WIN32
#include <direct.h>
#include <io.h>
#define mkdir(path, mode) _mkdir(path)
#define fsync(fd) _commit(fd)
#ifndef X_OK
#define X_OK 0
#endif
#endif

#endif /* U2_COMPAT_H */
