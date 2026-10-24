# sub_21f0 — site guard, second half: candidate y (DS:24) == 0 is refused when DS:4A != 0.
#           Falling through both tests is the accept.
# func 21F0..21F6  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_21f0:
L_0023f0:
        mov    0x24,%al
L_0023f3:
        cmp    $0x0,%al
L_0023f5:
        je L_0023fc
