# sub_486d — mechanical clean (bulk wave); behavior not yet reviewed
# func 486D..4879  len 000D B  evidence: reko
# calls: L_00528c
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_486d:
L_004a6d:
        fisttps 0x1f1e(%bx,%si)
L_004a71:
        add    %cl,-0x739(%bp,%di)
L_004a75:
        adc    $0x2e,%al
L_004a77:
        call L_00528c
