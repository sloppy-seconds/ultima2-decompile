# sub_2f7f — mechanical clean (bulk wave); behavior not yet reviewed
# func 2F7F..2F95  len 0017 B  evidence: seed+reko
# calls: L_000c30, L_0051df (str_out), L_00527a
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2f7f:
L_00317f:
        call L_0051df
        db 0x8d,"THINK AGAIN ",0x00        # string
L_003190:
        call L_00527a
L_003193:
        jmp L_000c30
