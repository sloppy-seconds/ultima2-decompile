#!/usr/bin/env bash
# Mutation-test the new asm/2199 step-gate block in ai_check.c.
#
# A test that passes on the first run proves nothing — AGENTS.md: "demonstrate a gate failing
# before you trust it passing". Each mutation breaks one clause of the gate in a COPY of ai.c
# under /var/tmp (the repo file is never touched), rebuilds, and requires ai_check to go red.
# A mutation that leaves the test green means the table is not actually covering that clause.
set -uo pipefail
cd /var/home/paul/Projects/decompile-u2-v2/engine

SRCS=$(ls src/core/*.c src/game/*.c src/debug/*.c | grep -v 'game/ai.c')
pass=0; fail=0

mutate() {
    local name="$1" from="$2" to="$3"
    cp src/game/ai.c /var/tmp/ai_mutant.c
    python3 - "$from" "$to" <<'PY'
import sys
p='/var/tmp/ai_mutant.c'
s=open(p).read()
old,new=sys.argv[1],sys.argv[2]
if old not in s:
    print("MUTATION-NOT-APPLIED"); sys.exit(2)
open(p,'w').write(s.replace(old,new,1))
PY
    [ $? -ne 0 ] && { echo "  SKIP  $name (pattern not found)"; fail=$((fail+1)); return; }
    if ! cc -std=c11 -Wall -Wextra -Werror -Isrc -Ibuild -o /var/tmp/ai_mut \
            tests/ai_check.c /var/tmp/ai_mutant.c $SRCS 2>/dev/null; then
        echo "  SKIP  $name (would not compile)"; return
    fi
    if /var/tmp/ai_mut >/var/tmp/ai_mut.out 2>&1; then
        echo "  NOT CAUGHT  $name — the table does not cover this clause"
        fail=$((fail+1))
    else
        echo "  caught      $name  ($(grep -c FAIL /var/tmp/ai_mut.out) failing checks)"
        pass=$((pass+1))
    fi
}

echo "mutations the gate table must catch:"
mutate "drop the 0x5C force-field clause" \
       'if (tile != 0x5c && !tile_enterable_by_default(tile)) return 0;' \
       'if (!tile_enterable_by_default(tile)) return 0;'
mutate "water kinds accept anything" \
       'if (tile != 0x00) return 0;' \
       'if (tile == 0xff) return 0;'
mutate "drop the DS:26A freeze" \
       'if (ctx->state.counter_26A != 0) return 0;

    const uint8_t tile' \
       'const uint8_t tile'
mutate "invert the DS:26A freeze" \
       'if (ctx->state.counter_26A != 0) return 0;' \
       'if (ctx->state.counter_26A != 0) return 1;'
mutate "move the 0x78 boundary to 0x79" \
       'if (type < 0x78) {' \
       'if (type < 0x79) {'
mutate "accept the explicit refusals" \
       'if (tile == 0x10 || tile == 0x04 || tile == 0x00) return 0;' \
       'if (tile == 0x10 || tile == 0x04) return 0;'
mutate "drop the 0x70 town-ground accept" \
       'if (tile == 0x70) return 1;' \
       'if (tile == 0x71) return 1;'
mutate "drop the site guard" \
       'if (ctx->state.sector_second != 0 && (nx == 0 || ny == 0)) return 0;
    return 1;' \
       'return 1;'
mutate "guard ignores row 0" \
       '(nx == 0 || ny == 0)) return 0;' \
       '(nx == 0)) return 0;'

echo
echo "caught $pass, MISSED $fail"
[ "$fail" -eq 0 ] && echo "MUTATION TEST: PASS" || echo "MUTATION TEST: FAIL"
