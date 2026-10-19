# sub_17b7 — mechanical clean (bulk wave); behavior not yet reviewed
# func 17B7..17C4  len 000E B  evidence: seed+reko
# calls: L_0053a5
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_17b7:
L_0019b7:
        mov    0x27,%al
L_0019ba:
        mov    $0x0,%bh
L_0019bc:
        mov    0x28,%bl
L_0019c0:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0019c2:
        call L_0053a5
