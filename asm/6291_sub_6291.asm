# sub_6291 — mechanical clean (bulk wave); behavior not yet reviewed
# func 6291..6303  len 0073 B  evidence: call+reko
# calls: L_0069b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_6291:
L_006491:
        mov    $0x0,%bh
L_006493:
        mov    0x482,%bl
L_006497:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006499:
        mov    %cs:0x620d(%di),%al
L_00649e:
        mov    %al,0x479
L_0064a1:
        mov    %al,0x47b
L_0064a4:
        mov    %cs:0x6221(%di),%al
L_0064a9:
        mov    %al,0x47a
L_0064ac:
        mov    %cs:0x6229(%di),%al
L_0064b1:
        mov    %al,0x47c
L_0064b4:
        call L_0069b3
L_0064b7:
        mov    $0x0,%bh
L_0064b9:
        mov    0x482,%bl
L_0064bd:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0064bf:
        mov    %cs:0x6222(%di),%al
L_0064c4:
        mov    %al,0x47a
L_0064c7:
        mov    %al,0x47c
L_0064ca:
        mov    %cs:0x620e(%di),%al
L_0064cf:
        mov    %al,0x47b
L_0064d2:
        call L_0069b3
L_0064d5:
        mov    $0x0,%bh
L_0064d7:
        mov    0x482,%bl
L_0064db:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0064dd:
        mov    %cs:0x622a(%di),%al
L_0064e2:
        mov    %al,0x47c
L_0064e5:
        call L_0069b3
L_0064e8:
        mov    $0x0,%bh
L_0064ea:
        mov    0x482,%bl
L_0064ee:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0064f0:
        mov    %cs:0x620d(%di),%al
L_0064f5:
        mov    %al,0x47b
L_0064f8:
        call L_0069b3
L_0064fb:
        mov    $0x0,%bh
L_0064fd:
        mov    0x482,%bl
L_006501:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006503:
        ret
