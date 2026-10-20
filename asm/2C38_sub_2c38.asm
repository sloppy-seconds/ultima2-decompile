# sub_2c38 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2C38..2CA3  len 006C B  evidence: seed+reko
# calls: L_000c33, L_004d26, L_0051df (str_out), L_0052b3, L_0061a6
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2c38:
L_002e38:
        call L_004d26
L_002e3b:
        call L_0061a6
L_002e3e:
        call L_004d26
L_002e41:
        mov    $0x0,%bh
L_002e43:
        mov    0x20,%bl
L_002e47:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_002e49:
        mov    0x137(%di),%al
L_002e4d:
        mov    %al,0x23
L_002e50:
        mov    0x157(%di),%al
L_002e54:
        mov    %al,0x24
L_002e57:
        call L_0052b3
L_002e5a:
        mov    0x1b7(%di),%al
L_002e5e:
        mov    0x6,%bx
L_002e62:
        mov    %al,(%bx,%si)
L_002e64:
        mov    0x23,%al
L_002e67:
        mov    %al,0x157(%di)
L_002e6b:
        mov    0x24,%al
L_002e6e:
        mov    %al,0x137(%di)
L_002e72:
        mov    %al,0x23
L_002e75:
        mov    0x157(%di),%al
L_002e79:
        mov    %al,0x24
L_002e7c:
        call L_0052b3
L_002e7f:
        mov    0x197(%di),%al
L_002e83:
        mov    0x6,%bx
L_002e87:
        mov    %al,(%bx,%si)
L_002e89:
        mov    $0x84,%al
L_002e8b:
        mov    %al,0x1d7(%di)
L_002e8f:
        call L_0051df
        db 0x8d,"SHE'S GONE!!!",0x00        # string
L_002ea1:
        jmp L_000c33
