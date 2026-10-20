# sub_6684 — mechanical clean (bulk wave); behavior not yet reviewed
# func 6684..66CA  len 0047 B  evidence: call+reko
# calls: L_0069b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_6684:
L_006884:
        mov    $0x0,%bh
L_006886:
        mov    0x482,%bl
L_00688a:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00688c:
        mov    $0x7f,%al
L_00688e:
        mov    %al,0x479
L_006891:
        mov    %al,0x47b
L_006894:
        mov    %cs:0x6269(%di),%al
L_006899:
        mov    %al,0x47a
L_00689c:
        mov    %cs:0x6279(%di),%al
L_0068a1:
        mov    %al,0x47c
L_0068a4:
        call L_0069b3
L_0068a7:
        mov    $0x0,%bh
L_0068a9:
        mov    0x482,%bl
L_0068ad:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0068af:
        mov    $0x80,%al
L_0068b1:
        mov    %al,0x479
L_0068b4:
        mov    %al,0x47b
L_0068b7:
        mov    %cs:0x6269(%di),%al
L_0068bc:
        mov    %al,0x47a
L_0068bf:
        mov    %cs:0x6279(%di),%al
L_0068c4:
        mov    %al,0x47c
L_0068c7:
        call L_0069b3
L_0068ca:
        ret
