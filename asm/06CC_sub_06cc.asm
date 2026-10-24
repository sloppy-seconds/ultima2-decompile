# sub_06cc — part of asm/06AC_clock_tick_wait: poll B, the head of the measured loop — this is
#           the third and load-bearing INT 1Ah read, and the target of the 20-tick back-edge.
#           Fragment; read the owner.
# func 06CC..06CF  len 0004 B  evidence: seed+reko
# seams: clock_int1a
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_06cc:
L_0008cc:
        mov    $0x0,%ah
L_0008ce:
clock_int1a:
        int $0x1a    # clock_int1a seam
