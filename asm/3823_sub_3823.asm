# sub_3823 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3823..38AF  len 008D B  evidence: reko
# calls: L_000c33, L_002490, L_0051df (str_out), L_0052b3, L_0054ca, L_0055b5
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3823:
L_003a23:
        nop
L_003a24:
        decb   0x25
L_003a28:
        js L_003a44
L_003a2a:
        call L_0051df
        db 0x8d,"TO LEVEL ",0x00        # string
L_003a38:
        mov    0x25,%al
L_003a3b:
        add    $0x0,%al
L_003a3d:
        daa
L_003a3e:
        call L_0055b5
L_003a41:
        jmp L_000c33
L_003a44:
        nop
L_003a45:
        mov    0x5a,%al
L_003a48:
        mov    %al,0x0
L_003a4b:
        mov    0x5b,%al
L_003a4e:
        mov    %al,0x1
L_003a51:
        mov    $0xfe,%bx
L_003a54:
        mov    $0xffff,%ax
L_003a57:
        mov    %ax,0x272(%bx)
L_003a5b:
        mov    %ax,0x372(%bx)
L_003a5f:
        sub    $0x2,%bx
L_003a62:
        jns L_003a57
L_003a64:
        mov    $0x0,%al
L_003a66:
        mov    %al,0x4a
L_003a69:
        call L_002490
L_003a6c:
        mov    0x5a,%al
L_003a6f:
        mov    %al,0x0
L_003a72:
        mov    0x5b,%al
L_003a75:
        mov    %al,0x1
L_003a78:
        mov    0x6d,%al
L_003a7b:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_003a7d:
        je L_003a99
L_003a7f:
        mov    0x6a,%al
L_003a82:
        mov    %al,0x23
L_003a85:
        mov    0x6b,%al
L_003a88:
        mov    %al,0x24
L_003a8b:
        call L_0052b3
L_003a8e:
        mov    $0x50,%al
L_003a90:
        mov    0x6,%bx
L_003a94:
        mov    %al,(%bx,%si)
L_003a96:
        jmp L_000c33
L_003a99:
        lea    0x36,%dx
L_003a9d:
        mov    $0x28,%ah
L_003a9f:
        mov    $0x100,%cx
L_003aa2:
        call L_0054ca
L_003aa5:
        push   %ax
L_003aa6:
        dec    %sp
L_003aa7:
        inc    %cx
L_003aa8:
        pop    %cx
L_003aa9:
        inc    %bp
L_003aaa:
        push   %dx
L_003aab:
        and    %ah,(%bx,%si)
L_003aad:
        jmp L_000c33
