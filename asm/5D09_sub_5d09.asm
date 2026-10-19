# sub_5d09 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5D09..5D13  len 000B B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5d09:
L_005f09:
        push   %ax
L_005f0a:
        push   %bx
L_005f0b:
        push   %cx
L_005f0c:
        push   %bp
L_005f0d:
        cmpb   $0x0,0x54d
L_005f12:
        jne L_005f58
