# sub_220a — contact re-test, y half. Both equal -> asm/2213 -> asm/218B (no move, and the
#           Minax proximity check if DS:4A != 0). Neither -> asm/2216, commit the move.
# func 220A..2212  len 0009 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_220a:
L_00240a:
        mov    0x1,%al
L_00240d:
        cmp    0x24,%al
L_002411:
        jne L_002416
