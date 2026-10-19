# sub_0cc0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0CC0..0CD1  len 0012 B  evidence: seed+reko
# calls: L_005417
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0cc0:
L_000ec0:
        mov    $0x0,%bh
L_000ec2:
        mov    0x1f,%bl
L_000ec6:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_000ec8:
        mov    %al,0x137(%di)
L_000ecc:
        mov    %al,0x23
L_000ecf:
        call L_005417
