# sub_4fbe — mechanical clean (bulk wave); behavior not yet reviewed
# func 4FBE..4FC4  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4fbe:
L_0051be:
        cmp    %cs:0x4f09(%bx),%ah
L_0051c3:
        je L_0051cc
