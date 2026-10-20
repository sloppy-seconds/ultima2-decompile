# sub_3812 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3812..3822  len 0011 B  evidence: reko
# calls: L_003581
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3812:
L_003a12:
        mov    0x14,%al
L_003a15:
        and    $0x10,%al
L_003a17:
        je L_003a05
L_003a19:
        mov    0x4a,%al
L_003a1c:
        cmp    $0x4,%al
L_003a1e:
        jne L_003a23
L_003a20:
        jmp L_003581
