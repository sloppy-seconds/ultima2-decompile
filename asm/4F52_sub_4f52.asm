# sub_4f52 — key_poll: no key pending (ZF from the AH=01h probe survives the `mov`), so skip
#           the consume AND the AH=0xFF setter and land on the upper-case tail with AH = 0.
# func 4F52..4F55  len 0004 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4f52:
L_005152:
        mov    $0x0,%ah
L_005154:
        je L_0051d3
