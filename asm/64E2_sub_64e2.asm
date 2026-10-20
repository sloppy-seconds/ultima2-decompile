# sub_64e2 — mechanical clean (bulk wave); behavior not yet reviewed
# func 64E2..653E  len 005D B  evidence: call+reko
# calls: L_0069b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_64e2:
L_0066e2:
        mov    $0x0,%bh
L_0066e4:
        mov    0x482,%bl
L_0066e8:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0066ea:
        mov    %cs:0x6231(%di),%al
L_0066ef:
        mov    %al,0x479
L_0066f2:
        mov    %al,0x47b
L_0066f5:
        mov    %cs:0x6251(%di),%al
L_0066fa:
        mov    %al,0x47a
L_0066fd:
        mov    %cs:0x6222(%di),%al
L_006702:
        mov    %al,0x47c
L_006705:
        call L_0069b3
L_006708:
        mov    $0x0,%bh
L_00670a:
        mov    0x482,%bl
L_00670e:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006710:
        mov    %cs:0x6239(%di),%al
L_006715:
        mov    %al,0x47b
L_006718:
        mov    %cs:0x6261(%di),%al
L_00671d:
        mov    %al,0x47c
L_006720:
        call L_0069b3
L_006723:
        mov    $0x0,%bh
L_006725:
        mov    0x482,%bl
L_006729:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00672b:
        mov    %cs:0x6259(%di),%al
L_006730:
        mov    %al,0x47c
L_006733:
        call L_0069b3
L_006736:
        mov    $0x0,%bh
L_006738:
        mov    0x482,%bl
L_00673c:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00673e:
        ret
