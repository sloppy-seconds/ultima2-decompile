# sub_6425 — mechanical clean (bulk wave); behavior not yet reviewed
# func 6425..648C  len 0068 B  evidence: call+reko
# calls: L_0069b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_6425:
L_006625:
        mov    $0x0,%bh
L_006627:
        mov    0x482,%bl
L_00662b:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00662d:
        mov    %cs:0x620d(%di),%al
L_006632:
        mov    %al,0x479
L_006635:
        mov    %cs:0x6221(%di),%al
L_00663a:
        mov    %al,0x47a
L_00663d:
        mov    %al,0x47c
L_006640:
        mov    %cs:0x6217(%di),%al
L_006645:
        mov    %al,0x47b
L_006648:
        call L_0069b3
L_00664b:
        mov    $0x0,%bh
L_00664d:
        mov    0x482,%bl
L_006651:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006653:
        mov    %cs:0x6229(%di),%al
L_006658:
        mov    %al,0x47c
L_00665b:
        call L_0069b3
L_00665e:
        mov    $0x0,%bh
L_006660:
        mov    0x482,%bl
L_006664:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006666:
        mov    %cs:0x620d(%di),%al
L_00666b:
        mov    %al,0x47b
L_00666e:
        call L_0069b3
L_006671:
        mov    $0x0,%bh
L_006673:
        mov    0x482,%bl
L_006677:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006679:
        mov    %cs:0x6221(%di),%al
L_00667e:
        mov    %al,0x47c
L_006681:
        call L_0069b3
L_006684:
        mov    $0x0,%bh
L_006686:
        mov    0x482,%bl
L_00668a:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00668c:
        ret
