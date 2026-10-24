# sub_06d4 — part of asm/06AC_clock_tick_wait: `mov $0x64,%ax` — the 100-iteration delay
#           constant, i.e. the unit of the thing being counted. Fragment; read the owner.
# func 06D4..06D6  len 0003 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_06d4:
L_0008d4:
        mov    $0x64,%ax
