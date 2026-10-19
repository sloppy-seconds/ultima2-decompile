# sub_353d — mechanical clean (bulk wave); behavior not yet reviewed
# func 353D..3545  len 0009 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_353d:
L_00373d:
        push   %ds
L_00373e:
        dec    %cx
L_00373f:
        add    %cl,0xbfb(%bp,%di)
L_003743:
        push   0x1f(%si)
