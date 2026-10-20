# sub_1580 — mechanical clean (bulk wave); behavior not yet reviewed
# func 1580..158F  len 0010 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_1580:
L_001780:
        pop    %es
L_001781:
        ret
        db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00        # tail-pad
