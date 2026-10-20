# sub_68ed — mechanical clean (bulk wave); behavior not yet reviewed
# func 68ED..6998  len 00AC B  evidence: call+reko
# calls: L_006aa3, L_006b3a
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_68ed:
L_006aed:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_006aee:
        incb   0x482
L_006af2:
        .byte 0xb7,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
L_006af4:
        .byte 0xb3,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bl' differently
L_006af6:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006af8:
        .byte 0x47  # forced-kept: gas re-encodes 'inc    %di' differently
L_006af9:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_006afb:
        .byte 0x3a,0x1e,0x82,0x04  # forced-kept: gas re-encodes 'cmp    0x482,%bl' differently
L_006aff:
        jb L_006b02
L_006b01:
        .byte 0xc3  # forced-kept: gas re-encodes 'ret' differently
L_006b02:
        .byte 0x8a,0xa5,0xaf,0x04  # forced-kept: gas re-encodes 'mov    0x4af(%di),%ah' differently
L_006b06:
        .byte 0x0a,0xe4  # forced-kept: gas re-encodes 'or     %ah,%ah' differently
L_006b08:
        je L_006af8
L_006b0a:
        .byte 0x83,0xff,0x01  # forced-kept: gas re-encodes 'cmp    $0x1,%di' differently
L_006b0d:
        je L_006b2c
L_006b0f:
        .byte 0xa1,0x74,0x04  # forced-kept: gas re-encodes 'mov    0x474,%ax' differently
L_006b12:
        .byte 0x88,0x26,0x8a,0x04  # forced-kept: gas re-encodes 'mov    %ah,0x48a' differently
L_006b16:
        .byte 0x2e,0x8a,0x85,0x7e,0x69  # forced-kept: gas re-encodes 'mov    %cs:0x697e(%di),%al' differently
L_006b1b:
        .byte 0xa2,0x89,0x04  # forced-kept: gas re-encodes 'mov    %al,0x489' differently
L_006b1e:
        .byte 0xa0,0x8a,0x04  # forced-kept: gas re-encodes 'mov    0x48a,%al' differently
L_006b21:
        .byte 0xb7,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
L_006b23:
        .byte 0x8a,0x1e,0x89,0x04  # forced-kept: gas re-encodes 'mov    0x489,%bl' differently
L_006b27:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006b29:
        jmp L_006b3a
L_006b2b:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_006b2c:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_006b2d:
        .byte 0x03,0x06,0x74,0x04  # forced-kept: gas re-encodes 'add    0x474,%ax' differently
L_006b31:
        .byte 0x88,0x26,0x8a,0x04  # forced-kept: gas re-encodes 'mov    %ah,0x48a' differently
L_006b35:
        .byte 0xc6,0x06,0x89,0x04,0x00  # forced-kept: gas re-encodes 'movb   $0x0,0x489' differently
L_006b3a:
        .byte 0xb7,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
L_006b3c:
        .byte 0xb3,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bl' differently
L_006b3e:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_006b40:
        .byte 0x8b,0x1e,0x89,0x04  # forced-kept: gas re-encodes 'mov    0x489,%bx' differently
L_006b44:
        .byte 0x8a,0x00  # forced-kept: gas re-encodes 'mov    (%bx,%si),%al' differently
L_006b46:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_006b48:
        jne L_006b4b
L_006b4a:
        .byte 0xc3  # forced-kept: gas re-encodes 'ret' differently
L_006b4b:
        .byte 0xa2,0x04,0x00  # forced-kept: gas re-encodes 'mov    %al,0x4' differently
L_006b4e:
        incw   0x489
L_006b52:
        .byte 0x8b,0x1e,0x89,0x04  # forced-kept: gas re-encodes 'mov    0x489,%bx' differently
L_006b56:
        .byte 0x8a,0x00  # forced-kept: gas re-encodes 'mov    (%bx,%si),%al' differently
L_006b58:
        .byte 0x24,0x1f  # forced-kept: gas re-encodes 'and    $0x1f,%al' differently
L_006b5a:
        .byte 0xa2,0x05,0x00  # forced-kept: gas re-encodes 'mov    %al,0x5' differently
L_006b5d:
        .byte 0x8b,0x1e,0x89,0x04  # forced-kept: gas re-encodes 'mov    0x489,%bx' differently
L_006b61:
        .byte 0x8a,0x00  # forced-kept: gas re-encodes 'mov    (%bx,%si),%al' differently
L_006b63:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_006b64:
        .byte 0xd0,0xd8  # forced-kept: gas re-encodes 'rcr    $1,%al' differently
L_006b66:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_006b67:
        .byte 0xd0,0xd8  # forced-kept: gas re-encodes 'rcr    $1,%al' differently
L_006b69:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_006b6a:
        .byte 0xd0,0xd8  # forced-kept: gas re-encodes 'rcr    $1,%al' differently
L_006b6c:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_006b6d:
        .byte 0xd0,0xd8  # forced-kept: gas re-encodes 'rcr    $1,%al' differently
L_006b6f:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_006b70:
        .byte 0xd0,0xd8  # forced-kept: gas re-encodes 'rcr    $1,%al' differently
L_006b72:
        .byte 0xa2,0x7f,0x04  # forced-kept: gas re-encodes 'mov    %al,0x47f' differently
L_006b75:
        incw   0x489
L_006b79:
        call L_006aa3
L_006b7c:
        jmp L_006b3a
L_006b7e:
        .byte 0x00,0x00  # forced-kept: gas re-encodes 'add    %al,(%bx,%si)' differently
L_006b80:
        .byte 0x80,0xc0,0xe0  # forced-kept: gas re-encodes 'add    $0xe0,%al' differently
L_006b83:
        .byte 0xf0,0xf8  # forced-kept: gas re-encodes 'lock clc' differently
L_006b85:
        .byte 0xfc  # forced-kept: gas re-encodes 'cld' differently
        db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00        # tail-pad
