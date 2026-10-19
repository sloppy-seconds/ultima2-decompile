# sub_4afc — mechanical clean (bulk wave); behavior not yet reviewed
# func 4AFC..4B07  len 000C B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4afc:
L_004cfc:
        push   %ax
L_004cfd:
        push   %bx
L_004cfe:
        push   %cx
L_004cff:
        push   %dx
L_004d00:
        mov    0x2(%si),%bx
L_004d03:
        mov    0x4(%si),%cx
L_004d06:
        mov    $0xf,%dl
