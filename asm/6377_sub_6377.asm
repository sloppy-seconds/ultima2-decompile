# sub_6377 — mechanical clean (bulk wave); behavior not yet reviewed
# func 6377..63CD  len 0057 B  evidence: call+reko
# calls: L_0069b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_6377:
L_006577:
        mov    $0x0,%bh
L_006579:
        mov    0x482,%bl
L_00657d:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00657f:
        mov    %cs:0x620d(%di),%al
L_006584:
        mov    %al,0x479
L_006587:
        mov    %cs:0x620e(%di),%al
L_00658c:
        mov    %al,0x47b
L_00658f:
        mov    %cs:0x6221(%di),%al
L_006594:
        mov    %al,0x47a
L_006597:
        mov    %cs:0x6222(%di),%al
L_00659c:
        mov    %al,0x47c
L_00659f:
        call L_0069b3
L_0065a2:
        mov    $0x0,%bh
L_0065a4:
        mov    0x482,%bl
L_0065a8:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0065aa:
        mov    %cs:0x620d(%di),%al
L_0065af:
        mov    %al,0x47b
L_0065b2:
        mov    %cs:0x6229(%di),%al
L_0065b7:
        mov    %al,0x47c
L_0065ba:
        mov    %cs:0x622a(%di),%al
L_0065bf:
        mov    %al,0x47a
L_0065c2:
        call L_0069b3
L_0065c5:
        mov    $0x0,%bh
L_0065c7:
        mov    0x482,%bl
L_0065cb:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0065cd:
        ret
