# sub_2bad — mechanical clean (bulk wave); behavior not yet reviewed
# func 2BAD..2BBD  len 0011 B  evidence: seed+reko
# strings: "PARALIZED!"
# calls: L_000c30, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2bad:
L_002dad:
        call L_0051df
        db "PARALIZED!",0x00        # string
L_002dbb:
        jmp L_000c30
