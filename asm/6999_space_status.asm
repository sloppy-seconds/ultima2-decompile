# space_status — space-travel status readout (fuel, xeno)
# name-evidence: strings '  FUEL=' / '  XENO='
# func 6999..6B3C  len 01A4 B  evidence: call+reko
# strings: "  FUEL="; "  XENO="; "  YAKO="; "  ZABO=" (+5 more)
# calls: L_000911, L_004c3e, L_00514d, L_0051df (str_out), L_0053eb, L_006c77, L_006c79, L_006c86 (+12 more)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
space_status:
L_006b99:
        nop
L_006b9a:
        call L_004c3e
L_006b9d:
        movb   $0xff,%cs:0x6998
L_006ba3:
        mov    $0x80,%al
L_006ba5:
        mov    %al,0x47b
L_006ba8:
        mov    $0x40,%al
L_006baa:
        mov    %al,0x47c
L_006bad:
        mov    $0x0,%bh
L_006baf:
        mov    0x6d,%bl
L_006bb3:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006bb5:
        mov    %cs:0x7012(%di),%al
L_006bba:
        mov    %al,0x4ca
L_006bbd:
        mov    %cs:0x701c(%di),%al
L_006bc2:
        mov    %al,0x4cb
L_006bc5:
        mov    %cs:0x7026(%di),%al
L_006bca:
        mov    %al,0x4cc
L_006bcd:
        mov    0xe5,%al
L_006bd0:
        stc
L_006bd1:
        cmc
L_006bd2:
        sbb    $0x1,%al
L_006bd4:
        das
L_006bd5:
        cmc
L_006bd6:
        mov    %al,0xe5
L_006bd9:
        mov    $0x28,%al
L_006bdb:
        mov    %al,0x31
L_006bde:
        mov    $0x0,%bh
L_006be0:
        mov    $0x1e,%bl
L_006be2:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006be4:
        mov    $0x0,%bh
L_006be6:
        mov    $0x14,%bl
L_006be8:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_006bea:
        call L_0053eb
L_006bed:
        call L_0051df
        db "  FUEL=",0x00        # string
L_006bf8:
        mov    $0x0,%bh
L_006bfa:
        mov    $0x1e,%bl
L_006bfc:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006bfe:
        mov    $0x0,%bh
L_006c00:
        mov    $0x15,%bl
L_006c02:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_006c04:
        call L_0053eb
L_006c07:
        call L_0051df
        db "  XENO=",0x00        # string
L_006c12:
        mov    $0x0,%bh
L_006c14:
        mov    $0x1e,%bl
L_006c16:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006c18:
        mov    $0x0,%bh
L_006c1a:
        mov    $0x16,%bl
L_006c1c:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_006c1e:
        call L_0053eb
L_006c21:
        call L_0051df
        db "  YAKO=",0x00        # string
L_006c2c:
        mov    $0x0,%bh
L_006c2e:
        mov    $0x1e,%bl
L_006c30:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_006c32:
        mov    $0x0,%bh
L_006c34:
        mov    $0x17,%bl
L_006c36:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_006c38:
        call L_0053eb
L_006c3b:
        call L_0051df
        db "  ZABO=",0x00        # string
L_006c46:
        mov    $0x20,%al
L_006c48:
        mov    %al,0x31
L_006c4b:
        call L_0071a3
L_006c4e:
        call L_006f3e
L_006c51:
        call L_006ffd
L_006c54:
        mov    0x62,%al
L_006c57:
        cmp    $0x5,%al
L_006c59:
        jae L_006c79
L_006c5b:
        call L_0051df
        db 0x8d,"YOU HAVE EXPLODED!",0x8d,0x8d,0x00        # string
L_006c74:
        call L_007489
L_006c77:
        jmp L_006c77
L_006c79:
        nop
L_006c7a:
        call L_0071a3
L_006c7d:
        call L_0051df
        db "CMD: ",0x00        # string
L_006c86:
        call L_006d3d
L_006c89:
        mov    $0x14,%bx
L_006c8c:
        call L_000911
L_006c8f:
        call L_00514d
L_006c92:
        cmp    $0xff,%ah
L_006c95:
        jne L_006c86
L_006c97:
        cmp    0x271,%al
L_006c9b:
        jne L_006ca0
L_006c9d:
        jmp L_006cd8
L_006c9f:
        nop
L_006ca0:
        cmp    0x270,%al
L_006ca4:
        jne L_006ca9
L_006ca6:
        jmp L_006cf0
L_006ca8:
        nop
L_006ca9:
        cmp    0x26e,%al
L_006cad:
        jne L_006cb2
L_006caf:
        jmp L_006d0a
L_006cb1:
        nop
L_006cb2:
        cmp    0x26f,%al
L_006cb6:
        jne L_006cbb
L_006cb8:
        jmp L_006d24
L_006cba:
        nop
L_006cbb:
        cmp    $0x48,%al
L_006cbd:
        jne L_006cc2
L_006cbf:
        jmp L_0070c5
L_006cc2:
        cmp    $0x4c,%al
L_006cc4:
        jne L_006cc9
L_006cc6:
        jmp L_007385
L_006cc9:
        call L_006ec4
L_006ccc:
        mov    $0x80,%al
L_006cce:
        mov    %al,0x47b
L_006cd1:
        mov    $0x40,%al
L_006cd3:
        mov    %al,0x47c
L_006cd6:
        jmp L_006c86
L_006cd8:
        call L_0051df
        db "LEFT",0x8d,0x00        # string
L_006ce1:
        call L_006ec4
L_006ce4:
        mov    $0x20,%al
L_006ce6:
        mov    %al,0x47b
L_006ce9:
        mov    $0x40,%al
L_006ceb:
        mov    %al,0x47c
L_006cee:
        jmp L_006c79
L_006cf0:
        call L_0051df
        db "RIGHT",0x8d,0x00        # string
L_006cfa:
        call L_006ec4
L_006cfd:
        mov    $0xdf,%al
L_006cff:
        mov    %al,0x47b
L_006d02:
        mov    $0x40,%al
L_006d04:
        mov    %al,0x47c
L_006d07:
        jmp L_006c79
L_006d0a:
        call L_0051df
        db "CLIMB",0x8d,0x00        # string
L_006d14:
        call L_006ec4
L_006d17:
        mov    $0x10,%al
L_006d19:
        mov    %al,0x47c
L_006d1c:
        mov    $0x80,%al
L_006d1e:
        mov    %al,0x47b
L_006d21:
        jmp L_006c79
L_006d24:
        call L_0051df
        db "DIVE",0x8d,0x00        # string
L_006d2d:
        call L_006ec4
L_006d30:
        mov    $0x6f,%al
L_006d32:
        mov    %al,0x47c
L_006d35:
        mov    $0x80,%al
L_006d37:
        mov    %al,0x47b
L_006d3a:
        jmp L_006c79
