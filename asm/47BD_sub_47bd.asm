# sub_47bd — mechanical clean (bulk wave); behavior not yet reviewed
# func 47BD..47C9  len 000D B  evidence: reko
# calls: L_00528c
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_47bd:
L_0049bd:
        fisttps 0x1f1e(%bx,%si)
L_0049c1:
        add    %cl,-0x739(%bp,%di)
L_0049c5:
        adc    $0x1d,%al
L_0049c7:
        call L_00528c
