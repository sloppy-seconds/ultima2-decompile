# sub_5c25 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5C25..5C34  len 0010 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5c25:
L_005e25:
        mov    %al,0x272(%di)
L_005e29:
        inc    %di
L_005e2a:
        incb   0x4
L_005e2e:
        mov    0x4,%al
L_005e31:
        cmp    $0x14,%al
L_005e33:
        jne L_005dc2
