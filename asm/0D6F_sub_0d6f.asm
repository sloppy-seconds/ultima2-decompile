# sub_0d6f — mechanical clean (bulk wave); behavior not yet reviewed
# func 0D6F..0DA3  len 0035 B  evidence: seed+reko
# calls: L_000daf, L_000fc4
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0d6f:
L_000f6f:
        mov    $0xfc,%al
L_000f71:
        mov    0x6,%bx
L_000f75:
        mov    %al,(%bx,%si)
L_000f77:
        mov    %al,0x197(%di)
L_000f7b:
        mov    $0x20,%al
L_000f7d:
        mov    %al,0x177(%di)
L_000f81:
        jmp L_000daf
L_000f84:
        mov    0x1b7(%di),%al
L_000f88:
        cmp    $0x8,%al
L_000f8a:
        je L_000f8f
L_000f8c:
        jmp L_000fc4
L_000f8e:
        nop
L_000f8f:
        mov    $0x34,%al
L_000f91:
        mov    0x6,%bx
L_000f95:
        mov    %al,(%bx,%si)
L_000f97:
        mov    %al,0x197(%di)
L_000f9b:
        mov    $0x40,%al
L_000f9d:
        mov    %al,0x177(%di)
L_000fa1:
        jmp L_000daf
