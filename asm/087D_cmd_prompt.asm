# cmd_prompt — prints the 'CMD: ' input prompt
# name-evidence: string 'CMD: '
# func 087D..0886  len 000A B  evidence: seed+reko
# strings: "CMD: "
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
cmd_prompt:
L_000a7d:
        nop
L_000a7e:
        call L_0051df
        db "CMD: ",0x00        # string
