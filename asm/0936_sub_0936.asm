# sub_0936 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0936..093F  len 000A B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0936:
L_000b36:
        mov    %al,0x5d
L_000b39:
        mov    0x5d,%al
L_000b3c:
        cmp    $0x20,%al
L_000b3e:
        jne L_000b4f
