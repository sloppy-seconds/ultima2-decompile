#!/usr/bin/env bash
# Mutation-test speed_check.c the same way tools/mutate_stepgate.sh does the step gate.
#
# A test whose control is a live dump is only as good as its ability to go red when the
# model drifts from that dump. Each mutation breaks one clause of asm/06ED's arithmetic in
# a COPY of speed.c (the repo file is never touched) and requires speed_check to fail.
# A mutation that leaves it green means the 20-slot table does not actually cover that clause.
set -uo pipefail
cd "$(dirname "$0")/.."

SRCS=$(ls src/core/*.c src/game/*.c src/debug/*.c | grep -v 'game/speed.c')
pass=0; fail=0

mutate() {
    local name="$1" from="$2" to="$3"
    cp src/game/speed.c /var/tmp/speed_mut.c
    python3 - "$from" "$to" <<'PY'
import sys
p='/var/tmp/speed_mut.c'; s=open(p).read()
old,new=sys.argv[1],sys.argv[2]
if old not in s:
    print("MUTATION-NOT-APPLIED"); sys.exit(2)
open(p,'w').write(s.replace(old,new,1))
PY
    if [ $? -ne 0 ]; then echo "  SKIP  $name (pattern not found)"; fail=$((fail+1)); return; fi
    if ! cc -std=c11 -Wall -Wextra -Werror -Isrc -Ibuild -o /var/tmp/speed_mut \
            tests/speed_check.c /var/tmp/speed_mut.c $SRCS 2>/dev/null; then
        echo "  SKIP  $name (would not compile)"; fail=$((fail+1)); return
    fi
    if /var/tmp/speed_mut >/var/tmp/speed_mut.out 2>&1; then
        echo "  NOT CAUGHT  $name — the table does not cover this clause"; fail=$((fail+1))
    else
        echo "  caught      $name  ($(grep -c FAIL /var/tmp/speed_mut.out) failing checks)"
        pass=$((pass+1))
    fi
}

echo "mutations the speed table must catch:"
mutate "drop the below-baseline clamp" \
       '        if (ax < baseline) {                 /* jae not taken -> mov $0x0,%ax */
            s->speed_delay[i] = 0;
            continue;
        }' \
       '        /* mutation: clamp removed */'
mutate "truncate MUL to 16 bits" \
       'uint32_t prod = (uint32_t)ax * (uint32_t)s->speed_mult[i];   /* mulw: 32-bit */' \
       'uint32_t prod = (uint32_t)(uint16_t)((uint32_t)ax * (uint32_t)s->speed_mult[i]);'
mutate "off-by-one in the multiplier index" \
       's->speed_mult[i]' 's->speed_mult[(i + 1) % U2_SPEED_SLOTS]'
mutate "divide by the multiplier instead of the baseline" \
       'uint32_t q    = prod / baseline;                             /* divw         */' \
       'uint32_t q    = prod / (s->speed_mult[i] ? s->speed_mult[i] : 1);'
mutate "ceiling one too high" \
       'if (next > U2_SPEED_CEILING)' 'if (next > U2_SPEED_CEILING + 1)'
mutate "floor test uses the wrong bound" \
       'if (next < ctx->state.speed_baseline)' 'if (next < 1)'
mutate "rescale even when the key was rejected" \
       'if (next > U2_SPEED_CEILING)
        return 0;' \
       'if (next > U2_SPEED_CEILING) {
            u2_speed_rescale(ctx);
            return 0;
        }'
mutate "index not halved in the accessor" \
       'return ctx->state.speed_delay[index];' 'return ctx->state.speed_delay[index ? index - 1 : 0];'

echo
echo "caught $pass, MISSED $fail"
[ "$fail" -eq 0 ] && echo "SPEED MUTATION TEST: PASS" || echo "SPEED MUTATION TEST: FAIL"
