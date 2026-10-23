# attack_arms_gate — the ATTACK command refuses when the arms are paralysed
# name-evidence: reached from asm/2B8F_cmd_A (which prints "ATTACK--") as the first
#           gate in its fall-through chain; reads [DS:26C] — the arms counter proven
#           by asm/0EC2_combat_paralyzed_arms — and on non-zero branches to
#           asm/2BAD_sub_2bad, which prints "PARALIZED!" and returns to the command
#           loop without attacking. Observed on screen as a `CMD:` line reading
#           exactly that, in the same slot the attack messages use.
# func 2BA5..2BAC  len 0008 B  evidence: seed+reko
# confidence: medium (bytes proven by check_func.py; the chain and the counter's
#           identity are what raise it above the bulk-wave default)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# why this matters for CP5: it is the byte proof of the owner's recollection that
#        **arms paralysis stops you fighting while legs paralysis stops you moving**.
#        Legs/arms are separate counters (C1) with separate gates in separate
#        commands — this one on ATTACK, the passability routine on movement — which
#        is exactly the shape a single boolean "paralysed" flag cannot express, and
#        is what C3 means by paralysis being a rejection rather than a mode.
#        Cited in docs/phase4-state.md § CP5 (C1, C3) and docs/phase4-kickoff-cp5.md.
# gate order in the chain, for whoever implements it: site kind first (asm/2B9B
#        tests [DS:4A] against 4), then this arms gate, then the roll
#        (asm/2BD7 calls rand, asm/2BDA does `clc; rcr $1,%al; cmp 0x4c,%al; jb`,
#        i.e. hit iff (rand >> 1) < agility byte), then --HIT!!! (asm/2BEC) or
#        MISS (asm/2E09_combat_miss_msg).
sub_2ba5:
L_002da5:
        nop
L_002da6:
        mov    0x26c,%al
L_002da9:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_002dab:
        je L_002dbe
