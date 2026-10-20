# sub_17f5 — mechanical clean (bulk wave); behavior not yet reviewed
# func 17F5..1816  len 0022 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_17f5:
L_0019f5:
        pop    %cx
L_0019f6:
        inc    %bp
L_0019f7:
        push   %bx
L_0019f8:
        sub    $0x8d,%al
L_0019fa:
        dec    %si
L_0019fb:
        dec    %di
L_0019fc:
        and    %cl,0x4e(%bx)
L_0019ff:
        dec    %cx
L_001a00:
        dec    %di
L_001a01:
        dec    %si
L_001a02:
        push   %bx
L_001a03:
        and    %al,0x4e(%bx,%di)
L_001a06:
        inc    %sp
L_001a07:
        and    %dl,0x4f(%si)
L_001a0a:
        and    %al,0x4f(%bx)
L_001a0d:
        and    %dl,0x4c(%bx,%si)
L_001a10:
        inc    %bp
L_001a11:
        inc    %cx
L_001a12:
        push   %bx
L_001a13:
        inc    %bp
L_001a14:
        .byte 0x21,0x8d,0x00  # forced-kept: gas re-encodes 'and    %cx,-0x1800(%di)' differently
