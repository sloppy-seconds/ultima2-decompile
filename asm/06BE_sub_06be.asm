# sub_06be — part of asm/06AC_clock_tick_wait: poll A, the pre-window read of the BIOS tick.
#           Fragment of a 65-byte routine; read the owner.
# func 06BE..06C1  len 0004 B  evidence: seed+reko
# seams: clock_int1a
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_06be:
L_0008be:
        mov    $0x0,%ah
L_0008c0:
clock_int1a:
        int $0x1a    # clock_int1a seam
