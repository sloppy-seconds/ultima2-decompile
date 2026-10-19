# sub_4815 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4815..4821  len 000D B  evidence: reko
# calls: L_00528c
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4815:
L_004a15:
        fisttps 0x1f1e(%bx,%si)
L_004a19:
        add    %cl,-0x739(%bp,%di)
L_004a1d:
        adc    $0x24,%al
L_004a1f:
        call L_00528c
