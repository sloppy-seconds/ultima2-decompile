# sub_212a — +1 HP regen, taken only when mon_hp < 0x10 (asm/2122 falls through here)
# func 212A..212D  len 0004 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_212a:
L_00232a:
        incb   0x177(%di)
