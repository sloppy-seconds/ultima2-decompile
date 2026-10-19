# sub_4a64 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4A64..4A70  len 000D B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4a64:
L_004c64:
        mov    %ax,0x272(%bx)
L_004c68:
        mov    %ax,0x372(%bx)
L_004c6c:
        sub    $0x2,%bx
L_004c6f:
        jns L_004c64
