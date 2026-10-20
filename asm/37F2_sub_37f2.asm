# sub_37f2 — mechanical clean (bulk wave); behavior not yet reviewed
# func 37F2..380A  len 0019 B  evidence: reko
# calls: L_003a0b, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_37f2:
L_0039f2:
        jmp L_003a0b
L_0039f4:
        dec    %bx
L_0039f5:
        dec    %sp
L_0039f6:
        dec    %cx
L_0039f7:
        dec    %bp
L_0039f8:
        inc    %dx
L_0039f9:
        .byte 0x00,0xa0,0x4a,0x00  # forced-kept: gas re-encodes 'add    %ah,0x4a(%bx,%si)' differently
L_0039fd:
        cmp    $0x5,%al
L_0039ff:
        je L_003a12
L_003a01:
        cmp    $0x4,%al
L_003a03:
        je L_003a12
L_003a05:
        call L_0051df
L_003a08:
        sub    $0x4857,%ax
