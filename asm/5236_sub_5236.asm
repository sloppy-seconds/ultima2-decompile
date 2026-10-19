# sub_5236 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5236..523D  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5236:
L_005436:
        pop    %bx
L_005437:
        pop    %ax
L_005438:
        mov    0x23f,%al
L_00543b:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_00543d:
        ret
