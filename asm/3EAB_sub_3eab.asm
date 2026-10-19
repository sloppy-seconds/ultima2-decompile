# sub_3eab — mechanical clean (bulk wave); behavior not yet reviewed
# func 3EAB..3EBA  len 0010 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3eab:
L_0040ab:
        mov    $0x0,%bh
L_0040ad:
        mov    0x1f,%bl
L_0040b1:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0040b3:
        .byte 0x8a,0x85,0x76,0x00  # forced-kept: gas re-encodes 'mov    0x76(%di),%al' differently
L_0040b7:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0040b9:
        jne L_0040d4
