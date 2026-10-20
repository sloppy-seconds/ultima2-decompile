# sub_08a7 — mechanical clean (bulk wave); behavior not yet reviewed
# func 08A7..08C7  len 0021 B  evidence: seed+reko
# calls: L_000c33, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_08a7:
L_000aa7:
        mov    $0x14,%al
L_000aa9:
        mov    %al,0x27
L_000aac:
        call L_0051df
        db "Z",0x00        # string
L_000ab1:
        .byte 0xb7,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
L_000ab3:
        .byte 0xb3,0xff  # forced-kept: gas re-encodes 'mov    $0xff,%bl' differently
L_000ab5:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_000ab7:
        .byte 0x4f  # forced-kept: gas re-encodes 'dec    %di' differently
L_000ab8:
        nop
L_000ab9:
        nop
L_000aba:
        nop
L_000abb:
        nop
L_000abc:
        nop
L_000abd:
        jne L_000ab7
L_000abf:
        decb   0x27
L_000ac3:
        jne L_000aac
L_000ac5:
        jmp L_000c33
