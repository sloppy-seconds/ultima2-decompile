# sub_10aa — mechanical clean (bulk wave); behavior not yet reviewed
# func 10AA..10BB  len 0012 B  evidence: seed+reko
# calls: L_005417
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_10aa:
L_0012aa:
        mov    $0x0,%bh
L_0012ac:
        mov    0x25,%bl
L_0012b0:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0012b2:
        mov    %al,0x1f7(%di)
L_0012b6:
        mov    %al,0x19
L_0012b9:
        call L_005417
