/*
 * sha256_check.c — prints digests for a fixed set of inputs so the test can
 * compare them against Python's hashlib. Compiled and run by
 * engine/tests/run_cp2.sh; not part of the u2 binary.
 *
 * Lengths straddle the block boundary and the padding edge (55/56/63/64/65),
 * which is where a hand-rolled SHA-256 goes wrong.
 */
#include <stdio.h>
#include "../src/core/sha256.h"

int main(void)
{
    static const size_t lens[] = { 0, 1, 3, 8, 55, 56, 57, 63, 64, 65, 119, 120, 1000 };
    unsigned char buf[1024];
    char hex[65];

    for (size_t i = 0; i < sizeof buf; i++)
        buf[i] = (unsigned char)('a' + (i % 26));

    for (size_t i = 0; i < sizeof lens / sizeof lens[0]; i++) {
        sha256_hex(buf, lens[i], hex);
        printf("%zu %s\n", lens[i], hex);
    }
    return 0;
}
