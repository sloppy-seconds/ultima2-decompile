# sub_6594 — mechanical clean (bulk wave); behavior not yet reviewed
# func 6594..660B  len 0078 B  evidence: call+reko
# calls: L_006884, L_0069b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_6594:
L_006794:
        mov    $0x0,%bh
L_006796:
        mov    0x482,%bl
L_00679a:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00679c:
        mov    %cs:0x6232(%di),%al
L_0067a1:
        mov    %al,0x479
L_0067a4:
        mov    %cs:0x623a(%di),%al
L_0067a9:
        mov    %al,0x47b
L_0067ac:
        mov    %cs:0x6279(%di),%al
L_0067b1:
        mov    %al,0x47a
L_0067b4:
        mov    %cs:0x6281(%di),%al
L_0067b9:
        mov    %al,0x47c
L_0067bc:
        call L_0069b3
L_0067bf:
        mov    $0x0,%bh
L_0067c1:
        mov    0x482,%bl
L_0067c5:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0067c7:
        mov    %cs:0x624a(%di),%al
L_0067cc:
        mov    %al,0x47b
L_0067cf:
        call L_0069b3
L_0067d2:
        mov    $0x0,%bh
L_0067d4:
        mov    0x482,%bl
L_0067d8:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0067da:
        mov    %cs:0x6242(%di),%al
L_0067df:
        mov    %al,0x47b
L_0067e2:
        mov    %cs:0x6279(%di),%al
L_0067e7:
        mov    %al,0x47c
L_0067ea:
        call L_0069b3
L_0067ed:
        mov    $0x0,%bh
L_0067ef:
        mov    0x482,%bl
L_0067f3:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0067f5:
        mov    %cs:0x6232(%di),%al
L_0067fa:
        mov    %al,0x47b
L_0067fd:
        call L_0069b3
L_006800:
        call L_006884
L_006803:
        mov    $0x0,%bh
L_006805:
        mov    0x482,%bl
L_006809:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00680b:
        ret
