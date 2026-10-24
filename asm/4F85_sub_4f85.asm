# sub_4f85 — key_poll fork: a non-zero AL is an ordinary character and the arrow table is not
#           consulted at all. Only AL == 0 (an extended key, scancode in AH) reaches the scan.
# func 4F85..4F88  len 0004 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4f85:
L_005185:
        cmp    $0x0,%al
L_005187:
        jne L_0051d1
