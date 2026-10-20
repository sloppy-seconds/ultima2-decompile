# character_dead_msg — announces a character death
# name-evidence: string ' IS DEAD!'
# func 0C8C..0C99  len 000E B  evidence: seed+reko
# strings: " IS DEAD!"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
character_dead_msg:
L_000e8c:
        call L_0051df
        db " IS DEAD!",0x8d,0x00        # string
