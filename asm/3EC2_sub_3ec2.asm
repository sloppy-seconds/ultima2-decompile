# sub_3ec2 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3EC2..3ED0  len 000F B  evidence: seed+reko
# strings: " NOT OWNED!"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3ec2:
L_0040c2:
        call L_0051df
        db " NOT OWNED!",0x00        # string
