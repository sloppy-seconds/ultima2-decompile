# sub_06cc — mechanical clean (bulk wave); behavior not yet reviewed
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
