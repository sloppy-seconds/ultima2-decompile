# sub_3582 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3582..3595  len 0014 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3582:
L_003782:
        and    %bh,(%bx,%di)
L_003784:
        sub    $0x30,%al
L_003786:
        xor    %dh,(%bx,%si)
L_003788:
        sub    $0x30,%al
L_00378a:
        xor    %dh,(%bx,%si)
L_00378c:
        and    %al,0x2e(%bp,%si)
L_00378f:
        inc    %bx
L_003790:
        cs add %ch,%cl
L_003793:
        sahf
L_003794:
        aam    $0xe8
