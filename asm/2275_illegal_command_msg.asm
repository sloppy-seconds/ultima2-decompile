# illegal_command_msg — rejects an unknown command letter
# name-evidence: string '-ILLEGAL COMMAND!'
# func 2275..2289  len 0015 B  evidence: seed+reko
# strings: "-ILLEGAL COMMAND!"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
illegal_command_msg:
L_002475:
        call L_0051df
        db "-ILLEGAL COMMAND!",0x00        # string
