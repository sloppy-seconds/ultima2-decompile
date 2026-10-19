# sub_10bf — mechanical clean (bulk wave); behavior not yet reviewed
# func 10BF..10CD  len 000F B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_10bf:
L_0012bf:
        mov    $0x0,%bh
L_0012c1:
        mov    0x25,%bl
L_0012c5:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0012c7:
        mov    %al,0x217(%di)
L_0012cb:
        mov    %al,0x1a
