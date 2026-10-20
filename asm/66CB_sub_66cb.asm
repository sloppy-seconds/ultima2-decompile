# sub_66cb — mechanical clean (bulk wave); behavior not yet reviewed
# func 66CB..67B2  len 00E8 B  evidence: call+reko
# calls: L_0069b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_66cb:
L_0068cb:
        nop
L_0068cc:
        mov    %cs:0x620f(%di),%al
L_0068d1:
        mov    %al,0x479
L_0068d4:
        mov    %cs:0x6289(%di),%al
L_0068d9:
        mov    %al,0x47a
L_0068dc:
        mov    %al,0x47c
L_0068df:
        mov    %cs:0x621a(%di),%al
L_0068e4:
        mov    %al,0x47b
L_0068e7:
        call L_0069b3
L_0068ea:
        mov    $0x0,%bh
L_0068ec:
        mov    0x482,%bl
L_0068f0:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0068f2:
        mov    %cs:0x6251(%di),%al
L_0068f7:
        mov    %al,0x47c
L_0068fa:
        call L_0069b3
L_0068fd:
        mov    $0x0,%bh
L_0068ff:
        mov    0x482,%bl
L_006903:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006905:
        mov    %cs:0x620f(%di),%al
L_00690a:
        mov    %al,0x47b
L_00690d:
        call L_0069b3
L_006910:
        mov    $0x0,%bh
L_006912:
        mov    0x482,%bl
L_006916:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006918:
        mov    %cs:0x6289(%di),%al
L_00691d:
        mov    %al,0x47c
L_006920:
        call L_0069b3
L_006923:
        mov    $0x0,%bh
L_006925:
        mov    0x482,%bl
L_006929:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00692b:
        mov    %cs:0x6210(%di),%al
L_006930:
        mov    %al,0x47b
L_006933:
        mov    %cs:0x6259(%di),%al
L_006938:
        mov    %al,0x47c
L_00693b:
        call L_0069b3
L_00693e:
        mov    $0x0,%bh
L_006940:
        mov    0x482,%bl
L_006944:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006946:
        mov    %cs:0x6219(%di),%al
L_00694b:
        mov    %al,0x47b
L_00694e:
        call L_0069b3
L_006951:
        mov    $0x0,%bh
L_006953:
        mov    0x482,%bl
L_006957:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006959:
        mov    %cs:0x6289(%di),%al
L_00695e:
        mov    %al,0x47c
L_006961:
        call L_0069b3
L_006964:
        mov    $0x0,%bh
L_006966:
        mov    0x482,%bl
L_00696a:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00696c:
        mov    %cs:0x621a(%di),%al
L_006971:
        mov    %al,0x47b
L_006974:
        mov    %cs:0x6251(%di),%al
L_006979:
        mov    %al,0x47c
L_00697c:
        call L_0069b3
L_00697f:
        mov    $0x0,%bh
L_006981:
        mov    0x482,%bl
L_006985:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006987:
        mov    %cs:0x621a(%di),%al
L_00698c:
        mov    %al,0x479
L_00698f:
        mov    %cs:0x6289(%di),%al
L_006994:
        mov    %al,0x47a
L_006997:
        mov    %cs:0x6219(%di),%al
L_00699c:
        mov    %al,0x47b
L_00699f:
        mov    %cs:0x6259(%di),%al
L_0069a4:
        mov    %al,0x47c
L_0069a7:
        call L_0069b3
L_0069aa:
        mov    $0x0,%bh
L_0069ac:
        mov    0x482,%bl
L_0069b0:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0069b2:
        ret
