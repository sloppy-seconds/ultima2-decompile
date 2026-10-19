# sub_47b5 — mechanical clean (bulk wave); behavior not yet reviewed
# func 47B5..47BB  len 0007 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_47b5:
L_0049b5:
        test   %dx,0xa00(%bp)
L_0049b9:
        .byte 0xc0,0x74,0x27  # forced-kept: gas re-encodes 'shlb   $0x8b,0x27(%si)' differently
