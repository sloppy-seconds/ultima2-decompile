# sub_3577 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3577..3581  len 000B B  evidence: seed+reko
# calls: L_000c33, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3577:
L_003777:
        jmp L_000c33
L_00377a:
        call L_0051df
L_00377d:
        inc    %cx
L_00377e:
        dec    %si
L_00377f:
        dec    %di
L_003780:
        push   %bx
L_003781:
        .byte 0x3a  # forced-kept: gas re-encodes 'cmp    (%bx,%si),%ah' differently
