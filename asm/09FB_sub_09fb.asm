# sub_09fb — mechanical clean (bulk wave); behavior not yet reviewed
# func 09FB..09FE  len 0004 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_09fb:
L_000bfb:
        cmp    $0x41,%al
L_000bfd:
        jae L_000c18
