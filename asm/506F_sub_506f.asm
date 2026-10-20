# sub_506f — mechanical clean (bulk wave); behavior not yet reviewed
# func 506F..5079  len 000B B  evidence: seed+reko
# strings: "FEMALE"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_506f:
L_00526f:
        call L_0051df
        db "FEMALE",0x00        # string
L_005279:
        .byte 0xc3  # forced-kept: gas re-encodes 'ret' differently
