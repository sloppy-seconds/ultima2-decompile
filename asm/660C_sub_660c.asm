# sub_660c — mechanical clean (bulk wave); behavior not yet reviewed
# func 660C..6683  len 0078 B  evidence: call+reko
# calls: L_006884, L_0069b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_660c:
L_00680c:
        mov    $0x0,%bh
L_00680e:
        mov    0x482,%bl
L_006812:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006814:
        mov    %cs:0x6232(%di),%al
L_006819:
        mov    %al,0x479
L_00681c:
        mov    %cs:0x623a(%di),%al
L_006821:
        mov    %al,0x47b
L_006824:
        mov    %cs:0x6269(%di),%al
L_006829:
        mov    %al,0x47a
L_00682c:
        mov    %cs:0x6271(%di),%al
L_006831:
        mov    %al,0x47c
L_006834:
        call L_0069b3
L_006837:
        mov    $0x0,%bh
L_006839:
        mov    0x482,%bl
L_00683d:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00683f:
        mov    %cs:0x624a(%di),%al
L_006844:
        mov    %al,0x47b
L_006847:
        call L_0069b3
L_00684a:
        mov    $0x0,%bh
L_00684c:
        mov    0x482,%bl
L_006850:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006852:
        mov    %cs:0x6242(%di),%al
L_006857:
        mov    %al,0x47b
L_00685a:
        mov    %cs:0x6269(%di),%al
L_00685f:
        mov    %al,0x47c
L_006862:
        call L_0069b3
L_006865:
        mov    $0x0,%bh
L_006867:
        mov    0x482,%bl
L_00686b:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00686d:
        mov    %cs:0x6232(%di),%al
L_006872:
        mov    %al,0x47b
L_006875:
        call L_0069b3
L_006878:
        call L_006884
L_00687b:
        mov    $0x0,%bh
L_00687d:
        mov    0x482,%bl
L_006881:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006883:
        ret
