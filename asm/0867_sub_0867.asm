# sub_0867 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0867..086E  len 0008 B  evidence: seed+reko
# calls: L_0052f9
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0867:
L_000a67:
        mov    $0xff,%al
L_000a69:
        mov    %al,0x12
L_000a6c:
        call L_0052f9
