# combat_hit_msg — monster hits the player
# name-evidence: string '--HIT!!!'
# func 2BEC..2BF7  len 000C B  evidence: seed+reko
# strings: "--HIT!!!"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
combat_hit_msg:
L_002dec:
        call L_0051df
        db "--HIT!!!",0x00        # string
