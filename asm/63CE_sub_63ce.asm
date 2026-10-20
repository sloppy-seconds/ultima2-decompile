# sub_63ce — mechanical clean (bulk wave); behavior not yet reviewed
# func 63CE..6424  len 0057 B  evidence: call+reko
# calls: L_0069b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_63ce:
L_0065ce:
        mov    $0x0,%bh
L_0065d0:
        mov    0x482,%bl
L_0065d4:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0065d6:
        mov    %cs:0x6217(%di),%al
L_0065db:
        mov    %al,0x479
L_0065de:
        mov    %cs:0x6218(%di),%al
L_0065e3:
        mov    %al,0x47b
L_0065e6:
        mov    %cs:0x6221(%di),%al
L_0065eb:
        mov    %al,0x47a
L_0065ee:
        mov    %cs:0x6222(%di),%al
L_0065f3:
        mov    %al,0x47c
L_0065f6:
        call L_0069b3
L_0065f9:
        mov    $0x0,%bh
L_0065fb:
        mov    0x482,%bl
L_0065ff:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006601:
        mov    %cs:0x6217(%di),%al
L_006606:
        mov    %al,0x47b
L_006609:
        mov    %cs:0x6229(%di),%al
L_00660e:
        mov    %al,0x47c
L_006611:
        mov    %cs:0x622a(%di),%al
L_006616:
        mov    %al,0x47a
L_006619:
        call L_0069b3
L_00661c:
        mov    $0x0,%bh
L_00661e:
        mov    0x482,%bl
L_006622:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006624:
        ret
