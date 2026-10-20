# sub_8cd0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 8CD0..8DCC  len 00FD B  evidence: call
# strings: "PSQR"; "ZY[X"; "r*"; ".+"
# calls: L_008dc2, L_008fcd
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_8cd0:
L_008ed0:
        pushf
L_008ed1:
        push   %ds
L_008ed2:
        push   %es
L_008ed3:
        db "PSQR"        # string
L_008ed7:
        mov    %cs,%bx
L_008ed9:
        mov    %bx,%ds
L_008edb:
        mov    %bx,%es
L_008edd:
        lea    0x12,%bx
L_008ee1:
        lea    0x1f3,%cx
L_008ee5:
        sub    $0x2,%cx
L_008ee8:
        .byte 0x2b,0xcb  # forced-kept: sub    %bx,%cx
L_008eea:
        mov    (%bx),%al
L_008eec:
        xor    $0x53,%al
L_008eee:
        mov    %al,(%bx)
L_008ef0:
        inc    %bx
L_008ef1:
        loop L_008eea
L_008ef3:
        db "ZY[X"        # string
L_008ef7:
        pop    %es
L_008ef8:
        pop    %ds
L_008ef9:
        popf
L_008efa:
        ret
        db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00        # gap-pad
L_008f13:
        db 0,0        # zeros
L_008f15:
        pushf
L_008f16:
        push   %cx
L_008f17:
        push   %dx
L_008f18:
        push   %ax
L_008f19:
        call L_008fcd
L_008f1c:
        push   %dx
L_008f1d:
        push   %cx
L_008f1e:
        cmp    $0x0,%al
L_008f20:
        je L_008f2e
L_008f22:
        add    $0xb0,%dx
L_008f26:
        jae L_008f29
L_008f28:
        inc    %cx
L_008f29:
        add    $0x18,%cx
L_008f2c:
        db "r*"        # string
L_008f2e:
        db ".+",0x16,0x16,0x03        # string
L_008f33:
        jae L_008f36
L_008f35:
        dec    %cx
L_008f36:
        sub    %cs:0x314,%cx
L_008f3b:
        jb L_008f58
L_008f3d:
        mov    %cx,%cs:0x29b
L_008f42:
        mov    %dx,%cs:0x29d
L_008f47:
        pop    %cx
L_008f48:
        pop    %dx
L_008f49:
        mov    %cx,%cs:0x314
L_008f4e:
        mov    %dx,%cs:0x316
L_008f53:
        pop    %ax
L_008f54:
        pop    %dx
L_008f55:
        pop    %cx
L_008f56:
        popf
L_008f57:
        ret
L_008f58:
        jmp L_008dc2
L_008f5b:
        push   %es
L_008f5c:
        .byte 0x00,0x40,0x00  # forced-kept: add    %al,0x0(%bx,%si)
L_008f5f:
        pushf
L_008f60:
        push   %cx
L_008f61:
        push   %dx
L_008f62:
        mov    %cs:0x29b,%cx
L_008f67:
        cmp    $0x0,%cx
L_008f6a:
        jne L_008f58
L_008f6c:
        mov    %cs:0x29d,%cx
L_008f71:
        cmp    %cs:0x2bc,%cx
L_008f76:
        jae L_008f58
L_008f78:
        pop    %dx
L_008f79:
        pop    %cx
L_008f7a:
        popf
L_008f7b:
        ret
L_008f7c:
        nop
L_008f7d:
        add    %ch,%al
L_008f7f:
        dec    %sp
L_008f80:
        add    %ch,0xe89
L_008f84:
        adc    $0x3,%al
L_008f86:
        mov    %dx,%cs:0x316
L_008f8b:
        mov    $0x0,%ax
L_008f8e:
        mov    %ax,%es
L_008f90:
        mov    %es:0x4e,%ax
L_008f94:
        cmp    $0xbfff,%ax
L_008f97:
        jle L_008f9d
L_008f99:
        mov    %es:0x12,%ax
L_008f9d:
        .byte 0x8b,0xc8  # forced-kept: mov    %ax,%cx
L_008f9f:
        mov    %es:0x6,%ax
L_008fa3:
        cmp    $0xf0,%al
L_008fa5:
        jge L_008fae
L_008fa7:
        .byte 0x3b,0xc8  # forced-kept: cmp    %ax,%cx
L_008fa9:
        je L_008fae
L_008fab:
        jmp L_008dc2
L_008fae:
        mov    %es:0xe,%ax
L_008fb2:
        cmp    $0xf0,%al
L_008fb4:
        jge L_008fbd
L_008fb6:
        .byte 0x3b,0xc1  # forced-kept: cmp    %cx,%ax
L_008fb8:
        je L_008fbd
L_008fba:
        jmp L_008dc2
L_008fbd:
        lea    0x23a,%bx
L_008fc1:
        mov    $0xc3,%ax
L_008fc4:
        mov    %ax,(%bx)
L_008fc6:
        mov    %cs,%bx
L_008fc8:
        mov    %bx,%ds
L_008fca:
        mov    %bx,%es
L_008fcc:
        ret
