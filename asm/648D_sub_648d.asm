# sub_648d — mechanical clean (bulk wave); behavior not yet reviewed
# func 648D..64E1  len 0055 B  evidence: call+reko
# calls: L_0069b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_648d:
L_00668d:
        mov    $0x0,%bh
L_00668f:
        mov    0x482,%bl
L_006693:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006695:
        mov    %cs:0x620e(%di),%al
L_00669a:
        mov    %al,0x479
L_00669d:
        mov    %al,0x47b
L_0066a0:
        mov    %cs:0x6229(%di),%al
L_0066a5:
        mov    %al,0x47a
L_0066a8:
        mov    %cs:0x6222(%di),%al
L_0066ad:
        mov    %al,0x47c
L_0066b0:
        call L_0069b3
L_0066b3:
        mov    $0x0,%bh
L_0066b5:
        mov    0x482,%bl
L_0066b9:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0066bb:
        mov    %cs:0x6218(%di),%al
L_0066c0:
        mov    %al,0x47b
L_0066c3:
        call L_0069b3
L_0066c6:
        mov    $0x0,%bh
L_0066c8:
        mov    0x482,%bl
L_0066cc:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0066ce:
        mov    %cs:0x6229(%di),%al
L_0066d3:
        mov    %al,0x47c
L_0066d6:
        call L_0069b3
L_0066d9:
        mov    $0x0,%bh
L_0066db:
        mov    0x482,%bl
L_0066df:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0066e1:
        ret
