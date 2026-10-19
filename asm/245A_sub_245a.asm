# sub_245a — mechanical clean (bulk wave); behavior not yet reviewed
# func 245A..2473  len 001A B  evidence: seed+reko
# calls: L_000c33, L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_245a:
L_00265a:
        mov    0x6a,%al
L_00265d:
        mov    %al,0x23
L_002660:
        mov    0x6b,%al
L_002663:
        mov    %al,0x24
L_002666:
        call L_0052b3
L_002669:
        mov    $0x50,%al
L_00266b:
        mov    0x6,%bx
L_00266f:
        mov    %al,(%bx,%si)
L_002671:
        jmp L_000c33
