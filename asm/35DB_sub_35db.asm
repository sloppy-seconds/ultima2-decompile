# sub_35db — mechanical clean (bulk wave); behavior not yet reviewed
# func 35DB..35DC  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_35db:
L_0037db:
        push   %bx
L_0037dc:
        .byte 0xd4  # forced-kept: gas re-encodes 'aam    $0x90' differently
