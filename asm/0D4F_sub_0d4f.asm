# sub_0d4f — mechanical clean (bulk wave); behavior not yet reviewed
# func 0D4F..0D63  len 0015 B  evidence: seed+reko
# calls: L_000daf
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0d4f:
L_000f4f:
        mov    $0x30,%al
L_000f51:
        mov    0x6,%bx
L_000f55:
        mov    %al,(%bx,%si)
L_000f57:
        mov    %al,0x197(%di)
L_000f5b:
        mov    $0x10,%al
L_000f5d:
        mov    %al,0x177(%di)
L_000f61:
        jmp L_000daf
