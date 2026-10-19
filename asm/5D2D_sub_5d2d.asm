# sub_5d2d — mechanical clean (bulk wave); behavior not yet reviewed
# func 5D2D..5D36  len 000A B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5d2d:
L_005f2d:
        mov    %cs:0x1(%bp),%bx
L_005f31:
        .byte 0x81,0xfb,0xff,0xff  # forced-kept: gas re-encodes 'cmp    $0xffff,%bx' differently
L_005f35:
        je L_005f3d
