# sub_467a — mechanical clean (bulk wave); behavior not yet reviewed
# func 467A..467E  len 0005 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_467a:
L_00487a:
        data32 add %ch,%al
L_00487d:
        .byte 0x36,0x0d  # forced-kept: gas re-encodes 'ss or  $0xb7,%ax' differently
