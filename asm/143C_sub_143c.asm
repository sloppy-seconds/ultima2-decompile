# sub_143c — mechanical clean (bulk wave); behavior not yet reviewed
# func 143C..144B  len 0010 B  evidence: call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_143c:
L_00163c:
        nop
L_00163d:
        mov    0x25,%al
L_001640:
        cmp    0x1b7(%di),%al
L_001644:
        je L_00164b
L_001646:
        mov    $0xff,%al
L_001648:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_00164a:
        ret
L_00164b:
        nop
