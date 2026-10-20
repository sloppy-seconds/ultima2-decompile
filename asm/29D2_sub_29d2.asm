# sub_29d2 — mechanical clean (bulk wave); behavior not yet reviewed
# func 29D2..2B64  len 0193 B  evidence: call+reko
# calls: L_002be6, L_002caa, L_002ccb, L_002d0a, L_002d46, L_002d65, L_004d4e, L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_29d2:
L_002bd2:
        nop
L_002bd3:
        mov    $0x0,%al
L_002bd5:
        mov    %al,%cs:0x29d0
L_002bd9:
        mov    %al,%cs:0x29d1
L_002bdd:
        mov    %al,0x19
L_002be0:
        mov    %al,0x1a
L_002be3:
        call L_004d4e
L_002be6:
        mov    %cs:0x29d0,%al
L_002bea:
        clc
L_002beb:
        adc    0x19,%al
L_002bef:
        and    $0x3f,%al
L_002bf1:
        mov    %al,0x23
L_002bf4:
        mov    %cs:0x29d1,%al
L_002bf8:
        clc
L_002bf9:
        adc    0x1a,%al
L_002bfd:
        and    $0x3f,%al
L_002bff:
        mov    %al,0x24
L_002c02:
        call L_0052b3
L_002c05:
        jne L_002c0a
L_002c07:
        jmp L_002d46
L_002c0a:
        cmp    $0x10,%al
L_002c0c:
        je L_002c2f
L_002c0e:
        cmp    $0x78,%al
L_002c10:
        jb L_002c16
L_002c12:
        cmp    $0xf0,%al
L_002c14:
        jb L_002c2f
L_002c16:
        cmp    $0x8,%al
L_002c18:
        je L_002c89
L_002c1a:
        cmp    $0xc,%al
L_002c1c:
        je L_002c6b
L_002c1e:
        cmp    $0x4,%al
L_002c20:
        je L_002c29
L_002c22:
        cmp    $0x70,%al
L_002c24:
        je L_002c2c
L_002c26:
        jmp L_002d0a
L_002c29:
        jmp L_002caa
L_002c2b:
        nop
L_002c2c:
        jmp L_002ccb
L_002c2f:
        mov    $0x0,%bh
L_002c31:
        mov    $0x0,%bl
L_002c33:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002c35:
        mov    $0x0,%bh
L_002c37:
        mov    $0x0,%bl
L_002c39:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002c3b:
        call L_002d65
L_002c3e:
        mov    $0x0,%bh
L_002c40:
        mov    $0x0,%bl
L_002c42:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002c44:
        mov    $0x0,%bh
L_002c46:
        mov    $0x1,%bl
L_002c48:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002c4a:
        call L_002d65
L_002c4d:
        mov    $0x0,%bh
L_002c4f:
        mov    $0x2,%bl
L_002c51:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002c53:
        mov    $0x0,%bh
L_002c55:
        mov    $0x1,%bl
L_002c57:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002c59:
        call L_002d65
L_002c5c:
        mov    $0x0,%bh
L_002c5e:
        mov    $0x2,%bl
L_002c60:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002c62:
        mov    $0x0,%bh
L_002c64:
        mov    $0x0,%bl
L_002c66:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002c68:
        call L_002d65
L_002c6b:
        mov    $0x0,%bh
L_002c6d:
        mov    $0x1,%bl
L_002c6f:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002c71:
        mov    $0x0,%bh
L_002c73:
        mov    $0x1,%bl
L_002c75:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002c77:
        call L_002d65
L_002c7a:
        mov    $0x0,%bh
L_002c7c:
        mov    $0x3,%bl
L_002c7e:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002c80:
        mov    $0x0,%bh
L_002c82:
        mov    $0x0,%bl
L_002c84:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002c86:
        call L_002d65
L_002c89:
        mov    $0x0,%bh
L_002c8b:
        mov    $0x1,%bl
L_002c8d:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002c8f:
        mov    $0x0,%bh
L_002c91:
        mov    $0x0,%bl
L_002c93:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002c95:
        call L_002d65
L_002c98:
        mov    $0x0,%bh
L_002c9a:
        mov    $0x3,%bl
L_002c9c:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002c9e:
        mov    $0x0,%bh
L_002ca0:
        mov    $0x1,%bl
L_002ca2:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002ca4:
        call L_002d65
L_002ca7:
        jmp L_002d46
L_002caa:
        mov    $0x0,%bh
L_002cac:
        mov    $0x1,%bl
L_002cae:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002cb0:
        mov    $0x0,%bh
L_002cb2:
        mov    $0x0,%bl
L_002cb4:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002cb6:
        call L_002d65
L_002cb9:
        mov    $0x0,%bh
L_002cbb:
        mov    $0x3,%bl
L_002cbd:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002cbf:
        mov    $0x0,%bh
L_002cc1:
        mov    $0x0,%bl
L_002cc3:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002cc5:
        call L_002d65
L_002cc8:
        jmp L_002d46
L_002cca:
        nop
L_002ccb:
        mov    $0x0,%bh
L_002ccd:
        mov    $0x0,%bl
L_002ccf:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002cd1:
        mov    $0x0,%bh
L_002cd3:
        mov    $0x0,%bl
L_002cd5:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002cd7:
        call L_002d65
L_002cda:
        mov    $0x0,%bh
L_002cdc:
        mov    $0x0,%bl
L_002cde:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002ce0:
        mov    $0x0,%bh
L_002ce2:
        mov    $0x1,%bl
L_002ce4:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002ce6:
        call L_002d65
L_002ce9:
        mov    $0x0,%bh
L_002ceb:
        mov    $0x2,%bl
L_002ced:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002cef:
        mov    $0x0,%bh
L_002cf1:
        mov    $0x0,%bl
L_002cf3:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002cf5:
        call L_002d65
L_002cf8:
        mov    $0x0,%bh
L_002cfa:
        mov    $0x2,%bl
L_002cfc:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002cfe:
        mov    $0x0,%bh
L_002d00:
        mov    $0x1,%bl
L_002d02:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002d04:
        call L_002d65
L_002d07:
        jmp L_002d46
L_002d09:
        nop
L_002d0a:
        mov    $0x0,%bh
L_002d0c:
        mov    $0x1,%bl
L_002d0e:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002d10:
        mov    $0x0,%bh
L_002d12:
        mov    $0x0,%bl
L_002d14:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002d16:
        call L_002d65
L_002d19:
        mov    $0x0,%bh
L_002d1b:
        mov    $0x2,%bl
L_002d1d:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002d1f:
        mov    $0x0,%bh
L_002d21:
        mov    $0x0,%bl
L_002d23:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002d25:
        call L_002d65
L_002d28:
        mov    $0x0,%bh
L_002d2a:
        mov    $0x2,%bl
L_002d2c:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002d2e:
        mov    $0x0,%bh
L_002d30:
        mov    $0x1,%bl
L_002d32:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002d34:
        call L_002d65
L_002d37:
        mov    $0x0,%bh
L_002d39:
        mov    $0x1,%bl
L_002d3b:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002d3d:
        mov    $0x0,%bh
L_002d3f:
        mov    $0x1,%bl
L_002d41:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002d43:
        call L_002d65
L_002d46:
        incb   0x19
L_002d4a:
        mov    0x19,%al
L_002d4d:
        and    $0x3f,%al
L_002d4f:
        mov    %al,0x19
L_002d52:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_002d54:
        je L_002d59
L_002d56:
        jmp L_002be6
L_002d59:
        incb   0x1a
L_002d5d:
        mov    0x1a,%al
L_002d60:
        cmp    $0x40,%al
L_002d62:
        jb L_002d56
L_002d64:
        ret
