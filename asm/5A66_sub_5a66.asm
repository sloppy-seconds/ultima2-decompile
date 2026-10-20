# sub_5a66 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5A66..5AB0  len 004B B  evidence: call+reko
# calls: L_0051df (str_out), L_0053eb, L_0055b5, L_0055d9, L_0055df, L_005698
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5a66:
L_005c66:
        mov    %al,0x2a
L_005c69:
        cmp    $0xa,%al
L_005c6b:
        jb L_005c96
L_005c6d:
        mov    0x29,%al
L_005c70:
        sub    0x2a,%al
L_005c74:
        das
L_005c75:
        jb L_005c96
L_005c77:
        call L_0055df
L_005c7a:
        mov    %al,0x29
L_005c7d:
        mov    $0x0,%bh
L_005c7f:
        mov    $0x2,%bl
L_005c81:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_005c83:
        mov    $0x0,%bh
L_005c85:
        mov    $0x21,%bl
L_005c87:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_005c89:
        call L_0053eb
L_005c8c:
        mov    0x29,%al
L_005c8f:
        call L_0055b5
L_005c92:
        call L_0055d9
L_005c95:
        ret
L_005c96:
        call L_0051df
        db 0x07,0x07,0x07,0x00        # string
L_005c9d:
        .byte 0x58  # forced-kept: gas re-encodes 'pop    %ax' differently
L_005c9e:
        jmp L_005698
        db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00        # tail-pad
