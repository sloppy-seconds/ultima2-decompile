/*
 * artifact.h — does this binary know where a developer's checkout lives?
 *
 * It should not. docs/install-design.md § 4 rules that an explicit path is
 * authoritative with no fall-through, and a baked-in developer location is the one
 * fall-through a shipped binary still carried: `references/u2upgrade` is where the
 * Exodus upgrade package happens to sit in this repository, and a player's download
 * has no such directory and no way to guess that the binary looked for one.
 *
 * Dev builds keep the fallbacks, because that is where a developer's media actually
 * is and taking it away would mean passing --ega-theme-dir on every run for no
 * benefit. The distinction is the artifact stamp the Makefile already carries, so
 * there is no second knob to keep in step: `make` and the terminal build the test
 * suite drives are dev, and the SDL artifact a player downloads is release.
 */

#ifndef U2_CORE_ARTIFACT_H
#define U2_CORE_ARTIFACT_H

#include <string.h>

#ifndef U2_ARTIFACT
#define U2_ARTIFACT "unknown"
#endif

static inline int u2_is_release_artifact(void)
{
    return strcmp(U2_ARTIFACT, "release") == 0;
}

#endif
