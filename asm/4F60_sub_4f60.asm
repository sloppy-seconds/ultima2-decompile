# sub_4f60 — key_poll swallow, third of three: AL == 0x17 is Ctrl-W. Note what is NOT here:
#           0x19, the south code. Ctrl-Y therefore reaches the walk loop as a south command —
#           an unobserved prediction, docs/needs-gameplay.md G30.
# func 4F60..4F63  len 0004 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4f60:
L_005160:
        cmp    $0x17,%al
L_005162:
        jne L_005169
