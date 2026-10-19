# sub_2199 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2199..21A2  len 000A B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2199:
L_002399:
        mov    %al,0x1f
L_00239c:
        mov    0x26a,%al
L_00239f:
        cmp    $0x0,%al
L_0023a1:
        je L_0023a6
