# sub_06c6 — part of asm/06AC_clock_tick_wait: `cmp 0x550,%dx ; je 06BE` — if the tick low has
#           not moved since the window opened, poll again without counting a pass. Fragment;
#           read the owner.
# func 06C6..06CB  len 0006 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_06c6:
L_0008c6:
        cmp    0x550,%dx
L_0008ca:
        je L_0008be
