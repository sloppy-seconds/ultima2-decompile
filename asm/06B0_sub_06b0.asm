# sub_06b0 — part of asm/06AC_clock_tick_wait: save the tick to DS:552:DS:550 and clear the
#           busy-pass counter DS:74. Fragment of a 65-byte routine; read the owner.
# func 06B0..06BD  len 000E B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_06b0:
L_0008b0:
        mov    %cx,0x552
L_0008b4:
        mov    %dx,0x550
L_0008b8:
        movw   $0x0,0x74
