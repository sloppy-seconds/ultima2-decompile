# sub_06d7 — part of asm/06AC_clock_tick_wait: `dec %ax ; jne` — the busy delay itself, the
#           pass whose count lands in DS:74. Fragment; read the owner.
# func 06D7..06D9  len 0003 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_06d7:
L_0008d7:
        dec    %ax
L_0008d8:
        jne L_0008d7
