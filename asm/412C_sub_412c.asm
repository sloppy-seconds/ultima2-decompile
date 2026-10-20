# sub_412c — mechanical clean (bulk wave); behavior not yet reviewed
# func 412C..415A  len 002F B  evidence: seed+reko
# strings: "A MERCHANT SAYS:"
# calls: L_000c33, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_412c:
L_00432c:
        call L_0051df
        db "A MERCHANT SAYS:",0x0d,"WILL YOU BUY MY APPLES?",0x00        # string
L_004358:
        jmp L_000c33
