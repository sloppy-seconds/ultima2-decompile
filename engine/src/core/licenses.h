#ifndef U2_LICENSES_H
#define U2_LICENSES_H

#include <stdio.h>

/*
 * licenses.h — the binary carries its own attribution record.
 *
 * The release is a single executable with no accompanying files, which is what
 * makes a player's copy easy to move and also makes it easy to lose track of what
 * is inside it. Printing the record on demand means the obligations and the
 * provenance travel with the artifact instead of living in a repository the
 * recipient may never see.
 *
 * The texts are compiled in from committed sources (see core/licenses_data.h and
 * engine/tools/gen_licenses.py), so this works with no data directory, no
 * network and no SDL present.
 */

/* Write the full record to `out`. Never fails; a NULL out is ignored. */
void u2_licenses_print(FILE *out);

#endif /* U2_LICENSES_H */
