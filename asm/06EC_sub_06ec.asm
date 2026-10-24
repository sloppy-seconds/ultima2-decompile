# sub_06ec — the single `ret` of asm/06AC_clock_tick_wait, and the reason the detector graded
#           06CC..06EC as a split: exactly one return in the run. Returns with DS:74 = busy
#           passes per 20 ticks. Fragment; read the owner.
# func 06EC..06EC  len 0001 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_06ec:
L_0008ec:
        ret
