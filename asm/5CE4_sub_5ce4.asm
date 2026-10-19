# sub_5ce4 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5CE4..5CEC  len 0009 B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5ce4:
L_005ee4:
        push   %ax
L_005ee5:
        mov    %cs:0x5c90,%al
L_005ee9:
        out    %al,$0x61
L_005eeb:
        pop    %ax
L_005eec:
        ret
