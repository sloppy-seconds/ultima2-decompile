# sub_488c — mechanical clean (bulk wave); behavior not yet reviewed
# func 488C..4899  len 000E B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_488c:
L_004a8c:
        add    %cl,0x1f1e(%bp,%si)
L_004a90:
        add    %cl,-0x7505(%bp,%di)
L_004a94:
        test   %dx,%si
L_004a96:
        add    %ch,%al
L_004a98:
        sbb    (%bp,%di),%cx
