# sub_480d — mechanical clean (bulk wave); behavior not yet reviewed
# func 480D..4813  len 0007 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_480d:
L_004a0d:
        test   %si,0xa00(%bp)
L_004a11:
        .byte 0xc0,0x74,0x28  # forced-kept: gas re-encodes 'shlb   $0x8b,0x28(%si)' differently
