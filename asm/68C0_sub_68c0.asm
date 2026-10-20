# sub_68c0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 68C0..68EC  len 002D B  evidence: call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_68c0:
L_006ac0:
        mov    0x25,%ah
L_006ac4:
        mov    $0x0,%al
L_006ac6:
        add    0x472,%ax
L_006aca:
        mov    %ah,0x488
L_006ace:
        mov    0x24,%al
L_006ad1:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_006ad3:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_006ad5:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_006ad7:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_006ad9:
        adc    0x23,%al
L_006add:
        mov    %al,0x487
L_006ae0:
        mov    $0x0,%bh
L_006ae2:
        mov    $0x0,%bl
L_006ae4:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_006ae6:
        mov    0x487,%bx
L_006aea:
        mov    (%bx,%si),%al
L_006aec:
        ret
