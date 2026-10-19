# sub_0daf — mechanical clean (bulk wave); behavior not yet reviewed
# func 0DAF..0DC3  len 0015 B  evidence: seed+reko
# calls: L_000daf
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0daf:
L_000faf:
        mov    $0x2c,%al
L_000fb1:
        mov    0x6,%bx
L_000fb5:
        mov    %al,(%bx,%si)
L_000fb7:
        mov    %al,0x197(%di)
L_000fbb:
        mov    $0x40,%al
L_000fbd:
        mov    %al,0x177(%di)
L_000fc1:
        jmp L_000daf
