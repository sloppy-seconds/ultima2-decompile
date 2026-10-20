# sub_653f — mechanical clean (bulk wave); behavior not yet reviewed
# func 653F..6593  len 0055 B  evidence: call+reko
# calls: L_0069b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_653f:
L_00673f:
        mov    $0x0,%bh
L_006741:
        mov    0x482,%bl
L_006745:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006747:
        mov    %cs:0x6241(%di),%al
L_00674c:
        mov    %al,0x479
L_00674f:
        mov    %al,0x47b
L_006752:
        mov    %cs:0x6251(%di),%al
L_006757:
        mov    %al,0x47a
L_00675a:
        mov    %cs:0x6222(%di),%al
L_00675f:
        mov    %al,0x47c
L_006762:
        call L_0069b3
L_006765:
        mov    $0x0,%bh
L_006767:
        mov    0x482,%bl
L_00676b:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00676d:
        mov    %cs:0x6249(%di),%al
L_006772:
        mov    %al,0x47b
L_006775:
        mov    %cs:0x6261(%di),%al
L_00677a:
        mov    %al,0x47c
L_00677d:
        call L_0069b3
L_006780:
        mov    $0x0,%bh
L_006782:
        mov    0x482,%bl
L_006786:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006788:
        mov    %cs:0x6259(%di),%al
L_00678d:
        mov    %al,0x47c
L_006790:
        call L_0069b3
L_006793:
        ret
